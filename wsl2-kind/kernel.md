
# WSL2 kernel upgrade

* [wsl kernel](https://www.catalog.update.microsoft.com/Search.aspx?q=wsl)

* [Compiling your own WSL2 Kernel for Cilium](https://harthoover.com/compiling-your-own-wsl2-kernel/)

* Start Ubuntu Docker

```shell
# docker run --name wsl-kernel-builder --rm -it ubuntu@sha256:9d6a8699fb5c9c39cf08a0871bd6219f0400981c570894cd8cbea30d3424a31f bash

❯ docker run --name wsl-kernel-builder --rm -it ubuntu:20.04 bash
```

* Install Dependancy

```shell
❯ sudo apt-get update
❯ sudo apt-get install -y git build-essential flex bison libssl-dev libelf-dev bc python3 python3-dev dwarves
```

* Clone WSL2 Linux Kernel Repository

```shell
❯ mkdir src && cd src

❯ git init
❯ git remote add origin https://github.com/microsoft/WSL2-Linux-Kernel.git
❯ git config --local gc.auto 0
```

* Configure Kernel

```shell
❯ export WSL_COMMIT_REF=linux-msft-wsl-5.15.57.1

❯ git -c protocol.version=2 fetch --no-tags --prune --progress --no-recurse-submodules --depth=1 origin +${WSL_COMMIT_REF}:refs/remotes/origin/build/linux-msft-wsl-5.15.y

❯ git checkout --progress --force -B build/linux-msft-wsl-5.15.y refs/remotes/origin/build/linux-msft-wsl-5.15.y

# Adds support for clientIP-based session affinity
❯ sed -i 's/# CONFIG_NETFILTER_XT_MATCH_RECENT is not set/CONFIG_NETFILTER_XT_MATCH_RECENT=y/' Microsoft/config-wsl

# Required modules for Cilium
❯ sed -i 's/# CONFIG_NETFILTER_XT_TARGET_CT is not set/CONFIG_NETFILTER_XT_TARGET_CT=y/' Microsoft/config-wsl
❯ sed -i 's/# CONFIG_NETFILTER_XT_TARGET_TPROXY is not set/CONFIG_NETFILTER_XT_TARGET_TPROXY=y/' Microsoft/config-wsl
```

* Build Kernel

```shell
# build the kernel
❯ make -j16 KCONFIG_CONFIG=Microsoft/config-wsl
```

* Extract New Kernel Image

```shell
❯ docker cp wsl-kernel-builder:/src/arch/x86/boot/bzImage .
```

* Link Kernel Image

```shell
PS C:\Users\kt411f> cat .wslconfig
[WSL2]
swap=0
localhostForwarding=true
kernel=C:\\tools\\wsl-jammy\\linux-msft-wsl-5.15.57.1

PS> wsl --shutdown

PS> .\init-wsl.ps1
  NAME          STATE           VERSION
* kind          Stopped         2
  wsl-vpnkit    Running         2

PS> wsl -d kind

❯ uname -a
Linux A6316868 5.15.57.1-microsoft-standard-WSL2+ #2 SMP Wed Feb 15 02:55:06 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
```
