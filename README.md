# 한국어 IME 자동화 규칙

Android Emulator에서 Gboard 한국어 두벌식과 TalkBack을 함께 검증할 때 입력 경로를 혼동하지 않도록 만든 규칙과 검사 도구입니다.

## 실패 원인

`수석`과 `ㅅㅜㅅㅓㄱ`은 화면에서 비슷하게 읽힐 수 있어도 같은 문자열이 아닙니다.

| 값 | Unicode code point | 의미 |
| --- | --- | --- |
| `수석` | `U+C218 U+C11D` | 완성형 Hangul syllable이며 NFC입니다. |
| `수석`의 NFD | `U+1109 U+116E U+1109 U+1165 U+11A8` | canonically equivalent한 결합 자모열입니다. |
| `ㅅㅜㅅㅓㄱ` | `U+3145 U+315C U+3145 U+3153 U+3131` | 호환 자모열입니다. NFC 정규화만으로 `수석`이 되지 않습니다. |

핵심 실패는 자모를 누른 행위가 아니라 입력 source와 처리 경로를 구분하지 않은 것입니다. `adb shell input text`, `keyevent`, 완성 문자열 주입, Gboard 화면 키 터치, IME composing, TalkBack 터치 탐색은 서로 다른 경로입니다.

AOSP의 `input text` 구현은 문자열을 `KeyCharacterMap`의 `KeyEvent` 배열로 바꾸어 주입합니다. Gboard 화면 키 좌표를 누르는 동작이나 `InputConnection.setComposingText()` 호출을 보장하지 않습니다. 따라서 Gboard 화면 키와 TalkBack의 상호작용을 검증할 때 대체 수단으로 쓰면 안 됩니다.

## 두 가지 QA를 분리하는 기준

| 목적 | 허용 | 금지 | 성공 기준 |
| --- | --- | --- | --- |
| 상태 준비 | 테스트가 허용한 `setText`, clipboard, broadcast, 별도 테스트 IME | 직접 입력을 검증했다고 기록하는 행위 | 필요한 상태가 준비됨 |
| Gboard 직접 입력 QA | Gboard 한국어 두벌식 화면 키의 실제 touch 경로 | clipboard, `setText`, 완성 문자열 broadcast, 완성 문자열 ADB 주입 | composing을 거쳐 최종 NFC 음절이 표시됨 |
| 물리 키보드 QA | 명시한 keyboard source의 실제 key event | 화면 키 QA와 결과를 합치는 행위 | 물리 키보드 정책에 따른 결과가 표시됨 |
| TalkBack 화면 키 QA | 확인한 TalkBack 입력 환경에서 실제 탐색과 선택 동작 | TalkBack을 끈 touch 결과를 대신 쓰는 행위 | 입력 결과와 TalkBack 음성 결과가 함께 확인됨 |

## 가장 짧은 사용법

PowerShell에서 현재 기기 상태를 읽기 전용으로 검사합니다.

```powershell
.\scripts\Inspect-AndroidInputState.ps1 `
  -Serial emulator-5554 `
  -RequireIme Gboard `
  -RequireTalkBack Off `
  -RequireKoreanDubeolsik
```

목표 문자열의 두벌식 키열을 계산합니다. 좌표는 계산 결과에 포함하지 않습니다.

```powershell
python .\scripts\dubeolsik_plan.py 수석
```

현재 Gboard 화면에서 수집한 좌표와 예상 composing 상태를 별도 JSON으로 저장합니다.

```json
{
  "source": "touchscreen",
  "talkBack": "Off",
  "talkBackTypingPreference": "",
  "resourceId": "com.example:id/query",
  "finalExpected": "수석",
  "steps": [
    {"label": "ㅅ", "action": "tap", "x": 100, "y": 2200, "expected": "ㅅ"},
    {"label": "ㅜ", "action": "tap", "x": 200, "y": 2300, "expected": "수"},
    {"label": "ㅅ", "action": "tap", "x": 100, "y": 2200, "expected": "숫"},
    {"label": "ㅓ", "action": "tap", "x": 300, "y": 2300, "expected": "수서"},
    {"label": "ㄱ", "action": "tap", "x": 400, "y": 2200, "expected": "수석"}
  ]
}
```

