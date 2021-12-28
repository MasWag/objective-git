#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/xcode_functions.sh"

function setup_build_environment ()
{
    pushd "$SCRIPT_DIR/.." > /dev/null
    ROOT_PATH="$PWD"
    popd > /dev/null

    NUMBER_OF_CORES="$(sysctl hw.ncpu | awk '{print $2}')"
    CLANG="/usr/bin/xcrun clang"
    CC="$CLANG"
    CPP="$CLANG -E"

    # We need to clear this so that cmake doesn't have a conniption
    MACOSX_DEPLOYMENT_TARGET=""

    # If IPHONEOS_DEPLOYMENT_TARGET has not been specified
    # setup reasonable defaults to allow running of a build script
    # directly (ie not from an Xcode proj)
    if [ -z "$IPHONEOS_DEPLOYMENT_TARGET" ]
    then
        IPHONEOS_DEPLOYMENT_TARGET="12.0"
    fi

    declare -gA ARCHS=( \
        ["iphoneos"]="arm64" \
        ["iphonesimulator"]="x86_64 arm64" \
    )

    # Setup a shared area for our build artifacts
    INSTALL_PATH="$ROOT_PATH/External/build"
    mkdir -p "$INSTALL_PATH/iphoneos/"{lib,include,lib/pkgconfig,log}
    mkdir -p "$INSTALL_PATH/iphonesimulator/"{lib,include,lib/pkgconfig,log}
}

function build_xcframework() {
    echo "Building XCFramework for \"$LIBRARY_NAME\" ..."
    xcodebuild -create-xcframework \
        -framework "$INSTALL_PATH/iphoneos/lib/$LIBRARY_NAME.framework" \
        -framework "$INSTALL_PATH/iphonesimulator/lib/$LIBRARY_NAME.framework" \
        -output "$INSTALL_PATH/$LIBRARY_NAME.xcframework"
    echo "Building done."
}

function build_framework()
{
    PLATFORM="$1"

    PLATFORM_INSTALL_PATH="$INSTALL_PATH/$PLATFORM"
    LIBS=()
    
    for ARCH in ${ARCHS[$PLATFORM]}
    do
        INSTALL_PREFIX="$PLATFORM_INSTALL_PATH/build/$LIBRARY_NAME/$ARCH"
        
        LIBS+=("$INSTALL_PREFIX/lib/$LIBRARY_NAME.a")
    done

    echo "Copying headers and pkg-config files ..."
    cp -r "$INSTALL_PREFIX/include/"* "$INSTALL_PATH/$PLATFORM/include/"
    cp "$INSTALL_PREFIX/lib/pkgconfig/$LIBRARY_NAME.pc" "$PLATFORM_INSTALL_PATH/lib/pkgconfig/"
    sed -e "s|^prefix=.*$|prefix=$PLATFORM_INSTALL_PATH|" \
        -i '' "$PLATFORM_INSTALL_PATH/lib/pkgconfig/$LIBRARY_NAME.pc"

    echo "Building framework for platform \"$PLATFORM\" ..."
    lipo -create "${LIBS[@]}" -output "${PLATFORM_INSTALL_PATH}/lib/$LIBRARY_NAME.a"
    mkdir -p "$PLATFORM_INSTALL_PATH/lib/$LIBRARY_NAME.framework"
    libtool -static -o "$PLATFORM_INSTALL_PATH/lib/$LIBRARY_NAME.framework/$LIBRARY_NAME" "$PLATFORM_INSTALL_PATH/lib/$LIBRARY_NAME.a"
    mkdir -p "$PLATFORM_INSTALL_PATH/lib/$LIBRARY_NAME.framework/Headers"
    cp -r "$INSTALL_PREFIX/include/"* "$PLATFORM_INSTALL_PATH/lib/$LIBRARY_NAME.framework/Headers"
    cp "$SCRIPT_DIR/../assets/Info.plist" "$PLATFORM_INSTALL_PATH/lib/$LIBRARY_NAME.framework"
    VERSION=$(git -C $SCRIPT_DIR/../External/$LIBRARY_NAME/ rev-parse HEAD)
    sed -e "s/BUNDLE_EXECUTABLE/$LIBRARY_NAME/g" \
        -e "s/BUNDLE_IDENTIFIER/org.$LIBRARY_NAME.$PLATFORM/g" \
        -e "s/BUNDLE_NAME/$LIBRARY_NAME/g" \
        -e "s/BUNDLE_VERSION/$VERSION/g" \
        -e "s/MIN_OS_VERSION/$IPHONEOS_DEPLOYMENT_TARGET/g" \
        -i '' "$PLATFORM_INSTALL_PATH/lib/$LIBRARY_NAME.framework/Info.plist"
}

function build_all_archs ()
{
    setup_build_environment

    local setup=$1
    local build_arch=$2

    # run the prepare function
    eval $setup

    if [ -d "$INSTALL_PATH/$LIBRARY_NAME.xcframework" ]
    then
        echo "Nothing to be done."
        exit 0
    fi

    for PLATFORM in "${!ARCHS[@]}"
    do
        for ARCH in ${ARCHS[$PLATFORM]}
        do
            if [ "$ARCH" == "arm64" ]
            then
                HOST="aarch64-apple-darwin"
            else
                HOST="$ARCH-apple-darwin"
            fi

            SDKVERSION=$(ios_sdk_version)
            SDKNAME="$PLATFORM$SDKVERSION"
            SDKROOT="$(ios_sdk_path $SDKNAME)"

            LOG="$INSTALL_PATH/$PLATFORM/log/$LIBRARY_NAME-$ARCH.log"
            [ -f "$LOG" ] && rm "$LOG"

            ARCH_INSTALL_PATH="$INSTALL_PATH/$PLATFORM"
        
            echo "Building $LIBRARY_NAME for $SDKNAME $ARCH"
            echo "Build log can be found in $LOG"
            echo "Please stand by..."

            # run the per arch build command
            eval $build_arch
        done
        build_framework "$PLATFORM"
    done
    build_xcframework
}

