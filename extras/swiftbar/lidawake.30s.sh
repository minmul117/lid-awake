#!/bin/bash
# <xbar.title>Lid Awake</xbar.title>
# <xbar.desc>뚜껑을 닫아도 Mac이 잠들지 않게 (pmset disablesleep + caffeinate)</xbar.desc>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
#
# 파일명의 .30s. = 30초마다 상태 갱신 (배터리 보호 체크 포함)

PMSET=/usr/bin/pmset
MIN_BATTERY=20          # 배터리 사용 중 이 % 아래로 떨어지면 자동으로 끔
SELF="$0"

turn_on() {
  sudo -n $PMSET -a disablesleep 1
  if ! pgrep -qf "caffeinate -dimsu"; then
    nohup /usr/bin/caffeinate -dimsu >/dev/null 2>&1 &
    disown
  fi
}

turn_off() {
  sudo -n $PMSET -a disablesleep 0
  pkill -f "caffeinate -dimsu"
}

case "$1" in
  on)  turn_on;  exit 0 ;;
  off) turn_off; exit 0 ;;
esac

state=$($PMSET -g | awk '/SleepDisabled/ {print $2}')
batt=$($PMSET -g batt)
percent=$(echo "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
on_ac=false
echo "$batt" | head -1 | grep -q "AC Power" && on_ac=true

# 배터리 보호: 전원 미연결 + 잔량 부족이면 자동 해제
if [ "$state" = "1" ] && [ "$on_ac" = false ] && [ -n "$percent" ] && [ "$percent" -lt "$MIN_BATTERY" ]; then
  turn_off
  state=0
  osascript -e "display notification \"배터리 ${percent}% — 잠자기 방지를 껐습니다\" with title \"Lid Awake\""
fi

# 메뉴 막대 아이콘
if [ "$state" = "1" ]; then
  echo " | sfimage=cup.and.saucer.fill"
else
  echo " | sfimage=cup.and.saucer"
fi

echo "---"
if [ "$state" = "1" ]; then
  echo "● 깨어 있음 (뚜껑 닫아도 유지)"
  echo "끄기 | bash='$SELF' param1=off terminal=false refresh=true"
else
  echo "○ 꺼짐 (평소처럼 잠자기)"
  echo "켜기 | bash='$SELF' param1=on terminal=false refresh=true"
fi
echo "---"
if [ "$on_ac" = true ]; then
  echo "전원: 어댑터 연결됨 · ${percent}% | color=gray"
else
  echo "전원: 배터리 ${percent}% (${MIN_BATTERY}% 미만 시 자동 해제) | color=gray"
fi