예시 숫자를 복사하지 않습니다. 현재 screenshot과 UI dump에서 다시 수집한 좌표로 바꾼 뒤, 비어 있는 증거 폴더를 지정해 실행합니다.

```powershell
.\scripts\Invoke-GboardTouchPlan.ps1 `
  -Serial emulator-5554 `
  -PlanPath .\current-plan.json `
  -EvidenceDirectory .\evidence
```

TalkBack on 계획은 `talkBackTypingPreference`를 반드시 기록합니다. 현재 입력 환경에 맞는 동작이 `swipe`라면 각 단계에 `x1`, `y1`, `x2`, `y2`, `durationMs`를 넣습니다. 실행기는 IME나 TalkBack 설정을 바꾸지 않습니다.

최종 UI dump에서 입력 필드를 검사합니다.

```powershell
python .\scripts\verify_hangul.py xml `
  --xml .\window.xml `
  --expected 수석 `
  --resource-id com.example:id/query
```

중간 composing 확인에는 `--allow-intermediate-jamo`를 쓸 수 있습니다. 최종 판정에는 사용하면 안 됩니다.

```powershell
python .\scripts\verify_hangul.py text `
  --observed ㅅ `
  --expected ㅅ `
  --allow-intermediate-jamo
```

음성 QA는 MP4와 같은 시점의 화면 캡처를 함께 검사합니다. `-VisibleIndicatorConfirmed`는 사람이 화면의 음성 출력 표시를 직접 본 뒤에만 넘깁니다.

```powershell
.\scripts\Test-TalkBackRecording.ps1 `
  -VideoPath .\talkback-qa.mp4 `
  -ScreenshotPath .\talkback-qa.png `
  -VisibleIndicatorConfirmed
```

## 직접 입력 절차

1. `Inspect-AndroidInputState.ps1`로 serial, AVD, API, 현재 IME, 활성 IME 목록, 한국어 두벌식 등록 여부, TalkBack, touch exploration 상태를 기록합니다.
2. TalkBack이 켜졌다면 TalkBack 설정 화면에서 입력 환경을 확인합니다. 글자 키에서 손을 떼어 입력하는 설정과 두 번 탭하여 입력하는 설정은 같은 동작이 아닙니다.
3. `dubeolsik_plan.py`로 논리 키열을 계산합니다. `수석`은 `ㅅ`, `ㅜ`, `ㅅ`, `ㅓ`, `ㄱ`입니다.
4. 현재 화면의 Gboard 키 위치를 UI dump와 스크린샷으로 새로 수집합니다. 저장한 좌표를 다른 기기, orientation, density, 언어 배열에 재사용하지 않습니다.
5. TalkBack이 꺼졌다면 각 Gboard 키의 touch 동작을 한 번씩 보냅니다. TalkBack이 켜졌다면 현재 입력 환경에 맞는 탐색과 선택 동작을 재현합니다. 짧은 `tap`을 손가락 탐색과 같은 동작으로 간주하지 않습니다.
6. 한 키를 입력할 때마다 대상 입력 필드의 composing 결과를 읽습니다. `수석`의 예시 변화는 `ㅅ`, `수`, `숫`, `수서`, `수석`입니다.
7. 마지막 입력은 UI dump와 스크린샷을 모두 남깁니다. `verify_hangul.py`가 exact match, NFC, 자모 미포함을 모두 통과해야 합니다.
8. TalkBack 음성도 검증한다면 MP4 audio stream, 비무음, 화면의 음성 출력 표시를 함께 확인합니다.

## 실패와 성공 판정표

