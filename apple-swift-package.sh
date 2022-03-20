#!/bin/bash

REL=$1
BUILD=1
if [ "$2" != "" ] ; then
    BUILD=$2
fi

OS=ubuntu2004
OSF=ubuntu20.04
if [ "$REL" == "" ] ; then
    echo Not working for SNAPSHOT
    exit
    SNAPSHOT=DEVELOPMENT-SNAPSHOT
    DATE=`date +"%s"`
    EPOCH_YDAY=`echo $DATE-3600*48| bc `
    YDAY=`epoch $EPOCH_YDAY | cut -b 1-10`
    echo $YDAY
    FILENAME="$BRANCH-$SNAPSHOT-$YDAY-a-$OSF"
    BRANCH=swift-5.7
    BRANCH_DIR=$BRANCH-$SNAPSHOT-$YDAY-a
    BRANCH_REL=$BRANCH-branch
else
    BRANCH=swift-$REL
    BRANCH_DIR=${BRANCH}-RELEASE
    FILENAME="${BRANCH_DIR}-$OSF"
    BRANCH_REL=$BRANCH-release
fi

FILE="$FILENAME.tar.gz"
#https://download.swift.org/swift-5.7-release/ubuntu2004/swift-5.7-RELEASE/swift-5.7-RELEASE-ubuntu20.04.tar.gz
URL=https://download.swift.org/$BRANCH_REL/$OS/$BRANCH_DIR/$FILE
echo $URL

if [ -f $FILE ] ; then 
    echo "File exist"
else
    wget $URL
fi
TYPE=`file $FILE`
if [[ "$TYPE" != *"gzip compressed data"* ]] ; then
    echo "$FILE is not a gz. Exiting"
#    rm $FILE
    exit 1
fi
mkdir -p apple-$BRANCH
mkdir -p apple-$BRANCH/DEBIAN
mkdir -p apple-$BRANCH/usr/local
export RELEASE=$REL BUILD
envsubst < control > apple-$BRANCH/DEBIAN/control
exit
tar -xvz -f $FILE
rsync -Hav $FILENAME/usr/  apple-$BRANCH/usr/local
dpkg-deb -b apple-$BRANCH
rm -rf apple-$BRANCH
rm -rf ${FILE/.tar.gz/}
