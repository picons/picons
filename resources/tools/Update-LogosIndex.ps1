<#
.SYNOPSIS
    Prepares the logos index files (utf8snp.index and srp.index): downloads, checks, adds your new
    lines, cleans and sorts them. Windows only.

.DESCRIPTION
    PowerShell port of clean-and-sort-utf8snp-index.py and clean-and-sort-srp-index.py.

    FIRST RUN
      - creates the "picons" folder next to the script and downloads utf8snp.index and srp.index into it
      - creates the "logos" folder inside "picons" (put your logo files there)
      - creates two text files next to the script: Add-UTF.txt and Add-SRP.txt

    USUAL WAY OF USE: TWO RUNS
      1st run: downloads utf8snp.index and srp.index into "picons" (and creates the "logos" folder and the
               two Add files). Nothing of yours is merged yet.
      2nd run: after you wrote your lines in Add-UTF.txt and/or Add-SRP.txt (and copied the logo files in
               picons\logos) the script merges them, checks and sorts the files, and writes them.
      Later runs work on the files already in "picons" (never downloaded again unless you use -Download).

    ADDING NEW LINES
      Write your new lines (one per channel, <identifier>=<logo>) in Add-UTF.txt (for utf8snp.index)
      and/or Add-SRP.txt (for srp.index), then run the script again. It checks your lines and updates the
      .index files WITHOUT asking anything (the output is kept short): the lines are merged, the whole file
      is checked and sorted exactly like the Python scripts do,
      the previous .index is saved in backup\<date-time> and the Add file is emptied
      (a copy goes to the same backup folder).

    EVERY RUN
      - a .index file already in "picons" is never replaced by a download (your edits are kept):
        it is checked, sorted and rewritten in place (a backup is saved first); with -Download it is
        replaced by a fresh copy instead
      - no question is ever asked
      - if a file fails a blocking check (missing '=', invalid SRP, invalid logo name, corrupted
        UTF-8) it is NOT modified, and the Add file is not emptied
      - prints the time of each file and the total, and the steps to upload to GitHub
      - in an Add file a ":" in an SRP (or in the logo) is replaced with "_" (in a channel name the checks
        remove it, as the picons rules say) and a full service reference (1:0:TYPE:SID:TSID:ONID:NAMESPACE:0:0:0:
        or 1_0_TYPE_SID_TSID_ONID_NAMESPACE_0_0_0) is converted to the SRP form; the changes are shown
      - a pasted line  javascript:zapChannel('1:0:19:...', 'Rai 1');  (optionally followed by =<logo>, otherwise
        the logo is the name in lowercase without spaces: rai1) becomes SRP=logo in Add-SRP.txt and
        name=logo in Add-UTF.txt
      - a zapChannel line pasted in Add-UTF.txt (the same line you paste in Add-SRP.txt) writes name=logo in
        utf8snp.index and replaces that SRP in srp.index (the old line is removed, the one in Add-SRP.txt is added). If the
        removed srp.index line had a logo (e.g. 1C8E_332C_13E_820000=ntctv), NOTHING is removed from
        utf8snp.index (the same logo may belong to another satellite): the script only warns when other lines
        still use that old logo, in utf8snp.index or in srp.index, and lists them
      - warns when a line points to a logo with no file in picons\logos (fine if the logo is already
        in the GitHub repository)
      - if the identifier of one of your lines is already in the index, the EXISTING line is overwritten
        with yours (the overwritten lines are listed, and the ones already identical are counted)
      - the SRP lines of Add-SRP.txt also update the logo of the same SRP when it is already in
        utf8snp.index (the SRP is never added there, only its logo is replaced)
      - your lines repeated inside the same Add file are listed, and kept in the Add file as comments
      - an Add file saved as ANSI (Windows-1252) instead of UTF-8 is read anyway, with a warning
      - with -GitHubUser <name> the upload link points to your fork
        (https://github.com/<name>/picons/tree/master/build-source)
      - the output of the run is saved in backup\<date-time>\log.txt when something was written or
        an error occurred (it contains your user and computer name: look at it before sharing it)

    Logo files are named <logo>.default.png or <logo>.default.svg (also .light .dark .black .white).

.PARAMETER Path
    Folder in which "picons" and the Add files are created. Default: the folder of the script.

.PARAMETER Download
    For .index files that already exist in "picons", replace them with a fresh copy downloaded from
    GitHub (instead of sorting the existing one). A backup is made first.

.PARAMETER Force
    Kept for compatibility: the script never asks questions.

.PARAMETER Guide
    At the end, print the long step-by-step instructions (add a logo, upload to GitHub).

.PARAMETER NoBackup
    Do not save the previous copy of the .index files in backup\<date-time>.
    (The copy of your emptied Add files is always saved.)

.PARAMETER KeepDownload
    Do not delete the picons\_download work folder at the end.

.PARAMETER Parallel
    Check the two files at the same time on 2 CPU cores. Off by default: starting the worker
    threads costs about a second, which is more than it saves on files of this size.

.PARAMETER ShowAll
    Print every per-line fix message and every fixed line number. By default only the first
    few are shown (printing thousands of lines to the console is very slow).

.PARAMETER Pause
    Wait for a key press before closing (useful with double click or "Run with PowerShell").

.PARAMETER Open
    At the end, open the picons folder in Explorer and the GitHub upload page in the browser.

.PARAMETER DryRun
    Do everything except writing: runs all the checks, shows what would be added, ignored, written and
    emptied, and changes nothing (no question is asked; the temporary files go in the Windows temp folder).

.PARAMETER GitHubUser
    Your GitHub user name. Only when you give it, the upload link points to your fork
    (https://github.com/<user>/picons/tree/master/build-source). Nothing is detected, saved or asked: without
    this parameter the link shows YOUR_GITHUB_USERNAME.

.PARAMETER NoLog
    Do not save the output of the run in backup\<date-time>\log.txt.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Update-LogosIndex.ps1

.NOTES
    Version 1.4.5
    Works with Windows PowerShell 5.1 and PowerShell 7.
    Exit code: 0 = ok, 1 = at least one file rejected or with errors to review, 2 = general error.
#>
[CmdletBinding()]
param(
    [string]$Path,
    [switch]$Download,
    [switch]$Force,
    [switch]$NoBackup,
    [switch]$KeepDownload,
    [switch]$Parallel,
    [switch]$ShowAll,
    [switch]$Pause,
    [switch]$Open,
    [switch]$DryRun,
    [switch]$NoLog,
    [switch]$Guide,
    [string]$GitHubUser
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.4.5'

# ----------------------------------------------------------------------------
# Basic settings
# ----------------------------------------------------------------------------
if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    Write-Host 'This script is meant for Windows only.' -ForegroundColor Red
    exit 2
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$Utf8NoBom  = New-Object System.Text.UTF8Encoding($false)
$Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
# Like errors='ignore' in Python: bytes that cannot be decoded are dropped
$Utf8Ignore = [System.Text.Encoding]::GetEncoding(
    'utf-8',
    (New-Object System.Text.EncoderReplacementFallback('')),
    (New-Object System.Text.DecoderReplacementFallback('')))

# Trimmed service reference: 4 hex parts, the namespace (last part) has at least 6 hex digits
$SrpRe = New-Object System.Text.RegularExpressions.Regex(
    '^[0-9A-F]+_[0-9A-F]+_[0-9A-F]+_[0-9A-F]{6,}$',
    ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant))

# Precompiled patterns used in the hot loop (shared with the worker threads)
$RxOpts = [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
# logo name that needs no fixing: lowercase, only a-z 0-9 _ -
$LogoOkRe = New-Object System.Text.RegularExpressions.Regex('^[a-z0-9_-]+$', $RxOpts)
# service reference already uppercase
$UpperRefRe = New-Object System.Text.RegularExpressions.Regex('^[0-9A-F_]+$', $RxOpts)
# plain ASCII channel name with nothing to sanitize
$FastNameRe = New-Object System.Text.RegularExpressions.Regex('^[A-Za-z0-9_+\-]([A-Za-z0-9 _.+\-]*[A-Za-z0-9_+\-])?$', $RxOpts)
# a full enigma2 service reference (1:0:TYPE:SID:TSID:ONID:NAMESPACE:0:0:0:) followed by =<logo>
$FullRefRe = New-Object System.Text.RegularExpressions.Regex(
    '^\s*[0-9A-Fa-f]+:[0-9A-Fa-f]+:[0-9A-Fa-f]+:([0-9A-Fa-f]+):([0-9A-Fa-f]+):([0-9A-Fa-f]+):([0-9A-Fa-f]+):[0-9A-Fa-f]+:[0-9A-Fa-f]+:[0-9A-Fa-f]+(?::[^=]*)?=(.*)$',
    $RxOpts)
# javascript:zapChannel('1:0:19:SID:TSID:ONID:NAMESPACE:0:0:0:', 'Channel name');  (optionally followed by =<logo>)
$ZapRe = New-Object System.Text.RegularExpressions.Regex(
    '^\s*(?:javascript:)?\s*zapChannel\(\s*''([^'']*)''\s*,\s*''((?:[^''\\]|\\.)*)''\s*\)\s*;?\s*(?:=\s*(.*))?$',
    ($RxOpts -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
$RefOnlyRe = New-Object System.Text.RegularExpressions.Regex(
    '^[0-9A-Fa-f]+:[0-9A-Fa-f]+:[0-9A-Fa-f]+:([0-9A-Fa-f]+):([0-9A-Fa-f]+):([0-9A-Fa-f]+):([0-9A-Fa-f]+):[0-9A-Fa-f]+:[0-9A-Fa-f]+:[0-9A-Fa-f]+(?::[^=]*)?$',
    $RxOpts)
# a full service reference written with underscores: 1_0_19_SID_TSID_ONID_NAMESPACE_0_0_0 (prefix 1_0_1, 1_0_16, 1_0_19 or 4097_0_1)
$UnderRefRe = New-Object System.Text.RegularExpressions.Regex(
    '^(?:1_0_(?:1|16|19)|4097_0_1)_([0-9A-Fa-f]+)_([0-9A-Fa-f]+)_([0-9A-Fa-f]+)_([0-9A-Fa-f]+)_0_0_0_?$',
    $RxOpts)
$SanReservedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($w in @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')) { [void]$SanReservedSet.Add($w) }

$BaseUrl   = 'https://raw.githubusercontent.com/picons/picons/master/build-source'
$UpstreamUrl  = 'https://github.com/picons/picons'
$UploadUrlFmt = 'https://github.com/{0}/picons/tree/master/build-source'
$UserNameRe = '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$'
$DetailLimit = 25
if ($ShowAll) { $DetailLimit = -1 }

if ([string]::IsNullOrWhiteSpace($Path)) {
    if ($PSScriptRoot) { $Path = $PSScriptRoot } else { $Path = (Get-Location).Path }
}

# ----------------------------------------------------------------------------
# Console messages (only used from the main thread)
# ----------------------------------------------------------------------------
function Write-Info([string]$Msg) {
    Write-Host '  info   ' -NoNewline -ForegroundColor DarkGray
    Write-Host $Msg
}
function Write-Warn([string]$Msg) {
    Write-Host '  warn   ' -NoNewline -ForegroundColor Yellow
    Write-Host $Msg
}
function Write-Err([string]$Msg) {
    Write-Host '  ERROR  ' -NoNewline -ForegroundColor Red
    Write-Host $Msg
}
function Show-Messages($Log) {
    # The workers only collect messages; they are printed here, in order, per file.
    # Fix messages (info) only with -ShowAll; warnings are capped; errors are always printed.
    $warns = 0
    $hidden = 0
    foreach ($m in $Log) {
        $kind = $m[0]
        if ($kind -eq 'info') { if ($ShowAll) { Write-Info $m[1] } }
        elseif ($kind -eq 'warn') {
            if ($ShowAll -or $warns -lt 5) { Write-Warn $m[1]; $warns++ } else { $hidden++ }
        }
        elseif ($kind -eq 'err') { Write-Err $m[1] }
        else { Write-Host ('  ' + $m[1]) -ForegroundColor Red }
    }
    if ($hidden -gt 0) { Write-Info ('... {0} more warnings hidden (use -ShowAll to print all of them)' -f $hidden) }
}

# ----------------------------------------------------------------------------
# Download (raw file, bytes identical to the original; written through a .part file)
# ----------------------------------------------------------------------------
function Get-RemoteFile {
    param([string]$Url, [string]$Destination)
    $ProgressPreference = 'SilentlyContinue'
    $tmp = $Destination + '.part'
    $lastError = ''
    for ($t = 1; $t -le 3; $t++) {
        try {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
            Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -TimeoutSec 60 -UserAgent 'picons-index-cleaner.ps1'
            if ((Get-Item -LiteralPath $tmp).Length -eq 0) { throw 'the downloaded file is empty' }
            Move-Item -LiteralPath $tmp -Destination $Destination -Force
            return $true
        } catch {
            $lastError = $_.Exception.Message
            Write-Warn ('Download failed (attempt {0} of 3): {1}' -f $t, $lastError)
            if ($t -lt 3) { Start-Sleep -Seconds (2 * $t) }
        }
    }
    Write-Err ('Unable to download {0}: {1}' -f $Url, $lastError)
    return $false
}

# ============================================================================
# WORKER CODE
# The functions below run on worker threads (runspaces): they must not write to
# the console. They collect messages in the $Log list instead.
# ============================================================================

# Equivalent of enigma2 Directories.sanitizeFilename (same as the Python script)
$SanBlacklist = [char[]]@('\', '/', ':', '*', '?', '"', '<', '>', '|', [char]0)
$SanReserved = @(
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
)

function Get-SanitizedName {
    param([string]$Name, [int]$MaxLen = 255)

    # Fast path: plain ASCII names with nothing to sanitize come back unchanged
    # (verified identical to the full algorithm on the real utf8snp.index)
    if ($Name.Length -le $MaxLen -and
        $Name -cmatch '^[A-Za-z0-9_+\-]([A-Za-z0-9 _.+\-]*[A-Za-z0-9_+\-])?$' -and
        ($SanReserved -cnotcontains $Name)) {
        return $Name
    }

    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $Name.ToCharArray()) {
        if (([Array]::IndexOf($SanBlacklist, $c) -lt 0) -and ([int]$c -gt 31)) { [void]$sb.Append($c) }
    }
    $s = $sb.ToString().Normalize([System.Text.NormalizationForm]::FormKD).Trim()

    if ($s.Length -eq 0 -or $s.Trim([char]'.').Length -eq 0 -or ($SanReserved -ccontains $s)) {
        $s = '__' + $s
    }

    $b = $Utf8Ignore.GetBytes($s)
    if ($b.Length -gt $MaxLen) {
        # split root and extension like os.path.splitext (leading dots do not count)
        $dot = [Array]::LastIndexOf($b, [byte]46)
        $extStart = -1
        if ($dot -gt 0) {
            for ($k = 0; $k -lt $dot; $k++) {
                if ($b[$k] -ne 46) { $extStart = $dot; break }
            }
        }
        if ($extStart -ge 0) {
            $rootB = [byte[]]$b[0..($dot - 1)]
            $extB = [byte[]]$b[$dot..($b.Length - 1)]
        } else {
            $rootB = $b
            $extB = [byte[]]@()
        }
        $oneIfRoot = 0
        if ($rootB.Length -gt 0) { $oneIfRoot = 1 }
        $maxExt = $MaxLen - $oneIfRoot
        if ($extB.Length -gt $maxExt) { $extB = [byte[]]$extB[0..($maxExt - 1)] }
        $keep = $MaxLen - $extB.Length
        if ($rootB.Length -gt $keep) { $rootB = [byte[]]$rootB[0..($keep - 1)] }
        $s = $Utf8Ignore.GetString($rootB) + $Utf8Ignore.GetString($extB)
    }

    $s = $s.TrimEnd([char]'.', [char]' ')
    if ($s.Length -eq 0) { $s = '__' }
    return $s
}

function Test-LooksLikeSrp([string]$Value) {
    # True if it looks like a botched SRP identifier (e.g. 1_282_1_64), not an ordinary name with underscores
    $us = $Value.Length - $Value.Replace('_', '').Length
    if ($us -lt 2 -or $us -gt 4) { return $false }
    $parts = @($Value.Split([char]'_') | Where-Object { $_ -ne '' })
    if ($parts.Count -lt 3) { return $false }
    $hex = 0
    foreach ($p in $parts) { if ($p -cmatch '^[0-9a-fA-F]+$') { $hex++ } }
    return ($hex -ge ($parts.Count - 1))
}

function Get-PaddedHex([string]$Hex) {
    # Fixed-width hex so that an ordinal string comparison equals the numeric comparison
    return $Hex.TrimStart([char]'0').PadLeft(64, '0')
}

function Get-CorruptedLines {
    # Slow path, used only when the file is not valid UTF-8: pinpoints the offending lines
    param([byte[]]$Bytes, [int]$Offset, $Log)
    $len = $Bytes.Length
    $start = $Offset
    $n = 1
    while ($start -lt $len) {
        $i = $start
        while ($i -lt $len -and $Bytes[$i] -ne 10 -and $Bytes[$i] -ne 13) { $i++ }
        $lineEnd = $i
        if ($i -lt $len) {
            if ($Bytes[$i] -eq 13 -and ($i + 1) -lt $len -and $Bytes[$i + 1] -eq 10) { $i += 2 } else { $i++ }
        }
        try {
            [void]$Utf8Strict.GetString($Bytes, $start, $lineEnd - $start)
        } catch {
            $ex = $_.Exception
            while ($ex.InnerException -and -not ($ex -is [System.Text.DecoderFallbackException])) { $ex = $ex.InnerException }
            $pos = 0
            $bad = 0
            if ($ex -is [System.Text.DecoderFallbackException]) {
                $pos = $ex.Index
                if ($ex.BytesUnknown -and $ex.BytesUnknown.Length -gt 0) { $bad = $ex.BytesUnknown[0] }
            }
            $preview = [System.Text.Encoding]::UTF8.GetString($Bytes, $start, [Math]::Min(60, $lineEnd - $start))
            [void]$Log.Add(@('err', ('Line {0}: corrupted text (invalid byte 0x{1:X2} at position {2}) -> {3}' -f $n, $bad, $pos, $preview)))
        }
        $start = $i
        $n++
    }
}

# Clean and sort one index file
#   Type 'utf8snp' = clean-and-sort-utf8snp-index.py
#   Type 'srp'     = clean-and-sort-srp-index.py
# Fills the $Result hashtable with the cleaned text and the counters; writes nothing, prints nothing.
function Invoke-Cleanup {
    param(
        [Parameter(Mandatory)][ValidateSet('utf8snp', 'srp')][string]$Type,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Log,
        [Parameter(Mandatory)][hashtable]$Result,
        [int]$DetailLimit = 25
    )

    $fileName = Split-Path -Leaf $FilePath
    # The result is filled in place (the caller keeps the reference), nothing is returned
    $r = $Result
    $r.Done = $true
    $swc = [System.Diagnostics.Stopwatch]::StartNew()
    try {

    # --- read and strict UTF-8 decoding -------------------------------------
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    } catch {
        [void]$Log.Add(@('err', ('Read error: {0}' -f $_.Exception.Message)))
        return
    }

    $offset = 0
    $bom = $false
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $offset = 3
        $bom = $true
        [void]$Log.Add(@('warn', 'UTF-8 BOM found at the start of the file: it will be removed'))
    }

    try {
        $orig = $Utf8Strict.GetString($bytes, $offset, $bytes.Length - $offset)
    } catch {
        Get-CorruptedLines -Bytes $bytes -Offset $offset -Log $Log
        [void]$Log.Add(@('abort', ('Aborted: file contains corrupted/unreadable text -- file not modified. Fix {0} and re-run.' -f $fileName)))
        return
    }

    $parts = [regex]::Split($orig, '\r\n|\n|\r')
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.AddRange([string[]]$parts)
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Length -eq 0) { $lines.RemoveAt($lines.Count - 1) }
    $r.Lines = $lines.Count

    # --- counters and structures --------------------------------------------
    $sortKeys = New-Object 'System.Collections.Generic.List[string]'
    $sortLines = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $fixed = New-Object 'System.Collections.Generic.SortedSet[int]'
    $errorLines = New-Object 'System.Collections.Generic.List[int]'
    $errors = 0
    $missingEq = 0
    $invalidSrp = 0
    $invalidLogo = 0
    $duplicates = 0
    $dupInfo = New-Object 'System.Collections.Generic.List[object]'
    $empty = 0
    $detailShown = 0
    $detailHidden = 0
    $sep = [string][char]1
    $eqChar = [char]'='
    $usChar = [char]'_'
    $zero = [char]'0'

    for ($idx = 0; $idx -lt $lines.Count; $idx++) {
        $n = $idx + 1
        $line = $lines[$idx]

        $noTrailing = $line.TrimEnd()
        if ($noTrailing.Length -eq 0) { $empty++; continue }
        if ($noTrailing.Length -ne $line.Length) {
            if ($DetailLimit -lt 0 -or $detailShown -lt $DetailLimit) {
                $detailShown++
                [void]$Log.Add(@('info', ('Line {0}: trailing whitespace removed' -f $n)))
            } else { $detailHidden++ }
            $line = $noTrailing
            [void]$fixed.Add($n)
        }

        $pos = $line.LastIndexOf($eqChar)
        if ($pos -lt 0) {
            [void]$Log.Add(@('err', ("Line {0}: missing '=' sign: '{1}'" -f $n, $line)))
            $missingEq++
            continue
        }
        $name = $line.Substring(0, $pos)
        $logo = $line.Substring($pos + 1)
        $srpMatch = $SrpRe.IsMatch($name)

        if ($Type -eq 'utf8snp') {
            # An identifier that looks like a botched SRP must be fixed by the submitter, not silently dropped
            if (-not $srpMatch -and $name.IndexOf($usChar) -ge 0 -and (Test-LooksLikeSrp $name)) {
                [void]$Log.Add(@('err', ("Line {0}: '{1}' looks like an SRP-style channel identifier but is invalid (bad underscores, wrong part count, or non-hex value)" -f $n, $name)))
                $invalidSrp++
                continue
            }
        }

        if (-not $LogoOkRe.IsMatch($logo)) {
            # slow path: the logo needs fixing or is invalid
            $lower = $logo.ToLowerInvariant()
            if (-not [string]::Equals($lower, $logo, [StringComparison]::Ordinal)) {
                if ($DetailLimit -lt 0 -or $detailShown -lt $DetailLimit) {
                    $detailShown++
                    [void]$Log.Add(@('info', ("Line {0}: logo lowercased  '{1}' -> '{2}'" -f $n, $logo, $lower)))
                } else { $detailHidden++ }
                $logo = $lower
                [void]$fixed.Add($n)
            }

            if ($logo.Length -eq 0) {
                [void]$Log.Add(@('err', ('Line {0}: empty logo name' -f $n)))
                $invalidLogo++
                continue
            }

            if ($logo -cnotmatch '^[a-z0-9_-]+$') {
                $odd = New-Object 'System.Collections.Generic.SortedSet[string]' ([StringComparer]::Ordinal)
                foreach ($c in $logo.ToCharArray()) {
                    if ([string]$c -cnotmatch '^[a-z0-9_-]$') { [void]$odd.Add([string]$c) }
                }
                $list = ($odd | ForEach-Object { "'" + $_ + "'" }) -join ', '
                [void]$Log.Add(@('err', ("Line {0}: invalid character(s) {1} in logo name '{2}'" -f $n, $list, $logo)))
                $invalidLogo++
                continue
            }
        }

        if ($Type -eq 'srp') {
            if (-not $srpMatch) {
                [void]$Log.Add(@('err', ("Line {0}: '{1}' is not a valid trimmed service reference (bad underscores, wrong part count, non-hex value, or namespace too short)" -f $n, $name)))
                $invalidSrp++
                continue
            }
            if (-not $UpperRefRe.IsMatch($name)) {
                $upper = $name.ToUpperInvariant()
                if ($DetailLimit -lt 0 -or $detailShown -lt $DetailLimit) {
                    $detailShown++
                    [void]$Log.Add(@('info', ("Line {0}: service reference uppercased  '{1}' -> '{2}'" -f $n, $name, $upper)))
                } else { $detailHidden++ }
                $name = $upper
                [void]$fixed.Add($n)
            }
            $key = $name
            $isSrp = $true
        } else {
            if ($srpMatch) {
                $key = $name.ToUpperInvariant()
                $isSrp = $true
            } else {
                $isSrp = $false
                if ($name.Length -gt 0) {
                    if ($name.Length -le 255 -and $FastNameRe.IsMatch($name) -and -not $SanReservedSet.Contains($name)) {
                        $san = $name
                    } else {
                        $san = Get-SanitizedName -Name $name
                    }
                    $key = $san.ToLowerInvariant()
                } else {
                    $key = ''
                }
            }
        }

        if ($key.Length -gt 0 -and $seen.ContainsKey($key)) {
            $first = $seen[$key]
            $note = ''
            if (-not [string]::Equals($first[1], $logo, [StringComparison]::Ordinal)) {
                $note = " (WARNING: different logo, kept '{0}', dropped '{1}')" -f $first[1], $logo
            }
            [void]$Log.Add(@('warn', ("Line {0}: duplicate identifier '{1}' (first seen at line {2}) -- removed{3}" -f $n, $key, $first[0], $note)))
            # line number, identifier, line of the first copy, logo of the first copy, logo of this line
            [void]$dupInfo.Add(@($n, $key, $first[0], $first[1], $logo))
            $duplicates++
            continue
        }

        if ($Type -eq 'utf8snp' -and -not ($key.Length -gt 0 -and $key -ne '__')) {
            [void]$Log.Add(@('err', ("Line {0}: '{1}' -- channel identifier is empty/invalid after sanitizing, removed" -f $n, $line)))
            $errors++
            $errorLines.Add($n)
            continue
        }

        # Sort key (compared with ordinal string comparison; ties keep insertion order via the index)
        #   utf8snp: logo, then SRP entries (0) by namespace/ONID/TSID/SID, then names (1) alphabetically
        #   srp:     namespace, ONID, TSID, SID
        if ($isSrp) {
            $x = $key.Split($usChar)
            # fixed-width hex: an ordinal string comparison equals the numeric comparison
            $nums = $x[3].TrimStart($zero).PadLeft(64, '0') + $x[2].TrimStart($zero).PadLeft(64, '0') + $x[1].TrimStart($zero).PadLeft(64, '0') + $x[0].TrimStart($zero).PadLeft(64, '0') + $sortKeys.Count.ToString('D10')
            if ($Type -eq 'srp') { $sk = $nums } else { $sk = $logo + $sep + '0' + $nums }
        } else {
            $sk = $logo + $sep + '1' + $key
        }
        $seen[$key] = @($n, $logo)
        $sortKeys.Add($sk)
        $sortLines.Add($key + '=' + $logo)

        if ($Type -eq 'utf8snp' -and -not [string]::Equals($key, $name, [StringComparison]::Ordinal)) {
            if ($DetailLimit -lt 0 -or $detailShown -lt $DetailLimit) {
                $detailShown++
                [void]$Log.Add(@('info', ("Line {0}: channel identifier sanitized  '{1}' -> '{2}'" -f $n, $name, $key)))
            } else { $detailHidden++ }
            [void]$fixed.Add($n)
        }
    }

    if ($detailHidden -gt 0) {
        [void]$Log.Add(@('info', ('... {0} more fix messages hidden (use -ShowAll to print all of them)' -f $detailHidden)))
    }

    $r.Empty = $empty
    $r.Duplicates = $duplicates
    $r.DupInfo = $dupInfo.ToArray()
    $r.Fixed = @($fixed)
    $r.Errors = $errors
    $r.ErrorLines = @($errorLines)

    # --- blocking errors: nothing gets written ------------------------------
    if ($missingEq -gt 0 -or $invalidSrp -gt 0 -or $invalidLogo -gt 0) {
        if ($missingEq -gt 0) {
            [void]$Log.Add(@('abort', ("Aborted: {0} line(s) missing '=' sign -- file not modified. Fix {1} and re-run." -f $missingEq, $fileName)))
        }
        if ($invalidSrp -gt 0) {
            [void]$Log.Add(@('abort', ('Aborted: {0} invalid SRP-style entry(ies) found -- file not modified. Fix {1} and re-run.' -f $invalidSrp, $fileName)))
        }
        if ($invalidLogo -gt 0) {
            [void]$Log.Add(@('abort', ('Aborted: {0} invalid logo name(s) found -- file not modified. Fix {1} and re-run.' -f $invalidLogo, $fileName)))
        }
        return
    }

    # --- sorting: one native ordinal sort on precomputed keys (keys are unique) ---
    $keysArr = $sortKeys.ToArray()
    $linesArr = $sortLines.ToArray()
    [Array]::Sort($keysArr, $linesArr, [System.Collections.IComparer][StringComparer]::Ordinal)

    $sb = New-Object System.Text.StringBuilder
    foreach ($l in $linesArr) {
        [void]$sb.Append($l).Append("`n")
    }
    $out = $sb.ToString()

    $r.Aborted = $false
    $r.Out = $out
    $r.Written = $linesArr.Length
    $r.Changed = ($bom -or -not [string]::Equals($out, $orig, [StringComparison]::Ordinal))
    return
    } finally {
        $r.Seconds = $swc.Elapsed.TotalSeconds
    }
}

# ============================================================================
# END OF WORKER CODE
# ============================================================================

function New-CleanupResult {
    return @{
        Done       = $false
        Seconds    = 0.0
        Aborted    = $true
        Out        = ''
        Changed    = $false
        Lines      = 0
        Written    = 0
        Empty      = 0
        Duplicates = 0
        Fixed      = @()
        Errors     = 0
        ErrorLines = @()
        DupInfo    = @()
    }
}

function Invoke-CleanupParallel {
    # Runs Invoke-Cleanup for every job on its own worker thread (max 2 at a time)
    param($Jobs, [int]$DetailLimit)

    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    foreach ($fn in @('Get-SanitizedName', 'Test-LooksLikeSrp', 'Get-PaddedHex', 'Get-CorruptedLines', 'Invoke-Cleanup')) {
        $def = (Get-Item -LiteralPath ('function:' + $fn)).Definition
        $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($fn, $def)))
    }
    $shared = @{
        Utf8Strict   = $Utf8Strict
        Utf8Ignore   = $Utf8Ignore
        SrpRe        = $SrpRe
        SanBlacklist = $SanBlacklist
        SanReserved  = $SanReserved
        SanReservedSet = $SanReservedSet
        LogoOkRe     = $LogoOkRe
        UpperRefRe   = $UpperRefRe
        FastNameRe   = $FastNameRe
    }
    foreach ($k in $shared.Keys) {
        $iss.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry($k, $shared[$k], '')))
    }

    $threads = [Math]::Max(1, [Math]::Min(2, $Jobs.Count))
    $pool = [runspacefactory]::CreateRunspacePool(1, $threads, $iss, $Host)
    $pool.Open()
    try {
        $running = New-Object System.Collections.Generic.List[object]
        foreach ($j in $Jobs) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddCommand('Invoke-Cleanup').AddParameter('Type', $j.Type).AddParameter('FilePath', $j.Path).AddParameter('Log', $j.Log).AddParameter('Result', $j.Result).AddParameter('DetailLimit', $DetailLimit)
            $running.Add([pscustomobject]@{ Job = $j; PS = $ps; Handle = $ps.BeginInvoke() })
        }
        foreach ($x in $running) {
            $out = $x.PS.EndInvoke($x.Handle)
            if (-not $x.Job.Result.Done) {
                $errs = (@($x.PS.Streams.Error) | ForEach-Object { $_.ToString() }) -join '; '
                $why = ''
                if ($x.PS.InvocationStateInfo.Reason) { $why = $x.PS.InvocationStateInfo.Reason.Message }
                throw ('worker for {0} did not run (state: {1}; outputs: {2}; errors: {3}; reason: {4})' -f
                    (Split-Path -Leaf $x.Job.Path), $x.PS.InvocationStateInfo.State, @($out).Count, $errs, $why)
            }
            if ($x.PS.Streams.Error.Count -gt 0) { throw $x.PS.Streams.Error[0].ToString() }
            $x.PS.Dispose()
        }
    } finally {
        $pool.Close()
        $pool.Dispose()
    }
}

