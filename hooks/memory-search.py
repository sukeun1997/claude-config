#!/usr/bin/env python3
"""
memory-search.py — Hybrid BM25 + Vector + MMR Memory Search (v2)

CLI:
  index --file <path>                        # Index a single file
  reindex [--force-reindex]                  # Reindex all memory files
  search "query" [-k 5] [--mode] [--compact] # Search
    --mode hybrid|vector|bm25               # Search mode (default: hybrid)
    --mmr [--mmr-lambda 0.7]                # MMR re-ranking (opt-in)
  self-test                                  # Auto verification
  stats                                      # Index statistics
  cache-stats / cache-clear                  # Embedding cache
  migrate [--force-reindex]                  # Manual migration

Requires: pip install google-genai, export GEMINI_API_KEY
"""

import argparse
import base64
import hashlib
import json
import math
import os
import re
import sqlite3
import struct
import sys
import tempfile
import time
from datetime import date, datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

EMBEDDING_MODEL = "gemini-embedding-001"
EMBEDDING_DIM = 768
DB_VERSION = "2"

MIN_SCORE = 0.35
TEMPORAL_DECAY_LAMBDA = 0.023  # ln(2)/30 ≈ 0.023 (30-day half-life)
TEMPORAL_WEIGHT = 0.15
RRF_K = 60

_CWD = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
_PROJECT_ID = _CWD.replace("/", "-")
MEMORY_DIR = Path.home() / ".claude" / "projects" / _PROJECT_ID / "memory"
VECTORS_DIR = MEMORY_DIR / "vectors"
DB_FILE = VECTORS_DIR / "memory.db"
INDEX_FILE = VECTORS_DIR / "index.json"  # Legacy, for migration

SCAN_DIRS = ["daily", "archive", "topics"]
SKIP_FILES = set()  # Previously excluded MEMORY.md; now index everything
DAILY_CHUNK_RE = re.compile(r"^### (\d{2}:\d{2}) - (.+)$", re.MULTILINE)

# ---------------------------------------------------------------------------
# Embedding client (lazy init)
# ---------------------------------------------------------------------------

_client = None


def get_client():
    global _client
    if _client is not None:
        return _client
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        zshrc = Path.home() / ".zshrc"
        if zshrc.exists():
            for line in zshrc.read_text().splitlines():
                m = re.match(r'^export\s+GEMINI_API_KEY[= ]"?([^"]+)"?', line)
                if m:
                    api_key = m.group(1).strip()
                    break
    if not api_key:
        print("Error: GEMINI_API_KEY not set.", file=sys.stderr)
        sys.exit(1)
    try:
        from google import genai
        _client = genai.Client(api_key=api_key)
        return _client
    except ImportError:
        print("Error: google-genai not installed. pip install google-genai", file=sys.stderr)
        sys.exit(1)


def embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed texts via Gemini API."""
    if not texts:
        return []
    client = get_client()
    from google.genai import types
    vectors = []
    for i in range(0, len(texts), 100):
        resp = client.models.embed_content(
            model=EMBEDDING_MODEL, contents=texts[i:i + 100],
            config=types.EmbedContentConfig(output_dimensionality=EMBEDDING_DIM),
        )
        vectors.extend(emb.values for emb in resp.embeddings)
    return vectors


# ---------------------------------------------------------------------------
# Vector encoding
# ---------------------------------------------------------------------------

def vec_to_blob(vec: list[float]) -> bytes:
    return struct.pack(f"{len(vec)}f", *vec)


def blob_to_vec(blob: bytes) -> list[float]:
    return list(struct.unpack(f"{len(blob) // 4}f", blob))


def vec_to_base64(vec: list[float]) -> str:
    return base64.b64encode(vec_to_blob(vec)).decode("ascii")


def base64_to_vec(b64: str) -> list[float]:
    return blob_to_vec(base64.b64decode(b64))


def vec_norm(vec: list[float]) -> float:
    return math.sqrt(sum(x * x for x in vec))


def cosine_sim(a, norm_a, b, norm_b):
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return sum(x * y for x, y in zip(a, b)) / (norm_a * norm_b)


def temporal_boost(chunk_date: str) -> float:
    if not chunk_date or chunk_date == "unknown":
        return 1.0
    try:
        d = datetime.strptime(chunk_date, "%Y-%m-%d").date()
        days = max(0, (date.today() - d).days)
        return 1.0 + TEMPORAL_WEIGHT * math.exp(-TEMPORAL_DECAY_LAMBDA * days)
    except ValueError:
        return 1.0


def text_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


# ---------------------------------------------------------------------------
# Embedding cache (Phase 1)
# ---------------------------------------------------------------------------

def embed_texts_cached(texts: list[str], db: sqlite3.Connection) -> list[list[float]]:
    """Embed texts with SQLite caching. Cache hits skip API call."""
    if not texts:
        return []
    hashes = [text_hash(t) for t in texts]
    results = [None] * len(texts)
    uncached = []
    for i, h in enumerate(hashes):
        row = db.execute(
            "SELECT vector FROM embedding_cache WHERE text_hash=?", (h,)
        ).fetchone()
        if row:
            results[i] = blob_to_vec(row[0])
        else:
            uncached.append(i)
    if uncached:
        vecs = embed_texts([texts[i] for i in uncached])
        now = time.strftime("%Y-%m-%dT%H:%M:%S")
        for idx, vec in zip(uncached, vecs):
            results[idx] = vec
            db.execute(
                "INSERT OR REPLACE INTO embedding_cache VALUES (?,?,?)",
                (hashes[idx], vec_to_blob(vec), now),
            )
        db.commit()
    return results


# ---------------------------------------------------------------------------
# SQLite database (Phase 2)
# ---------------------------------------------------------------------------

_SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS chunks (
    id TEXT PRIMARY KEY, source TEXT NOT NULL, date TEXT, topic TEXT,
    text TEXT NOT NULL, vector BLOB, norm REAL, content_hash TEXT, indexed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_chunks_source ON chunks(source);
CREATE TABLE IF NOT EXISTS files (
    path TEXT PRIMARY KEY, content_hash TEXT, indexed_at TEXT
);
CREATE TABLE IF NOT EXISTS embedding_cache (
    text_hash TEXT PRIMARY KEY, vector BLOB NOT NULL, created_at TEXT
);
"""


def get_db(db_path: Path = None) -> sqlite3.Connection:
    """Open or create SQLite database with schema and FTS5."""
    if db_path is None:
        db_path = DB_FILE
    db_path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(str(db_path))
    db.execute("PRAGMA journal_mode=WAL")

    # Integrity check
    try:
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            db.close()
            db_path.unlink(missing_ok=True)
            db = sqlite3.connect(str(db_path))
            db.execute("PRAGMA journal_mode=WAL")
            print("WARNING: DB corrupted, recreated.", file=sys.stderr)
    except Exception:
        pass

    db.executescript(_SCHEMA)

    # FTS5 virtual table + sync triggers
    try:
        db.execute("SELECT 1 FROM chunks_fts LIMIT 0")
    except sqlite3.OperationalError:
        db.execute(
            "CREATE VIRTUAL TABLE chunks_fts USING fts5("
            "text, topic, content='chunks', content_rowid='rowid', "
            "tokenize='unicode61 remove_diacritics 2')"
        )
        db.executescript("""
            CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
                INSERT INTO chunks_fts(rowid, text, topic)
                VALUES (new.rowid, new.text, new.topic);
            END;
            CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
                INSERT INTO chunks_fts(chunks_fts, rowid, text, topic)
                VALUES('delete', old.rowid, old.text, old.topic);
            END;
            CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
                INSERT INTO chunks_fts(chunks_fts, rowid, text, topic)
                VALUES('delete', old.rowid, old.text, old.topic);
                INSERT INTO chunks_fts(rowid, text, topic)
                VALUES (new.rowid, new.text, new.topic);
            END;
        """)
        db.commit()

    db.execute("INSERT OR REPLACE INTO meta VALUES ('version',?)", (DB_VERSION,))
    db.execute("INSERT OR REPLACE INTO meta VALUES ('model',?)", (EMBEDDING_MODEL,))
    db.execute("INSERT OR REPLACE INTO meta VALUES ('dimensions',?)", (str(EMBEDDING_DIM),))
    db.commit()
    return db


