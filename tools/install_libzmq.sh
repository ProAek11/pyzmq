#!/usr/bin/env bash
# script to install libzmq/libsodium for use in wheels
set -ex
LIBSODIUM_VERSION="1.0.18"

LIBZMQ_VERSION="$(python3 -m buildutils.bundle)"

if [[ "$(uname)" == "Darwin" ]]; then
    ARCHS="x86_64"
    case "${CIBW_ARCHS_MACOS:-auto}" in
        "universal2")
            ARCHS="x86_64 arm64"
            ;;
        "arm64")
            ARCHS="arm64"
            ;;
        "x86_64")
            ARCHS="x86_64"
            ;;
        "auto")
            ;;
        *)
            echo "Unexpected arch: ${CIBW_ARCHS_MACOS}"
            exit 1
            ;;
    esac
    echo "building libzmq for mac ${ARCHS}"
    for arch in ${ARCHS}; do
        export CFLAGS="-arch ${arch} ${CFLAGS:-}"
        export CXXFLAGS="-arch ${arch} ${CXXFLAGS:-}"
        export LDFLAGS="-arch ${arch} ${LDFLAGS:-}"
    done
fi

PREFIX="${PREFIX:-/usr/local}"

curl -L -O "https://download.libsodium.org/libsodium/releases/libsodium-${LIBSODIUM_VERSION}.tar.gz"

curl -L -O "https://github.com/zeromq/libzmq/releases/download/v${LIBZMQ_VERSION}/zeromq-${LIBZMQ_VERSION}.tar.gz"

tar -xzf libsodium-${LIBSODIUM_VERSION}.tar.gz
cd libsodium-${LIBSODIUM_VERSION}
./configure --prefix="$PREFIX"
make -j4
make install

cd ..

which ldconfig && ldconfig || true

tar -xzf zeromq-${LIBZMQ_VERSION}.tar.gz
cd zeromq-${LIBZMQ_VERSION}
# patch CURVE crash bug https://github.com/zeromq/libzmq/issues/4241
# FIXME: switch to `--disable-libsodium_randombytes_close`
# when we bump bundle libzmq to 4.3.5

patch -p1 <<EOF
diff --git a/src/random.cpp b/src/random.cpp
index 17c3537df3..12dead87ba 100644
--- a/src/random.cpp
+++ b/src/random.cpp
@@ -151,8 +151,6 @@ static void manage_random (bool init_)
     if (init_) {
         int rc = sodium_init ();
         zmq_assert (rc != -1);
-    } else {
-        randombytes_close ();
     }
 #else
     LIBZMQ_UNUSED (init_);
EOF

# avoid error on warning
export CXXFLAGS="-Wno-error ${CXXFLAGS:-}"

./configure --prefix="$PREFIX" --with-libsodium
make -j4
make install

which ldconfig && ldconfig || true