# ----------------------------------------------------------------------------
# Add files: the user writes new lines here, the script merges them into the .index files
# ----------------------------------------------------------------------------
function Get-AddTemplate {
    param([string]$Kind)
    if ($Kind -eq 'utf8snp') {
        $lines = @(
            '# Add-UTF.txt - new lines for picons\utf8snp.index',
            '#',
            '# Write ONE line per channel:   <identifier>=<logo>',
            '#',
            '#   <identifier> = the channel name             e.g.   kabelio itv2=itv2',
            '#               or the SRP of the channel       e.g.   1D5_B_1_130000=novipazar',
            '#   <logo>       = lowercase, only letters, digits, _ and -',
            '#                  It is the name of the logo file in picons\logos, without',
            '#                  ".default.png" / ".default.svg" (or the .light .dark .black .white variants).',
            '#',
            '# Empty lines and lines starting with # are ignored. Save this file as UTF-8.',
            '# Run Update-LogosIndex.ps1 again: your lines are checked and, after asking you,',
            '# merged into picons\utf8snp.index. Then this file is emptied (a copy goes to backup).',
            '# If an identifier is already in the index, your line REPLACES the existing one.',
            '# A pasted zapChannel line here (the same one you paste in Add-SRP.txt) also replaces that SRP in srp.index',
            '# (nothing is removed from utf8snp.index: you get a warning if other lines still use the old logo).',
            '# In an SRP a ":" is replaced with "_" (in a channel name it is removed by the checks, as the',
            '# rules say). A full service reference (1:0:19:SID:TSID:ONID:NAMESPACE:0:0:0: or 1_0_19_SID_..._0_0_0)',
            '# followed by =<logo> is converted to the SRP form.',
            '# You can also paste a  javascript:zapChannel(''1:0:19:...'', ''Rai 1'');  line (add =<logo> after it, or the',
            '# logo is taken from the name: Rai 1 -> rai1): it becomes the SRP line here or name=logo in Add-UTF.txt.',
            '#',
            '# Write your new lines below:'
        )
    } else {
        $lines = @(
            '# Add-SRP.txt - new lines for picons\srp.index',
            '#',
            '# Write ONE line per channel:   <SID>_<TSID>_<ONID>_<NAMESPACE>=<logo>',
            '#',
            '#   e.g.   1D5_B_1_130000=novipazar',
            '#   The 4 values are hexadecimal, uppercase, without leading zeros. In an enigma2',
            '#   service reference  1:0:TYPE:SID:TSID:ONID:NAMESPACE:0:0:0:  they are the 4 values after TYPE.',
            '#   <logo> = lowercase, only letters, digits, _ and -',
            '#            It is the name of the logo file in picons\logos, without',
            '#            ".default.png" / ".default.svg" (or the .light .dark .black .white variants).',
            '#',
            '# Empty lines and lines starting with # are ignored. Save this file as UTF-8.',
            '# Run Update-LogosIndex.ps1 again: your lines are checked and, after asking you,',
            '# merged into picons\srp.index. Then this file is emptied (a copy goes to backup).',
            '# If an identifier is already in the index, your line REPLACES the existing one. The logo of the same',
            '# SRP is also updated in picons\utf8snp.index, but only if it is already there (nothing is added to it).',
            '# In an SRP a ":" is replaced with "_" (in a channel name it is removed by the checks, as the',
            '# rules say). A full service reference (1:0:19:SID:TSID:ONID:NAMESPACE:0:0:0: or 1_0_19_SID_..._0_0_0)',
            '# followed by =<logo> is converted to the SRP form.',
            '# You can also paste a  javascript:zapChannel(''1:0:19:...'', ''Rai 1'');  line (add =<logo> after it, or the',
            '# logo is taken from the name: Rai 1 -> rai1): it becomes the SRP line here or name=logo in Add-UTF.txt.',
            '#',
            '# Write your new lines below:'
        )
    }
    return (($lines -join "`r`n") + "`r`n")
}