def migrate_from_json(db: sqlite3.Connection) -> int:
    """Migrate legacy index.json → SQLite. Returns chunk count."""
    if not INDEX_FILE.exists():
        return 0
    try:
        idx = json.loads(INDEX_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, KeyError):
        return 0

    now = time.strftime("%Y-%m-%dT%H:%M:%S")
    count = 0
    for chunk in idx.get("chunks", []):
        vec_data = chunk.get("vector_b64") or chunk.get("vector")
        if not vec_data:
            continue
        vec = base64_to_vec(vec_data) if isinstance(vec_data, str) else vec_data
        norm = chunk.get("norm") or vec_norm(vec)
        db.execute(
            "INSERT OR REPLACE INTO chunks VALUES (?,?,?,?,?,?,?,?,?)",
            (chunk["id"], chunk["source"], chunk.get("date", ""),
             chunk.get("topic", ""), chunk["text"],
             vec_to_blob(vec), norm, "", now),
        )
        count += 1

    for path, meta in idx.get("files", {}).items():
        db.execute(
            "INSERT OR REPLACE INTO files VALUES (?,?,?)",
            (path, meta.get("content_hash", ""), meta.get("indexed_at", now)),
        )
    db.commit()

    # Rebuild FTS from migrated data
    db.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
    db.commit()

    # Backup legacy file
    backup = INDEX_FILE.with_suffix(".json.bak")
    backup.unlink(missing_ok=True)
    INDEX_FILE.rename(backup)
    print(f"Migrated {count} chunks from index.json -> memory.db (backup: {backup.name})")
    return count


# ---------------------------------------------------------------------------
# Chunking
# ---------------------------------------------------------------------------

def chunk_daily_log(text: str, source: str) -> list[dict]:
    date_match = re.search(r"(\d{4}-\d{2}-\d{2})\.md$", source)
    d = date_match.group(1) if date_match else "unknown"
    positions = list(DAILY_CHUNK_RE.finditer(text))
    if not positions:
        s = text.strip()
        return [{"id": f"{d}#full", "source": source, "date": d,
                 "topic": "full", "text": s}] if s else []
    chunks = []
    for i, m in enumerate(positions):
        end = positions[i + 1].start() if i + 1 < len(positions) else len(text)
        t = text[m.start():end].strip()
        if t:
            chunks.append({"id": f"{d}#{m.group(1)}", "source": source,
                           "date": d, "topic": m.group(2).strip(), "text": t})
    return chunks


def chunk_topic_file(text: str, source: str) -> list[dict]:
    s = text.strip()
    if not s:
        return []
    name = Path(source).stem
    return [{"id": f"topic:{name}", "source": source, "date": "",
             "topic": name, "text": s}]


# ---------------------------------------------------------------------------
# Indexing
# ---------------------------------------------------------------------------

def file_hash(filepath: Path) -> str:
    return f"sha256:{hashlib.sha256(filepath.read_bytes()).hexdigest()[:16]}"


def index_file(filepath: Path, db: sqlite3.Connection) -> int:
    """Index a single file. Returns new chunk count."""
    rel = str(filepath.relative_to(MEMORY_DIR))
    if filepath.name in SKIP_FILES:
        return 0
    h = file_hash(filepath)
    row = db.execute("SELECT content_hash FROM files WHERE path=?", (rel,)).fetchone()
    if row and row[0] == h:
        return 0

    db.execute("DELETE FROM chunks WHERE source=?", (rel,))
    chunks = chunk_file(filepath, rel)
    if not chunks:
        db.execute("DELETE FROM files WHERE path=?", (rel,))
        db.commit()
        return 0

    vecs = embed_texts_cached([c["text"] for c in chunks], db)
    now = time.strftime("%Y-%m-%dT%H:%M:%S")
    for c, v in zip(chunks, vecs):
        db.execute(
            "INSERT OR REPLACE INTO chunks VALUES (?,?,?,?,?,?,?,?,?)",
            (c["id"], c["source"], c.get("date", ""), c.get("topic", ""),
             c["text"], vec_to_blob(v), round(vec_norm(v), 6),
             text_hash(c["text"]), now),
        )
    db.execute("INSERT OR REPLACE INTO files VALUES (?,?,?)", (rel, h, now))
    db.commit()
    return len(chunks)


