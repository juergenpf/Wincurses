# See License.md in the project root for license information.
[string]$DEFAULT_WSL_DISTRO="Ubuntu"
[string]$Wincurses_REPO_PATH='\\wsl.localhost\Ubuntu\home\juergen\repos\git\Wincurses'

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

function Set-WincursesTestLocation {
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
        push-location $loc
        if (Test-Path -Path "test" -PathType Container) {
            set-location "test"
        }
   }
}

Set-Alias cdwct Set-WincursesTestLocation