function Get-LogoBases {
    # Names (lowercase, without variant and extension) of the logo files in the logos folder
    param([string]$Dir)
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if (Test-Path -LiteralPath $Dir -PathType Container) {
        foreach ($f in @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue)) {
            if ($f.Name -cmatch '^([a-z0-9_-]+)\.(default|light|dark|black|white)\.(png|svg)$') { [void]$set.Add($Matches[1]) }
        }
    }
    return , $set
}

function Get-LineCount {
    param([string]$FilePath)
    $n = 0
    foreach ($l in [System.IO.File]::ReadLines($FilePath)) { $n++ }
    return $n
}

function Read-AddFile {
    # Returns: Ok, Error, Lines (the lines to add), Converted (full service references turned into the SRP
    # form), Replaced (other lines where ':' was changed to '_'), Samples (before/after examples, at most
    # $Limit; -1 = all), SamplesHidden, Fallback (not valid UTF-8: read as Windows-1252) and CheckText
    # (the same text with comments blanked, so that line numbers in messages match the Add file)
    param([string]$FilePath, [string]$Type = 'srp', [int]$Limit = 25)
    $r = @{
        Ok = $true; Error = ''
        Lines = (New-Object 'System.Collections.Generic.List[string]')
        Converted = 0; Replaced = 0
        Samples = (New-Object 'System.Collections.Generic.List[string]'); SamplesHidden = 0
        Fallback = $false; CheckText = ''
        ZapSrps = (New-Object 'System.Collections.Generic.List[string]')
    }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    } catch {
        $r.Ok = $false
        $r.Error = ('cannot be read: {0}' -f $_.Exception.Message)
        return $r
    }
    $off = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $off = 3 }
    try {
        $text = $Utf8Strict.GetString($bytes, $off, $bytes.Length - $off)
    } catch {
        # not UTF-8 (typically saved as ANSI by an old editor): read it as Windows-1252 and say so
        try {
            try { [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance) } catch { }
            $text = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes, $off, $bytes.Length - $off)
            $r.Fallback = $true
        } catch {
            $r.Ok = $false
            $r.Error = 'is not valid UTF-8 and could not be read as Windows-1252: open it in a text editor and save it again as UTF-8'
            return $r
        }
    }
    $check = New-Object System.Text.StringBuilder
    foreach ($l in [regex]::Split($text, '\r\n|\n|\r')) {
        $trim = $l.Trim()
        if ($trim.Length -eq 0 -or $trim[0] -eq [char]'#') {
            [void]$check.Append("`n")
        } else {
            $before = $l.TrimEnd()
            $zapOk = $false
            $zm = $ZapRe.Match($l)
            if ($zm.Success) {
                # javascript:zapChannel('<service reference>', '<name>');  ->  SRP=logo (Add-SRP) or name=logo (Add-UTF)
                $rm = $RefOnlyRe.Match($zm.Groups[1].Value.Trim())
                if ($rm.Success) {
                    $parts = @()
                    foreach ($g in 1..4) {
                        $h = $rm.Groups[$g].Value.TrimStart([char]'0').ToUpperInvariant()
                        if ($h.Length -eq 0) { $h = '0' }
                        $parts += $h
                    }
                    $chName = $zm.Groups[2].Value.Replace("\'", "'").Trim().Replace(':', '_')
                    $lg = $zm.Groups[3].Value.Trim()
                    if ($lg.Length -eq 0) {
                        # no logo given: the channel name in lowercase, letters and digits only (Rai 1 -> rai1)
                        $lg = ($chName.Normalize([System.Text.NormalizationForm]::FormD).ToLowerInvariant() -replace '[^a-z0-9]', '')
                    }
                    if ($Type -eq 'utf8snp') { $l = ('{0}={1}' -f $chName, $lg) } else { $l = ('{0}={1}' -f ($parts -join '_'), $lg) }
                    [void]$r.ZapSrps.Add(($parts -join '_'))
                    $r.Converted++
                    $zapOk = $true
                    if ($Limit -lt 0 -or $r.Samples.Count -lt $Limit) {
                        [void]$r.Samples.Add(('{0}   ->   {1}' -f $before, $l.TrimEnd()))
                    } else { $r.SamplesHidden++ }
                }
            }
            if (-not $zapOk) {
                # full service reference written with underscores (1_0_19_283D_3FB_1_C00000_0_0_0=logo)
                $ue = $l.LastIndexOf([char]'=')
                if ($ue -gt 0) {
                    $um = $UnderRefRe.Match($l.Substring(0, $ue).Trim())
                    if ($um.Success) {
                        $parts = @()
                        foreach ($g in 1..4) {
                            $h = $um.Groups[$g].Value.TrimStart([char]'0').ToUpperInvariant()
                            if ($h.Length -eq 0) { $h = '0' }
                            $parts += $h
                        }
                        $l = ($parts -join '_') + $l.Substring($ue)
                        $r.Converted++
                        $zapOk = $true
                        if ($Limit -lt 0 -or $r.Samples.Count -lt $Limit) {
                            [void]$r.Samples.Add(('{0}   ->   {1}' -f $before, $l.TrimEnd()))
                        } else { $r.SamplesHidden++ }
                    }
                }
            }
            if (-not $zapOk -and $l.Contains(':')) {
                $m = $FullRefRe.Match($l)
                $changed = $true
                if ($m.Success) {
                    # 1:0:19:SID:TSID:ONID:NAMESPACE:0:0:0:=logo  ->  SID_TSID_ONID_NAMESPACE=logo (uppercase, no leading zeros)
                    $parts = @()
                    foreach ($g in 1..4) {
                        $h = $m.Groups[$g].Value.TrimStart([char]'0').ToUpperInvariant()
                        if ($h.Length -eq 0) { $h = '0' }
                        $parts += $h
                    }
                    $l = ('{0}={1}' -f ($parts -join '_'), $m.Groups[5].Value)
                    $r.Converted++
                } else {
                    $l2 = $l.Replace(':', '_')
                    if ($Type -eq 'utf8snp') {
                        # in a channel NAME a ":" is not allowed and the checks remove it (like the other forbidden
                        # characters): only an SRP-like identifier or the logo part get "_"
                        $ce = $l.LastIndexOf([char]'=')
                        if ($ce -ge 0) {
                            $idPart = $l.Substring(0, $ce)
                            if ($idPart.Trim() -cnotmatch '^[0-9A-Fa-f_:]+$') { $idPart = $idPart } else { $idPart = $idPart.Replace(':', '_') }
                            $l2 = $idPart + $l.Substring($ce).Replace(':', '_')
                        } else { $l2 = $l }
                    }
                    if ($l2 -ceq $l) { $changed = $false } else { $l = $l2; $r.Replaced++ }
                }
                if ($changed) {
                    if ($Limit -lt 0 -or $r.Samples.Count -lt $Limit) {
                        [void]$r.Samples.Add(('{0}   ->   {1}' -f $before, $l.TrimEnd()))
                    } else { $r.SamplesHidden++ }
                }
            }
            [void]$r.Lines.Add($l.TrimEnd())
            [void]$check.Append($l).Append("`n")
        }
    }
    $r.CheckText = $check.ToString()
    return $r
}

