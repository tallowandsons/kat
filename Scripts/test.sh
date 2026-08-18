#!/bin/sh
# Runs `swift test`. Without Xcode installed, swift-testing's runtime
# (Testing.framework + lib_TestingInterop.dylib) lives under the Command Line Tools'
# private Developer/Frameworks dir instead of a default search path — and critically,
# these paths must be passed as top-level `swift test` flags (Package.swift-level
# target settings only affect the test bundle's own link step, not the separate
# swiftpm-testing-helper process `swift test` spawns to run it).
#
# Usage: Scripts/test.sh [swift test args...]

set -e

CLT_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
CLT_TESTING_LIB="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

exec swift test \
    -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
    -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$CLT_TESTING_LIB" \
    -Xlinker -L -Xlinker "$CLT_TESTING_LIB" \
    "$@"
