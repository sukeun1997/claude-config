# HTML Template — Dark Glassmorphism 대시보드

`--html` 플래그 시 사용. 기존 `ai-news-dashboard.html` 디자인 계승.

## 생성 규칙

1. 파일 경로: `/tmp/briefing-{date}.html` (date: YYYY-MM-DD)
2. 생성 후: `Bash("open /tmp/briefing-{date}.html")`
3. open 실패 시: 파일 경로 출력

## 데이터 바인딩

Phase 2 결과를 아래 구조로 변환하여 HTML에 삽입:

각 카드 = {
  tier: "HIGH" | "MED" | "LOW",
  score: 95,
  title: "항목 제목",
  desc: "2-3줄 요약",
  action: "적용 방법",
  category: "ai-tools" | "backend" | "infra" | "community",
  url: "출처 URL",
  source: "소스명"
}

## 전체 HTML 템플릿

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI 뉴스 브리핑 {date} | 맞춤 추천 대시보드</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600;700&family=Fira+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0a0a1a;--bg2:#0f0f23;--bg3:#151530;
  --glass:rgba(255,255,255,.04);--glass-border:rgba(255,255,255,.08);
  --high:#66bb6a;--high-bg:rgba(102,187,106,.08);--high-border:rgba(102,187,106,.25);
  --med:#ffa726;--med-bg:rgba(255,167,38,.06);--med-border:rgba(255,167,38,.2);
  --low:#78909c;--low-bg:rgba(120,144,156,.06);--low-border:rgba(120,144,156,.18);
  --accent:#4fc3f7;--accent2:#7c4dff;
  --text:#e2e8f0;--text2:#94a3b8;--text3:#64748b;
  --font-sans:'Fira Sans',system-ui,-apple-system,sans-serif;
  --font-mono:'Fira Code',monospace;
  --radius:16px;--radius-sm:10px;
}
@media(prefers-reduced-motion:reduce){*{animation:none!important;transition-duration:0s!important}}
html{scroll-behavior:smooth}
body{font-family:var(--font-sans);background:var(--bg);color:var(--text);min-height:100vh;line-height:1.6;overflow-x:hidden}

/* Ambient background */
.ambient{position:fixed;inset:0;z-index:0;overflow:hidden;pointer-events:none}
.ambient .orb{position:absolute;border-radius:50%;filter:blur(120px);opacity:.12;animation:float 20s ease-in-out infinite}
.ambient .orb:nth-child(1){width:600px;height:600px;background:var(--accent);top:-10%;left:-5%;animation-delay:0s}
.ambient .orb:nth-child(2){width:500px;height:500px;background:var(--accent2);bottom:-10%;right:-5%;animation-delay:-7s}
.ambient .orb:nth-child(3){width:400px;height:400px;background:var(--high);top:40%;left:50%;animation-delay:-14s}
@keyframes float{0%,100%{transform:translate(0,0) scale(1)}33%{transform:translate(30px,-40px) scale(1.05)}66%{transform:translate(-20px,30px) scale(.95)}}

.container{position:relative;z-index:1;max-width:1280px;margin:0 auto;padding:32px 24px 64px}

/* Header */
.header{text-align:center;margin-bottom:48px}
.header-badge{display:inline-flex;align-items:center;gap:8px;padding:6px 16px;border-radius:99px;background:rgba(79,195,247,.1);border:1px solid rgba(79,195,247,.2);font-size:13px;color:var(--accent);font-weight:500;margin-bottom:16px;letter-spacing:.02em}
.header-badge svg{width:14px;height:14px}
.header h1{font-size:clamp(28px,4vw,42px);font-weight:700;background:linear-gradient(135deg,var(--text),var(--accent));-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;line-height:1.2;margin-bottom:8px}
.header p{color:var(--text2);font-size:15px;max-width:560px;margin:0 auto}

/* Stats row */
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:16px;margin-bottom:48px}
.stat-card{background:var(--glass);border:1px solid var(--glass-border);border-radius:var(--radius-sm);padding:20px 24px;backdrop-filter:blur(12px);transition:border-color .2s,transform .2s}
.stat-card:hover{border-color:rgba(255,255,255,.15);transform:translateY(-2px)}
.stat-label{font-size:12px;color:var(--text3);text-transform:uppercase;letter-spacing:.08em;font-weight:600;margin-bottom:4px}
.stat-value{font-size:32px;font-weight:700;font-family:var(--font-mono);line-height:1.2}
.stat-value.accent{color:var(--accent)}
.stat-value.high{color:var(--high)}
.stat-value.med{color:var(--med)}
.stat-value.low{color:var(--low)}
.stat-sub{font-size:12px;color:var(--text3);margin-top:2px}

