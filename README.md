![Wincurses Logo](assets/Wincurses.png)

## Introduction

Welcome to Project Wincurses. The purpose of this Project is to provide a [devcontainer](https://containers.dev/) - usually used with [Visual Studio Code](https://code.visualstudio.com/) - that provides the toolchains to cross-compile [ncurses](https://invisible-island.net/ncurses/) on [Linux](https://www.linux.org/) for the [Windows](https://www.microsoft.com/en-US/windows) platform, targeting different C-Runtimes and CPU architectures (Intel and ARM).

Please note that the status of this project is pre-release, but I'm sharing it because it is usable already and might be helpful for your attempts to build ncurses for Windows. Any suggestions or contributions are highly welcome.

The devcontainer is based on [Debian SID](https://www.debian.org/releases/sid/), because Debian with its next release will  support the modern [UCRT (Universal C-RunTime) based toolchain](https://packages.debian.org/unstable/gcc-mingw-w64-ucrt64) of the [MinGW](https://www.mingw-w64.org/) project. Traditionally, MinGW only supported the outdated MSVCRT C-Runtime, which lacks some features of the C99 Standard and also has no support for [UTF-8](https://en.wikipedia.org/wiki/UTF-8) locales, so it is not really suitable for wide character builds of ncurses. UCRT is much more profound in supporting [Unicode](https://en.wikipedia.org/wiki/Unicode).

Wincurses favours a [GCC](https://gcc.gnu.org/)-first approach. Whenever possible, a target will be compiled using gcc. At the moment, there is only one target, where gcc is not supported: [Windows on ARM](https://learn.microsoft.com/en-US/windows/arm/overview). For that purpose, I have also installed a [clang/llvm](https://clang.llvm.org/) toolchain targeting windows. I integrated Martin Storsjö's excellent [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) toolchain into the devcontainer.

This project is for developers primarily, it does'nt focus on building deployable results, at least not yet.

## The Motivation

The key part of the repository is the devcontainer definition itself in the usual .devcontainer directory, the core logic for my build system is in the Scripts subdirectory. I do not have the ncurses sources in this repository, instead there is a git submoule ncurses that links to [my snapshot of ncurses](https://github.com/juergenpf/ncurses-snapshots), which is a fork of Thomas Dickey's [official github snapshot of ncurses](https://github.com/ThomasDickey/ncurses-snapshots). I keep the main branch of my fork typically in sync with the official snapshot, which is updated weekly. For a variety of reasons, ncurses development repo is not git, but a private RCS repo that is synchronized to github. You can see and feel: ncurses is a project developed and maintained by Oldies;-)

The reason why I use my own snapshot as a submodule is, that I'm actually developing on that fork. As some of you may know, I am one of the major contributors to ncurses since 1995 or so, and I also developed the Windows port at a time, where there was no modern Virtual Terminal based Console API in Windows. That worked for the upper layers of ncurses, but many people install ncurses and actually want to use terminfo, and that was not supported at all by the Windows port - simply because the old Windows Console was a display device, but not a Terminal (tty character device) like in the UNIX architecture. In 2018 Microsoft introduced a new Console Architecture that provides support for UNIX-like Pseudo-Terminals which can process ANSI-compliant virtual terminal control sequences. Back then, I integrated that into the existing legacy architecture. It worked somehow, but had it's deficits - mainly because I tried to keep things as unified as possible between the new Windows Console world and the legacy one, and several design- and implementation decisions were plain wrong or at least questionable, mainly due to the lack of proper documentation about the new architecture from Microsoft in these early days  and my lack of understanding it or guessing it correctly. 

Now even Windows 10 is no longer a supported platform and me feeling uncomfortable to be the person behind the current less favourable mixed implementation, I decided to come up with a rewrite of the Windows Port which will completely drop the legacy support and will only be based on the modern Console-Pseudo-Terminal (CONPTY) architecture, and trying to stay as close as possible in that I/O model and terminal abstraction. For me this was a big move, as I retired in 2019 and did little coding on larger projects since then, more focussing on trying out stuff I never touched before intensively in my professional live (like coding in Haskell or diving into the RISC-V architecture).

This development happens on the branch conpty of the ncurses git submodule. So, if you want to build ncurses for Windows and follow the current development, you should use that branch. I merge that with the weekly snapshots and the merge points are tagged with tags named conptyYYYYMMDD (wher YYYYMMDD is the time of the patch release of the official ncurses repository)

The main reason I want to do development on a Linux platform using cross-compilers is simply, because the POSIX emulation Layer MSYS2 on Windows is so painfully slow when it comes to File U/O and process creation. That's ok if you do occasional builds, but development with frequent rebuilds... I didn't like the experience.

So I invested into setting up this devcontainer and using it now for a while I can say it was worth every minute doing that in parallel to the ncurses development.

And even if you are not interested in the development, you may find it valuable just because it can build out-of-the-box all the variants for different C-Runtimes and Hardware architectures.

## Get started

If you are new to devcontainers with Visual Studio Code, I recommend reading the ["Getting started" on GitHub](https://microsoft.github.io/code-with-engineering-playbook/developer-experience/devcontainers-getting-started/).

My devcontainer definition is tested on Intel and ARM Linuxes, I personally use it in a WSL2 based Ubuntu on Windows 11. It also works on MacOS with one modification: you have to remove the mounts sand the RemoteEnv configurations from devcontainer.json, because Docker on MacOS can't do it that way. Otherwise the container also runs on MacOS, you just can't do git push from inside the container.

If you want to use the devcontainer, either fork this project on GitHub into your own account, or use it directly from mine:

```bash
$ git clone https://github.com/juergenpf/Wincurses.git
$ cd Wincurses
$ git submodule update --init --recursive
$ cd ncurses
$ git checkout conpty
$ cd ../..
$ code .
```

This will bring up Visual Studio Code (aka vscode), assuming it is installed on your system. vscode will discover the .devcontainer.json file and ask you, to reopen the session in the devcontainer. You should do that and then, if this is the first call, the containerimage will be built and then the container will be launched and vscode connects to it. Depending on the performance of your hardware and the performance of your internet connection, this may take a few minutes. But this is only done, when the image needs to be built or rebuilt.

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

The devcontainer has mounted your local repository into its filesystem. The build instructions for the container also managed to put /wirksoaces/Wincurses/Scripts into your PATH environment variable.

One remark: if you use this under WSL2, you should **NOT** install vscode in your Linux distribution, but in your Windows environment and add the WSL2 extension. Your Linux distro should have interop enabled, so it can launch Windows programs from inside the Linux environment. For a very compact description how to set everything up, see [this article](https://windowsforum.com/threads/set-up-a-modern-local-dev-environment-with-wsl2-vs-code-docker-on-windows-10-11.379834/). Otherwise your preferred search or AI agent will give you tons of references how to set it up correctly.

But now it's time to talk about the scripts, 

## The Scripts

### ncbuild

`ncbuild` is the core script of our build system. It provides options to let you choose between

- Debug and NoDebug builds (Default is Debug)
- Builds vor ANSI codepages or wide codepages (Default is wide!)
- Build for MSVCRT or UCRT (default is UCRT)
- Build for x86_64, i686 or aarch64 (default us x86_64)
- Build static or dynamic libraries (default is static)

So, if you just type
```bash
wincurses$ ncbuild
```
you'll get a static debug build of a wide ncurses for x86_64 targetting the UCRT.

#### Usage

```bash
./ncbuild [options]
```

#####  Options
~~~
  -a, --ascii           Build ASCII version (disable wide character support)
  -t, --reentrant       Build reentrant version
  -m, --msvcrt          Build with MSVCRT instead of UCRT
  -w, --woa             Build for Windows on ARM (WOA) with UCRT
  -x, --x86             Build for x86 (i686) with MSVCRT
  -l, --libseparate     Build terminfo library separately from curses
  -d, --dynamic         Build with shared libraries (default is static)
  -n, --nodebug         Build without debug symbols and features
  -c, --clean           Clean build and install directories before building
  -v, --verbose         Enable verbose output
  -h, --help            Show this help message and exit~~~
~~~
#### Example
```bash
./ncbuild --ascii --x86 --msvcrt
```
would do a static debug build of a non-wide ncurses for the i686 architecture targetting MSVCRT.

#### The options in Detail

##### -a, --ascii
The default for our build system is to do builds that have the ncurses configuration option `--enable-widec` set. With this option you produce a `--disable-widec`

##### -t, --reentrant
The default is to build libraries without reentrancy support (`--disable-rentrant`). With this option you insert `--enable-reentrant`

##### -m, --msvcrt
The default is to build for UCRT. With this option you trigger to build for MSVCRT. This is actually only indirectly a ncurses configuration option, as it mainly selects the toolchain to be used for the build. This will be reflected in the `--host` configuration option of ncurses

##### -w, --woa
The default is to build for x86_64 Intel 64-Bit architecture. With this option you select aarch64 for Windows on ARM. Please note, that this option conflicts with --msvcrt. This old stuff is not supported on newer architectures.

##### -x, --x86
Like --woa, this selects a different architecture for the build, this time an i686 Intel 32-Bit build. In this case, you must specify also --msvcrt, as x86 is considered legacy and only supports the old C runtime.

##### -l, --libseparate
The default is, that the terminfo functionality is linked into the main ncurses library (statically and dynamically), corresponding to ncurses configure option `--without-termlib`. With this option, you trigger a `--with-termlib` option, which will create a sepparate library `tinfo`. Please note, that this option currently does not work.

##### -d, --dynamic
By default, we build static libraries. With this option you trigger the build of DLLs.

##### -n, --nodebug
By default, we build with support for debugging. Please note, this is a developer system, so debugging is a major task. With this option, no debug information are generated.

##### -c, --clean
By default, we do not clean the build directory before continuing with the steps to configure and build. That means, if after a first run you have a Makefile und your compile fails, ncbuild will skip configuration and continue to process the makefile. With the --clean option yiu ensure, that the build directories are cleaned befor continuing. This results in running configure and then doing the build.

##### -v, --verbose
Writes some additional tracing informations from the script to stderr.

##### -h, --help
Obvious.

### Build and Install Directory Structure

TBD