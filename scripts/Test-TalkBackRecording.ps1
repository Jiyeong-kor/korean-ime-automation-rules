[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$VideoPath,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ScreenshotPath,

    [Parameter(Mandatory)]
    [switch]$VisibleIndicatorConfirmed,

    [double]$MinimumMaxVolumeDb = -60.0
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

foreach ($command in "ffprobe", "ffmpeg") {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "$command was not found on PATH"
    }
}

$probeJson = & ffprobe -v error -select_streams a -show_entries stream=index,codec_name `
    -of json -- $VideoPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "ffprobe failed: $($probeJson -join [Environment]::NewLine)"
}
$probe = ($probeJson -join "`n") | ConvertFrom-Json
$hasAudioStream = @($probe.streams).Count -gt 0

$volumeOutput = & ffmpeg -hide_banner -nostats -i $VideoPath -af volumedetect -f null NUL 2>&1
$maxVolumeLine = $volumeOutput | Select-String -Pattern "max_volume:\s+(-?inf|[-0-9.]+)\s+dB" |
    Select-Object -Last 1
$maxVolumeDb = $null
if ($maxVolumeLine -and $maxVolumeLine.Matches[0].Groups[1].Value -ne "-inf") {
    $maxVolumeDb = [double]::Parse(
        $maxVolumeLine.Matches[0].Groups[1].Value,
        [Globalization.CultureInfo]::InvariantCulture
    )
}
$nonSilent = $null -ne $maxVolumeDb -and $maxVolumeDb -gt $MinimumMaxVolumeDb
$screenshot = Get-Item -LiteralPath $ScreenshotPath
$screenshotPresent = $screenshot.Length -gt 0

$result = [ordered]@{
    video = (Resolve-Path -LiteralPath $VideoPath).Path
    audioStream = $hasAudioStream
    maxVolumeDb = $maxVolumeDb
    minimumMaxVolumeDb = $MinimumMaxVolumeDb
    nonSilent = $nonSilent
    screenshot = (Resolve-Path -LiteralPath $ScreenshotPath).Path
    screenshotPresent = $screenshotPresent
    visibleIndicatorConfirmed = $VisibleIndicatorConfirmed.IsPresent
    ok = (
        $hasAudioStream -and
        $nonSilent -and
        $screenshotPresent -and
        $VisibleIndicatorConfirmed.IsPresent
    )
}
$result | ConvertTo-Json
if (-not $result.ok) {
    exit 2
}