/* Section titles */
.section-title{display:flex;align-items:center;gap:12px;margin-bottom:24px;margin-top:8px}
.section-title h2{font-size:18px;font-weight:600;color:var(--text)}
.section-title .line{flex:1;height:1px;background:linear-gradient(90deg,var(--glass-border),transparent)}
.priority-dot{width:10px;height:10px;border-radius:50%;flex-shrink:0}
.priority-dot.high{background:var(--high);box-shadow:0 0 8px rgba(102,187,106,.4)}
.priority-dot.med{background:var(--med);box-shadow:0 0 8px rgba(255,167,38,.3)}
.priority-dot.low{background:var(--low)}

/* Cards */
.cards-high{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:20px;margin-bottom:48px}
.cards-med{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px;margin-bottom:48px}
.cards-low{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:14px;margin-bottom:48px}

.card{position:relative;background:var(--glass);border:1px solid var(--glass-border);border-radius:var(--radius);padding:28px;backdrop-filter:blur(16px);cursor:pointer;transition:transform .25s,border-color .25s,box-shadow .25s;overflow:hidden}
.card::before{content:'';position:absolute;inset:0;border-radius:var(--radius);opacity:0;transition:opacity .3s}
.card:hover{transform:translateY(-4px)}
.card:focus-visible{outline:2px solid var(--accent);outline-offset:2px}

.card.high{border-color:var(--high-border)}
.card.high::before{background:linear-gradient(135deg,rgba(102,187,106,.06),transparent)}
.card.high:hover{border-color:var(--high);box-shadow:0 8px 32px rgba(102,187,106,.12)}
.card.high:hover::before{opacity:1}

.card.med{border-color:var(--med-border);padding:24px}
.card.med::before{background:linear-gradient(135deg,rgba(255,167,38,.05),transparent)}
.card.med:hover{border-color:var(--med);box-shadow:0 6px 24px rgba(255,167,38,.1)}
.card.med:hover::before{opacity:1}

.card.low{border-color:var(--low-border);padding:20px}
.card.low:hover{border-color:var(--low);box-shadow:0 4px 16px rgba(120,144,156,.08)}

.card-header{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:14px}
.badge{display:inline-flex;align-items:center;gap:5px;padding:4px 10px;border-radius:6px;font-size:11px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;flex-shrink:0}
.badge.high{background:var(--high-bg);color:var(--high);border:1px solid var(--high-border)}
.badge.med{background:var(--med-bg);color:var(--med);border:1px solid var(--med-border)}
.badge.low{background:var(--low-bg);color:var(--low);border:1px solid var(--low-border)}
.relevance{font-family:var(--font-mono);font-size:20px;font-weight:700;line-height:1}
.relevance.high{color:var(--high)}
.relevance.med{color:var(--med)}
.relevance.low{color:var(--low)}
.relevance span{font-size:12px;font-weight:400;opacity:.7}

.card-title{font-size:16px;font-weight:600;line-height:1.4;margin-bottom:10px;color:var(--text)}
.card.med .card-title,.card.low .card-title{font-size:15px}

.card-desc{font-size:13px;color:var(--text2);line-height:1.6;margin-bottom:16px}
.card.low .card-desc{margin-bottom:12px}

.card-method{background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.06);border-radius:8px;padding:12px 14px;margin-bottom:16px}
.card-method-label{font-size:11px;color:var(--text3);font-weight:600;text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px}
.card-method-text{font-size:13px;color:var(--text2);line-height:1.5}
.card-method code{font-family:var(--font-mono);font-size:12px;background:rgba(79,195,247,.1);color:var(--accent);padding:2px 6px;border-radius:4px}

.card-footer{display:flex;align-items:center;justify-content:space-between;gap:12px}
.card-tag{display:inline-flex;align-items:center;gap:4px;font-size:11px;color:var(--text3);padding:4px 8px;border-radius:5px;background:rgba(255,255,255,.03)}
.card-tag svg{width:12px;height:12px;opacity:.6}
.card-link{display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:500;color:var(--accent);text-decoration:none;padding:6px 14px;border-radius:8px;background:rgba(79,195,247,.08);border:1px solid rgba(79,195,247,.15);transition:all .2s}
.card-link:hover{background:rgba(79,195,247,.15);border-color:rgba(79,195,247,.3);transform:translateX(2px)}
.card-link svg{width:14px;height:14px;transition:transform .2s}
.card-link:hover svg{transform:translateX(3px)}