function New-MergedSource {
    # Source index + the new lines appended at the end (they get checked and sorted together)
    param([string]$Source, $AddLines, [string]$Out)
    $srcBytes = [System.IO.File]::ReadAllBytes($Source)
    $tail = ''
    if ($srcBytes.Length -gt 0 -and $srcBytes[$srcBytes.Length - 1] -ne 10) { $tail = "`n" }
    $addBytes = $Utf8NoBom.GetBytes($tail + (@($AddLines) -join "`n") + "`n")
    $fs = [System.IO.File]::Create($Out)
    try {
        $fs.Write($srcBytes, 0, $srcBytes.Length)
        $fs.Write($addBytes, 0, $addBytes.Length)
    } finally {
        $fs.Close()
    }
}

function Get-IndexKey {
    # Identifier of a line, built exactly like Invoke-Cleanup does (used to find the lines to overwrite)
    param([string]$Type, [string]$Name)
    if ($Type -eq 'srp' -or $SrpRe.IsMatch($Name)) { return $Name.ToUpperInvariant() }
    if ($Name.Length -eq 0) { return '' }
    if ($Name.Length -le 255 -and $FastNameRe.IsMatch($Name) -and -not $SanReservedSet.Contains($Name)) { return $Name.ToLowerInvariant() }
    return (Get-SanitizedName -Name $Name).ToLowerInvariant()
}

