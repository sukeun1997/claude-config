# Haru Project History

## v379 (iOS App)
- repo: sukeun1997/v379, branch: main, 로컬: /Users/sukeun/379
- v379 서버 포트: 8584 (v373은 8484)
- 브랜치 전략: 모든 PR base = main (feat/phase1 은퇴)

## iOS Features (완료)
- EventKit 연동: CalendarManager actor, iCloud 우선 + fallback, endDate=startDate(종일)
- 캘린더 CRUD: DayDetail 집중형, optimistic update, EKEventEditWrapper iOS only
- Phase 4 완료: P4-2(자연어 필터) + P4-4(타임블로킹), 워크트리 feat-phase4-p2-p4
- JaCoCo 커버리지 73%
- StoreKit 2 Freemium 모델: Free (리스트 3개, 기본 기능) / Pro ₩3,900/월 or ₩29,000/년
- 위젯 3종: Small + Medium + LockScreen (WidgetKit)
- Pro 잠금 패턴: .proGated() ViewModifier + PaywallView
- 온보딩 5스텝 구현 완료
- RitualScheduler — 하루 자동 시작/마감 스케줄러

## Infrastructure (완료)
- harutodo.com 도메인 + HTTPS 활성화 완료
- GitHub Pages 법적 문서: https://sukeun1997.github.io/haru-legal/
- LGTM 풀스택 옵저버빌리티: Prometheus + Grafana + Loki + Alloy + Tempo
- Grafana 대시보드 import 시 ${DS_*} → datasource uid 문자열 교체 + __inputs 제거 필수
- Haru LGTM Phase 1 운영 중: Prometheus+Grafana, OCI 158.179.165.211

## 품질
- @BatchSize N+1 해결, DateFormatter 중앙화, Color(hex:) 통합

## 기타
- 게임 프로젝트 "Empires in Your Pocket": Godot 4.6, 모바일 4X, Offset hex (휴면)
