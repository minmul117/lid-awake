# Lid Awake

외부 모니터 없이 **맥북 뚜껑을 닫아도 잠들지 않게** 해 주는 가벼운 macOS 메뉴 막대 앱입니다.
의존성 없이 Swift 파일 하나로 되어 있습니다.

## 기능

- 메뉴 막대 ☕ 아이콘으로 켜기/끄기 (켜짐: 주황색 채워진 컵, 꺼짐: 흐린 빈 컵)
- 켜면 `pmset -a disablesleep 1` + `caffeinate` 를 함께 적용
- **모드 선택** (메뉴 → 모드, 켜져 있는 중에도 바로 전환, 항목에 마우스를 올리면 설명 툴팁)
  - *시스템 + 화면 유지* (`caffeinate -dims`, 기본값): 뚜껑을 연 채 잠가도 화면이 켜진 상태로 유지
  - *시스템만 유지* (`caffeinate -ims`): 시스템은 깨어 있고 화면은 평소처럼 꺼짐 — 잠금 화면 방치용
  - 두 모드 모두 화면 잠금 상태와 뚜껑 닫힘에서 계속 깨어 있음 (로그아웃하면 앱이 종료되며 해제)
  - 꺼져 있을 때는 모드와 배터리 보호가 잠김 (선택값은 그대로 유지)
- **뚜껑 닫힘 감지**: 뚜껑이 닫히면 모드와 상관없이 화면 유지를 풀고 `pmset displaysleepnow`로 화면을 즉시 끔
  - 닫힌 뚜껑 안에서 화면이 켜져 발열하는 것을 방지
  - "디스플레이가 꺼진 후 암호 요구" 설정이 있으면 화면 잠금이 걸림
  - 뚜껑을 다시 열면 선택한 모드로 복귀
- **배터리 보호**: 배터리 사용 중 잔량이 설정값(10/20/30%, 기본 20%) 미만이면 자동 해제
- **로그인 시 실행** (macOS 13+ `SMAppService`)
- **종료 시 복원**: 앱을 끄면 잠자기 설정을 원래대로 되돌림. `caffeinate`는 `-w <앱 PID>`로 묶여 있어 앱이 죽으면 같이 종료
- 터미널 등 외부에서 바꾼 `pmset` 상태를 30초마다 동기화

## 요구 사항

- macOS 13 Ventura 이상
- Xcode Command Line Tools (`xcode-select --install`)

## 설치 / 업데이트

```bash
git clone <this-repo> && cd lid-awake
make install      # 빌드 → /Applications 교체 설치 → 실행
```

코드를 고친 뒤에도 `make install` 한 번이면 기존 앱을 종료하고 새 버전으로 바꿉니다.

### 관리자 암호 (처음 한 번)

처음 켜거나 끌 때 관리자 암호 창이 한 번 뜹니다. 이때 앱이 `/etc/sudoers.d/lidawake`를 등록해
(`pmset -a disablesleep 0/1` 두 명령만 허용, `visudo` 문법 검사 통과 시에만 설치) 다음부터는 암호 없이 전환됩니다.

첫 암호 창 없이 미리 등록하려면(SwiftBar 플러그인도 이 규칙을 씀):

```bash
make sudoers      # /etc/sudoers.d/lidawake 등록
```

제거: `sudo rm /etc/sudoers.d/lidawake` (`make uninstall`도 함께 제거)

## 명령 요약

| 명령 | 설명 |
| --- | --- |
| `make build` | `build/LidAwake.app` 생성 |
| `make run` | 빌드 후 설치하지 않고 바로 실행 |
| `make install` | 빌드 + `/Applications` 설치 + 실행 |
| `make uninstall` | 종료 + `/Applications`에서 삭제 + sudoers 규칙 제거 |
| `make sudoers` | 암호 없는 전환 규칙 미리 등록 |
| `make clean` | `build/` 삭제 |

## 구조

```
Sources/main.swift          앱 전체 (AppDelegate, 메뉴, pmset/caffeinate 제어)
Resources/Info.plist        번들 정보 (LSUIElement = Dock 아이콘 없음)
VERSION                     버전 — 빌드 시 Info.plist에 주입
scripts/build.sh            swiftc 빌드 + ad-hoc 서명
scripts/install.sh          빌드 + /Applications 교체 설치
scripts/setup-sudoers.sh    sudoers 등록 (visudo 문법 검사 후 설치)
extras/swiftbar/            같은 기능의 SwiftBar 플러그인 버전
AGENTS.md                   AI 코딩 에이전트용 안내 (CLAUDE.md는 이 파일의 심링크)
```

## 릴리스

1. `VERSION` 수정
2. `make install`로 확인
3. `git tag v$(cat VERSION) && git push --tags`

## 주의

뚜껑을 닫은 채 켜 두면 열이 잘 빠지지 않습니다. 가방 안에서 켜 두지 마세요.
