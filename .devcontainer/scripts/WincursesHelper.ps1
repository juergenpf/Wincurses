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
        [Switch]$woa
    )
    [string]$prefix="ucrt64"
    if ($msvcrt) {
        $prefix="mingw64"
        if ($x86) {
            $prefix="mingw32"
        }
    }
    if ($woa) {
        $prefix="clangarm64"
    }
    return $prefix
}

function GetTargetArch {
    patam(
        [Switch]$x86,
        [Switch]$woa
    )
    if ($woa) {
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
        [Switch]$woa
    )
    [string]$prefix="ucrt64"
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MSYS2 64bit_is1"
    $installDir = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).InstallLocation
    [string]$prefix = GetConfigPrefix -msvcrt:$msvcrt -x86:$x86 -woa:$woa
    [string]$debugger="gdb"

    if ($woa -and ($x86 -or $msvcrt)) {
        Write-Error "-woa Option must not be used together with -x86 or -msvcrt"
        return $null
    }
    if ($woa) {
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
        [Switch]$x86,
        [Switch]$woa,
        [Switch]$msvcrt
    )
    if ($x86 -and $woa) {
        Write-Error "-x86 and -WoA are mutually exclusive"
        return $false
    }
    if ($x86 -and (-not $msvcrt)) {
        Write-Error "-x86 requires -msvcrt"
        return $false
    }
    if ($woa -and $msvcrt) {
        Write-Error "-WoA and --msvcrt are mutually exclusive"
        return $false
    }
    return $true
}

function BuildPrefix {
    param(
        [Switch]$nodebug,
        [Switch]$x86,
        [Switch]$woa
    )
    [string]$prefix = "debug"
    if ($nodebug) {
        $prefix = "release"
    }
    return (Join-Path (Join-Path $prefix "WindowsCross") (GetTargetArch -x86:$x86 -woa:$woa))
}

function GetSuffix {
    param(
        [Switch]$reentrant,
        [Switch]$ascii
    )
    $suffix = ""
    if ($reentrant) {
        $suffix = "t${suffix}"
    }
    if (-not $ascii) {
        $suffix = "w${suffix}"
    }
    return $suffix
}

function RelativeBuildDir {
    param(
        [Switch]$nodebug,
        [Switch]$reentrant,
        [Switch]$ascii,
        [Switch]$x86,
        [Switch]$woa,
        [Switch]$msvcrt
    )
    $suffix = GetSuffix -reentrant:$reentrant -ascii:$ascii
    $pre = BuildPrefix -nodebug:$nodebug -x86:$x86 -woa:$woa
    return (Join-Path (Join-Path $pre "nc${suffix}") (GetConfigPrefix -msvcrt:$msvcrt -x86:$x86 -woa:$woa))
}


function RelativeInstallBase {
    param(
        [Switch]$nodebug,
        [Switch]$reentrant,
        [Switch]$ascii,
        [Switch]$x86,
        [Switch]$woa,
        [Switch]$msvcrt
    )
    $suffix = GetSuffix -reentrant:$reentrant -ascii:$ascii
    $pre = BuildPrefix -nodebug:$nodebug -x86:$x86 -woa:$woa
    return (Join-Path $pre "nc${suffix}")
}

function RelativeInstallDir {
    param(
        [Switch]$nodebug,
        [Switch]$reentrant,
        [Switch]$ascii,
        [Switch]$x86,
        [Switch]$woa,
        [Switch]$msvcrt
    )
    return (Join-Path (RelativeInstallBase -nodebug:$nodebug -x86:$x86 -woa:$woa -reentrant:$reentrant -ascii:$ascii -msvcrt:$msvcrt) (GetConfigPrefix -msvcrt:$msvcrt -x86:$x86 -woa:$woa))
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

    if (-not (ConsistencyCheck -x86:$x86 -woa:$woa -msvcrt:$msvcrt)) {
        Write-Error "Inconsistent configuration"
        return
    }

    $Env:WNCDEBUG=""
    
    [string]$loc = (Join-Path (Join-Path (Get-WincursesDirectory) "build") (RelativeBuildDir -nodebug:$nodebug -x86:$x86 -woa:$woa -reentrant:$reentrant -ascii:$ascii -msvcrt:$msvcrt))
    if (Test-Path -path $loc  -PathType Container) {
        [string]$inst=(Join-Path (Join-Path (Get-WincursesDirectory) "inst") (RelativeInstallDir -nodebug:$nodebug -x86:$x86 -woa:$woa -reentrant:$reentrant -ascii:$ascii -msvcrt:$msvcrt))
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
        $Env:WNCDEBUG=(Get-MinGWDebugPath -msvcrt:$msvcrt -x86:$x86 -woa:$woa)

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
