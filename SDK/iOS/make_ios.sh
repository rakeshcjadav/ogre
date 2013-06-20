#!/bin/bash

# Build and package the SDK for iOS
# Assumes that you are in the SDK/iOS directory

LIPO=lipo
SDKBUILDDIR=`pwd`

set IPHONEOS_DEPLOYMENT_TARGET 4.3

# Clean up files from previous builds
echo Cleaning previous builds...
if [ "$1" = "clean" ];then
	rm -rf $SDKBUILDDIR/build
fi
rm -rf $SDKBUILDDIR/sdk_contents 

# Configure with CMake
mkdir -p $SDKBUILDDIR/build
pushd $SDKBUILDDIR/build
cmake -DOGRE_BUILD_PLATFORM_APPLE_IOS:BOOL=TRUE -DOGRE_INSTALL_SAMPLES_SOURCE:BOOL=TRUE -DOGRE_INSTALL_DOCS:BOOL=TRUE -G Xcode ../../..

# Read version number
OGRE_VERSION=`cat version.txt`

# echo Building API docs...
# 
# # Build docs explicitly since INSTALL doesn't include it
# xcodebuild -project OGRE.xcodeproj -target doc -configuration Release -sdk iphoneos IPHONEOS_DEPLOYMENT_TARGET=4.0 DEFAULT_COMPILER=com.apple.compilers.llvm.clang.1_0
# 
# pushd api/html
# 
# # Delete unnecessary files
# rm -f *.hhk *.hhc *.map *.md5 *.dot *.hhp *.plist ../*.tmp
# popd
# 
# Build the Xcode docset and zip it up to save space
#make
#zip -9 -r org.ogre3d.documentation.Reference1_7.docset.zip org.ogre3d.documentation.Reference1_7.docset
# 
# Copy the docset to the disc image.  Disabled to reduce the size of the disc image.
#cp -R api $SDKBUILDDIR/sdk_contents/docs/
#cp org.ogre3d.documentation.Reference1_7.docset.zip $SDKBUILDDIR/sdk_contents/docs/
# 
# echo API generation done.

# Invoke Xcode build for device and simulator

# Install targets will fail because they can't find libraries.  So we've added a post build phase to copy them to the
# location that the target expects them then copy them to the correct location

echo Building for simulator...
xcodebuild -project OGRE.xcodeproj -target install -parallelizeTargets -configuration Release -sdk iphonesimulator IPHONEOS_DEPLOYMENT_TARGET=4.0 DEFAULT_COMPILER=com.apple.compilers.llvm.clang.1_0
mkdir -p sdk/lib/iphonesimulator/Release
mv -v lib/iphonesimulator/Release/*.a sdk/lib/iphonesimulator/Release

echo Building for devices...
xcodebuild -project OGRE.xcodeproj -target install -parallelizeTargets -configuration Release -sdk iphoneos IPHONEOS_DEPLOYMENT_TARGET=4.0 DEFAULT_COMPILER=com.apple.compilers.llvm.clang.1_0
mkdir -p sdk/lib/iphoneos/Release
mv -v lib/iphoneos/Release/*.a sdk/lib/iphoneos/Release

# Frameworks
echo Copying frameworks...

# Stuff we've built
# Cram them together so we have a 'fat' library for device and simulator
for LIBNAME in $SDKBUILDDIR/build/sdk/lib/iphoneos/Release/lib*
do
	echo lipo $LIBNAME
	BASELIBNAME=`basename $LIBNAME`
	$LIPO $SDKBUILDDIR/build/sdk/lib/iphoneos/Release/$BASELIBNAME -arch i386 $SDKBUILDDIR/build/sdk/lib/iphonesimulator/Release/$BASELIBNAME -create -output $SDKBUILDDIR/build/sdk/lib/Release/$BASELIBNAME
done

# Remove some unnecessary files. Single arch libs and duplicate headers.
rm -rf $SDKBUILDDIR/build/sdk/lib/iphoneos $SDKBUILDDIR/build/sdk/lib/iphonesimulator $SDKBUILDDIR/build/sdk/lib/Debug

echo Frameworks copied.

echo Generating Samples Project...

pushd sdk
cmake -DOGRE_BUILD_PLATFORM_APPLE_IOS:BOOL=TRUE -DOGRE_DEPENDENCIES_DIR=../../../../iOSDependencies -G Xcode .
#sed -f ../../edit_linker_paths.sed OGRE.xcodeproj/project.pbxproj > tmp.pbxproj
#mv tmp.pbxproj OGRE.xcodeproj/project.pbxproj
rm CMakeCache.txt

# Fix absolute paths
SDK_ROOT=`pwd`
echo $SDK_ROOT | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g' > sdkroot.tmp
SDK_ROOT=`cat sdkroot.tmp`
rm sdkroot.tmp
sed -i -e "s/$SDK_ROOT/\$SRCROOT/g" OGRE.xcodeproj/project.pbxproj

# All of the files generated by CMake need to have their paths fixed up.
# Since they are being run by Xcode, they inherit the SRCROOT environment variable.
# We can use this variable to fill in the path up to where the project resides.
for FILE in CMakeScripts/*
do
	sed -i -e "s/$SDK_ROOT/\$\(SRCROOT\)/g" $FILE
done

for FILE in CMakeFiles/*.*
do
	sed -i -e "s/$SDK_ROOT/\$\(SRCROOT\)/g" $FILE
done

find . -iname cmake_install.cmake -exec sed -i -e "s/$SDK_ROOT/\$\(SRCROOT\)/g" \{\} \;

for FILE in lib/pkgconfig/*
do
	sed -i -e "s/$SDK_ROOT/\$\(SRCROOT\)/g" $FILE
done

# Now loop through all the samples CMakeScripts directories
for DIR in Samples/*
do
	if [ -d "$DIR/CMakeScripts" ]; then
        for FILE in $DIR/CMakeScripts/*
        do
            sed -i -e "s/$SDK_ROOT/\$\(SRCROOT\)/g" $FILE
        done
    fi
done

popd

# Remove sed temp files
find . -iname *-e -exec rm -f \{\} \;

echo End Generating Samples Project

echo Copying SDK...

mkdir -p $SDKBUILDDIR/sdk_contents
ditto sdk $SDKBUILDDIR/sdk_contents
popd

echo End Copying SDK

# Remove DS_Store files to avoid increasing the size of the SDK with duplicates
find sdk_contents -iname .DS_Store -exec rm -rf \{\} \;

echo Building DMG...

# Note that our template DMG has already been set up with images, folders and links
# and has already had 'bless -folder blah -openfolder blah' run on it
# to make it auto-open on mounting.

SDK_NAME=OgreSDK_iOS_v$OGRE_VERSION
rm $SDK_NAME.dmg

bunzip2 -k -f template.dmg.bz2
mkdir -p tmp_dmg
hdiutil attach template.dmg -noautoopen -quiet -mountpoint tmp_dmg
ditto sdk_contents tmp_dmg/OgreSDK
hdiutil detach tmp_dmg
hdiutil convert -format UDBZ -o $SDK_NAME.dmg template.dmg
rm -rf tmp_dmg
rm template.dmg

echo Done!
