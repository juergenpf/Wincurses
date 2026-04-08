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
    <#
    .SYNOPSIS
        Returns the root directory of the Wincurses repository.
    .DESCRIPTION
        Returns the absolute path to the Wincurses repository root as configured
        at install time. The path is substituted into the script during deployment.
    .OUTPUTS
        System.String. The absolute path to the repository root.
    #>
    [CmdletBinding()]
    param()
    [string]$dir="@REPOPATH@"
    return $dir
}

function GetEffectiveBuildRoot {
    [CmdletBinding()]
    param([int]$JobID)

    [string]$repoRoot = Get-WincursesDirectory
    [string]$buildRoot = $repoRoot
    if ($JobID -ne $null -or $jobid -gt 0) {
        $buildRoot = (Join-PAth $repoRoot (Join-Path (Join-Path ".bulk" "jobs") $JobID.ToString()))
    }
    return $buildRoot
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
    <#
    .SYNOPSIS
        Navigates into a Wincurses build output directory and configures the environment for testing.
    .DESCRIPTION
        Resolves the build and install directories for the specified Wincurses build configuration,
        sets TERM and TERMINFO environment variables, optionally adds the library or binary directory
        to PATH for dynamic builds, and pushes the build test directory onto the location stack.
        Also sets the WNCDEBUG environment variable to the path of the appropriate MinGW debugger
        (gdb for x86/x86_64, lldb for aarch64/Windows-on-ARM).

        Use Pop-Location (or the 'popd' alias) to return from the test directory.
        Use the 'ncdbg' alias to launch the debugger on a test program.
    .PARAMETER release
        Select the release build configuration. Default is debug.
    .PARAMETER ascii
        Select the 8-bit ASCII (narrow character) variant of the library.
        Default is wide (Unicode) character support.
    .PARAMETER reentrant
        Select the reentrant (thread-safe) variant of the library.
    .PARAMETER spfuncs
        Select the build with sp-funcs (screen-pointer functions) support enabled.
    .PARAMETER interop
        Select the build with interop features enabled.
    .PARAMETER conpty
        Select the build with ConPTY console support.
        Intended for Windows 10 version 1809 (build 17763) and later.
        At least one of -conpty or -winconsole must be specified.
        If neither is given, -conpty is assumed as the default.
    .PARAMETER winconsole
        Select the build with classic Windows Console API (screen-buffer) support.
        Intended for Windows versions older than Windows 10 1809, including Windows 8 and earlier.
        Can be combined with -conpty to select a build that supports both backends.
    .PARAMETER x86
        Select the x86 (i686, 32-bit) target architecture. Requires -msvcrt.
    .PARAMETER aarch64
        Select the aarch64 (ARM64, Windows-on-ARM) target architecture.
        Implies UCRT runtime; cannot be combined with -msvcrt or -x86.
    .PARAMETER dynamic
        Add the build library or install bin directory to PATH so that
        dynamically-linked test programs can find the ncurses DLLs.
    .PARAMETER termlib
        Select the terminfo-library-only build variant.
    .PARAMETER msvcrt
        Select the MSVCRT (legacy C runtime) variant. Default is UCRT.
        Required for -x86 builds. Cannot be combined with -aarch64.
    .PARAMETER JobID
        If the build you want to test is part of a bulk job, specify the Job ID 
        to locate the correct build output. Default is 0, which means no bulk job.
    .EXAMPLE
        pwct -conpty
        Navigate to the default wide/debug/x86_64/UCRT/ConPTY build directory.
    .EXAMPLE
        pwct -conpty -winconsole -msvcrt -x86
        Navigate to the combined ConPTY+winconsole build for x86 MSVCRT.
    .EXAMPLE
        pwct -conpty -aarch64
        Navigate to the aarch64 (Windows-on-ARM) ConPTY build directory.
    .EXAMPLE
        pwct -conpty -release -wide -reentrant
        Navigate to the wide, reentrant, release build directory with ConPTY support.
    #>
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage="Select release build configuration (default: debug)")]
        [Switch]$release,
        [Parameter(HelpMessage="Select ASCII (narrow, 8-bit) character variant (default: wide)")]
        [Switch]$ascii,
        [Parameter(HelpMessage="Select the reentrant (thread-safe) library variant")]
        [Switch]$reentrant,
        [Parameter(HelpMessage="Enable sp-funcs (screen-pointer functions) support")]
        [Switch]$spfuncs,
        [Parameter(HelpMessage="Enable interop features")]
        [Switch]$interop,
        [Parameter(HelpMessage="Select ConPTY backend (Windows 10 1809+). Default when neither -conpty nor -winconsole is given.")]
        [Switch]$conpty,
        [Parameter(HelpMessage="Select classic Windows Console API backend (legacy Windows, pre-Win10 1809). Can be combined with -conpty.")]
        [Switch]$winconsole,
        [Parameter(HelpMessage="Select x86 (i686, 32-bit) target architecture. Requires -msvcrt.")]
        [Switch]$x86,
        [Parameter(HelpMessage="Select aarch64 (ARM64, Windows-on-ARM) target architecture. Implies UCRT.")]
        [Switch]$aarch64,
        [Parameter(HelpMessage="Add library/bin directory to PATH for dynamic builds")]
        [Switch]$dynamic,
        [Parameter(HelpMessage="Select the terminfo-library-only build variant")]
        [Switch]$termlib,
        [Parameter(HelpMessage="Select MSVCRT runtime (default: UCRT). Required for -x86. Cannot be combined with -aarch64.")]
        [Switch]$msvcrt,
        [Parameter(HelpMessage="If the build you want to test is part of a bulk job, specify the Job ID to locate the correct build output")]
        [int]$JobID = 0
    )
    [string]$buildRoot = GetEffectiveBuildRoot -JobID $JobID

    [bool]$isconpty = $conpty
    if (!($conpty -or $winconsole)) {
        $isconpty = $true
    }
    if (-not (ConsistencyCheck -release:$release -ascii:$ascii -reentrant:$reentrant -spfuncs:$spfuncs -interop:$interop -conpty:$isconpty -winconsole:$winconsole -x86:$x86 -aarch64:$aarch64 -msvcrt:$msvcrt)) {
        Write-Error "Inconsistent configuration"
        return
    }

    $Env:WNCDEBUG=""
    
    [string]$loc = (Join-Path (Join-Path ($buildRoot) "build") (RelativeBuildDir -release:$release -x86:$x86 -aarch64:$aarch64 -reentrant:$reentrant -ascii:$ascii -msvcrt:$msvcrt -spfuncs:$spfuncs -interop:$interop -conpty:$isconpty -winconsole:$winconsole))
    if (Test-Path -path $loc  -PathType Container) {
        [string]$inst=(Join-Path (Join-Path ($buildRoot) "inst") (RelativeInstallDir -release:$release -x86:$x86 -aarch64:$aarch64 -reentrant:$reentrant -ascii:$ascii -msvcrt:$msvcrt -spfuncs:$spfuncs -interop:$interop -conpty:$isconpty -winconsole:$winconsole))
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
    <#
    .SYNOPSIS
        Launches the MinGW debugger (gdb or lldb) on the specified program.
    .DESCRIPTION
        Uses the WNCDEBUG environment variable set by Push-WincursesTestLocation (pwct)
        to locate the appropriate MinGW debugger for the current build configuration
        and starts it with the given program as the target.
        Use the 'ncdbg' alias as a shorthand.
    .PARAMETER Program
        Path to the program to debug. Typically a test executable in the current
        build test directory.
    .EXAMPLE
        ncdbg .\ncurses.exe
        Launch the debugger on ncurses.exe in the current directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0, HelpMessage="Path to the program to debug")]
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
