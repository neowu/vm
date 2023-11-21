#!/bin/sh -e -x
swift build -c release --product vz
codesign --force --entitlement Resources/vz.entitlements --sign - .build/release/vz

sudo cp .build/release/vz /usr/local/bin 
vz --generate-completion-script zsh | sudo tee /usr/local/share/zsh/site-functions/_vz