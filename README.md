![Wincurses Logo](assets/Wincurses.png)

## Introduction

Welcome to Project Wincurses. The purpose of this Project is to establish a [devcontainer](https://containers.dev/) - usually used with [Visual Studio Code](https://code.visualstudio.com/) (short: `VS Code`) - that provides the toolchains to cross-compile [ncurses](https://invisible-island.net/ncurses/) on [Linux](https://www.linux.org/) for the [Windows](https://www.microsoft.com/en-US/windows) platform, targeting different C-Runtimes and CPU architectures (Intel and ARM).

Please note that the status of this project is pre-release, but I'm sharing it because it is usable already and might be helpful for your attempts to build ncurses for Windows. Any suggestions or contributions are highly welcome.

The devcontainer is based on [Debian SID](https://www.debian.org/releases/sid/), because Debian with its next release will  support the modern [UCRT (Universal C-RunTime) based toolchain](https://packages.debian.org/unstable/gcc-mingw-w64-ucrt64) of the [MinGW](https://www.mingw-w64.org/) project. Historically, MinGW only supported the outdated MSVCRT C-Runtime, which lacks some features of the C99 Standard and also has no support for [UTF-8](https://en.wikipedia.org/wiki/UTF-8) locales, so it is not really suitable for wide character builds of ncurses. UCRT is much more profound in supporting [Unicode](https://en.wikipedia.org/wiki/Unicode).

Wincurses favours a [GCC](https://gcc.gnu.org/)-first approach. Whenever possible, a target will be compiled using gcc. At the moment, there is only one target, where gcc is not supported: [Windows on ARM](https://learn.microsoft.com/en-US/windows/arm/overview). For that purpose, I have also included a [clang/llvm](https://clang.llvm.org/) toolchain targeting Windows. I integrated Martin Storsjö's excellent [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) toolchain into the devcontainer. The `Windows on ARM` port based on clang is exprimental, although promising. I'm testing that on a Windows 11 Pro running as VM in [Parallels Desktop for Mac](https://en.wikipedia.org/wiki/Parallels_Desktop_for_Mac) and at least the test programs run as they should. I'm doing the build in `VS Code` on MacOS and have configured the VM so it can access my MacOS directories. So in the VM I just open Powershell and navigate to the test folder and run the programs native in Windows on ARM.

This project is for developers primarily; it doesn't focus on building deployable results, at least not yet.

## The Motivation

The key part of the repository is the devcontainer definition itself in the usual .devcontainer directory, and the core logic for my build system is in the Scripts subdirectory. I do not have the ncurses sources replicated in this repository. Instead, there is a git submodule ncurses that links to [my snapshot of ncurses](https://github.com/juergenpf/ncurses-snapshots), which is a fork of Thomas Dickey's [official GitHub snapshot of ncurses](https://github.com/ThomasDickey/ncurses-snapshots). I keep the main branch of my fork typically in sync with the official snapshot, which is updated weekly. For a variety of reasons, the ncurses development repo is not git, but a private RCS repo that is synchronized to GitHub. You can see and feel: ncurses is a project developed and maintained by Oldies ;-)

The reason why I use my own snapshot as a submodule is that I'm actually developing on that fork. As some of you may know, I am one of the major contributors to ncurses since 1995 or so, and I also developed the Windows port at a time (2009) when there was no modern Virtual Terminal based Console API in Windows. That worked for the upper layers of ncurses, but many people install ncurses and actually want to use terminfo, and that was not supported at all by the Windows port — simply because the old Windows Console was a display device, not a Terminal (tty character device) like in the UNIX architecture. In 2018, Microsoft introduced a new Console Architecture that provides support for UNIX-like Pseudo-Terminals which can process ANSI-compliant virtual terminal control sequences. Back then, I integrated that into the existing legacy architecture. It worked somehow, but had its deficits — mainly because I tried to keep things as unified as possible between the new Windows Console world and the legacy one, and several design and implementation decisions were plain wrong or at least questionable, mainly due to the lack of proper documentation about the new architecture from Microsoft in those early days and my lack of understanding it or guessing it correctly. It is very unpleasant to maintain this mixed codebase.

Now even Windows 10 is no longer a supported platform, and me feeling uncomfortable to be the person behind the current less favourable mixed implementation, I decided to come up with a rewrite of the Windows Port which will completely separate the legacy implementation from the modern Console-Pseudo-Terminal (CONPTY) implementation, and try to stay as close as possible in that I/O model and virtual pseudo-terminal abstraction. For me, this was a big move, as I retired in 2019 and did little coding on larger projects since then, more focusing on trying out stuff I never touched before intensively in my professional life (like coding in Haskell or diving into the RISC-V architecture).

This development happens on the branch `mergeconpty` of the ncurses git submodule, `mergeconpty` is keeping the legacy support, but now completely separated from the ConPTY implementation.  So, if you want to build ncurses for Windows and follow the current development, you should use this branch. I merge it with the weekly snapshot, and the merge points is tagged with a tag named mergeconptyYYYYMMDD (where YYYYMMDD is the time of the patch release of the official ncurses repository).

The main reason I want to do development on a Linux platform using cross-compilers is simply because the POSIX emulation layer MSYS2 on Windows is so painfully slow when it comes to File I/O and process creation. That's ok if you do occasional builds, but development with frequent rebuilds... I didn't like the experience.

So I invested into setting up this devcontainer, and using it now for a while, I can say it was worth every minute doing that in parallel to the ncurses development.

And even if you are not interested in the development, you may find it valuable, just because it can build out-of-the-box all the variants for different C-Runtimes and hardware architectures.

## Get started

If you are new to devcontainers with VS Code, I recommend reading the ["Getting started" on GitHub](https://microsoft.github.io/code-with-engineering-playbook/developer-experience/devcontainers-getting-started/).

My devcontainer definition is tested on Intel and ARM Linuxes. I personally use it in a WSL2-based Ubuntu on Windows 11. It also works on macOS with one modification: you have to remove the mounts and the RemoteEnv configurations from devcontainer.json, because Docker on macOS can't do it that way. Otherwise, the container also runs on macOS; you just can't do git push from inside the container.

If you want to use the devcontainer, either fork this project on GitHub into your own account, or use it directly from mine:

```bash
$ git clone https://github.com/juergenpf/Wincurses.git
$ cd Wincurses
$ git submodule update --init --recursive
$ cd ncurses
$ git checkout conpty
$ cd ..
$ ./.devcontainer/scripts/configure
$ code .
```
The configure script is necessary to create a defcontainer.json file that automatically configures your timezone and locale for the devcontainer, inheriting them from your Linux or MacOS environment. It also checks the release version of the uses LLVM toolchain for Windows on ARM, and if this version has been updated, it generates an updated config file for the devcontainer.

In order to forward the SSH auth from your host into the `VS Code` container, you must configure `VS Code` to handle ssh agent forwarding for you. Open the command palette and type "`Remote.SSH`". You should see "`Remote-SSH:Settings`" beeing offered in the drop-down selection. Open that settings dialog and set two options to these values:
- remote.SSH.EnableAgentForwarding: true
- remote.SSH.useLocalServer: false

with these settings, `VS Code` will handle the minimum required to allow you to access github.

**WARNING:** Apple apparently believes, that asking the OS for the name of the timezone is a security relevant thing and you need `sudo` priviledge to do that. Most developers have that on their dev-machines, so depending on your setup be prepared, that `configure` may ask for your password to get permission to enter sudo mode.

**IMPORTANT HINT:** Please run the configure script from time to time, at least each time you sync a new version of this repository, because things may have changed. In most cases, this will not require to rebuild the devcontainer, but even that may be necessary if you sync. The configure script will update the devcontainer configuration only. if any of the parameters for the configuration have changed. It will tell you that. So it is safe to run configure, it will not affect the configuration if nothing has changed.

The final "`code .`" will now bring up VS Code, assuming it is installed on your system. VS Code will discover the .devcontainer.json file and ask you, to reopen the session in the devcontainer. You should do that and then, if this is the first call, the containerimage will be built and then the container will be launched and VS Code connects to it. Depending on the performance of your hardware and the performance of your internet connection, this may take a few minutes. But this is only done, when the image needs to be built or rebuilt.

If everything worked as expected, you should see

```
wincurses$
```

You may try
```
wincurses$ pwd
/workspaces/Wincurses
wincurses$ ls
assets  License.md  ncurses  README.md  Scripts
wincurses$
```

The devcontainer has mounted your local repository into its filesystem. The build instructions for the container also managed to put /workspaces/Wincurses/Scripts into your PATH environment variable.


One remark: if you use this under WSL2, you should **NOT** install VS Code in your Linux distribution, but in your Windows environment and add the WSL2 extension. Your Linux distro should have interop enabled, so it can launch Windows programs from inside the Linux environment. For a very compact description of how to set everything up, see [this article](https://windowsforum.com/threads/set-up-a-modern-local-dev-environment-with-wsl2-vs-code-docker-on-windows-10-11.379834/). Otherwise, your preferred search or AI agent will give you tons of references on how to set it up correctly.

But now it's time to talk about the scripts.

## The Scripts

### ncbuild

`ncbuild` is the core script of our build system. It provides options to let you choose between:

- Debug and NoDebug builds (default is Debug)
- Builds for ASCII codepages or wide codepages (default is wide)
- Build for MSVCRT or UCRT (default is UCRT)
- Build for x86_64, i686, or aarch64 (default is x86_64)
- Build static or dynamic libraries (default is static)

So, if you just type
```bash
wincurses$ ncbuild
```
you'll get a static debug build of a wide ncurses for x86_64 targeting the UCRT.

#### Usage
~~~bash
Usage: ncbuild [options]
Options:

  Build configuration (default: debug): Only one of these options can be specified.

    -debug               Build debug version (this is the default)
    -release             Build release version

  Character width configuration (default: wide): Only one of these options can be specified.

    -ascii               Build ASCII version (8-Bit characters only)
    -wide                Build wide character version (Unicode support, this is the default)

  Reentrancy options (for improved thread safetyness)

    -reentrant           Build reentrant version (improved thread safety)

  Target architecture (default: x86_64): Only one of these options can be specified.
                         When not -native, this is the architeture of the Windows OS being targeted.  

    -x86_64              Build for x86_64 (amd64) architecture
    -aarch64             Build for aarch64 (arm64) architecture, Windows on ARM
    -x86                 Build for x86 (i686) architecture
    -native              Build for native execution in Linux or the host environment

  Windows console support (default: ConPTY): Only one of these options can be specified.
                         This is only allowd, when building for Windows. 

    -conpty              Build with ConPTY support (intended for Windows 10 1809 and later)   
    -winconsole          Build with winconsole support (intended for Windows older than Windows 10 1809)

  C-Runtime of the Windows target OS (default: UCRT): Only one of these options can be specified.
                         This is only allowd, when building for Windows.

    -ucrt                Build with UCRT runtime
    -msvcrt              Build with MSVCRT instead of UCRT

  Internal library configuration features:

    -interop             Build with interop features enabled
    -spfuncs             Build with sp-funcs support.
    -termlib             Build terminfo library only
    -dynamic             Build with shared libraries (default is static)

  Other options:
  
    -log <file>          Log verbose output to the specified file
    -c|-clean            Clean build and install directories before building
    -v|-verbose          Enable verbose output
    -h|-help             Show this help message and exit
~~~
#### Example
```bash
./ncbuild --ascii --x86 --msvcrt
```
would do a static debug build of a non-wide ncurses for the i686 architecture targeting MSVCRT.

#### The options in Detail

##### -debug
By default, we build with support for debugging. Please note, this is a developer system, so debugging is a major task. With this option, no debug information is generated.

##### -release
Build with a release configuration (no tracing, no debugging libraries, no test programs)

##### -ascii
Build for a typical 8-bit ASCII characterset ()`--disable-widec`).

##### -wide
Build with support for wide characters (Unicode, `--enable-widec`). If you don't specify either `-wide` or `-ascii`, this is the default.

##### -reentrant
The default is to build libraries without reentrancy support (`--disable-reentrant`). With this option, you enable `--enable-reentrant`. The library will then be compiled with increased thread safety, which may come with some performance implications due to locking.

##### -x86_64
Build for Windows on 64-Bit Intel CPUs. This is the default if you don't specify any other target system option

##### -aarch64
Build for Windows on ARM.

##### -x86
Build for 32-Bit Intel CPUs. Please note, that 32-Bit support nowadays is declining, we may drop that too in the future.

##### -native
Do y build for the native environment. If you run this inside the devcontainer, we will build a Debian version of the libraries, as the container is currently based on Debian. You may run `ncbuild -native` as the only target option also outside the container directly on your host system. On MacOS for example this would build then ncurses for MacOS.

##### -conpty
When you build for Windows, with this option you build ncurses with support for Pseudo-Console, which is available since Windows 10 Version 1809 (October 2018). If you don't specify any of the console options for Windows, this is the default.

##### -winconsole
If your code needs to run on Windows version before Windows 10 Version 1809 (released October 2018), you can use this option in addition. The library is built in a way, that it detects whether or not ConPTY is supported it uses it if available. The classical console API will only be used, if ConPTY is not available. You may compile ncurses without `-conpty` and only with this option, but then your code will only run on older Windows versions. We do not support to run a `-winconsole` only build on modern Windows.

##### -ucrt
Compile for Windows with the Universal C Run-Time (`UCRT`). If you don't specify any runtime option, this is the default. This is the current preferred runtime with support for Unicode-Locales. This is actually only indirectly a ncurses configuration option, as it mainly selects the toolchain to be used for the build. This will be reflected in the `-host` configuration option of ncurses.

##### -msvcrt
With this option, you trigger a build for MSVCRT. This is actually only indirectly a ncurses configuration option, as it mainly selects the toolchain to be used for the build. This will be reflected in the `-host` configuration option of ncurses.

##### -interop
This option is relevant in the forms library to ease the definition of field types when calling these routines from other languages than C, which might have problems using C constructs like va_lists.

##### -spfuncs
This option adds an additional set of functions to the ncurses API which optimises the use of multiple terminals in a single application. This is less relevant for Windows, as a Windows process can only have one single console, and we use the console for ncurses. 

##### -termlib
The default is that the terminfo functionality is linked into the main ncurses library (statically and dynamically), corresponding to the ncurses configure option `--without-termlib`. With this option, you trigger a `--with-termlib` option, which will create a separate library `tinfo`.

##### -dynamic
By default, we build static libraries. With this option, you trigger the build of DLLs.

##### -log filename
The log output of the scripts will be redirected into that file.

##### -c|-clean
By default, we do not clean the build directory before continuing with the steps to configure and build. That means, if after a first run you have a Makefile and your compile fails, ncbuild will skip configuration and continue to process the makefile. With the --clean option, you ensure that the build directories are cleaned before continuing. This results in running configure and then doing the build.

##### -v|-verbose
Writes some additional tracing information from the script to stderr.

##### -h|-help
Obvious.

#### What will be built?
When the default debug build option is selected, we will compile the library with most of the debugging and diagnostic settings (eg. tracing is built in, assertions enabled etc.). We also build the progs belongig to ncurses (e.g. tic.exe, infocmp.exe etc.) as well as all the tests. The output will be in a subdirectory `debug` under the top-level `build` directory.

If the `-release` option is selected, the diagnostic and debug options are mostly **not** configured and we don't build the tests. The output will be in a subdirectory `release` under the top level `build` directory.

After a successful build, an install will be performed into the top level inst directory. The structure of this directory mirros the one of the build directory, so every build that represents a different configuration will be installed into its own install subdirectory.

Even if the install fails, you may be able to run the test programs, even without insall there is no `terminfo` library available. That actually doesn't matter as the libraries are built with `ms-terminal` as a fallback terminal description in case no database could be discovered. 

`ncbuild` is a command, that may also be run outside of the devcontainer. In that case, I assume, that the host OS has the necessary toolchains (gcc, binutils etc.) installed, to be able to compile ncurses. 

### ncbuildinfo
This script takes the same arguments as ncbuild, but instead of running the build, it just dumps a set of variables that describes build and install directories, prefixes, suffixes and target-architecture. These are written in a way that you can pipe it into a shell and get the various informations into shell variables for further processing.

### ncnuke
`ncnuke` will completely remove the top level directories `build` and ìnst` and v´create new ones, which are empty. Every subsequent build will start fresh. We assume this to software for adults, so no questions like "are you sure?" will be asked. We assume, you know what you are doing.

### ncbuildall
`ncbuildall` is a bulk command that builds all possible combinations of the `-spfuncs` and the `-interop` options in one command (4 possible combinations). 
In each of these four combinations, it will build wide and non-wide variants, so we have 8 builds. If you use the --reentrant option, we add reentrancy to all the combinations, which will result in 16 total builds.

Then it will build all usefull combinatuons of `-conpty` and `-winconsole` and apply thes to each build (3 combinations).

So for a Windows build, you'l have 24 builds if you don't use `-reentrant`and 48 builds if you use it. That will take a while.

Therefore I've implemented a simble bulk job management system into this container. Actually, `ncbuildall` will run in such a background job with low priority and tell you after you've started the command the JobID it has assigned to that bulk build. You can examine the status and results of such a bulk job with the `ncbulkinfo` command (see below).

You may call `ncbuildall` with these options:
```bash
Usage: ncbuildall [options]

  Build configuration (default: debug): Only one of these options can be specified.

    -debug               Build debug version (This is the default)
    -release             Build release version

  Reentrancy options (for improved thread safetyness)

    -reentrant           Build reentrant version

  Target architecture (default: x86_64): Only one of these options can be specified.
                         When not -native, this is the architeture of the Windows OS being targeted.

    -x86_64              Build for x86_64 (amd64) architecture
    -aarch64             Build for aarch64 (arm64) architecture
    -x86                 Build for x86 (i686) architecture
    -native              Build for native execution in Linux or the host environment

  C-Runtime of the Windows target OS (default: UCRT): Only one of these options can be specified.
                         This is only allowd, when building for Windows.

    -ucrt                Build with UCRT runtime
    -msvcrt              Build with MSVCRT instead of UCRT

  Internal library configuration features:

    -termlib             Build terminfo library only
    -dynamic             Build with shared libraries (default is static)

  Other options:
  
    -verbose             Enable verbose output
    -log <file>          Log verbose output to the specified file
    -help                Show this help message and exit  ```
```
The meaning of the various obtions is explained in the `ncbuild` command description.

### ncbulkinfo (alias: ncbi)
If you use `ncbuildall` you may want to inspect the results and the status of such a bulk build in a comfortable way. This is the purpose of this command. It has these options:
```bash
Options:
  -l, -list    List all job entries (this is the default if no other options are specified).
  -s, -show    Show details of a specific job entry.
  -d, -delete  Delete a specific job entry.
  -p, -purge   Purge all job entries.
  -o, -out     Show the standard output of a specific job entry.
  -e, -err     Show the standard error of a specific job entry.
```
#### -l|-list
Will list all jobs in the system, running jobs will have a '*' before their Job ID.
#### -s | -show
The `-show` option accepts a job ID as additional argument, if you don't specify a Job ID the last created Job will be used. The `-out` or `-err` options can only be used together with `-show` and must be specified **before** `-show`. If `-show`is used, it should alwayd be the last option on the commandline.

Example use:
```bash
$ ncbulkinfo -show 91
```
will show the `log` output of the job with ID 91. If you use
```bash
$ ncbulkinfo -err -show 91
```
you will see the stderr output of that job.
#### -d|-delete
Requires a Job ID and will delete all files and directories related to this job. If you try to delete a running job, you'll get an error.

Example use:
```bash
$ ncbi -delete 91
```
will delete Job 91.
#### -p|-purge
This command will delete **ALL** jobs, except the currently running ones.
#### -e,-err
Can only be used together with `-show` and must be specified before `-show`. It tells the show command, that you want to see the error output of the job.
#### --,-out
Can only be used together with `-show` and must be specified before `-show`. It tells the show command, that you want to see the standard output of the job.

## Build and Install Directory Layout

The build system (see Scripts/ncbuild) creates a structured build directory to organize cross-compiled outputs for different targets and configurations. The layout is as follows:

```
build/
  debug/ or release/
    WindowsCross/
      [x86_64|i686|aarch64] (Depending on architecture you build for)
        nc[w][t][s][i][p][c]/ (meaning of characters see below)
          [mingw64|ucrt64|mingw32] (depends on target config)
            [build artifacts, Makefile, etc.]

```
Where the suffix characters [w][t][s][i][p][c] mean: 
- w: wide character build (no --ascii was specified)
- t: reentrant build
- s: a build with --spfuncs
- i: a build with --interop
- p: For non-native builds only: a ConPTY build (no --noconpty was specified)
- c: For non-native builds only: a --winconsole build


The actual build directory path is constructed as:
  
  build/{debug|release}/WindowsCross/{arch}/nc{[w][t][s][i][p][c]}/{config_prefix}/

  Where:
  - `{arch}` = x86_64, i686, or aarch64
  - `{[w][t][s][i][p][c]}` = optional suffixes described above
  - `{config_prefix}` = mingw64, ucrt64, or mingw32

- The install directory mirrors this structure under `inst/` instead of `build/`.


This structure allows for easy separation and identification of builds for different architectures, C runtimes, and feature sets.

If you do a bulk build, these directories will be additionally prefixed with the directory path `.bulk/jobs/[jobid]/`, where [jobid] is the assigned Job ID for that job.

## How to test compiled programs
In theory you could use [wine](https://www.winehq.org/) - which is contained in the devcontainer - to run the compiled Windows programs on Linux. But let's be clear about two facts:
- **Never** run a console test program in a VS Code terminal! Too many agents and tools are interacting with input and output of that terminal window and this makes it nearly impossible to run tests without strange effects. So open a shell outside of VS Code, navigate to the directory and use wine to launch the program.
- `wine` apparently has a rather incomplete console implementation. You will never get the results you'' see on a native Windows system.

For these reasons I highly recomment to do testing on a Windows system. The preferred setup - the one I am using - is running this devcontainer in a Linux distribution under the WSL2 subsystem for Linux on a Windows machine. Because Windows allows navigation into the WSL2 Linux directories, you can navigate with Powershell or CMD into the directory where your test executables are and launch them under Windows. If you have msys2/mingw installed, you can even debug them there.

### WSL2 specfic aspects
You really should clone the Wincurses repository inside your WSL2 distribution and run the `.devcontainer/scripts/configure` script there. The script discovers that you are running  in WSL2 and adds configuration to the devcontainer that later on when running in the container allows the build scripts to generate information that is helpful to test and debug the test programs in the native Windows environment.
When running `.devcontainer/scripts/configure` under WSL2, a Powershell Helperfile will be copied into the Windows directory that contains your Powershell `$PROFILE`. You should include this helper file into your profile, e.g. by doing this:
Open a Windows Terminal session with Powershell or use your preferred mthod to open a Powershell Terminal session, and type
```powershell
notepad $PROFILE
```
or use your editor of choice instead of notepad. Inside the profile script, add these lines:
```powershell
$wnchelper=(Join-Path (Split-Path $PROFILE) "WincursesHelper.ps1")
if (Test-Path -Path "$wnchelper" -PathType Leaf) {
    . "$wnchelper"
}
```
When you now open a new Powershell Terminal session, this helperfile will be included and add two new cmdlets:
- Push-WincursesTestLocation (alias: pwct)
- Start-MinGWDebug (alias: ncdbg)

The Push-WincursesTestLocation accepts these switches:
- -JobID
- -ascii
- -reentrant
-  -spfuncs
-  -interop
- -noconpty
- -wincurses
- -x86
- -woa
- -dynamic
- -libseparate
- -msvcrt
- -nodebug

They have the same meaning (except JobID) as with ncbuild, but in this case they are only used to compute the name of the build directory used for the configuration you selected by the choice of options. Please not, that Powershell always uses the long names for the options, but only with a single '-' in front of the option.
So, if you use the alias `pwct`, when you type in Powershell
```powershell
pwct
```
without any options, you will be pushed into the test directory of the build for x86_64 UCRT with wide character support (and ConPTY support if you target Windows).
```powershell
pwct -x86 -msvcrt -ascii -winconsole
```
will push you into the test directory of a 32-Bit build without wide-character support for the old MSVCRT C-Runtime and support for the old Windows Console API. You may leave this location with a simple `Pop-Location` (alias: popd).
Please note that these directories are all UNC directories pointing to locations in the dummy host `\\wsl.localhost` that Microsoft has implemented to allow Windows to navigate seamlessly into directories that are located in Linux Distributions running under WSL2. The pwct alias tries to detect the MSYS2 debugger suitable for that build target and sets an environment variable WNCDEBUG to point to that debugger.

For testing and bug hunting, it is often more productive to use the builtin trace functions of ncurses, by setting the NCURSES_TRACE environment variable to a proper numeric value (see the ncurses documentation for details). But if you develop new functions, e.g. for a port to a different OS, you sometimes really need to be able to debug the code with an ordinary debugger. For the Windows cross-build environment I'll give you a few pragmatic hints how that can be done from the Windows commandline in certain specific build environments.

The next actions will only be possible, if at least you have installed a minimal `MSYS2` environment and have installed the required gdb packages 
- mingw-w64-ucrt-x86_64-gdb
- mingw-w64-x86_64-gdb
- mingw-w64-i686-gdb

The `Start-MinGWDebug` cmdlet looks for the WNCDEBUG environment variable and loads that debugger. This will usually be gdb, except for the Windows on ARM target. There we use lldb as the source has been compiled with clang.

Assuming you are in the default build  directory, you can use `Start-MinGWDebug` to launch the MinGW gdb debugger to debug a Windows executable.
```powershell
ncdbg ncurses.exe
```
for example would debug the ncurses.exe test program compiled for the UCRT and x86_64 architecture. If you would like to debug the 32-Bit MSVCRT version, you would need to type
```powershell
pwct -x86 -msvcrt
ncdbg ncurses.exe
```
Please note, that this only works, becaus the ncbuild script, in case it detects a WSL2 environment, generates a specially crafted `.gdbinit` file in the test directory that helps gdb to find the sources. Otherweise gdb would be lost with only the source information derived from the locations in the container where the build was done. The first time you launch gdb this way, you'll see a security warning that gdb refuses this `.gdbinit` without your permission. Follow the instructions this warning gives you to allow these kind of `.gdbinit` in your environment.

Therefore, if you want to debug ncurses programs, it is important to be in this 
directory so `.gdbinit` can be found and processed.

Because ncurses programs often bring the terminal into special states, when you hit a breakpoint formatted display of sources or variables or typing in commands may be strange. In most cases, it is more practical to launch the test program and then attach gdb to it. So, if you for example want to debug `ncurses.exe`, open a separate Powershell Terminal and use `pwct` to push into the test directory and simply start ncurses.exe. Then, in the window where you want to run the debugger, type this command:
```powershell
tasklist | findstr ncurses
```
which shoud list running all processes whose process name contains ncurses. Note the PID of your testprogram. Then launch ncdbg and type
```gdb
(gdb) attach PID
```
where PID is the concrete PID of your test program.

### MacOS and Parallels Desktop specific aspects
If you - like me - use MacOS and run a Windows on ARM installation in Parallels Desktop as a VM, you can use a very similar approach to the WSL2 testing described above. The `.devcontainer/scripts/configure` scriot in this case creates the Powershell helper script in the MacOS Downloads directory of your user profile. It also creates an init file for the lldb debugger that helps the debugger to find the sources, because the compile was done in the devcontainer with a different directory structure. You can now do this:
```powershell
- Open a Powershell Terminal session in your Windows on ARM VM on MacOS
- Type these commands:

$T=(Split-Path $PROFILE)
mkdir "$T"
copy \\Mac\Home\Downloads\WincursesHelper.ps1 "$T"
copy \\Mac\Home\Downloads\lldbinit.windows $Env:USERPROFILE\.lldbinit
```
You may get a message telling you, that the directory already exists - that's fine, we just want to be sure. With these steps you have copied the generated Powershell helper into the same directory where you powershell profile resides. Now, in the already open Powershell terminal do this:
```powershell
notepad $PROFILE
```
or use your editor of choice instead of notepad. Inside the profile script, add these lines:
```powershell
$wnchelper=(Join-Path (Split-Path $PROFILE) "WincursesHelper.ps1")
if (Test-Path -Path "$wnchelper" -PathType Leaf) {
    . "$wnchelper"
}
```
You now essentially have a similar situation like described above for WSL2 and you can follow the steps documented there to navigate now in you Windows on ARM VM to the ncurses test directories and run the tests in the native Windows environment.

Please note, that under MacOS in the devcontainer you also generate the Intel based libraries and test programs, and because Windows on ARM offers emulation of Windows code, you can run and debug the Intel program also on your Windows on ARM System. So if you do
```
pwct
ncdbg ncurses.exe
```
on an Windows on ARM system, you actually debug (with gdb) the x86_64 version of the program. If you want to debug real ARM code, you must do this:
```
pwct -woa
ncdbg ncurses.exe
```
In the MSYS2 environment on Windows on ARM, in addition to the packages mentioned above in the WLS2 sdection, you need to install this package:
```bash
mingw-w64-clang-aarch64-lldb
```
in order to be able to debug clang compiled ARM code.

### A pure Linux testing approach
If you run a native Linux box (Intel based) and still want to have a conveniant test environment not requirung to copy the compiled assets to a separate physical Windows test machine, you of course can use your preferred virtualization tool and run a Windows VM on your Linux box. These tools usually allow to share folders, so it should be possible to setup a procedure that copies the build results to be tested to the Windows machine or even allow the Windows machine to directly access as network drive the build directory and access the results. One very promising tool to try that out is the [Winboat](https://www.winboat.app/) project, which some consider to be `LSW`, the Linux-Subsystem-for-Windows, the equivalent to WSL from the other site. 