def chunk_memory_md(text: str, source: str) -> list[dict]:
    """Chunk MEMORY.md by ## sections."""
    sections = re.split(r"^## ", text, flags=re.MULTILINE)
    chunks = []
    for sec in sections:
        sec = sec.strip()
        if not sec:
            continue
        lines = sec.split("\n", 1)
        topic = lines[0].strip()
        body = ("## " + sec).strip()
        chunk_id = f"memory:{topic[:40]}"
        chunks.append({"id": chunk_id, "source": source, "date": "", "topic": topic, "text": body})
    return chunks


def chunk_file(filepath: Path, rel_path: str) -> list[dict]:
    text = filepath.read_text(encoding="utf-8", errors="replace")
    if not text.strip():
        return []
    if rel_path == "MEMORY.md":
        return chunk_memory_md(text, rel_path)
    if "daily/" in rel_path or "archive/" in rel_path:
        return chunk_daily_log(text, rel_path)
    return chunk_topic_file(text, rel_path)


def collect_memory_files() -> list[Path]:
    files = []
    # Root-level .md files (MEMORY.md, etc.)
    for md in sorted(MEMORY_DIR.glob("*.md")):
        if md.name not in SKIP_FILES:
            files.append(md)
    # Subdirectory files
    for sub in SCAN_DIRS:
        t = MEMORY_DIR / sub
        if t.is_dir():
            files.extend(
                md for md in sorted(t.rglob("*.md")) if md.name not in SKIP_FILES
            )
    return files


# ---------------------------------------------------------------------------
# Search (Phase 2: BM25 + Vector + RRF Hybrid)
# ---------------------------------------------------------------------------

def fts5_sanitize(query: str) -> str:
    """Sanitize query for FTS5: remove special chars, escape operators."""
    q = re.sub(r'[*"()\[\]{}^~]', ' ', query)
    return ' '.join(
        f'"{w}"' if w.upper() in ('AND', 'OR', 'NOT', 'NEAR') else w
        for w in q.split()
    )


def bm25_search(db, query, limit=50):
    """BM25 keyword search via FTS5. Returns chunk IDs ranked by BM25."""
    s = fts5_sanitize(query)
    if not s.strip():
        return []
    try:
        return [r[0] for r in db.execute(
            "SELECT c.id FROM chunks_fts f JOIN chunks c ON c.rowid=f.rowid "
            "WHERE chunks_fts MATCH ? ORDER BY rank LIMIT ?",
            (s, limit),
        ).fetchall()]
    except sqlite3.OperationalError:
        return []


def vector_search(db, query, limit=50):
    """Cosine similarity vector search. Returns (chunk_id, boosted_score) list."""
    q_vec = embed_texts_cached([query], db)[0]
    q_norm = vec_norm(q_vec)
    rows = db.execute(
        "SELECT id, vector, norm, date FROM chunks WHERE vector IS NOT NULL"
    ).fetchall()
    scored = []
    for cid, vblob, n, d in rows:
        v = blob_to_vec(vblob)
        sim = cosine_sim(q_vec, q_norm, v, n or vec_norm(v))
        boosted = sim * temporal_boost(d or "")
        if boosted >= MIN_SCORE:
            scored.append((cid, boosted))
    scored.sort(key=lambda x: x[1], reverse=True)
    return scored[:limit]


def _fetch_results(db, id_scores):
    """Fetch chunk details for (id, score) list."""
    results = []
    for cid, score in id_scores:
        r = db.execute(
            "SELECT source, date, topic, text FROM chunks WHERE id=?", (cid,)
        ).fetchone()
        if r:
            results.append({
                "id": cid, "score": round(score, 6),
                "source": r[0], "date": r[1] or "",
                "topic": r[2] or "", "text": r[3],
            })
    return results


