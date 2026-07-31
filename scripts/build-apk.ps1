# Builds a release APK stamped with the current git commit, so the build hash
# shown in Settings links to the exact source on GitHub. Reads Supabase config
# from env.json. Run from the repo root:  ./scripts/build-apk.ps1
#
# Commit your changes before building so the stamped hash exists on GitHub.
param(
    [ValidateSet('apk', 'appbundle')]
    [string]$Target = 'apk'
)
$ErrorActionPreference = 'Stop'

$hash = (git rev-parse --short HEAD).Trim()
$time = (git log -1 --format=%cI).Trim()

# App version from pubspec (strip any +buildNumber suffix).
$versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' | Select-Object -First 1
$version = $versionLine.Matches[0].Groups[1].Value.Split('+')[0].Trim()

if (-not (git status --porcelain)) {
    Write-Host "Building $Target from clean commit $hash (v$version)" -ForegroundColor Green
} else {
    Write-Warning "Working tree has uncommitted changes; the stamped hash ($hash) will not match GitHub until you commit."
}

flutter build $Target --release `
    --dart-define-from-file=env.json `
    --dart-define=APP_VERSION=$version `
    --dart-define=BUILD_HASH=$hash `
    --dart-define=BUILD_TIME=$time
