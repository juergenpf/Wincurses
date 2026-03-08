# Copyright (c) 2026 Juergen Pfeifer.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Get-WincursesDirectory {
    [CmdletBinding()]
    param()
    [string]$dir="@REPOPATH@"
    return $dir
}

function Get-MinGWDebugPath {
    [CmdletBinding()]
    param(
        [Switch]$msvcrt,
        [Switch]$x86,
        [Switch]$woa
    )
    [string]$prefix="ucrt64"
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MSYS2 64bit_is1"
    $installDir = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).InstallLocation
    [string]$debugger="gdb"

    if ($woa -and ($x86 -or $msvcrt)) {
        Write-Error "-woa Option must not be used together with -x86 or -msvcrt"
        return $null
    }

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
    if ($woa) {
        $prefix="clangarm64"
        $debugger="lldb"
    }

    if (-not [string]::IsNullOrEmpty($installDir)) {
        $dbgPath = Join-Path (Join-Path (Join-Path $installDir $prefix) "bin") "${debugger}.exe"
        if (Test-Path $dbgPath -PathType Leaf) {
            Write-Verbose "Found ${debugger}.exe at $dbgPath"
            return $dbgPath
        } else {
            Write-Error "${debugger}.exe not found"
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
    if ($wnc_woa) {
       $wnc_prefix.Value = "clangarm64"
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

function RelativeInstallBase {
    param(
        [bool]$wnc_debug,
        [string]$wnc_arch,
        [bool]$wnc_reentrant,
        [bool]$wnc_wide
    )
    $suffix = GetSuffix -wnc_reentrant:$wnc_reentrant -wnc_wide:$wnc_wide
    $pre = BuildPrefix -wnc_debug:$wnc_debug -wnc_arch:$wnc_arch
    return (Join-Path $pre "nc${suffix}")
}

function RelativeInstallDir {
    param(
        [bool]$wnc_debug,
        [string]$wnc_arch,
        [bool]$wnc_reentrant,
        [bool]$wnc_wide,
        [string]$wnc_prefix
    )
    return (Join-Path (RelativeInstallBase -wnc_debug:$wnc_debug -wnc_arch:$wnc_arch -wnc_reentrant:$wnc_reentrant -wnc_wide:$wnc_wide) $wnc_prefix)
}   

function Push-WincursesTestLocation {
    [CmdletBinding()]
    param(
        [Switch]$ascii,
        [Switch]$reentrant,
        [Switch]$nodebug,
        [Switch]$x86,
        [Switch]$woa,
        [Switch]$dynamic,
        [Switch]$libSeparate,
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
    if ($woa) {
        $wnc_woa = $true
        $wnc_arch = "aarch64"
    }
    if ($ascii) {
        $wnc_wide = $false
    }
    if ($nodebug) {
        $wnc_debug = $false
    }
    if ($reentrant) {
        $wnc_reentrant = $true
    }
    if ($dynamic) {
        $wnc_static = $false
    }
    if ($libSeparate) {
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
        [string]$inst=(Join-Path (Join-Path (Get-WincursesDirectory) "inst") (RelativeInstallDir -wnc_debug:$wnc_debug -wnc_arch:$wnc_arch -wnc_reentrant:$wnc_reentrant -wnc_wide:$wnc_wide -wnc_prefix:$wnc_prefix))
        [string]$lib = (Join-Path $loc "lib")
        [string]$bin=(Join-Path $inst "bin")
        if (-not $wnc_static) {
            if (Test-Path -Path $bin -PathType Container) {
                Write-Verbose "Adding $bin to PATH"
                $Env:PATH = "$bin;$Env:PATH"
            } else {
                if (Test-Path -Path $lib -PathType Container) {
                    Write-Verbose "Adding $lib to PATH"
                    $Env:PATH = "$lib;$Env:PATH"
                } else {
                    Write-Error "Neither $bin nor $lib directory found"
                }
            }
        }
        $Env:TERM="ms-terminal"
        Write-Verbose "Set TERM to ms-terminal"
        [string]$tinfo=(Join-Path (Join-Path $inst "share") "terminfo")
        if (Test-Path -Path $tinfo -pathtype Container) {
            Write-Verbose "Setting TERMINFO to $tinfo"
            $Env:TERMINFO=$tinfo
        } else {    
            write-verbose "TERMINFO directory not found, relying on fallback settings"
        }
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
        [Switch]$x86,
	[Switch]$woa
    )
    $dbgPath = Get-MinGWDebugPath -msvcrt:$msvcrt -x86:$x86 -woa:$woa
    if ($dbgPath) {
        & $dbgPath $Program
    }
    else {
            Write-Error "Debugger not found"
    }
}

Set-Alias pwct Push-WincursesTestLocation
Set-Alias ncdbg Start-MinGWDebug
