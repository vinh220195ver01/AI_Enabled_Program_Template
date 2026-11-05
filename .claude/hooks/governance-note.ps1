# Windows PowerShell wrapper for: bash .claude/hooks/governance-guard.sh note <CODE>
# Finds Git for Windows' bash wherever it is installed (PATH, or next to git.exe), so an AI
# agent running in PowerShell does not have to guess an install path.
# Usage: powershell -NoProfile -File .claude/hooks/governance-note.ps1 D-4
param([Parameter(Mandatory = $true)][string]$Code)

$bash = (Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $bash) {
    $git = (Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($git) {
        # git.exe is in <Git>\cmd (or <Git>\mingw64\bin): walk up until a <Git>\bin\bash.exe exists
        $dir = Split-Path $git
        for ($i = 0; $i -lt 4 -and $dir -and -not $bash; $i++) {
            foreach ($c in (Join-Path $dir 'bin\bash.exe'), (Join-Path $dir 'usr\bin\bash.exe')) {
                if (Test-Path $c) { $bash = $c; break }
            }
            $dir = Split-Path $dir
        }
    }
}
if (-not $bash) {
    [Console]::Error.WriteLine('bash not found. Install Git for Windows (https://git-scm.com), then run again.')
    exit 1
}
& $bash (Join-Path $PSScriptRoot 'governance-guard.sh') note $Code
exit $LASTEXITCODE
