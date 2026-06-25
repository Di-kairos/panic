# install.ps1 — установщик panic для Windows (BETA) с проверкой целостности.
#
# Тянет panic.ps1 и SHA256SUMS из РЕЛИЗНОГО тега (не из ветки main) и сверяет SHA256
# ДО установки. Закрывает supply-chain риск «irm|iex из main без проверки»: содержимое
# релизного тега неизменно (в отличие от подвижной main), хеш ловит повреждение, частичную/
# кэш-подмену и рассинхрон с публикацией. ЧЕСТНО: сумма и скрипт приходят по одному каналу —
# от подмены САМОГО релиза это не защищает; для подлинности нужна подпись (SHA256SUMS.sig).
#
# Использование (рекомендуется verify-then-run, см. windows/README.md):
#   irm https://github.com/Di-kairos/panic/releases/latest/download/install.ps1 -OutFile install.ps1
#   irm https://github.com/Di-kairos/panic/releases/latest/download/SHA256SUMS  -OutFile SHA256SUMS
#   # сверить хеш install.ps1 вручную, прочитать скрипт, затем:
#   pwsh -File install.ps1
#
# Переменные окружения:
#   PANIC_VERSION     — конкретный тег (напр. 0.1.3). По умолчанию latest.
#   PANIC_BASE_URL    — источник целиком: http(s) URL ИЛИ локальный каталог (тесты/форки).
#   PANIC_INSTALL_DIR — каталог установки. По умолчанию %LOCALAPPDATA%\Programs\panic.
#   PANIC_SKIP_PATH   — '1' пропускает правку PATH (для тестов).
#
# ВНИМАНИЕ: BETA-порт. Логика проверена через Pester (системные примитивы мокаются);
# поведение на широком парке Windows-консолей/локалей/конфигов BitLocker не обкатано.

$ErrorActionPreference = 'Stop'

$Repo = 'Di-kairos/panic'

# Источник: явный PANIC_BASE_URL → конкретный тег PANIC_VERSION → latest-релиз.
if ($env:PANIC_BASE_URL) {
    $BaseUrl = $env:PANIC_BASE_URL
} elseif ($env:PANIC_VERSION) {
    $BaseUrl = "https://github.com/$Repo/releases/download/v$($env:PANIC_VERSION)"
} else {
    $BaseUrl = "https://github.com/$Repo/releases/latest/download"
}

$InstallDir = if ($env:PANIC_INSTALL_DIR) { $env:PANIC_INSTALL_DIR } else {
    Join-Path $env:LOCALAPPDATA 'Programs\panic'
}
$ScriptPath = Join-Path $InstallDir 'panic.ps1'
$ShimPath   = Join-Path $InstallDir 'panic.cmd'

Write-Host 'panic (Windows, BETA) installer'
Write-Host '-------------------------------'

# Скачать файл из релиза: http(s) → Invoke-RestMethod; локальный каталог → копия.
# Локальный путь поддержан, чтобы тесты гоняли проверку хеша без сети.
function Get-ReleaseFile {
    param([string]$Name, [string]$OutFile)
    if ($BaseUrl -match '^https?://') {
        Invoke-RestMethod -Uri "$BaseUrl/$Name" -OutFile $OutFile
    } else {
        Copy-Item -Path (Join-Path $BaseUrl $Name) -Destination $OutFile -Force
    }
}

# Временный каталог под загрузку; чистим в любом случае.
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("panic-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Tmp -Force | Out-Null
try {
    $tmpScript = Join-Path $Tmp 'panic.ps1'
    $tmpSums   = Join-Path $Tmp 'SHA256SUMS'

    Write-Host 'Downloading panic.ps1 + SHA256SUMS from release...'
    Get-ReleaseFile -Name 'panic.ps1'  -OutFile $tmpScript
    Get-ReleaseFile -Name 'SHA256SUMS' -OutFile $tmpSums

    # Ожидаемый хеш для panic.ps1 из SHA256SUMS (формат: '<hash>  имя').
    $expected = $null
    foreach ($line in Get-Content -Path $tmpSums) {
        $parts = $line -split '\s+', 2
        if ($parts.Count -eq 2) {
            $fname = $parts[1].Trim().TrimStart('*')
            if ($fname -eq 'panic.ps1') { $expected = $parts[0].Trim().ToLower() }
        }
    }
    if (-not $expected) {
        Write-Error 'SHA256SUMS не содержит записи для panic.ps1 — установка прервана.'
        exit 1
    }

    $actual = (Get-FileHash -Path $tmpScript -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) {
        Write-Error "Контрольная сумма НЕ совпала (возможна подмена) — установка прервана.`nexpected: $expected`nactual:   $actual"
        exit 1
    }
    Write-Host 'Checksum OK.'

    # Хеш верный → устанавливаем.
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    Copy-Item -Path $tmpScript -Destination $ScriptPath -Force
    Write-Host "Installed: $ScriptPath"
}
finally {
    Remove-Item -Path $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# .cmd-шим, чтобы вызывать просто `panic <command>` из cmd/PowerShell.
$shim = @"
@echo off
pwsh -NoProfile -File "%~dp0panic.ps1" %*
if errorlevel 1 exit /b %errorlevel%
"@
Set-Content -Path $ShimPath -Value $shim -Encoding ASCII
Write-Host "Shim created: $ShimPath"

# Добавить каталог в пользовательский PATH (idempotent). PANIC_SKIP_PATH=1 — пропустить.
if ($env:PANIC_SKIP_PATH -ne '1') {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $paths = $userPath.Split(';') | Where-Object { $_ -ne '' }
    if ($paths -notcontains $InstallDir) {
        $newPath = (($paths + $InstallDir) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "Added to user PATH: $InstallDir"
    } else {
        Write-Host 'Already on user PATH.'
    }
}

Write-Host ''
Write-Host 'Done. NEXT STEPS:'
Write-Host '  1) Open a NEW terminal (so PATH refreshes).'
Write-Host '  2) Run:  panic version'
Write-Host '  3) Preview (read-only):  panic status'
Write-Host ''
Write-Host 'NOTE: BETA port. `panic now` LOCKS/dismounts encrypted volumes and locks the screen —'
Write-Host 'run `panic status` first to see what it would touch. Forced locking may corrupt open files.'
