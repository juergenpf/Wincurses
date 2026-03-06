# See License.md in the project root for license information.

function Get-WincursesDirectory {
    [CmdletBinding()]
    param()
    [string]$dir="@REPOPATH@"
    Write-verbose "Wincurses directory: $dir"
    return $dir
}

function Get-MinGWGDBPath {
    [CmdletBinding()]
    param(
        [Switch]$msvcrt,
        [Switch]$x86
    )
    [string]$prefix="ucrt64"
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MSYS2 64bit_is1"
    $installDir = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).InstallLocation

    if ([string]::IsNullOrEmpty($installDir)) {
        if (Test-Path "${Env:SystemDrive}\msys64") { 
            $installDir = "${Env:SystemDrive}\msys64" 
        }
    }

    if ($msvcrt) {
        $prefix="mingw64"
        if ($x86) {
            $prefix="mingw32"
        }
    }
    if (-not [string]::IsNullOrEmpty($installDir)) {
        $gdbPath = Join-Path (Join-Path (Join-Path $installDir $prefix) "bin") "gdb.exe"
        if (Test-Path $gdbPath -PathType Leaf) {
            Write-Verbose "Found gdb.exe at $gdbPath"
            return $gdbPath
        } else {
            Write-Error "gdb.exe not found"
        }
    }
    return $null
}


function ConsistencyCheck {
    param(
        [bool]$wnc_x86,
        [bool]$wnc_woa,
        [bool]$wnc_ucrt,
        [ref]$wnc_prefix
    )
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
        $wnc_prefix.Value = "mingw64"
        if ($wnc_x86) {
            $wnc_prefix.Value = "mingw32"
        }
    }
    return $true
}

function BuildPrefix {
    param(
        [bool]$wnc_debug,
        [string]$wnc_arch
    )
    [string]$prefix = "debug"
    if (-not $wnc_debug) {
        $prefix = "release"
    }
    return (Join-Path (Join-Path $prefix "WindowsCross") $wnc_arch)
}

function GetSuffix {
    param(
        [bool]$wnc_reentrant,
        [bool]$wnc_wide
    )
    $suffix = ""
    if ($wnc_reentrant) {
        $suffix = "t${suffix}"
    }
    if ($wnc_wide) {
        $suffix = "w${suffix}"
    }
    return $suffix
}

function RelativeBuildDir {
    param(
        [bool]$wnc_debug,
        [string]$wnc_arch,
        [bool]$wnc_reentrant,
        [bool]$wnc_wide,
        [string]$wnc_prefix
    )
    $suffix = GetSuffix -wnc_reentrant:$wnc_reentrant -wnc_wide:$wnc_wide
    $pre = BuildPrefix -wnc_debug:$wnc_debug -wnc_arch:$wnc_arch
    return (Join-Path (Join-Path $pre "nc${suffix}") $wnc_prefix)
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

    [string]$wnc_arch = "x86_64"
    [string]$wnc_prefix = "ucrt64"
    [Bool]$wnc_debug = $true
    [Bool]$wnc_wide = $true
    [Bool]$wnc_reentrant = $false
    [Bool]$wnc_ucrt = $true
    [Bool]$wnc_static = $true
    [Bool]$wnc_libseparate = $false
    [Bool]$wnc_x86 = $false
    [Bool]$wnc_woa = $false

    if ($msvcrt) {
        $wnc_ucrt = $false
    }
    if ($x86) {
        $wnc_x86 = $true
        $wnc_arch = "i686"
    }
    if ($WoA) {
        $wnc_woa = $true
        $wnc_arch = "aarch64"
    }
    if ($Ascii) {
        $wnc_wide = $false
    }
    if ($Nodebug) {
        $wnc_debug = $false
    }
    if ($Reentrant) {
        $wnc_reentrant = $true
    }
    if ($Dynamic) {
        $wnc_static = $false
    }
    if ($LibSeparate) {
        $wnc_libseparate = $true
    }

    $prefixRef = [ref]$wnc_prefix
    if (-not (ConsistencyCheck -wnc_x86:$wnc_x86 -wnc_woa:$wnc_woa -wnc_ucrt:$wnc_ucrt -wnc_prefix:$prefixRef)) {
        Write-Error "Inconsistent configuration"
        return
    }
    $wnc_prefix = $prefixRef.Value

    [string]$loc = (Join-Path (Join-Path (Get-WincursesDirectory) "build") (RelativeBuildDir -wnc_debug:$wnc_debug -wnc_arch:$wnc_arch -wnc_reentrant:$wnc_reentrant -wnc_wide:$wnc_wide -wnc_prefix:$wnc_prefix))
    if (Test-Path -path $loc  -PathType Container) {
        [string]$lib = (Join-Path $loc "lib")
        if (-not $wnc_static) {
            $Env:PATH = "$lib;$Env:PATH"
        }
        $Env:TERM="ms-terminal"
        Write-Verbose "Pushing location $loc"
        push-location $loc
        if (Test-Path -Path "test" -PathType Container) {
            write-verbose "Entering directory test"
            set-location "test"
        }
    } else {
        Write-Error "Build directory not found: $loc"
    }
}

function Start-MinGWDebug {
    [CmdletBinding()]
    param(
        [string]$Program,
        [Switch]$msvcrt,
        [Switch]$x86
    )
    $gdbPath = Get-MinGWGDBPath -msvcrt:$msvcrt -x86:$x86
    if ($gdbPath) {
        & $gdbPath $Program
    }
    else {
            Write-Error "gdb.exe not found"
    }
}

Set-Alias pwct Push-WincursesTestLocation
Set-Alias ncdbg Start-MinGWDebug