function Merge-IndexLines {
    # Builds the text to check: the source index with
    #   - the lines whose identifier is also in your new lines dropped (so yours replace them)
    #   - srp only: the existing lines of the SRPs in $RemoveKeys dropped (their logos are returned in RemovedLogos);
    #     your new line for the same SRP (the new logo) is then added as usual
    #   - the lines that still use a logo of $RemoveLogos (the old logo of a removed srp.index line) are only
    #     REPORTED in StillUsing, never removed (the same logo may belong to another satellite)
    #   - utf8snp only: the logo of the SRP lines in $UpdateLines replaced where that SRP is already there
    # and your new lines appended at the end. Returns $null when the source is not valid UTF-8
    # (the normal checks report it).
    param([string]$Type, [string]$Source, $AddLines, $UpdateLines, $RemoveKeys = @(), $RemoveLogos = $null)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Source)
        $off = 0
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $off = 3 }
        $text = $Utf8Strict.GetString($bytes, $off, $bytes.Length - $off)
    } catch {
        return $null
    }

    $remSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ($Type -eq 'srp') {
        foreach ($rk in @($RemoveKeys)) { if ($rk) { [void]$remSet.Add(([string]$rk).Trim().ToUpperInvariant()) } }
    }

    # your new lines (without the ones of the SRPs that are being removed)
    $addList = New-Object 'System.Collections.Generic.List[string]'
    $dropped = 0
    foreach ($al in @($AddLines)) {
        $p = $al.LastIndexOf([char]'=')
        $addList.Add($al)
    }

    $addMap = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach ($al in $addList) {
        $p = $al.LastIndexOf([char]'=')
        if ($p -lt 0) { continue }
        $nm = $al.Substring(0, $p)
        $k = Get-IndexKey -Type $Type -Name $nm
        if ($k.Length -gt 0 -and -not $addMap.ContainsKey($k)) {
            $addMap[$k] = @($al, $al.Substring($p + 1).Trim().ToLowerInvariant())
        }
    }
    $updMap = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    if ($Type -eq 'utf8snp') {
        foreach ($ul in @($UpdateLines)) {
            $p = $ul.LastIndexOf([char]'=')
            if ($p -lt 0) { continue }
            $nm = $ul.Substring(0, $p)
            $k = Get-IndexKey -Type 'srp' -Name $nm
            if ($k.Length -gt 0 -and -not $updMap.ContainsKey($k)) { $updMap[$k] = $ul.Substring($p + 1).Trim().ToLowerInvariant() }
        }
    }

    $parts = [regex]::Split($text, '\r\n|\n|\r')
    $srcLines = New-Object 'System.Collections.Generic.List[string]'
    $srcLines.AddRange([string[]]$parts)
    if ($srcLines.Count -gt 0 -and $srcLines[$srcLines.Count - 1].Length -eq 0) { $srcLines.RemoveAt($srcLines.Count - 1) }

    $kept = New-Object 'System.Collections.Generic.List[string]'
    $over = New-Object 'System.Collections.Generic.List[object]'
    $upd = New-Object 'System.Collections.Generic.List[object]'
    $removed = New-Object 'System.Collections.Generic.List[object]'
    $removedLogos = New-Object 'System.Collections.Generic.List[string]'
    $same = 0
    $users = New-Object 'System.Collections.Generic.List[string]'
    $srpCand = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in $srcLines) {
        $t = $line.TrimEnd()
        $p = $t.LastIndexOf([char]'=')
        if ($t.Length -eq 0 -or $p -lt 0) { $kept.Add($line); continue }
        $nm = $t.Substring(0, $p)
        $lg = $t.Substring($p + 1).Trim().ToLowerInvariant()
        $k = Get-IndexKey -Type $Type -Name $nm
        if ($remSet.Count -gt 0 -and $remSet.Contains($k)) {
            $removed.Add(@($t, 'removed'))
            $removedLogos.Add($lg)
            continue
        }
        if ($k.Length -gt 0 -and $addMap.ContainsKey($k)) {
            # your line wins: the existing one is dropped (your line is appended below)
            if ($lg -ceq $addMap[$k][1]) { $same++ } else { $over.Add(@($t, $addMap[$k][0])) }
            continue
        }
        if ($null -ne $RemoveLogos -and $lg.Length -gt 0 -and $RemoveLogos.Contains($lg)) { $users.Add($t) }
        if ($k.Length -gt 0 -and $updMap.ContainsKey($k) -and $lg -cne $updMap[$k]) {
            $newLine = $nm + '=' + $updMap[$k]
            $upd.Add(@($t, $newLine))
            $kept.Add($newLine)
            continue
        }
        if ($remSet.Count -gt 0) { $srpCand.Add(@($t, $lg)) }
        $kept.Add($line)
    }
    if ($remSet.Count -gt 0 -and $removedLogos.Count -gt 0) {
        foreach ($c in $srpCand) { if ($removedLogos.Contains($c[1])) { $users.Add($c[0]) } }
    }

    $sb = New-Object System.Text.StringBuilder
    foreach ($l in $kept) { [void]$sb.Append($l).Append("`n") }
    foreach ($l in $addList) { [void]$sb.Append($l).Append("`n") }
    return @{
        Text = $sb.ToString(); SrcLines = $kept.Count; AddKept = $addList
        Overwritten = $over; Same = $same; Updated = $upd
        Removed = $removed; RemovedLogos = $removedLogos; Dropped = $dropped; StillUsing = $users
    }
}

