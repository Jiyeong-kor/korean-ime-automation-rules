# 한국어 IME 입력 경로 조사

## 결론

`수석`을 직접 입력하는 QA에서 검증할 대상은 완성 문자열 전달이 아니라 Gboard 화면 키가 IME composing을 거쳐 편집기에 전달되는 전체 경로입니다.

`adb shell input text`는 AOSP에서 입력 문자열을 `KeyCharacterMap.getEvents()`로 `KeyEvent` 배열로 바꾸어 주입합니다. Gboard 화면 키의 touch event를 만들지 않으며, `InputConnection.setComposingText()`를 직접 호출하지도 않습니다. 따라서 Gboard 화면 키 QA의 대체 수단이 아닙니다.

`keyevent`는 keyboard source의 down과 up event를 주입합니다. IME가 hardware key event를 처리할 수는 있지만, 이 결과는 물리 키보드 경로에 속합니다. on-screen Gboard의 touch 처리나 TalkBack touch exploration 결과와 합치면 안 됩니다.

Gboard 화면의 키 좌표를 touch하면 Gboard가 입력을 처리하고 편집기의 `InputConnection`과 통신할 수 있습니다. 다만 TalkBack이 켜지면 touch exploration과 입력 환경이 동작을 바꿉니다. TalkBack off에서 통과한 `tap`을 TalkBack on 결과로 재사용할 수 없습니다.

## Unicode와 Hangul

Unicode Standard Annex 15는 NFD를 canonical decomposition, NFC를 canonical decomposition 뒤 canonical composition으로 정의합니다. Unicode Standard 3.12절은 현대 Hangul syllable과 결합 자모의 산술적 분해와 합성 알고리즘을 정의합니다.

`수석`의 NFC code point는 `U+C218 U+C11D`입니다. NFD는 `U+1109 U+116E U+1109 U+1165 U+11A8`입니다. 두 표현은 canonically equivalent합니다.

`ㅅㅜㅅㅓㄱ`은 Hangul Compatibility Jamo의 `U+3145 U+315C U+3145 U+3153 U+3131`입니다. NFC로 정규화해도 그대로 남습니다. NFKC도 마지막 `ㄱ`의 음절 내 위치를 입력 과정처럼 추론하지 못하므로 `수서ᄀ`이 됩니다. 사후 정규화는 IME composing을 대신하지 못합니다.

## IME composing

Android IME 문서는 `InputConnection`을 IME와 편집기 사이의 통신 채널로 설명합니다. 여러 단계로 glyph나 단어를 조합하는 IME는 `setComposingText()`로 진행 중인 영역을 바꾸고, 완료할 때 `commitText()`나 composition 종료 동작을 사용합니다.

편집기는 composing region을 추적해야 합니다. `InputConnection` API는 `setComposingText()`, `setComposingRegion()`, `finishComposingText()`를 이 경로의 핵심 method로 설명합니다.

한국어 두벌식에서 `수석`의 논리 키열은 `ㅅ`, `ㅜ`, `ㅅ`, `ㅓ`, `ㄱ`입니다. 일반적인 composing 변화는 `ㅅ`, `수`, `숫`, `수서`, `수석`입니다. 세 번째 `ㅅ`은 다음 모음이 들어오기 전까지 앞 음절의 종성 후보가 됩니다.

## TalkBack

Google의 TalkBack 도움말은 Gboard에서 손가락을 움직여 원하는 글자를 찾고, 현재 입력 환경에 따라 손가락을 떼거나 다른 선택 동작으로 입력한다고 설명합니다. 물리 키보드는 별도 keyboard shortcut 정책을 사용합니다.

TalkBack 16.1 도움말은 다음 입력 환경을 구분합니다.

1. 모든 키를 선택한 뒤 두 번 탭합니다.
2. 글자 키는 손가락을 떼어 입력하고 다른 키는 두 번 탭합니다.
3. 모든 키를 손가락을 떼어 입력합니다.

따라서 TalkBack enabled와 touch exploration enabled만으로 정확한 key activation 동작을 알 수 없습니다. 실행 전에 화면 설정을 확인해야 합니다.

## 입력 경로 비교

| 경로 | Android event 또는 API | Gboard 화면 키 QA | TalkBack 화면 키 QA |
| --- | --- | --- | --- |
| `adb shell input text` | 문자열을 `KeyEvent` 배열로 변환 후 주입 | 불충분 | 불충분 |
| `adb shell input keyevent` | keyboard source의 down과 up event 주입 | 다른 경로 | 물리 키보드 정책으로만 별도 검증 |
| 완성 문자열 broadcast 또는 테스트 IME | 대개 `commitText()`나 동등한 완성 문자열 전달 | 금지 | 금지 |
| `adb shell input touchscreen tap` | touchscreen down과 up event | TalkBack off에서 후보 경로 | 현재 입력 환경 재현을 보장하지 않음 |
| Gboard 키의 실제 touch exploration과 선택 | touchscreen event를 TalkBack과 Gboard가 처리 | TalkBack off 대상 아님 | 요구한 경로 |

## 공식 자료

1. Android Developers, [Create an input method](https://developer.android.com/develop/ui/views/touch-and-input/creating-input-method)
2. Android Developers, [InputConnection](https://developer.android.com/reference/android/view/inputmethod/InputConnection)
3. Android Developers, [KeyCharacterMap.getEvents](https://developer.android.com/reference/android/view/KeyCharacterMap#getEvents(char%5B%5D))
4. Android Developers, [Handle keyboard actions](https://developer.android.com/develop/ui/views/touch-and-input/keyboard-input/commands)
5. AOSP, [Input.java](https://android.googlesource.com/platform/frameworks/base/+/1cff983/cmds/input/src/com/android/commands/input/Input.java)
6. Google Gboard Help, [Gboard 설정하기](https://support.google.com/gboard/answer/6380730?hl=ko)
7. Google Android Accessibility Help, [Navigate your device with TalkBack](https://support.google.com/accessibility/android/answer/6006598)
8. Google Android Accessibility Help, [What’s new with TalkBack 16.1](https://support.google.com/accessibility/android/answer/16561624)
9. Unicode Consortium, [Unicode Normalization Forms](https://www.unicode.org/reports/tr15/)
10. Unicode Consortium, [Conjoining Jamo Behavior](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-3/#G24646)

## 2026년 7월 26일 환경 관찰

Pixel_9_Pro AVD와 Android API 36을 확인했습니다. Gboard 15.1과 TalkBack 16.0이 설치되어 있었고, Gboard에는 한국어 두벌식과 English (US)가 등록되어 있었습니다.

초기 TalkBack 상태는 off였습니다. 기본 IME가 별도 작업 중 Gboard에서 `AdbIME`로 바뀌는 것을 확인했습니다. Gboard 직접 touch 실험을 위해 잠시 상태를 바꿨지만, 다른 작업이 동시에 화면을 조작하고 있음을 다시 확인했습니다. 즉시 기본 IME와 soft keyboard 설정을 원래 값으로 복구하고 실험을 멈췄습니다.

따라서 이 관찰은 사전 조건과 충돌 감지 근거만 제공합니다. 직접 touch 성공, TalkBack on 성공, 음성 성공을 주장하지 않습니다.
