#!/bin/bash
# 빌드 → /Applications 설치 → 실행 (기존 버전은 종료 후 교체)
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

pkill -x LidAwake 2>/dev/null || true
sleep 0.5
rm -rf /Applications/LidAwake.app
cp -R build/LidAwake.app /Applications/
open /Applications/LidAwake.app
echo "설치 완료: /Applications/LidAwake.app"
