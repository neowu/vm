#!/bin/sh -e
swift build -c release --product vz
codesign --force --entitlement Resources/vz.entitlements --sign - .build/release/vz