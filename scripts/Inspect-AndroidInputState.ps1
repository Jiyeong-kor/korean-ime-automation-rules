[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Serial,

    [ValidateSet("Any", "Gboard")]
    [string]$RequireIme = "Any",

    [ValidateSet("Either", "On", "Off")]
    [string]$RequireTalkBack = "Either",

    [switch]$RequireKoreanDubeolsik,

    [ValidateSet("Unknown", "touchscreen", "keyboard")]
    [string]$InputSource = "Unknown"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $output = & adb -s $Serial @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($output -join [Environment]::NewLine)"
    }
    return ($output -join "`n").Trim()
}

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb was not found on PATH"
}

$state = Invoke-Adb get-state
if ($state -ne "device") {
    throw "device is not ready: $state"
}

$ime = Invoke-Adb shell settings get secure default_input_method
$enabledImes = Invoke-Adb shell ime list -s
$accessibilityEnabled = Invoke-Adb shell settings get secure accessibility_enabled
$accessibilityServices = Invoke-Adb shell settings get secure enabled_accessibility_services
$touchExploration = Invoke-Adb shell settings get secure touch_exploration_enabled
$inputDump = Invoke-Adb shell dumpsys input_method
$displaySize = Invoke-Adb shell wm size
$displayDensity = Invoke-Adb shell wm density
$windowDisplayDump = Invoke-Adb shell dumpsys window displays
$orientationMatch = [regex]::Match($windowDisplayDump, "mRotation=(\d+)")
$talkBackOn = (
    $accessibilityEnabled -eq "1" -and
    $touchExploration -eq "1" -and
    $accessibilityServices -match "(?i)talkback"
)
$hasKoreanDubeolsik = $inputDump -match "한국어\(두벌식\)"
$isGboard = $ime -eq "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME"

$result = [ordered]@{
    capturedAt = (Get-Date).ToString("o")
    serial = $Serial
    avd = (Invoke-Adb emu avd name).Split("`n")[0].Trim()
    api = [int](Invoke-Adb shell getprop ro.build.version.sdk)
    android = Invoke-Adb shell getprop ro.build.version.release
    displaySize = $displaySize
    displayDensity = $displayDensity
    surfaceOrientation = if ($orientationMatch.Success) {
        [int]$orientationMatch.Groups[1].Value
    } else {
        $null
    }
    currentIme = $ime
    enabledImes = @($enabledImes -split "`n")
    isGboard = $isGboard
    hasKoreanDubeolsik = $hasKoreanDubeolsik
    accessibilityEnabled = $accessibilityEnabled -eq "1"
    touchExplorationEnabled = $touchExploration -eq "1"
    talkBackEnabled = $talkBackOn
    inputSource = $InputSource
}

$failures = [System.Collections.Generic.List[string]]::new()
if ($RequireIme -eq "Gboard" -and -not $isGboard) {
    $failures.Add("current IME is not Gboard")
}
if ($RequireKoreanDubeolsik -and -not $hasKoreanDubeolsik) {
    $failures.Add("Gboard Korean Dubeolsik subtype was not found")
}
if ($RequireTalkBack -eq "On" -and -not $talkBackOn) {
    $failures.Add("TalkBack is not enabled with touch exploration")
}
if ($RequireTalkBack -eq "Off" -and $talkBackOn) {
    $failures.Add("TalkBack is enabled")
}

$result.failures = @($failures)
$result.ok = $failures.Count -eq 0
$result | ConvertTo-Json -Depth 4
if ($failures.Count -gt 0) {
    exit 2
}
