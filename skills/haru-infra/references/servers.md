# SSH 서버 접속 정보

## OCI ARM (Always Free)
- `ssh -i ~/.ssh/id_ed25519 ubuntu@158.179.165.211`
- 4 OCPU / 24GB RAM, Ubuntu 24.04 aarch64, ap-chuncheon-1
- 뉴스 수집기: `/home/ubuntu/news/` (매일 09:00 KST 크론잡)
- 트리거: "oracle 접속해서 ~해줘" → OCI ARM에 SSH 후 작업 수행

## AWS EC2 (사용 중단 예정)
- `ssh -i ~/Downloads/as22.pem ec2-user@13.209.41.117`
- t3.micro, ap-northeast-2, 크론잡 삭제 완료 (2026-02-21)
- 트리거: "aws 접속해서 ~해줘" → AWS EC2에 SSH 후 작업 수행
