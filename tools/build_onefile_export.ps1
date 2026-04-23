param(
	[string]$ExportDir = (Join-Path $PSScriptRoot "..\\Game_exe"),
	[string]$EntryExe = "Game_1.8.exe",
	[string]$OutputFile = (Join-Path $PSScriptRoot "..\\OneFileRelease\\DroneScript.exe"),
	[string]$ProductName = "DroneScript"
)

$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "==> $Message" -ForegroundColor Cyan
}

$launcherDir = Join-Path $PSScriptRoot "onefile_launcher"
$payloadDir = Join-Path $launcherDir "Payload"
$payloadZip = Join-Path $payloadDir "payload.zip"
$manifestPath = Join-Path $launcherDir "PayloadManifest.g.cs"
$publishDir = Join-Path $launcherDir "publish"
$stageDir = Join-Path $launcherDir ".payload_stage"

$resolvedExportDir = (Resolve-Path $ExportDir).Path
if (-not (Test-Path -LiteralPath $resolvedExportDir)) {
	throw "Export directory not found: $ExportDir"
}

$entryPath = Join-Path $resolvedExportDir $EntryExe
if (-not (Test-Path -LiteralPath $entryPath)) {
	throw "Entry executable not found: $entryPath"
}

$resolvedOutputFile = [System.IO.Path]::GetFullPath($OutputFile)
$resolvedOutputDir = [System.IO.Path]::GetDirectoryName($resolvedOutputFile)
if ([string]::IsNullOrWhiteSpace($resolvedOutputDir)) {
	throw "Output directory could not be resolved for: $OutputFile"
}

Write-Step "Preparing payload"
if (Test-Path -LiteralPath $stageDir) {
	Remove-Item -LiteralPath $stageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stageDir | Out-Null

$items = Get-ChildItem -LiteralPath $resolvedExportDir -Force
foreach ($item in $items) {
	if ($item.FullName -eq $resolvedOutputFile) {
		continue
	}
	if ($item.Extension -ieq ".exe" -and $item.Name -ne $EntryExe) {
		continue
	}
	Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $stageDir $item.Name) -Recurse -Force
}

if (Test-Path -LiteralPath $payloadZip) {
	Remove-Item -LiteralPath $payloadZip -Force
}
Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $payloadZip -CompressionLevel Optimal

$payloadHash = (Get-FileHash -LiteralPath $payloadZip -Algorithm SHA256).Hash.ToLowerInvariant()

$manifestContent = @"
namespace DroneScriptOneFile;

internal static class PayloadManifest
{
    public const string ProductName = "$($ProductName.Replace('"', '\"'))";
    public const string EntryExeName = "$($EntryExe.Replace('"', '\"'))";
    public const string PayloadHash = "$payloadHash";
    public const string ExtractFolderName = "DroneScriptOneFile";
}
"@
[System.IO.File]::WriteAllText($manifestPath, $manifestContent, [System.Text.Encoding]::UTF8)

Write-Step "Publishing one-file launcher"
if (Test-Path -LiteralPath $publishDir) {
	Remove-Item -LiteralPath $publishDir -Recurse -Force
}

dotnet publish `
	"$launcherDir\\DroneScriptOneFile.csproj" `
	-c Release `
	-r win-x64 `
	--self-contained true `
	-o $publishDir | Out-Host

$publishedExe = Join-Path $publishDir "DroneScriptOneFile.exe"
if (-not (Test-Path -LiteralPath $publishedExe)) {
	throw "Published launcher was not created: $publishedExe"
}

Write-Step "Writing final EXE"
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
Copy-Item -LiteralPath $publishedExe -Destination $resolvedOutputFile -Force

Write-Step "Done"
Write-Host "Single-file build created: $resolvedOutputFile" -ForegroundColor Green
