---
name: korean-ime-direct-input-qa
description: Validate direct Korean text entry on Android through Gboard Dubeolsik and IME composing, including TalkBack on or off. Use when Codex types Korean on an Android device or Emulator, distinguishes direct keyboard QA from state setup, investigates separated jamo such as ㅅㅜㅅㅓㄱ, checks ADB input paths, or verifies Korean text and TalkBack recordings.
---

# Korean IME direct input QA

Treat text injection, physical key events, on-screen key touch, IME composition, and TalkBack touch exploration as separate test paths. Never infer success from visual similarity or command exit status.

## Choose the test path

1. Classify the request as state setup, physical keyboard QA, Gboard on-screen direct input QA, or TalkBack on-screen direct input QA.
2. If the user asks for direct Korean key input, prohibit clipboard, `setText`, completed-string broadcasts, completed-string ADB injection, and test IMEs that commit a completed string.
3. Use `adb shell input text` only when the test explicitly targets its injected `KeyEvent` path. Do not use it as proof of Gboard touch input.
4. Use `keyevent` only for an explicitly named physical or virtual keyboard test. Do not merge its result with on-screen Gboard QA.

## Run preflight

1. Select the exact device by serial. Never rely on the implicit first ADB device.
2. Run `scripts/Inspect-AndroidInputState.ps1`.
3. Record AVD or device model, Android API, current IME, enabled IMEs, Korean Dubeolsik availability, TalkBack state, touch exploration state, orientation, display size, density, and intended input source.
4. When TalkBack is on, read its current typing preference from the TalkBack settings UI. Service state alone does not reveal whether keys activate on lift or require another gesture.
5. Stop if any required state differs. Do not change a shared device when another task may be using it.

## Prepare the key plan

1. Run `scripts/dubeolsik_plan.py` with an NFC target.
2. Keep the logical Dubeolsik keys separate from QWERTY key names and screen coordinates.
3. Capture the current keyboard with a screenshot and UI dump.
4. Resolve each visible Gboard key to a fresh center coordinate for the current device, orientation, density, keyboard layout, shift state, and TalkBack state.
5. Never reuse a coordinate map from a different state.

## Execute direct input

1. Focus the exact editable node and show Gboard.
2. Confirm the visible layout is Korean Dubeolsik.
3. With TalkBack off, send one touchscreen action to each current Gboard key.
4. With TalkBack on, reproduce the active TalkBack typing preference. A short ADB tap is not automatically equivalent to explore by touch, slide, lift, split tap, or double tap.
5. After every logical key, dump the target editable node and compare it with the planned composing state. For `수석`, expect `ㅅ`, `수`, `숫`, `수서`, and `수석`.
6. Stop on the first unexpected state. Do not finish the remaining taps and reinterpret the result later.

## Verify completion

1. Capture the final UI dump and screenshot from the same run.
2. Run `scripts/verify_hangul.py` against the exact editable node.
3. Require exact expected text, NFC, and no code point from Hangul Jamo, Hangul Compatibility Jamo, Hangul Jamo Extended-A, or Hangul Jamo Extended-B.
4. Treat `ㅅㅜㅅㅓㄱ` as immediate failure.
5. Treat canonically equivalent NFD as failure when the requested result is a precomposed NFC syllable.
6. Do not normalize a failed observation and then call the original input successful.

## Verify TalkBack audio

1. Record the screen and audio in the same run.
2. Run `scripts/Test-TalkBackRecording.ps1`.
3. Require an MP4 audio stream and a measured non-silent signal.
4. Inspect the matching screenshot or frame and confirm the visible speech or audio output indicator.
5. Pass `-VisibleIndicatorConfirmed` only after direct visual inspection.
6. Fail if any of the three checks is missing.

## Report evidence

Report the exact environment, input source, key sequence, intermediate observations, final code points, screenshot and UI dump paths, TalkBack state, and commands that were actually run. Label blocked or skipped experiments accurately. Never replace missing observation with an expected result.

Read `references/research.md` when investigating input-path behavior, Unicode normalization, IME composition, Gboard, TalkBack, or AOSP command semantics.
