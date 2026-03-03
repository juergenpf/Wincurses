# See License.md in the project root for license information.
[string]$DEFAULT_WSL_DISTRO='@DISTRO@'
[string]$Wincurses_REPO_PATH='@REPOPATH@'

[string]$wnc_arch="x86_64"
[string]$wnc_prefix="ucrt64"

[Bool]$wnc_debug=$true
[Bool]$wnc_wide=$true
[Bool]$wnc_reentrant=$false
[Bool]$wnc_ucrt=$true
[Bool]$wnc_static=$true
[Bool]$wnc_libseparate=$false
[Bool]$wnc_x86=$false
[Bool]$wnc_woa=$false

function Get-WincursesDirectory {
    param()
    return $Wincurses_REPO_PATH
}

function Get-MinGWGDBPath {
    param()
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MSYS2 64bit_is1"
    $installDir = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).InstallLocation

    if ([string]::IsNullOrEmpty($installDir)) {
        if (Test-Path "${Env:SystemDrive}\msys64") { 
            $installDir = "${Env:SystemDrive}\msys64" 
        }
    }

    if (-not [string]::IsNullOrEmpty($installDir)) {
        $gdbPath = Join-Path (Join-Path (Join-Path $installDir "mingw64") "bin") "gdb.exe"
        if (Test-Path $gdbPath -PathType Leaf) {
            return $gdbPath
        } else {
            Write-Error "gdb.exe not found"
        }
    }
    return $null
}

function Push-WincursesTestLocation {
    [CmdletBinding()]
    param(
        [Switch]$Ascii,
        [Switch]$Reentrant,
        [Switch]$Nodebug,
        [Switch]$x86,
        [Switch]$WoA,
        [Switch]$Dynamic,
        [Switch]$LibSeparate,
        [Switch]$msvcrt
    )

    function ConsistencyCheck() {
        param()
        if ($wnc_x86 -and $wnc_woa) {
            Write-Error "-x86 and -WoA are mutually exclusive"
            return $false
        }
        if ($wnc_x86 -and $wnc_ucrt) {
            Write-Error "-x86 requires -msvcrt"
            return $false
        }
        if ($wnc_woa -and (-not $wnc_ucrt)) {
            Write-Error "-WoA and --msvcrt are mutually exclusive"
            return $false
        }
        if (-not $wnc_ucrt) {
            $wnc_prefix="mingw64"
            if ($wnc_x86) {
                $wnc_prefix="mingw32"
            }
        }
        return $true
    }

    function build_prefix {
        param()
        [string]$prefix="debug"

        if (-not $wnc_debug) {
            $prefix="release"
        }
        return (Join-Path (Join-Path $prefix "WindowsCross") $wnc_arch)
    }

    function Get-Suffix {
        param()
        $suffix=""
        if ($wnc_reentrant) {
            $suffix="t${suffix}" 
        }
        if ($wnc_wide) {
            $suffix="w${suffix}" 
        }
        return $suffix
    }

    function relative_builddir {
        param()
        $suffix=(Get-Suffix)
        $pre=$(build_prefix)
        return (Join-Path (Join-Path $pre "nc${suffix}") $wnc_prefix) 
    }

    if ($msvcrt) {
        $wnc_ucrt=$false
    }
    if ($x86){
        $wnc_x86=$true
        $wnc_arch="i686"
    }
    if ($WoA) {
        $wnc_woa=$true
        $wnc_arch="aarch64"
    }
    if ($Ascii) {
        $wnc_wide=$false
    }
    if ($Nodebug) {
        $wnc_debug=$false
    }
    if ($Reentrant) {
        $wnc_reentrant=$true
    }
    if ($Dynamic) {
        $wnc_static=$false
    }
    if ($LibSeparate) {
        $wnc_libseparate=$true
    }

    if (-not (ConsistencyCheck)) {
        return
    }

   [string]$loc=(Join-Path (Join-Path (Get-WincursesDirectory) "build") (relative_builddir))
   if (Test-Path -path $loc  -PathType Container) {
       [string]$lib=(Join-Path $loc "lib")
       if (-not $wnc_static) {
           $Env:PATH="$lib;$Env:PATH"
       }
        push-location $loc
        if (Test-Path -Path "test" -PathType Container) {
            set-location "test"
        }
   }
}

function Start-MinGWDebug {
    param(
        [string]$Program
    )
    $gdbPath = Get-MinGWGDBPath
    if ($gdbPath) {
        & $gdbPath $Program
    }
    else {
            Write-Error "gdb.exe not found"
    }
}

Set-Alias pwct Push-WincursesTestLocation
Set-Alias ncdbg Start-MinGWDebug