def hybrid_search(db, query, top_k=5):
    """RRF fusion of BM25 + Vector search."""
    bm25_ids = bm25_search(db, query, 50)
    bm25_ranks = {c: r for r, c in enumerate(bm25_ids, 1)}
    vec_res = vector_search(db, query, 50)
    vec_ranks = {c: r for r, (c, _) in enumerate(vec_res, 1)}

    all_ids = set(bm25_ranks) | set(vec_ranks)
    max_r = max(len(bm25_ids), len(vec_res), 1) + 1

    dates = {}
    if all_ids:
        ph = ','.join('?' * len(all_ids))
        dates = dict(db.execute(
            f"SELECT id, date FROM chunks WHERE id IN ({ph})",
            list(all_ids),
        ).fetchall())

    scored = []
    for cid in all_ids:
        rrf = (1.0 / (RRF_K + bm25_ranks.get(cid, max_r))
               + 1.0 / (RRF_K + vec_ranks.get(cid, max_r)))
        scored.append((cid, rrf * temporal_boost(dates.get(cid, ""))))
    scored.sort(key=lambda x: x[1], reverse=True)
    return _fetch_results(db, scored[:top_k])


def search_dispatch(db, query, mode, top_k):
    """Dispatch search by mode."""
    if mode == "bm25":
        ids = bm25_search(db, query, top_k)
        return _fetch_results(db, [(c, 0.0) for c in ids])
    elif mode == "vector":
        return _fetch_results(db, vector_search(db, query, top_k))
    return hybrid_search(db, query, top_k)


# ---------------------------------------------------------------------------
# MMR Re-ranking (Phase 3, opt-in)
# ---------------------------------------------------------------------------

def mmr_rerank(db, candidates, top_k=5, lam=0.7):
    """Maximal Marginal Relevance re-ranking for diversity."""
    if len(candidates) <= top_k:
        return candidates
    vecs = []
    for c in candidates:
        r = db.execute(
            "SELECT vector, norm FROM chunks WHERE id=?", (c["id"],)
        ).fetchone()
        vecs.append((blob_to_vec(r[0]), r[1]) if r and r[0] else None)

    selected, sel_vecs, remaining = [], [], list(range(len(candidates)))
    for _ in range(top_k):
        best_i, best_mmr = None, -float('inf')
        for i in remaining:
            if not vecs[i]:
                continue
            vi, ni = vecs[i]
            max_s = max(
                (cosine_sim(vi, ni, sv, sn) for sv, sn in sel_vecs),
                default=0.0,
            )
            mmr = lam * candidates[i]["score"] - (1 - lam) * max_s
            if mmr > best_mmr:
                best_mmr, best_i = mmr, i
        if best_i is None:
            break
        selected.append(candidates[best_i])
        sel_vecs.append(vecs[best_i])
        remaining.remove(best_i)
    return selected


# ---------------------------------------------------------------------------
# Self-test (Phase 4)
# ---------------------------------------------------------------------------

