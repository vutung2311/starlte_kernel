#!/bin/bash

VARIANT=xx
ARCH=arm64
export KBUILD_BUILD_USER=BuildUser
export KBUILD_BUILD_HOST=BuildHost
export PLATFORM_VERSION=9.0.0
# export KBUILD_BUILD_TIMESTAMP="Mon Nov 23 00:45:00 +07 1987"
export KBUILD_COMPILER_STRING="Google Clang 8.0"

GCC_BIN_PATH=$HOME/opt/gcc-arm-8.2-2019.01-x86_64-aarch64-linux-gnu/bin
# CLANG_BIN_PATH=$HOME/Git/clang-linux-x86/clang-r349610/bin

BUILD_CROSS_COMPILE=$GCC_BIN_PATH/aarch64-linux-gnu-
BUILD_CC=/usr/bin/clang
# BUILD_CC="${BUILD_CROSS_COMPILE}gcc"
BUILD_LD=/usr/bin/ld.lld
# BUILD_LD="${BUILD_CROSS_COMPILE}ld"
BUILD_LDLTO=/usr/bin/ld.lld
# BUILD_LDLTO="${BUILD_CROSS_COMPILE}ld.gold"
BUILD_JOB_NUMBER="$(nproc)"
# BUILD_JOB_NUMBER=1

OUTPUT_ZIP="g960f_kernel.p"
RDIR="$(pwd)"

case ${VARIANT} in
can|duos|eur|xx)
	KERNEL_DEFCONFIG=exynos9810-starlte_defconfig
	;;
*)
	echo "Unknown variant: ${VARIANT}"
	exit 1
	;;
esac

FUNC_CLEAN_DTB()
{
	if ! [ -d ${RDIR}/arch/${ARCH}/boot/dts ] ; then
		echo "no directory : "${RDIR}/arch/${ARCH}/boot/dts""
	else
		echo "rm files in : "${RDIR}/arch/${ARCH}/boot/dts/*.dtb""
		rm ${RDIR}/arch/${ARCH}/boot/dts/exynos/*.dtb
	fi
}

FUNC_BUILD_KERNEL()
{
	echo ""
	echo "=============================================="
	echo "START : FUNC_BUILD_KERNEL"
	echo "=============================================="
	echo ""
	echo "build common config="$KERNEL_DEFCONFIG ""
	echo "build model config=SM-G960F"

	FUNC_CLEAN_DTB

	make -j$BUILD_JOB_NUMBER ARCH=${ARCH} \
			CC=$BUILD_CC \
			LD=$BUILD_LD \
			LDLTO=$BUILD_LDLTO \
			CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
			$KERNEL_DEFCONFIG || exit -1

	for var in "$@"
	do
		if [[ "$var" = "--with-lto" ]] ; then
			echo ""
			echo "Enable LTO_CLANG"
			echo ""
			./scripts/config \
			-e LTO_CLANG \
			-d ARM64_ERRATUM_843419 \
			-d MODVERSIONS
			OUTPUT_ZIP=${OUTPUT_ZIP}".lto"
			break
		fi
	done

	make -j$BUILD_JOB_NUMBER ARCH=${ARCH} \
			CC=$BUILD_CC \
			LD=$BUILD_LD \
			LDLTO=$BUILD_LDLTO \
			CROSS_COMPILE="$BUILD_CROSS_COMPILE" || exit -1

	echo ""
	echo "================================="
	echo "END   : FUNC_BUILD_KERNEL"
	echo "================================="
	echo ""
}

FUNC_BUILD_RAMDISK()
{
	case ${VARIANT} in
	can|duos|eur|xx)
		cp ${RDIR}/arch/${ARCH}/boot/Image ${RDIR}/aik/split_img/boot.img-zImage
		cp ${RDIR}/arch/${ARCH}/boot/dtb.img ${RDIR}/aik/split_img/boot.img-dtb
		find ${RDIR} -name "*.ko" -not -path "*/aik/ramdisk/*" -exec mv -f {} ${RDIR}/aik/ramdisk/lib/modules/ \;
		cd ${RDIR}/aik
		./fixperm.sh
		./repackimg.sh
		;;
	*)
		echo "Unknown variant: ${VARIANT}"
		exit 1
		;;
	esac
}

FUNC_BUILD_ZIP()
{
	cd ${RDIR}/out/
	case ${VARIANT} in
	can|duos|eur|xx)
		cp ${RDIR}/aik/image-new.img ${RDIR}/out/boot.img
		;;
	*)
		echo "Unknown variant: ${VARIANT}"
		exit 1
		;;
	esac

	cd ${RDIR}/out/ && zip ../${OUTPUT_ZIP}.zip -r *
}

# MAIN FUNCTION
rm -rf ./build.log
(
	START_TIME=`date +%s`

	FUNC_BUILD_KERNEL "$@"
	FUNC_BUILD_RAMDISK
	FUNC_BUILD_ZIP

	END_TIME=`date +%s`

	let "ELAPSED_TIME=${END_TIME}-${START_TIME}"
	echo "Total compile time was ${ELAPSED_TIME} seconds"

) 2>&1	 | tee -a ./build.log
