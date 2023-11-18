#!/bin/sh -e
swift build --product vz
codesign --force --entitlement Resources/vz.entitlements --sign - .build/debug/vz
.build/debug/vz