#!/bin/sh -e
swift build --product vm
codesign --force --entitlement Resources/vm.entitlements --sign - .build/debug/vm
.build/debug/vm