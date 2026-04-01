---
name: reflect
description: Session retrospective - summarize what went well, what didn't, and lessons learned
user_invocable: true
---

# Reflect Skill

세션/스프린트 종료 시 회고를 수행하여 학습을 메모리에 영속화합니다.

## Trigger

- 사용자가 `/reflect` 호출
- 긴 세션(5+ 구현 작업) 종료 시 자동 제안

## Steps

1. **세션 활동 수집**
   - 현재 대화에서 수행한 작업 목록 정리
   - `git log --oneline -20` 으로 최근 커밋 확인
   - 생성/수정된 파일 수, 테스트 결과, 빌드 성공/실패 횟수 파악

2. **회고 프레임워크 (3L)**
   아래 세 가지 관점으로 세션을 분석:

   ### Liked (잘된 것)
   - 효율적이었던 접근 방식
   - 재사용할 만한 패턴/기법
   - 예상보다 빠르게 해결된 것

   ### Lacked (부족했던 것)
   - 삽질/시행착오가 있었던 부분
   - 사전에 알았으면 좋았을 정보
   - 비효율적이었던 도구 사용

   ### Learned (배운 것)
   - 새로 발견한 코드베이스 지식
   - 디버깅 인사이트
   - 향후 세션에 적용할 개선점

3. **결과물 생성**
   회고 결과를 마크다운 테이블로 정리:

   ```markdown
   ## Session Reflect - {date}

   | Category | Item |
   |----------|------|
   | Liked    | ... |
   | Lacked   | ... |
   | Learned  | ... |

   ### Action Items
   - [ ] ...
   ```

4. **메모리 영속화**
   - **Learned** 항목 중 향후 세션에 유용한 것 → 메모리 파일로 저장 (feedback 또는 project 타입)
   - **Lacked** 항목 중 반복 방지가 필요한 것 → feedback 메모리로 저장
   - 이미 존재하는 메모리와 중복 확인 후 업데이트 또는 신규 생성

5. **다음 세션 제안**
   - 미완료 작업이 있으면 다음 세션 시작 시 참고할 컨텍스트 정리
   - 필요한 경우 태스크/FD 파일 업데이트 제안
