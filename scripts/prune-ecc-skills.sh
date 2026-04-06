#!/usr/bin/env bash
# ECC 스킬 경량화 스크립트
# 사용하는 스킬만 남기고 나머지를 backup 후 제거
# ECC 업데이트 시 복원되므로, 업데이트 후 재실행 필요

set -euo pipefail

ECC_SKILLS_DIR="$HOME/.claude/plugins/cache/everything-claude-code/ecc/1.10.0/skills"
BACKUP_DIR="$HOME/.claude/plugins/cache/everything-claude-code/ecc/1.10.0/skills-disabled"

# 보존할 스킬 목록 (줄바꿈 구분)
KEEP_SKILLS="
swiftui-patterns
jpa-patterns
postgres-patterns
database-migrations
springboot-security
security-review
springboot-tdd
swift-protocol-di-testing
springboot-verification
cost-aware-llm-pipeline
kotlin-patterns
kotlin-testing
kotlin-coroutines-flows
kotlin-exposed-patterns
kotlin-ktor-patterns
springboot-patterns
java-coding-standards
django-patterns
django-tdd
django-verification
django-security
python-patterns
python-testing
hexagonal-architecture
docker-patterns
git-workflow
coding-standards
backend-patterns
api-design
deployment-patterns
tdd-workflow
verification-loop
continuous-learning-v2
context-budget
documentation-lookup
eval-harness
search-first
safety-guard
strategic-compact
skill-stocktake
configure-ecc
codebase-onboarding
architecture-decision-records
prompt-optimizer
rules-distill
swift-actor-persistence
swift-concurrency-6-2
compose-multiplatform-patterns
android-clean-architecture
"

if [ ! -d "$ECC_SKILLS_DIR" ]; then
  echo "ERROR: ECC skills directory not found: $ECC_SKILLS_DIR"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

moved=0
kept=0

for skill_dir in "$ECC_SKILLS_DIR"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")

  if echo "$KEEP_SKILLS" | grep -qx "$skill_name"; then
    kept=$((kept + 1))
  else
    mv "$skill_dir" "$BACKUP_DIR/"
    moved=$((moved + 1))
  fi
done

echo "=== ECC 스킬 경량화 완료 ==="
echo "보존: ${kept}개"
echo "비활성화: ${moved}개 → $BACKUP_DIR"
echo ""
echo "복원하려면: mv $BACKUP_DIR/* $ECC_SKILLS_DIR/"
echo "ECC 업데이트 후 재실행 필요: bash ~/.claude/scripts/prune-ecc-skills.sh"
