# 한국어 IME 자동화 규칙

Android에서 한국어를 입력하거나 입력 결과를 검증하는 작업에는 `skills/korean-ime-direct-input-qa/SKILL.md`를 먼저 읽고 따른다.

1. 상태 준비와 직접 입력 QA를 구분한다.
2. 직접 입력 QA에서는 clipboard, `setText`, 완성 문자열 broadcast와 완성 문자열 ADB 주입을 사용하지 않는다.
3. 기기, IME, 한국어 배열, TalkBack, 입력 source를 실행 전에 기록한다.
4. 두벌식 키열 계산과 화면 좌표 수집을 분리한다.
5. 실제 Gboard 키를 거친 composing 결과만 직접 입력 성공으로 인정한다.
6. 마지막 UI dump와 스크린샷에서 완성형 NFC 음절을 확인한다.
7. 호환 자모나 결합 자모가 남으면 즉시 실패한다.
8. 음성 QA는 MP4 오디오 stream, 비무음 구간, 화면의 음성 출력 표시를 모두 확인한다.
9. 관찰하지 않은 결과를 성공으로 기록하지 않는다.
