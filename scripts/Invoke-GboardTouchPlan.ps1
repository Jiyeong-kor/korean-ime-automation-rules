[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Serial,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$PlanPath,

    [Parameter(Mandatory)]
    [string]$EvidenceDirectory
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

function Get-StepValue {
    param(
        [Parameter(Mandatory)]$Step,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Number
    )
    $property = $Step.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "step $Number requires $Name"
    }
    return $property.Value
}

$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
if ($plan.source -ne "touchscreen") {
    throw "plan source must be touchscreen"
}
if ($plan.talkBack -notin @("On", "Off")) {
    throw "plan talkBack must be On or Off"
}
if ($plan.talkBack -eq "On" -and [string]::IsNullOrWhiteSpace($plan.talkBackTypingPreference)) {
    throw "TalkBack plans must record talkBackTypingPreference"
}
if ([string]::IsNullOrWhiteSpace($plan.resourceId)) {
    throw "plan resourceId is required"
}
if ([string]::IsNullOrWhiteSpace($plan.finalExpected)) {
    throw "plan finalExpected is required"
}
$steps = @($plan.steps)
if ($steps.Count -eq 0) {
    throw "plan steps are empty"
}
if ($steps[-1].expected -ne $plan.finalExpected) {
    throw "last expected value must equal finalExpected"
}

$evidencePath = [IO.Path]::GetFullPath($EvidenceDirectory)
if (Test-Path -LiteralPath $evidencePath) {
    if (Get-ChildItem -LiteralPath $evidencePath -Force | Select-Object -First 1) {
        throw "evidence directory must be empty: $evidencePath"
    }
} else {
    New-Item -ItemType Directory -Path $evidencePath | Out-Null
}

$preflightPath = Join-Path $PSScriptRoot "Inspect-AndroidInputState.ps1"
$preflight = & $preflightPath `
    -Serial $Serial `
    -RequireIme Gboard `
    -RequireTalkBack $plan.talkBack `
    -RequireKoreanDubeolsik `
    -InputSource touchscreen
if ($LASTEXITCODE -ne 0) {
    throw "input preflight failed"
}
$preflight | Set-Content -LiteralPath (Join-Path $evidencePath "preflight.json") -Encoding utf8

$remotePrefix = "/data/local/tmp/codex-ime-$PID"
$remoteFiles = [System.Collections.Generic.List[string]]::new()
try {
    for ($index = 0; $index -lt $steps.Count; $index++) {
        $step = $steps[$index]
        $number = $index + 1
        $label = [string](Get-StepValue $step "label" $number)
        $expected = [string](Get-StepValue $step "expected" $number)
        $action = [string](Get-StepValue $step "action" $number)
        if ([string]::IsNullOrWhiteSpace($label)) {
            throw "step $($index + 1) label is required"
        }
        if ([string]::IsNullOrWhiteSpace($expected)) {
            throw "step $($index + 1) expected value is required"
        }

        switch ($action) {
            "tap" {
                $x = Get-StepValue $step "x" $number
                $y = Get-StepValue $step "y" $number
                Invoke-Adb shell input touchscreen tap $x $y | Out-Null
            }
            "swipe" {
                $x1 = Get-StepValue $step "x1" $number
                $y1 = Get-StepValue $step "y1" $number
                $x2 = Get-StepValue $step "x2" $number
                $y2 = Get-StepValue $step "y2" $number
                $durationMs = Get-StepValue $step "durationMs" $number
                Invoke-Adb shell input touchscreen swipe `
                    $x1 $y1 $x2 $y2 $durationMs | Out-Null
            }
            default {
                throw "step $($index + 1) action must be tap or swipe"
            }
        }

        $delayProperty = $step.PSObject.Properties["delayMs"]
        $delayMs = if ($null -ne $delayProperty) { [int]$delayProperty.Value } else { 250 }
        Start-Sleep -Milliseconds $delayMs

        $remoteXml = "$remotePrefix-step-$number.xml"
        $localXml = Join-Path $evidencePath ("step-{0:D2}.xml" -f $number)
        $remoteFiles.Add($remoteXml)
        Invoke-Adb shell uiautomator dump $remoteXml | Out-Null
        Invoke-Adb pull $remoteXml $localXml | Out-Null

        $verifyArguments = @(
            (Join-Path $PSScriptRoot "verify_hangul.py"),
            "xml",
            "--xml", $localXml,
            "--expected", $expected,
            "--resource-id", [string]$plan.resourceId
        )
        if ($index -lt $steps.Count - 1) {
            $verifyArguments += "--allow-intermediate-jamo"
        }
        $verification = & python @verifyArguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "step $number failed: $($verification -join [Environment]::NewLine)"
        }
        $verification | Set-Content `
            -LiteralPath (Join-Path $evidencePath ("step-{0:D2}.json" -f $number)) `
            -Encoding utf8
    }

    $remotePng = "$remotePrefix-final.png"
    $localPng = Join-Path $evidencePath "final.png"
    $remoteFiles.Add($remotePng)
    Invoke-Adb shell screencap -p $remotePng | Out-Null
    Invoke-Adb pull $remotePng $localPng | Out-Null

    [ordered]@{
        ok = $true
        serial = $Serial
        finalExpected = $plan.finalExpected
        steps = $steps.Count
        evidenceDirectory = $evidencePath
        finalScreenshot = $localPng
    } | ConvertTo-Json
} finally {
    foreach ($remoteFile in $remoteFiles) {
        try {
            Invoke-Adb shell rm $remoteFile | Out-Null
        } catch {
            Write-Warning "could not remove temporary device file: $remoteFile"
        }
    }
}
