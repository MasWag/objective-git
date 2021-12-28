#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

"$SCRIPT_DIR/build_dependencies.sh"

xcodebuild clean archive \
    -workspace "$SCRIPT_DIR/../ObjectiveGitFramework.xcworkspace" \
    -scheme "ObjectiveGit iOS" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath /tmp/xcf/sim.archive \
    -derivedDataPath /tmp/iphonesimulator \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
xcodebuild clean archive \
    -workspace "$SCRIPT_DIR/../ObjectiveGitFramework.xcworkspace" \
    -scheme "ObjectiveGit iOS" \
    -destination "generic/platform=iOS" \
    -archivePath /tmp/xcf/ios.archive \
    -derivedDataPath /tmp/iphoneos \
    -sdk iphoneos \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild -create-xcframework \
    -framework "/tmp/xcf/ios.archive.xcarchive/Products/@rpath/ObjectiveGit.framework" \
    -framework "/tmp/xcf/sim.archive.xcarchive/Products/@rpath/ObjectiveGit.framework" \
    -output "$SCRIPT_DIR/../Framework/ObjectiveGit.xcframework"

pushd "$SCRIPT_DIR/../Framework" > /dev/null

zip -rq "ObjectiveGit.xcframework.zip" "ObjectiveGit.xcframework"

popd > /dev/null
