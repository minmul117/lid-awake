#!/bin/bash
# (선택) pmset disablesleep 0/1 두 명령만 암호 없이 실행하도록 허용
# 이 설정이 없으면 켜고 끌 때마다 관리자 암호 창이 뜹니다.
# 제거: sudo rm /etc/sudoers.d/lidawake
set -euo pipefail

USER_NAME="$(whoami)"
TMP="$(mktemp)"
cat > "$TMP" <<EOF
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
EOF

# 문법 검사 후에만 설치
sudo visudo -cf "$TMP"
sudo install -m 0440 -o root -g wheel "$TMP" /etc/sudoers.d/lidawake
rm -f "$TMP"
echo "등록 완료: /etc/sudoers.d/lidawake"