function Write-Samples {
    # Prints "old   ->   new" pairs (at most $Limit; -1 = all)
    param($Items, [int]$Limit, [string]$Indent = '        ', [string]$Color = 'DarkGray')
    $n = 0
    foreach ($it in $Items) {
        if ($Limit -ge 0 -and $n -ge $Limit) {
            Write-Host ('{0}... {1} more (use -ShowAll to print all of them)' -f $Indent, ($Items.Count - $n)) -ForegroundColor DarkGray
            break
        }
        Write-Host ('{0}{1}   ->   {2}' -f $Indent, $it[0], $it[1]) -ForegroundColor $Color
        $n++
    }
}

# ----------------------------------------------------------------------------
# Main program
# ----------------------------------------------------------------------------
$exitCode = 0
$transcribing = $false
$BackupDir = ''
$backupUsed = $false
try {
    $BaseDir = (Resolve-Path -LiteralPath $Path).Path
    $PiconsDir = Join-Path $BaseDir 'picons'
    $LogosDir = Join-Path $PiconsDir 'logos'
    if ($DryRun) {
        $WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ('picons-work-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    } else {
        $WorkDir = Join-Path $PiconsDir '_download'
    }
    $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupDir = Join-Path (Join-Path $BaseDir 'backup') $Stamp

    try { Clear-Host } catch { }
    $LogTemp = Join-Path ([System.IO.Path]::GetTempPath()) ('picons-index-' + $Stamp + '.log')
    if (-not $NoLog) {
        try { Start-Transcript -Path $LogTemp -Force | Out-Null; $transcribing = $true } catch { $transcribing = $false }
    }
    Write-Host ''
    Write-Host ('  Picons index cleaner v{0}' -f $ScriptVersion) -ForegroundColor Cyan -NoNewline
    if ($DryRun) { Write-Host '   DRY RUN: nothing will be written or changed' -ForegroundColor Magenta } else { Write-Host '' }

    $defs = @(
        @{ Type = 'utf8snp'; Name = 'utf8snp.index'; Title = 'UTF8SNP Index'; AddName = 'Add-UTF.txt' },
        @{ Type = 'srp'; Name = 'srp.index'; Title = 'SRP Index'; AddName = 'Add-SRP.txt' }
    )

    $copied = 0
    $unchanged = 0
    $rejected = 0
    $withErrors = 0
    $ignoredTotal = 0
    $wouldWrite = 0

    # 1) folders
    if ($DryRun) { $dirsToMake = @($WorkDir) } else { $dirsToMake = @($PiconsDir, $WorkDir) }
    foreach ($d in $dirsToMake) {
        if (-not (Test-Path -LiteralPath $d -PathType Container)) { [void](New-Item -ItemType Directory -Path $d -Force) }
    }

    # 2) the Add files (next to the script): created the first time, read and checked every time
    $createdAdd = @()
    $secondRunShown = $false
    foreach ($def in $defs) {
        $def.Dest = Join-Path $PiconsDir $def.Name
        $def.AddPath = Join-Path $BaseDir $def.AddName
        $def.AddCount = 0
        $def.AddLines = @()
        $def.AddEffective = @()
        $def.AddValid = $true
        $def.Merged = $false
        $def.HasMerge = $false
        $def.UpdateLines = @()
        $def.RemoveKeys = @()
        $def.ZapSrps = @()
        $def.Overwritten = New-Object 'System.Collections.Generic.List[object]'
        $def.Updated = New-Object 'System.Collections.Generic.List[object]'
        $def.Removed = New-Object 'System.Collections.Generic.List[object]'
        $def.Same = 0
        $def.Dropped = 0
        $def.StillUsing = New-Object 'System.Collections.Generic.List[string]'

        if (-not (Test-Path -LiteralPath $def.AddPath -PathType Leaf)) {
            if ($DryRun) { continue }
            [System.IO.File]::WriteAllText($def.AddPath, (Get-AddTemplate $def.Type), $Utf8NoBom)
            $createdAdd += $def.AddName
            continue
        }

        $add = Read-AddFile -FilePath $def.AddPath -Type $def.Type -Limit $DetailLimit
        if (-not $add.Ok) {
            Write-Err ('{0} {1}' -f $def.AddName, $add.Error)
            $def.AddValid = $false
            $withErrors++
            continue
        }
        if ($add.Lines.Count -eq 0) { continue }

        if (-not $secondRunShown) {
            Write-Host '  2nd run: merging your lines into the index files, please wait...' -ForegroundColor Yellow
            $secondRunShown = $true
        }
        # same checks as for the index files; the line numbers shown are the ones of the Add file
        $checkPath = Join-Path $WorkDir ($def.AddName + '.check')
        [System.IO.File]::WriteAllText($checkPath, $add.CheckText, $Utf8NoBom)
        $clog = New-Object 'System.Collections.Generic.List[object]'
        $cres = New-CleanupResult
        Invoke-Cleanup -Type $def.Type -FilePath $checkPath -Log $clog -Result $cres -DetailLimit $DetailLimit
        if ($add.Fallback) {
            Write-Warn ('{0} is not valid UTF-8: it was read as Windows-1252 (ANSI). Check the accented characters.' -f $def.AddName)
        }
        for ($k = 0; $k -lt $clog.Count; $k++) {
            # the checks ran on a temporary copy: show the real name of the Add file
            $clog[$k] = @($clog[$k][0], ($clog[$k][1] -replace '\.check\b', ''))
        }
        Show-Messages $clog
        if ($cres.Aborted -or $cres.Errors -gt 0) {
            Write-Err ('{0}: fix the errors above (line numbers are the ones of {0}) and run again. {1} not changed.' -f $def.AddName, $def.Name)
            $def.AddValid = $false
            $withErrors++
            continue
        }
        $def.AddCount = $add.Lines.Count
        $def.AddLines = $add.Lines
        $def.AddEffective = $add.Lines
        $def.ZapSrps = @($add.ZapSrps)
        if ($ShowAll) {
            if ($add.Converted + $add.Replaced -gt 0) { Write-Info ('{0}: {1} line(s) converted' -f $def.AddName, ($add.Converted + $add.Replaced)) }
            foreach ($smp in $add.Samples) { Write-Host ('           {0}' -f $smp) -ForegroundColor DarkGray }
        }
        # logos named by the new lines that have no file in the local logos folder
        $logoBases = Get-LogoBases $LogosDir
        $noLogoFile = New-Object 'System.Collections.Generic.List[string]'
        foreach ($al in $add.Lines) {
            $ep = $al.LastIndexOf([char]'=')
            if ($ep -ge 0) {
                $lg = $al.Substring($ep + 1).Trim().ToLowerInvariant()
                if ($lg.Length -gt 0 -and -not $logoBases.Contains($lg) -and -not $noLogoFile.Contains($lg)) { $noLogoFile.Add($lg) }
            }
        }
        if ($noLogoFile.Count -gt 0) {
            $more = ''
            if ($noLogoFile.Count -gt 8) { $more = ', ...' }
            Write-Warn ('{0}: no file in logos\ for: {1}{2} (fine if already on GitHub)' -f $def.AddName, ((@($noLogoFile | Select-Object -First 8)) -join ', '), $more)
        }
    }
    if ($createdAdd.Count -gt 0) {
        Write-Info ('1st run: the index files are downloaded into picons and {0} created. Write your lines in the Add file(s) and run the script a 2nd time to merge and write them.' -f ($createdAdd -join ', '))
    }

    # Cross-file rules (everything automatic)
    #  - a zapChannel line pasted in Add-UTF.txt makes the channel known by name: its SRP is removed from srp.index
    #    (its new line in Add-SRP.txt, with the new logo, is added as usual), see Merge-IndexLines
    #  - the SRP lines of Add-SRP.txt also update the logo of the same SRP already present in utf8snp.index
    $zapKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ($defs[0].AddValid -and $defs[0].AddCount -gt 0) {
        foreach ($z in $defs[0].ZapSrps) { [void]$zapKeys.Add($z.ToUpperInvariant()) }
    }
    if ($defs[1].AddValid) { $defs[1].RemoveKeys = @($zapKeys) }
    if ($defs[1].AddValid -and $defs[1].AddCount -gt 0) {
        $upd = New-Object 'System.Collections.Generic.List[string]'
        foreach ($al in $defs[1].AddLines) {
            $p = $al.LastIndexOf([char]'=')
            $upd.Add($al)
        }
        $defs[0].UpdateLines = @($upd)
    }

    # 3) what to do with each .index file (no questions: a backup is always made before writing)
    foreach ($def in $defs) {
        $def.Mode = 'skip'
        if (-not $def.AddValid) {
            Write-Warn ('Skipping {0} until {1} is fixed' -f $def.Name, $def.AddName)
            continue
        }
        if ((-not (Test-Path -LiteralPath $def.Dest -PathType Leaf)) -or $Download) { $def.Mode = 'download' } else { $def.Mode = 'inplace' }
    }

    # 4) download what is missing, merge the Add files. srp.index goes first: the logos of the srp.index lines
    #    that are removed are needed to clean utf8snp.index.
    $workSw = [System.Diagnostics.Stopwatch]::StartNew()
    $jobs = New-Object System.Collections.Generic.List[object]
    $removedLogos = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($def in @($defs[1], $defs[0])) {
        if ($def.Mode -eq 'skip') { continue }
        if ($def.Mode -eq 'inplace') {
            $def.Source = $def.Dest
        } else {
            $def.Source = Join-Path $WorkDir $def.Name
            Write-Info ('Downloading {0}' -f $def.Name)
            if (-not (Get-RemoteFile -Url ('{0}/{1}' -f $BaseUrl, $def.Name) -Destination $def.Source)) {
                $rejected++
                $def.Mode = 'failed'
                continue
            }
        }
        $jobPath = $def.Source
        $updCount = @($def.UpdateLines).Count
        $remKeys = @($def.RemoveKeys)
        $remLogos = $null
        if ($def.Type -eq 'utf8snp' -and $removedLogos.Count -gt 0) { $remLogos = $removedLogos }
        if ($def.AddCount -gt 0 -or $updCount -gt 0 -or $remKeys.Count -gt 0 -or $null -ne $remLogos) {
            $mergePath = Join-Path $WorkDir ($def.Name + '.merge')
            $m = Merge-IndexLines -Type $def.Type -Source $def.Source -AddLines $def.AddLines -UpdateLines $def.UpdateLines -RemoveKeys $remKeys -RemoveLogos $remLogos
            if ($null -ne $m) {
                [System.IO.File]::WriteAllText($mergePath, $m.Text, $Utf8NoBom)
                $def.SrcLines = $m.SrcLines
                $def.AddEffective = $m.AddKept
                $def.Overwritten = $m.Overwritten
                $def.Updated = $m.Updated
                $def.Removed = $m.Removed
                $def.Same = $m.Same
                $def.Dropped = $m.Dropped
                $def.StillUsing = $m.StillUsing
                foreach ($x in $m.RemovedLogos) { if ($x.Length -gt 0) { [void]$removedLogos.Add($x) } }
                $jobPath = $mergePath
            } elseif ($def.AddCount -gt 0) {
                # the source is not valid UTF-8: plain append, the checks will report the corrupted lines
                $def.SrcLines = Get-LineCount $def.Source
                New-MergedSource -Source $def.Source -AddLines $def.AddLines -Out $mergePath
                $jobPath = $mergePath
            }
            if ($jobPath -ne $def.Source) {
                $def.HasMerge = $true
                if ($def.AddCount -gt 0) { $def.Merged = $true }
            }
        }
        $def.Log = New-Object 'System.Collections.Generic.List[object]'
        $job = @{ Type = $def.Type; Path = $jobPath; Log = $def.Log; Result = (New-CleanupResult) }
        $def.Job = $job
        $jobs.Add($job)
    }

    if (-not $DryRun -and -not (Test-Path -LiteralPath $LogosDir -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $LogosDir -Force)
    }

    # 5) check and sort (one after the other, or on 2 CPU cores with -Parallel)
    if ($jobs.Count -gt 0) {
        $parallel = $Parallel -and ($jobs.Count -gt 1)
        if ($parallel) {
            try {
                Invoke-CleanupParallel -Jobs $jobs -DetailLimit $DetailLimit
            } catch {
                Write-Warn ('Parallel run failed ({0}): falling back to sequential' -f $_.Exception.Message)
                $parallel = $false
            }
        }
        if (-not $parallel) {
            foreach ($job in $jobs) {
                $job.Log.Clear()
                $job.Result = New-CleanupResult
                Invoke-Cleanup -Type $job.Type -FilePath $job.Path -Log $job.Log -Result $job.Result -DetailLimit $DetailLimit
            }
        }
    }

    # 6) one result line per file; write the results, empty the Add files that were merged
    $listLimit = 5
    if ($ShowAll) { $listLimit = -1 }
    foreach ($def in $defs) {
        if ($def.Mode -eq 'skip' -or $def.Mode -eq 'failed') { continue }
        $res = $def.Job.Result
        Show-Messages $def.Log

        if ($res.Aborted) {
            $note = ''
            if ($def.Merged) { $note = (' {0} not emptied.' -f $def.AddName) }
            Write-Host ('  [X] {0} NOT modified (errors above).{1}' -f $def.Name, $note) -ForegroundColor Red
            $rejected++
            continue
        }
        if ($def.HasMerge) { $res.Changed = $true }
        if ($res.Errors -gt 0) {
            $withErrors++
            Write-Warn ('{0}: {1} error(s) logged but not fixed: review manually' -f $def.Name, $res.Errors)
        }

        # your lines dropped because the identifier is repeated in the Add file
        $ignored = @()
        if ($def.Merged -and $res.DupInfo) {
            foreach ($d in $res.DupInfo) {
                $ix = [int]$d[0] - [int]$def.SrcLines - 1
                if ($ix -ge 0 -and $ix -lt @($def.AddEffective).Count) {
                    $ignored += [pscustomobject]@{ Line = @($def.AddEffective)[$ix]; OtherLogo = $d[3]; InAdd = ([int]$d[2] -gt [int]$def.SrcLines) }
                }
            }
        }
        $ignoredTotal += $ignored.Count

        # write (a backup of the previous file is saved first)
        $newText = $res.Out
        $writeNeeded = $true
        $status = ''
        if ($def.Mode -eq 'inplace' -and -not $res.Changed) {
            $unchanged++
            $writeNeeded = $false
            $status = 'already clean'
        }
        if ($writeNeeded -and (Test-Path -LiteralPath $def.Dest -PathType Leaf)) {
            $oldText = $Utf8NoBom.GetString([System.IO.File]::ReadAllBytes($def.Dest))
            if ([string]::Equals($oldText, $newText, [StringComparison]::Ordinal)) {
                $unchanged++
                $writeNeeded = $false
                $status = 'already up to date'
            } elseif (-not $NoBackup -and -not $DryRun) {
                [void](New-Item -ItemType Directory -Path $BackupDir -Force)
                Copy-Item -LiteralPath $def.Dest -Destination (Join-Path $BackupDir $def.Name) -Force
                $backupUsed = $true
            }
        }
        if ($writeNeeded) {
            if ($DryRun) {
                $status = 'would be written'
                $wouldWrite++
            } else {
                $tmp = $def.Dest + '.tmp'
                [System.IO.File]::WriteAllText($tmp, $newText, $Utf8NoBom)
                Move-Item -LiteralPath $tmp -Destination $def.Dest -Force
                $status = 'written'
                $copied++
            }
        }

        # the new lines are now in the index (or were already there): empty the Add file, keep a copy
        if ($def.Merged) {
            if ($DryRun) {
                $status = $status + '; ' + $def.AddName + ' would be emptied'
            } else {
                [void](New-Item -ItemType Directory -Path $BackupDir -Force)
                Copy-Item -LiteralPath $def.AddPath -Destination (Join-Path $BackupDir $def.AddName) -Force
                $backupUsed = $true
                $addText = Get-AddTemplate $def.Type
                if ($ignored.Count -gt 0) {
                    # the lines that were not added stay in the Add file, as comments
                    $extra = @('#', '# NOT added: the identifier is repeated in this file (the first line was kept).', '# To use one of them instead: delete the other line with the same identifier, then remove the leading # below.')
                    foreach ($g in $ignored) { $extra += ('# ' + $g.Line) }
                    $addText = $addText + (($extra -join "`r`n") + "`r`n")
                }
                [System.IO.File]::WriteAllText($def.AddPath, $addText, $Utf8NoBom)
                $status = $status + '; ' + $def.AddName + ' emptied'
            }
        }

        # the result line
        $bits = @()
        $nNew = [Math]::Max(0, $def.AddCount - $def.Dropped - $ignored.Count - $def.Same - $def.Overwritten.Count)
        if ($nNew -gt 0) { $bits += ('{0} added' -f $nNew) }
        if ($def.Overwritten.Count -gt 0) { $bits += ('{0} replaced' -f $def.Overwritten.Count) }
        if ($def.Removed.Count -gt 0) { $bits += ('{0} removed' -f $def.Removed.Count) }
        if ($def.Updated.Count -gt 0) { $bits += ('{0} logo(s) updated' -f $def.Updated.Count) }
        if ($def.Same -gt 0) { $bits += ('{0} already identical' -f $def.Same) }
        if ($def.Dropped -gt 0) { $bits += ('{0} skipped (channel now by name)' -f $def.Dropped) }
        if ($ignored.Count -gt 0) { $bits += ('{0} not added (repeated)' -f $ignored.Count) }
        $dupOther = $res.Duplicates - $ignored.Count
        if ($dupOther -gt 0) { $bits += ('{0} duplicate(s) cleaned' -f $dupOther) }
        if ($res.Fixed.Count -gt 0) { $bits += ('{0} fixed' -f $res.Fixed.Count) }
        if ($res.Empty -gt 0) { $bits += ('{0} empty line(s) removed' -f $res.Empty) }
        if ($bits.Count -eq 0) { $bits += 'no changes' }
        $color = 'Green'
        if ($status -like 'already*') { $color = 'DarkGray' }
        Write-Host ('  {0,-14}' -f $def.Name) -NoNewline -ForegroundColor Cyan
        Write-Host (($bits -join ', ') + '  ') -NoNewline
        Write-Host ('[{0}]' -f $status.TrimStart(';', ' ')) -ForegroundColor $color

        if ($def.Overwritten.Count -gt 0) {
            Write-Host '    replaced (old -> new):' -ForegroundColor DarkGray
            Write-Samples -Items $def.Overwritten -Limit $listLimit -Indent '      '
        }
        if ($def.Removed.Count -gt 0) {
            Write-Host '    removed:' -ForegroundColor DarkGray
            Write-Samples -Items $def.Removed -Limit $listLimit -Indent '      '
        }
        if ($def.Updated.Count -gt 0) {
            Write-Host '    logo updated (old -> new):' -ForegroundColor DarkGray
            Write-Samples -Items $def.Updated -Limit $listLimit -Indent '      '
        }
        if ($ignored.Count -gt 0) {
            Write-Host '    not added:' -ForegroundColor DarkGray
            foreach ($g in @($ignored | Select-Object -First $(if ($ShowAll) { 100000 } else { $listLimit }))) {
                if ($g.InAdd) { $why = ('repeated in {0}' -f $def.AddName) } else { $why = ("already in the index with logo '{0}'" -f $g.OtherLogo) }
                Write-Host ('      {0}   ({1})' -f $g.Line, $why) -ForegroundColor DarkGray
            }
        }
        if ($def.StillUsing.Count -gt 0) {
            Write-Warn ('{0}: {1} line(s) still use the old logo ({2}); nothing was removed (another satellite?):' -f $def.Name, $def.StillUsing.Count, (@($removedLogos) -join ', '))
            $showN = $listLimit
            if ($ShowAll) { $showN = $def.StillUsing.Count }
            foreach ($u in @($def.StillUsing | Select-Object -First $showN)) { Write-Host ('      {0}' -f $u) -ForegroundColor DarkGray }
            if ($def.StillUsing.Count -gt $showN) { Write-Host ('      ... {0} more (use -ShowAll to print all of them)' -f ($def.StillUsing.Count - $showN)) -ForegroundColor DarkGray }
        }
    }

    # 7) end
    if ($rejected -gt 0 -or $withErrors -gt 0) { $exitCode = 1 }
    Write-Host ''
    $endBits = @(('{0:N1} s' -f $workSw.Elapsed.TotalSeconds))
    if ($backupUsed) { $endBits += ('backup: {0}' -f $BackupDir) }
    Write-Host ('  Done ({0})' -f ($endBits -join ', ')) -ForegroundColor DarkGray

    if ($KeepDownload -or $rejected -gt 0) {
        Write-Host ('  Work files kept in: {0}' -f $WorkDir) -ForegroundColor DarkGray
    } else {
        Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    $ghUser = ''
    if ($GitHubUser) {
        if ($GitHubUser.Trim() -match $UserNameRe) { $ghUser = $GitHubUser.Trim() }
        else { Write-Warn ('"{0}" is not a valid GitHub user name: ignored' -f $GitHubUser) }
    }
    if ($ghUser) { $UploadUrl = $UploadUrlFmt -f $ghUser } else { $UploadUrl = $UploadUrlFmt -f 'YOUR_GITHUB_USERNAME' }

    if ($DryRun) {
        Write-Host '  Dry run finished: nothing was changed. Run again without -DryRun to apply.' -ForegroundColor Magenta
    } else {
        $logoRe = '^([a-z0-9_-]+)\.(default|light|dark|black|white)\.(png|svg)$'
        $logoFiles = @(Get-ChildItem -LiteralPath $LogosDir -File -ErrorAction SilentlyContinue)
        $badNames = @($logoFiles | Where-Object { $_.Name -cnotmatch $logoRe })

        # logo names used by the lines of the two index files (to spot logo files that no line points to)
        $usedLogos = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($def in $defs) {
            if (Test-Path -LiteralPath $def.Dest -PathType Leaf) {
                foreach ($l in [System.IO.File]::ReadLines($def.Dest)) {
                    $p = $l.LastIndexOf([char]'=')
                    if ($p -ge 0) { [void]$usedLogos.Add($l.Substring($p + 1).Trim()) }
                }
            }
        }
        $unused = @($logoFiles | Where-Object { $_.Name -cmatch $logoRe -and -not $usedLogos.Contains($Matches[1]) })

        foreach ($def in $defs) {
            $pending = 0
            if ($def.AddValid -and (Test-Path -LiteralPath $def.AddPath -PathType Leaf)) {
                $a = Read-AddFile -FilePath $def.AddPath -Type $def.Type -Limit 0
                if ($a.Ok) { $pending = $a.Lines.Count }
            }
            if ($pending -gt 0) { Write-Warn ('{0} still has {1} line(s) waiting: run the script again' -f $def.AddName, $pending) }
        }
        if ($badNames.Count -gt 0) {
            Write-Warn ('{0} file(s) in logos\ with a wrong name (must be <logo>.default.png/.svg, lowercase): {1}' -f $badNames.Count, ((@($badNames | Select-Object -First 5 | ForEach-Object { $_.Name })) -join ', '))
        }
        if ($unused.Count -gt 0) {
            Write-Warn ('{0} logo file(s) not used by any index line: {1}' -f $unused.Count, ((@($unused | Select-Object -First 5 | ForEach-Object { $_.Name })) -join ', '))
        }
        if ($rejected -gt 0 -or $withErrors -gt 0) { Write-Warn 'Some files were rejected or have errors: fix them and re-run before uploading.' }
        $anyDownloaded = $false
        $anyMerged = $false
        foreach ($def in $defs) {
            if ($def.Mode -eq 'download') { $anyDownloaded = $true }
            if ($def.Merged) { $anyMerged = $true }
        }
        if ($rejected -eq 0 -and $anyMerged -and $copied -gt 0) {
            Write-Host ''
            Write-Host '  Next (2nd run done): upload to GitHub' -ForegroundColor Cyan
            Write-Host ('    1. open {0}  ->  Add file > Upload files' -f $UploadUrl)
            Write-Host '    2. drag utf8snp.index, srp.index and the logos folder from picons (not backup or _download), then Commit changes'
            Write-Host '    3. open a pull request from your fork to picons/picons'
        } elseif ($anyDownloaded -and -not $anyMerged) {
            Write-Host ''
            Write-Host '  Next (1st run done):' -ForegroundColor Cyan
            Write-Host '    1. copy your logo files into picons\logos  (<logo>.default.png or .svg)'
            Write-Host '    2. write one line per channel in Add-UTF.txt and/or Add-SRP.txt (instructions inside)'
            Write-Host '    3. run this script again (2nd run)'
        }
        if ($Guide) {
        Write-Host ''
        Write-Host '  HOW TO ADD A NEW LOGO' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '  1. Copy the logo file(s) into the logos folder:'
        Write-Host ('       {0}' -f $LogosDir) -ForegroundColor Yellow
        Write-Host '     File name:  <logo>.default.png  or  <logo>.default.svg   e.g.  novipazar.default.svg'
        Write-Host '     (the variants .light  .dark  .black  .white are also allowed, png or svg)'
        Write-Host '     <logo> = lowercase, only letters, digits, _ and -'
        Write-Host ''
        Write-Host '  2. Write ONE NEW LINE per channel in the Add files, next to this script:'
        Write-Host ('       {0}' -f $BaseDir) -ForegroundColor Yellow
        Write-Host '       Add-UTF.txt   goes into utf8snp.index   <channel name>=<logo>    e.g.  kabelio itv2=itv2'
        Write-Host '                                         or    <SRP>=<logo>             e.g.  1D5_B_1_130000=novipazar'
        Write-Host '       Add-SRP.txt   goes into srp.index       <SRP>=<logo>             e.g.  1D5_B_1_130000=novipazar'
        Write-Host '     Open them with a text editor (Notepad, Notepad++, VS Code...) and save as UTF-8.'
        Write-Host '     Any order is fine; lines starting with # are ignored (the instructions are inside the files).'
        Write-Host '     <logo> is the name of the logo file of step 1 without ".default.png" / ".default.svg".'
        Write-Host '     The SRP is made of the 4 hex values SID, TSID, ONID and NAMESPACE of the channel,'
        Write-Host '     uppercase, without leading zeros, separated by "_". In an enigma2 service reference'
        Write-Host '     1:0:TYPE:SID:TSID:ONID:NAMESPACE:0:0:0:  they are the 4 values after the TYPE.'
        Write-Host ''
        Write-Host '  3. Run this script again. It checks your lines, shows what it is going to do and asks'
        Write-Host '     before writing into the .index files (a backup is saved in backup). Your lines'
        Write-Host '     are merged, the files are sorted and the Add files are emptied.'
        Write-Host ''
        Write-Host '  HOW TO UPLOAD TO GITHUB' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '  4. Open the build-source folder of YOUR fork of picons/picons in your browser:'
        Write-Host ('       {0}' -f $UploadUrl) -ForegroundColor Yellow
        Write-Host ('     No fork yet? Open {0} and click "Fork" first.' -f $UpstreamUrl)
        Write-Host '  5. Click "Add file" ---> "Upload files"'
        Write-Host '  6. Drag and drop from the picons folder:'
        Write-Host ('       {0}' -f $PiconsDir) -ForegroundColor Yellow
        Write-Host '       - utf8snp.index and srp.index'
        Write-Host '       - the "logos" folder'
        Write-Host '     (do NOT upload the "backup" and "_download" folders)'
        Write-Host '  7. Write a short commit message (e.g. "Add <logo> logo") and click the green button at'
        Write-Host '     the bottom ("Commit changes").'
        Write-Host ('  8. Then open {0} and click "Compare & pull request"' -f $UpstreamUrl)
        Write-Host '     (or "Contribute" ---> "Open pull request") to send your changes to the picons repository.'
        Write-Host ''
        }
    }

    if ($Open -and -not $DryRun) {
        try {
            Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $PiconsDir)
            if ($ghUser) { Start-Process -FilePath $UploadUrl }
        } catch {
            Write-Warn ('Could not open the folder/page automatically: {0}' -f $_.Exception.Message)
        }
    }
}
catch {
    Write-Host ''
    Write-Err ('Unexpected error: {0}' -f $_.Exception.Message)
    Write-Host ('  {0}' -f $_.InvocationInfo.PositionMessage) -ForegroundColor DarkGray
    $exitCode = 2
}

# The output of the run is saved next to the backups when something was written or something went wrong
if ($transcribing) {
    try { Stop-Transcript | Out-Null } catch { }
    try {
        if ($BackupDir -and ($exitCode -ne 0 -or $copied -gt 0 -or (Test-Path -LiteralPath $BackupDir -PathType Container))) {
            [void](New-Item -ItemType Directory -Path $BackupDir -Force)
            Copy-Item -LiteralPath $LogTemp -Destination (Join-Path $BackupDir 'log.txt') -Force
            Write-Host ('  Log saved in {0}' -f (Join-Path $BackupDir 'log.txt')) -ForegroundColor DarkGray
        }
    } catch { }
    Remove-Item -LiteralPath $LogTemp -Force -ErrorAction SilentlyContinue
}

if ($Pause) { [void](Read-Host 'Press Enter to close') }
exit $exitCode
