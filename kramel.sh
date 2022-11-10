#!/usr/bin/bash
# Written by: cyberknight777
# YAKB v1.0
# Copyright (c) 2022-2023 Cyber Knight <cyberknight755@gmail.com>
#
#			GNU GENERAL PUBLIC LICENSE
#			 Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

# Some Placeholders: [!] [*] [✓] [✗]

# Default defconfig to use for builds.
export CONFIG=merlin_defconfig

# Default directory where kernel is located in.
KDIR=$(pwd)
export KDIR

# Default linker to use for builds.
export LINKER="ld.lld"

# Device name.
export DEVICE="Redmi Note 9"

# Date of build.
DATE=$(date +"%Y-%m-%d")
export DATE

# Device codename.
export CODENAME="merlinx"

# Builder and Host name.
export BUILDER="sigspence"
export HOST="serverngebut"

# Build status. Set 1 for release builds. | Set 0 for bleeding edge builds.
export RELEASE=$rel
if [ "${RELEASE}" == 1 ]; then
    export STATUS="Release"
    export re="rc"
else
    export STATUS="Beta"
    export re="r"
fi

# Number of jobs to run.
PROCS=$(nproc --all)
export PROCS

# Compiler to use for builds.
export COMPILER=clang

if [[ "${COMPILER}" == gcc ]]; then
    if [ ! -d "${KDIR}/gcc64" ]; then
        curl -sL https://github.com/cyberknight777/gcc-arm64/archive/refs/heads/master.tar.gz | tar -xzf -
        mv "${KDIR}"/gcc-arm64-master "${KDIR}"/gcc64
    fi

    if [ ! -d "${KDIR}/gcc32" ]; then
	curl -sL https://github.com/cyberknight777/gcc-arm/archive/refs/heads/master.tar.gz | tar -xzf -
        mv "${KDIR}"/gcc-arm-master "${KDIR}"/gcc32
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc32/bin:"${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-elf-
        CROSS_COMPILE_ARM32=arm-eabi-
        LD="${KDIR}"/gcc64/bin/aarch64-elf-"${LINKER}"
        AR=llvm-ar
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        OBJCOPY=llvm-objcopy
        OBJSIZE=llvm-objsize
        STRIP=llvm-strip
        HOSTAR=llvm-ar
        HOSTCC=gcc
        HOSTCXX=aarch64-elf-g++
        CC=aarch64-elf-gcc
    )

elif [[ "${COMPILER}" == clang ]]; then
    if [ ! -d "${KDIR}/proton-clang" ]; then
        git clone --depth=1 https://github.com/kdrag0n/proton-clang
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/proton-clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING
    export PATH=$KDIR/proton-clang/bin/:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
        LD="${LINKER}"
        AR=llvm-ar
        AS=llvm-as
        NM=llvm-nm
        OBJDUMP=llvm-objdump
        STRIP=llvm-strip
        CC=clang
	CONFIG_DEBUG_SECTION_MISMATCH=y
    )
fi

if [ ! -d "${KDIR}/anykernel3-merlin/" ]; then
    git clone --depth=1 https://github.com/Tanmsyffa/anykernel3 -b merlin anykernel3-merlin
fi

    export KBUILD_BUILD_HOST=$HOST
    export KBUILD_BUILD_USER=$BUILDER
if [[ ${STATUS} == Release ]]; then
    export LOCALVERSION="-rc1b1"
else
    export LOCALVERSION="-r1b6"
fi
    export zipn=ChimeraKernel-${CODENAME}-${STATUS}${LOCALVERSION}

# A function to send message(s) via Telegram's BOT api.
tg() {
    curl -sX POST https://api.telegram.org/bot"${TOKEN}"/sendMessage \
        -d chat_id="${CHATID}" \
        -d parse_mode=html \
        -d disable_web_page_preview=true \
        -d text="$1" &>/dev/null
}

# A function to send file(s) via Telegram's BOT api.
tgs() {
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${TOKEN}"/sendDocument \
        -F chat_id="${CHATID}" \
        -F parse_mode=html \
        -F caption="$2"
}

# A function to regenerate defconfig.
 rgn() {
     echo -e "\n\e[1;93m[*] Regenerating defconfig! \e[0m"
     make "${MAKE[@]}" $CONFIG
     cp -rf "${KDIR}"/out/.config "${KDIR}"/arch/arm64/configs/$CONFIG
     echo -e "\n\e[1;32m[✓] Defconfig regenerated! \e[0m"
}

tg "
<b>Status</b>: <code>${STATUS}</code>
<b>Builder</b>: <code>${BUILDER}</code>
<b>Core count</b>: <code>$(nproc --all)</code>
<b>Device</b>: <code>${DEVICE} [${CODENAME}]</code>
<b>Kernel Version</b>: <code>$(make kernelversion 2>/dev/null)</code>
<b>Date</b>: <code>$(date)</code>
<b>Zip Name</b>: <code>${zipn}</code>
<b>Compiler</b>: <code>${KBUILD_COMPILER_STRING}</code>
"
    rgn
    echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
    BUILD_START=$(date +"%s")
    time make -j"$PROCS" "${MAKE[@]}" Image.gz dtbo.img 2>&1 | tee log.txt
    time make -j"$PROCS" "${MAKE[@]}" dtbs dtbo.img
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    if [ -f "${KDIR}/out/arch/arm64/boot/Image.gz" ]; then
            tg "<b>Kernel Built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</b>"
        echo -e "\n\e[1;32m[✓] Kernel built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! \e[0m"
    else
            tgs "log.txt" "Build failed"
        echo -e "\n\e[1;31m[✗] Build Failed! \e[0m"
        exit 1
    fi

        tg "<b>Building zip!</b>"
    echo -e "\n\e[1;93m[*] Building zip! \e[0m"
    mv "${KDIR}"/out/arch/arm64/boot/dtbo.img "${KDIR}"/anykernel3-merlin
    cat "${KDIR}"/out/arch/arm64/boot/dts/mediatek/mt6768.dtb > "${KDIR}"/anykernel3-merlin/dtb
    mv "${KDIR}"/out/arch/arm64/boot/Image.gz "${KDIR}"/anykernel3-merlin
    cd "${KDIR}"/anykernel3-merlin || exit 1
    zip -r9 "$zipn".zip . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip"
    echo -e "\n\e[1;32m[✓] Built zip! \e[0m"
    if [[ ${RELEASE} == 1 ]]; then
        tgs "${zipn}.zip" "This is a <b>stable</b> build."
    else
        tgs "${zipn}.zip" "This is a <b>beta</b> build."
    fi

    echo -e "\n\e[1;93m[*] Cleaning Directory! \e[0m"
    cd ..
    rm -rf out anykernel3* log.txt
    echo -e "\n\e[1;32m[✓] Directory has been cleaned! \e[0m"


