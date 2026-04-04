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

function GetConfigPrefix {
    [CmdletBinding()]
    param(
        [Switch]$msvcrt,
        [Switch]$x86,
        [Switch]$aarch64
    )
    [string]$prefix="ucrt64"
    if ($msvcrt) {
        $prefix="mingw64"
        if ($x86) {
            $prefix="mingw32"
        }
    }
    if ($aarch64) {
        $prefix="clangarm64"
    }
    return $prefix
}

function GetTargetArch {
    param(
        [Switch]$x86,
        [Switch]$aarch64
    )
    if ($aarch64) {
        return "aarch64"
    }
    if ($x86) {
        return "i686"
    }
    return "x86_64"
}

function Get-MinGWDebugPath {
    [CmdletBinding()]
    param(
        [Switch]$msvcrt,
        [Switch]$x86,
        [Switch]$aarch64
    )
    [string]$prefix="ucrt64"
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MSYS2 64bit_is1"
    $installDir = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).InstallLocation
    [string]$prefix = GetConfigPrefix -msvcrt:$msvcrt -x86:$x86 -aarch64:$aarch64
    [string]$debugger="gdb"

    if ($aarch64 -and ($x86 -or $msvcrt)) {
        Write-Error "-aarch64 option must not be used together with -x86 or -msvcrt"
        return $null
    }
    if ($aarch64) {
        $debugger="lldb"
    }

    if ([string]::IsNullOrEmpty($installDir)) {
        if (Test-Path "${Env:SystemDrive}\msys64") { 
            $installDir = "${Env:SystemDrive}\msys64" 
        }
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
        [Switch]$release,
        [Switch]$ascii,
        [Switch]$reentrant,
        [Switch]$spfuncs,
        [Switch]$interop,
        [Switch]$conpty,
        [Switch]$winconsole,
        [Switch]$x86,
        [Switch]$aarch64,
        [Switch]$dynamic,
        [Switch]$termlib,
        [Switch]$msvcrt
    )
    [int]$targets=0

    if ($x86) { $targets++ }
    if ($aarch64) { $targets++ }
    if ($targets -gt 1) {
        Write-Error "Multiple target architectures specified. Only one of -x86 or -aarch64 can be used. x86_64 is default."
        return $false
    }
    if (-not ($conpty -or $winconsole)) {
        Write-Error "At least one of -conpty or -winconsole must be specified"
        return $false
    }
    if ($x86 -and (-not $msvcrt)) {
        Write-Error "-x86 requires -msvcrt"
        return $false
    }
    if ($aarch64 -and $msvcrt) {
        Write-Error "-aarch64 and -msvcrt are mutually exclusive. Windows on ARM implies UCRT."
        return $false
    }
    return $true
}

function BuildPrefix {
    param(
        [Switch]$release,
        [Switch]$x86,
        [Switch]$aarch64
    )
    [string]$prefix = "debug"
    if ($release) {
        $prefix = "release"
    }
    return (Join-Path (Join-Path $prefix "WindowsCross") (GetTargetArch -x86:$x86 -aarch64:$aarch64))
}

function GetSuffix {
    param(
        [Switch]$reentrant,
        [Switch]$ascii
    )
    [string]$sufft = ""
    [string]$suffw = ""
    if ($reentrant) {
        $sufft = "t"
    }
    if (-not $ascii) {
        $suffw = "w"
    }
    return "${sufft}${suffw}"
}

function GetExtraSuffix {
    param(
        [Switch]$spfuncs,
        [Switch]$interop,
        [Switch]$conpty,
        [Switch]$winconsole
    )
    $suffix = ""
    if ($spfuncs) {
        $suffix = "${suffix}s"
    }
    if ($interop) {
        $suffix = "${suffix}i"
    }
    if ($conpty) {
        $suffix = "${suffix}p"
    }
    if ($winconsole) {
        $suffix = "${suffix}c"
    }
    return $suffix
}

function RelativeBuildDir {
    param(
        [Switch]$release,
        [Switch]$reentrant,
        [Switch]$interop,
        [Switch]$spfuncs,
        [Switch]$ascii,
        [Switch]$x86,
        [Switch]$aarch64,
        [Switch]$msvcrt,
        [Switch]$conpty,
        [Switch]$winconsole
    )
    $suffix = GetSuffix -reentrant:$reentrant -ascii:$ascii
    $extraSuffix = GetExtraSuffix -spfuncs:$spfuncs -interop:$interop -conpty:$conpty -winconsole:$winconsole
    $pre = BuildPrefix -release:$release -x86:$x86 -aarch64:$aarch64
    return (Join-Path (Join-Path $pre "nc${suffix}${extraSuffix}") (GetConfigPrefix -msvcrt:$msvcrt -x86:$x86 -aarch64:$aarch64))
}