def cmd_self_test(args):
    """Verify BM25, vector encoding, FTS5 sanitize, and cache."""
    print("Running self-test...")
    with tempfile.TemporaryDirectory() as tmp:
        db = get_db(Path(tmp) / "test.db")
        tests = [
            ("t#1", "t.md", "2026-02-20", "Kafka",
             "Kafka Glue 마이그레이션 ErrorHandlingDeserializer 3단 체인"),
            ("t#2", "t.md", "2026-02-20", "Memory",
             "3계층 메모리 아키텍처 Hot Always Cold Daily Log"),
            ("t#3", "t.md", "2026-02-19", "Spring",
             "TestContainers DynamicPropertySource Docker API"),
        ]
        for i, (cid, src, d, topic, txt) in enumerate(tests):
            v = [0.1] * EMBEDDING_DIM
            v[i] = 0.9
            db.execute(
                "INSERT INTO chunks VALUES (?,?,?,?,?,?,?,?,?)",
                (cid, src, d, topic, txt, vec_to_blob(v), vec_norm(v), "", "now"),
            )
        db.commit()
        db.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
        db.commit()

        errors = []

        # BM25 tests
        r = bm25_search(db, "Kafka Glue", 5)
        if not r or r[0] != "t#1":
            errors.append(f"BM25 'Kafka Glue': expected t#1 first, got {r}")
        if not bm25_search(db, "메모리 아키텍처", 5):
            errors.append("BM25 Korean '메모리 아키텍처' returned empty")
        if not bm25_search(db, "DynamicPropertySource", 5):
            errors.append("BM25 'DynamicPropertySource' returned empty")

        # FTS5 sanitize (quotes around AND/NOT are intentional escaping)
        s = fts5_sanitize('test "q" AND (NOT) *')
        if any(c in s for c in '*()'):
            errors.append(f"fts5_sanitize left special chars: {s}")

        # Vector blob roundtrip
        orig = [0.1, 0.2, -0.5, 0.0, 0.99]
        decoded = blob_to_vec(vec_to_blob(orig))
        if any(abs(a - b) > 1e-6 for a, b in zip(orig, decoded)):
            errors.append("Vector blob roundtrip mismatch")

        # Base64 roundtrip
        b64 = vec_to_base64(orig)
        decoded2 = base64_to_vec(b64)
        if any(abs(a - b) > 1e-6 for a, b in zip(orig, decoded2)):
            errors.append("Vector base64 roundtrip mismatch")

        # Embedding cache CRUD
        db.execute(
            "INSERT INTO embedding_cache VALUES ('th',?,?)",
            (vec_to_blob([0.1] * 10), "now"),
        )
        db.commit()
        if not db.execute(
            "SELECT 1 FROM embedding_cache WHERE text_hash='th'"
        ).fetchone():
            errors.append("Embedding cache insert/retrieve failed")

        db.close()

    if errors:
        print(f"FAILED: {len(errors)} error(s)")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    print("All tests passed.")


# ---------------------------------------------------------------------------
# CLI commands
# ---------------------------------------------------------------------------

def ensure_db():
    """Open DB, auto-migrate from JSON if needed."""
    db = get_db()
    if INDEX_FILE.exists():
        migrate_from_json(db)
    return db


def cmd_index(args):
    fp = Path(args.file).resolve()
    if not fp.exists():
        print(f"Error: {fp} not found", file=sys.stderr)
        sys.exit(1)
    db = ensure_db()
    n = index_file(fp, db)
    total = db.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    db.close()
    print(f"Indexed {n} chunk(s) from {fp.name}. Total: {total} chunks.")


def cmd_reindex(args):
    if getattr(args, 'force_reindex', False):
        DB_FILE.unlink(missing_ok=True)
        print("Force reindex: DB reset.")
    db = ensure_db()
    files = collect_memory_files()
    if not files:
        print("No memory files found to index.")
        db.close()
        return

    existing, total_new = set(), 0
    for f in files:
        rel = str(f.relative_to(MEMORY_DIR))
        existing.add(rel)
        n = index_file(f, db)
        total_new += n
        if n > 0:
            print(f"  {rel}: {n} chunk(s)")

    # Remove stale entries
    all_paths = {r[0] for r in db.execute("SELECT path FROM files").fetchall()}
    stale = all_paths - existing
    for s in stale:
        db.execute("DELETE FROM files WHERE path=?", (s,))
        db.execute("DELETE FROM chunks WHERE source=?", (s,))
    if stale:
        db.commit()

    total = db.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    db.close()
    print(
        f"\nReindex complete: {total_new} new chunk(s), "
        f"{total} total, {len(stale)} stale removed."
    )


def cmd_search(args):
    db = ensure_db()
    mode = getattr(args, 'mode', 'hybrid')
    use_mmr = getattr(args, 'mmr', False)
    k = args.k * (3 if use_mmr else 1)

    results = search_dispatch(db, args.query, mode, k)
    if use_mmr and len(results) > args.k:
        results = mmr_rerank(db, results, args.k, getattr(args, 'mmr_lambda', 0.7))
    db.close()

    if not results:
        print("No results found. Run 'reindex' first if the index is empty.")
        return

    for i, r in enumerate(results, 1):
        if args.compact:
            lines = r["text"].split("\n")
            preview = "\n".join(lines[:3])
            if len(lines) > 3:
                preview += f"\n  ... ({len(lines) - 3} more lines)"
            print(f"[{r['score']}] {r['source']} | {r['topic']} | {preview}")
        else:
            print(f"\n--- Result {i} (score: {r['score']}) ---")
            print(f"Source: {r['source']}")
            if r["date"]:
                print(f"Date: {r['date']}")
            print(f"Topic: {r['topic']}")
            print(f"\n{r['text']}")


