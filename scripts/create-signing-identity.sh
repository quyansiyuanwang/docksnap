#!/usr/bin/env bash
# Creates a local, self-signed code-signing identity in the login keychain.
#
# macOS ties the Accessibility permission to the app's code signature. An ad-hoc
# signature (`codesign -s -`) has a code hash that changes on every build, so the
# permission is dropped each time. A self-signed certificate gives a stable
# designated requirement:
#
#   identifier "com.quyansiyuanwang.docksnap" and certificate leaf = H"..."
#
# The certificate never leaves this machine. Remove it later with:
#   security delete-identity -c "DockSnap Local Signing"
set -euo pipefail

NAME="DockSnap Local Signing"

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "identity already exists: $NAME"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$TMP_DIR/key.pem" \
    -out "$TMP_DIR/cert.pem" \
    -subj "/CN=$NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning"

openssl pkcs12 -export -legacy \
    -inkey "$TMP_DIR/key.pem" \
    -in "$TMP_DIR/cert.pem" \
    -out "$TMP_DIR/identity.p12" \
    -passout pass:docksnap \
    -name "$NAME"

security import "$TMP_DIR/identity.p12" \
    -k "$HOME/Library/Keychains/login.keychain-db" \
    -P docksnap \
    -T /usr/bin/codesign \
    -T /usr/bin/security

echo "created identity: $NAME"