function RelativeInstallBase {
    param(
        [Switch]$release,
        [Switch]$reentrant,
        [Switch]$interop,
        [Switch]$spfuncs,
        [Switch]$ascii,
        [Switch]$x86,
        [Switch]$aarch64,
        [Switch]$msvcrt,
        [Switch]$conpty,
        [Switch]$winconsole
    )
    $suffix = GetSuffix -reentrant:$reentrant -ascii:$ascii
    $extraSuffix = GetExtraSuffix -spfuncs:$spfuncs -interop:$interop -conpty:$conpty -winconsole:$winconsole
    $pre = BuildPrefix -release:$release -x86:$x86 -aarch64:$aarch64
    return (Join-Path $pre "nc${suffix}${extraSuffix}")
}

function RelativeInstallDir {
    param(
        [Switch]$release,
        [Switch]$reentrant,
        [Switch]$interop,
        [Switch]$spfuncs,
        [Switch]$ascii,
        [Switch]$x86,
        [Switch]$aarch64,
        [Switch]$msvcrt,
        [Switch]$conpty,
        [Switch]$winconsole
    )
    return (Join-Path (RelativeInstallBase -release:$release -x86:$x86 -aarch64:$aarch64 -reentrant:$reentrant -ascii:$ascii -msvcrt:$msvcrt -spfuncs:$spfuncs -interop:$interop -conpty:$conpty -winconsole:$winconsole) (GetConfigPrefix -msvcrt:$msvcrt -x86:$x86 -aarch64:$aarch64))
}

function Push-WincursesTestLocation {
    [CmdletBinding()]
    param(
        [Switch]$release,
        [Switch]$ascii,
        [Switch]$reentrant,
        [Switch]$spfuncs,
        [Switch]$interop,
        [Switch]$conpty,
        [Switch]$winconsole,
        [Switch]$x86,
        [Switch]$aarch64,
        [Switch]$dynamic,
        [Switch]$termlib,
        [Switch]$msvcrt
    )
    [bool]$isconpty = $conpty
    if (!($conpty -or $winconsole)) {
        $isconpty = $true
    }
    if (-not (ConsistencyCheck -release:$release -ascii:$ascii -reentrant:$reentrant -spfuncs:$spfuncs -interop:$interop -conpty:$isconpty -winconsole:$winconsole -x86:$x86 -aarch64:$aarch64 -msvcrt:$msvcrt)) {
        Write-Error "Inconsistent configuration"
        return
    }

    $Env:WNCDEBUG=""
    
    [string]$loc = (Join-Path (Join-Path (Get-WincursesDirectory) "build") (RelativeBuildDir -release:$release -x86:$x86 -aarch64:$aarch64 -reentrant:$reentrant -ascii:$ascii -msvcrt:$msvcrt -spfuncs:$spfuncs -interop:$interop -conpty:$isconpty -winconsole:$winconsole))
    if (Test-Path -path $loc  -PathType Container) {
        [string]$inst=(Join-Path (Join-Path (Get-WincursesDirectory) "inst") (RelativeInstallDir -release:$release -x86:$x86 -aarch64:$aarch64 -reentrant:$reentrant -ascii:$ascii -msvcrt:$msvcrt -spfuncs:$spfuncs -interop:$interop -conpty:$isconpty -winconsole:$winconsole))
        [string]$lib = (Join-Path $loc "lib")
        [string]$bin = (Join-Path $inst "bin")
        if ($dynamic) {
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
        $Env:WNCDEBUG=(Get-MinGWDebugPath -msvcrt:$msvcrt -x86:$x86 -aarch64:$aarch64)

    } else {
        Write-Error "Build directory not found: $loc"
    }
}

function Start-MinGWDebug {
    [CmdletBinding()]
    param(
        [string]$Program
    )
    $dbgPath = $Env:WNCDEBUG
    if ($dbgPath) {
        & $dbgPath $Program
    }
    else {
            Write-Error "Debugger not found"
    }
}

Set-Alias pwct Push-WincursesTestLocation
Set-Alias ncdbg Start-MinGWDebug
