#!/bin/bash
# (선택) pmset disablesleep 0/1 두 명령만 암호 없이 실행하도록 허용
# 앱은 처음 암호 창이 뜰 때 같은 규칙을 자동으로 등록합니다.
# 첫 암호 창 없이 미리 등록하거나, SwiftBar 플러그인을 쓸 때 실행하세요.
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