| 관찰 | 판정 | 이유 |
| --- | --- | --- |
| `adb shell input text 수석` 뒤 원하는 글자가 보임 | 직접 입력 QA 실패 | Gboard 화면 키 touch와 composing 경로가 확인되지 않았습니다. |
| `keyevent`로 QWERTY 키를 보내 조합됨 | 화면 키 QA 실패 | physical keyboard 경로입니다. 별도 물리 키보드 QA로만 기록합니다. |
| Gboard 화면에서 `ㅅ`, `ㅜ`, `ㅅ`, `ㅓ`, `ㄱ`을 누름 | 진행 중 | 최종 문자열과 code point를 아직 확인하지 않았습니다. |
| 최종 값이 `ㅅㅜㅅㅓㄱ` | 즉시 실패 | 호환 자모가 남았습니다. |
| 최종 값이 NFD 결합 자모열 | 이 저장소의 기본 기준에서는 실패 | canonically equivalent하지만 요구한 완성형 NFC가 아닙니다. |
| 최종 값이 `수석`, NFC이며 자모가 없음 | 텍스트 성공 | 완성형 음절을 확인했습니다. |
| MP4에 audio stream만 있음 | 음성 QA 실패 | 실제 비무음과 화면 표시가 확인되지 않았습니다. |
| MP4 audio stream, 비무음, 화면 음성 출력 표시가 모두 있음 | 음성 성공 | 세 근거를 같은 실행에서 확인했습니다. |

## 이번 재현 범위

2026년 7월 26일에 Pixel_9_Pro AVD, Android API 36, Gboard 15.1, TalkBack 16.0 환경을 읽기 전용으로 확인했습니다. Gboard에는 한국어 두벌식과 English (US)가 등록되어 있었습니다.

직접 touch 재현을 시작하려던 중 다른 작업이 같은 Emulator의 화면과 기본 IME를 바꾸고 있음을 확인했습니다. 기기 상태를 원래 값으로 돌리고 직접 touch 실험을 중단했습니다. 따라서 이번 결과에는 TalkBack on과 off의 직접 입력 성공을 기록하지 않습니다.

로컬 검사기는 성공과 실패 fixture를 모두 통과했습니다. 자세한 결과와 공식 근거는 [조사 기록](skills/korean-ime-direct-input-qa/references/research.md)에 정리했습니다.

## 저장소 구성

| 경로 | 역할 |
| --- | --- |
| `AGENTS.md` | 저장소에서 자동 적용할 핵심 규칙 |
| `skills/korean-ime-direct-input-qa/SKILL.md` | 다른 Codex 작업에서 재사용할 skill |
| `scripts/Inspect-AndroidInputState.ps1` | Android 입력 사전 조건 검사 |
| `scripts/Invoke-GboardTouchPlan.ps1` | 좌표 계획 실행과 단계별 composing 증거 저장 |
| `scripts/dubeolsik_plan.py` | Hangul syllable을 두벌식 논리 키열로 변환 |
| `scripts/verify_hangul.py` | 문자열이나 UI dump의 NFC와 자모 분리 검사 |
| `scripts/Test-TalkBackRecording.ps1` | MP4 audio stream과 비무음 검사 |
| `tests/` | 표준 라이브러리 기반 회귀 검사 |

## 공식 근거

1. [Android IME 만들기](https://developer.android.com/develop/ui/views/touch-and-input/creating-input-method)
2. [InputConnection API](https://developer.android.com/reference/android/view/inputmethod/InputConnection)
3. [AOSP input 명령 구현](https://android.googlesource.com/platform/frameworks/base/+/1cff983/cmds/input/src/com/android/commands/input/Input.java)
4. [KeyCharacterMap.getEvents API](https://developer.android.com/reference/android/view/KeyCharacterMap#getEvents(char%5B%5D))
5. [TalkBack으로 Gboard 입력하기](https://support.google.com/accessibility/android/answer/6006598)
6. [TalkBack 입력 환경](https://support.google.com/accessibility/android/answer/16561624)
7. [Unicode Normalization Forms](https://www.unicode.org/reports/tr15/)
8. [Unicode Hangul Syllable Composition](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-3/#G24646)
