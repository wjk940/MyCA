#!/bin/bash

# This script builds the iOS and Mac openSSL libraries
# Download openssl http://www.openssl.org/source/ and place the tarball next to this script

# Credits:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh


set -e

###################################
# 		 OpenSSL Version
###################################
OPENSSL_VERSION="openssl-1.0.2g"
###################################

SDK_VERSION=$(xcodebuild -version -sdk iphoneos | grep SDKVersion | cut -f2 -d ':' | tr -d '[[:space:]]')

echo "----------------------------------------"
echo "OpenSSL version: ${OPENSSL_VERSION}"
echo "iOS SDK version: ${SDK_VERSION}"
echo "----------------------------------------"
echo " "

DEVELOPER=`xcode-select -print-path`
OPENSSLROOTDIR="${PWD}/builds"

buildMac()
{
	ARCH=$1

	echo "Start Building ${OPENSSL_VERSION} for ${ARCH}"

	TARGET="darwin-i386-cc"
	OPTIONS="no-ssl2 no-ssl3 no-comp"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
		OPTIONS="enable-ec_nistp_64_gcc_128 no-ssl2 no-ssl3 no-comp"
	fi

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
	echo "Configure"
	./Configure ${TARGET} ${OPTIONS} --openssldir="${OPENSSLROOTDIR}/${OPENSSL_VERSION}-${ARCH}" &> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-${ARCH}.log"
	echo "make depend"
	make depend >> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	make >> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	echo "make install"
	make install >> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	echo "make clean"
	make clean >> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null
	
	echo "Done Building ${OPENSSL_VERSION} for ${ARCH}"
}

buildIOS()
{
	ARCH=$1

	echo "Start Building ${OPENSSL_VERSION} for ${PLATFORM} ${SDK_VERSION} ${ARCH}"
	
	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH}"
	
	echo "Configure"

	if [[ "${ARCH}" == "x86_64" ]]; then
		./Configure darwin64-x86_64-cc --openssldir="${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-${ARCH}" &> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-${ARCH}.log"
	else
		./Configure iphoneos-cross --openssldir="${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-${ARCH}" &> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-${ARCH}.log"
	fi
	# add -isysroot to CC=
	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${SDK_VERSION} !" "Makefile"

	echo "make"
	make >> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	echo "make install"
	make install >> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	echo "make clean"
	make clean  >> "${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null
	
	echo "Done Building ${OPENSSL_VERSION} for ${ARCH}"
}

echo "Cleaning up"
rm -rf include/openssl/* lib/*
rm -rf ${OPENSSLROOTDIR}
rm -rf ${OPENSSL_VERSION}

mkdir -p lib/iOS
mkdir -p lib/Mac
mkdir -p include/openssl/
mkdir -p "${OPENSSLROOTDIR}"

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	echo "Downloading ${OPENSSL_VERSION}.tar.gz"
	curl -O https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
	echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

buildMac "i386"
buildMac "x86_64"

echo "Copying headers"
cp ${OPENSSLROOTDIR}/${OPENSSL_VERSION}-i386/include/openssl/* include/openssl/

echo "Building Mac libraries"
lipo \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-i386/lib/libcrypto.a" \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-x86_64/lib/libcrypto.a" \
	-create -output lib/Mac/libcrypto.a

lipo \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-i386/lib/libssl.a" \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-x86_64/lib/libssl.a" \
	-create -output lib/Mac/libssl.a

buildIOS "armv7"
buildIOS "arm64"
buildIOS "x86_64"
buildIOS "i386"

echo "Building iOS libraries"
lipo \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-i386/lib/libcrypto.a" \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
	-create -output lib/iOS/libcrypto.a

lipo \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-i386/lib/libssl.a" \
	"${OPENSSLROOTDIR}/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
	-create -output lib/iOS/libssl.a

echo "Cleaning up"
rm -rf ${OPENSSL_VERSION}

echo "Done"