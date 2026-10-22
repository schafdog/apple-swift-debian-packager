#!/bin/bash
REL=$1
BUILD=$2
ARCH=$3
: ${BUILD:=RELEASE}
: ${ARCH:=amd64}
: ${OS_VER:=debian13}

if [[ "$REL" == "" ]] ; then
    echo "$0 VERSION [RELEASE|SNAPSHOT [ARCH]]"
    echo "Override OS by OS_VER. Defaults to $OS_VER. Others: ubuntu24.04, ubi9 (Redhat), fedora41"
    exit
fi

if [ "$ARCH" != "amd64" ] ;  then
    OS_ARCH_SUFFIX=-$ARCH
fi

SWIFT_BRANCH=swift-${REL}-release
SWIFT_VERSION=swift-${REL}-RELEASE
SWIFT_WEBROOT=https://download.swift.org
APPLE_SWIFT_BUILD=apple-swift-${REL}-${OS_VER}${OS_ARCH_SUFFIX}

SWIFT_WEBDIR="$SWIFT_WEBROOT/$SWIFT_BRANCH/$(echo $OS_VER | tr -d .)$OS_ARCH_SUFFIX"
SWIFT_BIN_URL="$SWIFT_WEBDIR/$SWIFT_VERSION/$SWIFT_VERSION-$OS_VER$OS_ARCH_SUFFIX.tar.gz"
FILE="$SWIFT_VERSION-$OS_VER$OS_ARCH_SUFFIX.tar.gz"

if [ -f $FILE ] ; then 
    echo "File $FILE exist"
else
    echo "Downloading $SWIFT_BIN_URL"
    wget $SWIFT_BIN_URL || exit
fi
TYPE=`file $FILE`
if [[ "$TYPE" != *"gzip compressed data"* ]] ; then
    echo "$FILE is not a gz. Exiting"
#    rm $FILE
    exit 1
fi
FILENAME=$SWIFT_VERSION-$OS_VER${OS_ARCH_SUFFIX}

if [ -d "$FILENAME" ] ; then
    echo "Directory $FILENAME exist. Skipping tar extract"
else
    mkdir -p $FILENAME
    tar -xvz -f $FILE $TAR_OPT
fi

: ${PREFIX:=/opt/apple-swift}
mkdir -p ${APPLE_SWIFT_BUILD}/DEBIAN
mkdir -p ${APPLE_SWIFT_BUILD}${PREFIX}
mkdir -p ${APPLE_SWIFT_BUILD}/usr/local/bin

# Swift Build (default build system from 6.4) requires the toolchain to live in <root>/usr,
# so keep the usr/ layout under PREFIX and symlink the tools into /usr/local/bin
rsync -Hav $FILENAME/usr/  ${APPLE_SWIFT_BUILD}${PREFIX}/usr || exit
for f in ${APPLE_SWIFT_BUILD}${PREFIX}/usr/bin/* ; do
    ln -sf ${PREFIX}/usr/bin/$(basename $f) ${APPLE_SWIFT_BUILD}/usr/local/bin/
done

export RELEASE=$REL-$OS_VER BUILD ARCH
echo "Release info $RELEASE $REL $BUILD"
envsubst < control > ${APPLE_SWIFT_BUILD}/DEBIAN/control

if [ -f $APPLE_SWIFT_BUILD-$BUILD.deb ] ; then
    echo "$APPLE_SWIFT_BUILD-$BUILD.deb exists"
else
    dpkg-deb --root-owner-group -b $APPLE_SWIFT_BUILD $APPLE_SWIFT_BUILD-$BUILD.deb
fi
if [ "$CLEANUP" == "yes" ] ; then
    rm -rf ${FILE}
    rm -rf ${FILENAME}
    rm -rf $APPLE_SWIFT_BUILD
fi
if [ "$skip_repo" != "yes" ] ; then
    # Move to repo
    mkdir -p /usr/local/debs/$ARCH/
    cp $APPLE_SWIFT_BUILD-$BUILD.deb /usr/local/debs/$ARCH/
    pushd /usr/local/debs
    dpkg-scanpackages --multiversion $ARCH override > $ARCH/Packages
    popd
    if [ "$CLEANUP" == "yes" ] ; then
	rm $APPLE_SWIFT_BUILD-$BUILD.deb
    fi
fi
