# Active Context: chore/auto-dev-to-master-pr

## Why

- Branch: `chore/auto-dev-to-master-pr` (9 commits ahead of develop)
- Purpose: auto dev to master pr

## Progress
ae6155183 fix: prevent script injection and add merge safety checks
ec23b81d3 feat: add auto-merge after 24h grace period
c7be56e6b chore: replace Slack with PR comment reminder + team mention
0ebc9b87a chore: improve PR title, add Slack reminder for stale PRs
dcbbceb83 fix: use BOT_TOKEN for team reviewer assignment
f35d75c16 fix: separate PR creation and team reviewer assignment
a83986d85 chore: improve auto dev-to-master PR workflow
5da0098c1 chore: add workflow_dispatch trigger for testing
a96f5be40 chore: replace periodic-build with auto dev-to-master PR workflow

### Changed Files
```
.github/workflows/auto-dev-to-master-pr.yml
.github/workflows/periodic-build.yml
```
Stats:  2 files changed, 326 insertions(+), 67 deletions(-)

## Next
- (auto-generated — update with current next steps)

## Open Questions
- (none yet)

---
*Auto-generated on 2026-03-31 18:20. Update manually or via `/clear`.*
