# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Codex, etc.) when working with code in this repository. `CLAUDE.md` is a symlink to this file.

## 개요

Lid Awake는 외부 모니터 없이 맥북 뚜껑을 닫아도 잠들지 않게 해 주는 macOS 메뉴 막대 앱입니다.
Xcode 프로젝트나 SwiftPM 없이 `Sources/main.swift` 하나를 `swiftc`로 직접 컴파일하며, 외부 의존성이 없습니다.
사용자용 기능 설명은 `README.md`에 있습니다.

## 명령

```bash
make build      # build/LidAwake.app 생성 (swiftc -O + ad-hoc 서명)
make run        # 빌드 후 설치하지 않고 실행
make install    # 빌드 → 실행 중인 앱 종료 → /Applications 교체 → 실행
make uninstall  # 앱 삭제 + /etc/sudoers.d/lidawake 제거 (sudo 필요)
make sudoers    # sudoers 규칙 미리 등록 (sudo 필요)
```

- 테스트와 린터는 없습니다. 컴파일은 `make build`로 확인하고, 동작은 `make install` 후 메뉴 막대에서 확인합니다.
- 메뉴 막대 아이콘과 메뉴 모양은 자동으로 검증할 수 없습니다. UI를 바꿨다면 사용자가 무엇을 확인해야 하는지 구체적으로 안내합니다.

## 구조와 동작 흐름

모든 로직은 `Sources/main.swift`의 `AppDelegate` 하나에 있습니다.

- **켜짐 여부의 기준은 `pmset -g`의 `SleepDisabled` 값입니다.** `isOn`은 이 값을 캐시할 뿐입니다. 앱이 시작할 때와 30초마다 `tick()`에서 값을 다시 읽어서, 터미널 등 외부에서 바꾼 상태와 맞춥니다. `isOn`은 `setSleepDisabled`가 성공한 뒤에만 바꿉니다.
- **켜짐 = `pmset -a disablesleep 1` + `caffeinate` 자식 프로세스입니다.** `caffeinate`는 `-w <앱 PID>`로 실행되므로 앱이 죽으면 같이 종료됩니다. 플래그는 `desiredCaffeinateFlags`(선택한 모드 + 뚜껑 상태)로 정해지고, 값이 바뀌면 `restartCaffeinateIfNeeded()`가 프로세스를 다시 실행합니다.
- **뚜껑 감지**: IORegistry `IOPMrootDomain`의 `AppleClamshellState`를 2초마다 확인합니다. 뚜껑이 닫히면 모드와 상관없이 `-ims`로 바꾸고 `pmset displaysleepnow`로 화면을 끕니다.
- **메뉴**: `menuNeedsUpdate`에서 메뉴를 열 때마다 새로 만듭니다. `autoenablesItems = false`이므로 항목의 활성 상태는 `isEnabled`로 직접 지정해야 합니다. 이 방식으로 꺼져 있을 때 모드와 배터리 보호를 잠급니다. 색이 들어간 안내 줄은 `attributedTitle`로 만들며, 비활성 항목이어도 지정한 색이 그대로 표시됩니다.
- **아이콘**: 켜짐은 팔레트 색(주황)을 입힌 비템플릿 이미지, 꺼짐은 템플릿 이미지에 `appearsDisabled`를 적용한 것입니다.
- **설정 저장**: `UserDefaults`의 `mode`, `minBattery` 키를 사용합니다.

## 권한 처리 (sudoers)

- `pmset disablesleep`은 root 권한이 필요합니다. `setSleepDisabled`는 먼저 `sudo -n /usr/bin/pmset -a disablesleep 0|1`을 시도하고, 실패하면 AppleScript로 관리자 암호 창을 띄웁니다. 이때 받은 권한으로 `/etc/sudoers.d/lidawake`도 설치하므로(`visudo -cf` 검사를 통과한 경우에만) 다음부터는 암호를 묻지 않습니다.
- sudo는 인자까지 정확히 일치해야 규칙을 적용합니다. 따라서 아래 파일에 있는 명령 문자열을 항상 똑같이 유지해야 합니다.
  - `Sources/main.swift`: `setSleepDisabled`(실행하는 명령)와 `sudoersInstallCommand`(규칙)
  - `scripts/setup-sudoers.sh`: 규칙
  - `extras/swiftbar/lidawake.30s.sh`: 실행하는 명령 (`sudo -n`만 사용하므로 규칙이 없으면 동작하지 않음)
- 빌드는 ad-hoc 서명이라서, 정식 개발자 서명이 필요한 권한 도우미 방식(SMJobBless 등)은 쓰지 않습니다. 로그인 시 실행은 `SMAppService.mainApp`을 사용합니다.

## 주의할 동작

- `make install`은 `pkill`(SIGTERM)로 기존 앱을 끄기 때문에 `applicationWillTerminate`가 호출되지 않습니다. 그래서 `SleepDisabled` 값이 그대로 남고, 새로 실행된 앱이 이 값을 읽어 켜진 상태를 이어 갑니다. 잠자기 설정은 메뉴의 "종료"로 끌 때만 복원됩니다.
- 배터리 보호는 타이머(`tick()`)에서 `setSleepDisabled(false)`를 호출합니다. sudoers 규칙이 없으면 사용자가 아무것도 누르지 않았는데도 암호 창이 뜰 수 있습니다.
- `extras/swiftbar/`는 앱과 코드를 공유하지 않는 별도 구현입니다(`caffeinate -dimsu` 고정, 모드와 뚜껑 감지 없음). 앱의 동작을 바꿔도 플러그인에는 자동으로 반영되지 않습니다.

## 관례

- UI 문자열, 코드 주석, README는 한국어로 작성합니다.
- 커밋 제목은 영어 명령형으로, 본문은 한국어 글머리표로 작성합니다. 동작을 바꾸는 커밋에서는 `VERSION`도 올리고 본문 마지막 글머리표에 적습니다. `scripts/build.sh`가 빌드할 때 이 값을 `Info.plist`에 넣습니다.
- 릴리스: `VERSION` 수정 → `make install`로 확인 → `git tag v$(cat VERSION) && git push --tags`