def cmd_stats(args):
    db = ensure_db()
    c = db.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    f = db.execute("SELECT COUNT(*) FROM files").fetchone()[0]
    ca = db.execute("SELECT COUNT(*) FROM embedding_cache").fetchone()[0]
    last = db.execute("SELECT MAX(indexed_at) FROM chunks").fetchone()[0]
    db.close()
    sz = DB_FILE.stat().st_size / 1024 if DB_FILE.exists() else 0
    print(f"Chunks: {c}")
    print(f"Files:  {f}")
    print(f"Cache:  {ca} embeddings")
    print(f"DB:     {sz:.1f} KB")
    print(f"Last:   {last or 'never'}")


def cmd_cache_stats(args):
    db = ensure_db()
    c = db.execute("SELECT COUNT(*) FROM embedding_cache").fetchone()[0]
    o = db.execute("SELECT MIN(created_at) FROM embedding_cache").fetchone()[0]
    n = db.execute("SELECT MAX(created_at) FROM embedding_cache").fetchone()[0]
    db.close()
    print(f"Cached: {c}")
    print(f"Oldest: {o or 'none'}")
    print(f"Newest: {n or 'none'}")


def cmd_cache_clear(args):
    db = ensure_db()
    c = db.execute("SELECT COUNT(*) FROM embedding_cache").fetchone()[0]
    db.execute("DELETE FROM embedding_cache")
    db.commit()
    db.close()
    print(f"Cleared {c} cached embedding(s).")


def cmd_migrate(args):
    if getattr(args, 'force_reindex', False):
        DB_FILE.unlink(missing_ok=True)
        db = get_db()
        total = 0
        for f in collect_memory_files():
            n = index_file(f, db)
            total += n
            if n > 0:
                print(f"  {f.relative_to(MEMORY_DIR)}: {n} chunk(s)")
        db.close()
        print(f"Force reindex complete: {total} chunks.")
    elif INDEX_FILE.exists():
        db = get_db()
        n = migrate_from_json(db)
        db.close()
        print(f"Migrated {n} chunks.")
    else:
        print("No index.json found. Nothing to migrate.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description="Hybrid BM25 + Vector Memory Search v2")
    s = p.add_subparsers(dest="command", required=True)

    p_idx = s.add_parser("index", help="Index a single file")
    p_idx.add_argument("--file", required=True, help="Path to .md file")

    p_re = s.add_parser("reindex", help="Reindex all memory files")
    p_re.add_argument("--force-reindex", action="store_true",
                       help="Drop all data and rebuild from source")

    p_sr = s.add_parser("search", help="Search memory")
    p_sr.add_argument("query", help="Search query")
    p_sr.add_argument("-k", type=int, default=5, help="Top K results (default: 5)")
    p_sr.add_argument("--mode", choices=["hybrid", "vector", "bm25"],
                       default="hybrid", help="Search mode (default: hybrid)")
    p_sr.add_argument("--mmr", action="store_true", help="Enable MMR re-ranking")
    p_sr.add_argument("--mmr-lambda", type=float, default=0.7,
                       help="MMR lambda (default: 0.7)")
    p_sr.add_argument("--compact", action="store_true",
                       help="Compact output (saves context tokens)")

    s.add_parser("self-test", help="Run self-test verification")
    s.add_parser("stats", help="Show index statistics")
    s.add_parser("cache-stats", help="Show embedding cache statistics")
    s.add_parser("cache-clear", help="Clear embedding cache")

    p_mig = s.add_parser("migrate", help="Migrate from JSON to SQLite")
    p_mig.add_argument("--force-reindex", action="store_true",
                        help="Drop all and rebuild from source files")

    args = p.parse_args()
    cmds = {
        "index": cmd_index, "reindex": cmd_reindex, "search": cmd_search,
        "self-test": cmd_self_test, "stats": cmd_stats,
        "cache-stats": cmd_cache_stats, "cache-clear": cmd_cache_clear,
        "migrate": cmd_migrate,
    }
    cmds[args.command](args)


if __name__ == "__main__":
    main()