/* User profile bar */
.profile-bar{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin-bottom:40px}
.profile-chip{display:inline-flex;align-items:center;gap:6px;padding:5px 12px;border-radius:99px;font-size:12px;color:var(--text2);background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.06)}
.profile-chip svg{width:13px;height:13px;opacity:.5}

/* Footer */
.footer{text-align:center;padding-top:32px;border-top:1px solid var(--glass-border);color:var(--text3);font-size:13px}

/* Responsive */
@media(max-width:768px){
  .container{padding:20px 16px 48px}
  .stats{grid-template-columns:repeat(2,1fr)}
  .cards-high,.cards-med,.cards-low{grid-template-columns:1fr}
  .header h1{font-size:24px}
}
@media(max-width:480px){
  .stats{grid-template-columns:1fr}
}
</style>
</head>
<body>
<div class="ambient"><div class="orb"></div><div class="orb"></div><div class="orb"></div></div>
<div class="container">

<!-- Header -->
<header class="header">
  <div class="header-badge">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/></svg>
    {date} AI Daily Brief
  </div>
  <h1>AI 뉴스 맞춤 추천 대시보드</h1>
  <p>현재 워크플로우 기반으로 분석한 적용 가능한 뉴스와 구체적인 실행 방법</p>
</header>

<!-- Profile chips (워크플로우 키워드 기반으로 동적 생성) -->
<div class="profile-bar">
  {profile_chips}
</div>

<!-- Stats -->
<div class="stats">
  <div class="stat-card">
    <div class="stat-label">전체 분석 항목</div>
    <div class="stat-value accent">{total_count}</div>
    <div class="stat-sub">{category_count}개 카테고리에서 선별</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">즉시 적용</div>
    <div class="stat-value high">{high_count}</div>
    <div class="stat-sub">지금 바로 워크플로우에 반영</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">참고/학습</div>
    <div class="stat-value med">{med_count}</div>
    <div class="stat-sub">아키텍처 결정 시 활용</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">관심 분야</div>
    <div class="stat-value low">{low_count}</div>
    <div class="stat-sub">필요 시 탐색</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">평균 적합도</div>
    <div class="stat-value accent">{avg_score}<span style="font-size:16px;opacity:.6">%</span></div>
    <div class="stat-sub">프로필 매칭 기준</div>
  </div>
</div>

<!-- HIGH PRIORITY -->
<div class="section-title">
  <span class="priority-dot high"></span>
  <h2>즉시 적용 가능</h2>
  <span class="line"></span>
</div>
<div class="cards-high">
  {high_cards}
</div>

<!-- MEDIUM PRIORITY -->
<div class="section-title">
  <span class="priority-dot med"></span>
  <h2>참고 / 학습</h2>
  <span class="line"></span>
</div>
<div class="cards-med">
  {med_cards}
</div>

<!-- LOW PRIORITY -->
<div class="section-title">
  <span class="priority-dot low"></span>
  <h2>관심 분야</h2>
  <span class="line"></span>
</div>
<div class="cards-low">
  {low_cards}
</div>

<!-- Footer -->
<footer class="footer">
  Generated by Claude Code + OMC &middot; AI News Briefing {date} &middot; Personalized for your workflow
</footer>

</div>
</body>
</html>
```

## 카드 HTML 구조

```html
<div class="card {tier}" onclick="window.open('{url}','_blank')">
  <div class="card-header">
    <span class="badge {tier}">{TIER}</span>
    <div class="relevance {tier}">{score}<span>%</span></div>
  </div>
  <div class="card-title">{title}</div>
  <div class="card-desc">{desc}</div>
  <div class="card-method">
    <div class="card-method-label">적용 방법</div>
    <div class="card-method-text">{action}</div>
  </div>
  <div class="card-footer">
    <span class="card-tag">{category}</span>
    <a href="{url}" class="card-link">자세히 보기</a>
  </div>
</div>
```

## 구현 지시

HTML 파일 전체를 Write 도구로 한번에 생성한다. CSS는 `<style>` 태그에 인라인.
Phase 2 결과의 카드 데이터를 반복하여 카드 HTML 생성.
