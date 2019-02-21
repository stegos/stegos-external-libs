#!/usr/bin/env bash
#

install_deps_linux() {
    apt-get update &&
        apt-get install -y \
            bison \
            build-essential \
            curl \
            flex \
            libgmp-dev
    (cd /tmp &&
        curl -L https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2 | tar xvfj -)
    mkdir var
    mv /tmp/bin/linux/amd64/github-release var/github-release
}

install_deps_macos() {
    brew install gmp pbc mpfr
}

BASE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBC_SRC=https://crypto.stanford.edu/pbc/files/pbc-0.5.14.tar.gz
FLINT_SRC=http://www.flintlib.org/flint-2.5.2.tar.gz
MPFR_SRC=https://www.mpfr.org/mpfr-current/mpfr-4.0.2.tar.gz

# where make install will install stuff
var=${BASE}/var
prefix=${var}/local
src=${var}/src
pbc=${src}/pbc-0.5.14
flint=${src}/flint-2.5.2
mpfr=${src}/mpfr-4.0.2

lib=${prefix}/lib
inc=${prefix}/include

uname_s=$(uname -s)
case ${uname_s} in
Linux*)
    arch=linux
    PBC_CONFIGURE_FLAGS="--enable-static"
    MPFR_CONFIGURE_FLAGS="--enable-static --disable-shared"
    FLINT_CONFIGURE_FLAGS="--enable-static --disable-shared --with-mpfr=${prefix}"
    install_deps_linux
    ;;
Darwin*)
    arch=osx
    PBC_CONFIGURE_FLAGS="--enable-static"
    FLINT_CONFIGURE_FLAGS="--enable-static"
    install_deps_macos
    ;;
*)
    echo Unknown OS \"$(uname_s)\"

    ;;
esac

mkdir -p ${src}

# Build PBC library

cd ${src} &&
    curl -L ${PBC_SRC} | tar xvfz - &&
    cd ${pbc} &&
    ./configure ${PBC_CONFIGURE_FLAGS} --prefix=${prefix} &&
    make &&
    make install

# Use @rpath in libraries ids for macOS
if [[ ${uname_s} == Darwin* ]]; then
    (cd ${lib} && install_name_tool -id '@rpath/libpbc.dylib' libpbc.dylib)
fi

# Build MPFR for Linux
if [[ ${uname_s} == Linux* ]]; then
    cd ${src} &&
        curl -L ${MPFR_SRC} | tar xvfz - &&
        cd ${mpfr} &&
        ./configure ${MPFR_CONFIGURE_FLAGS} --prefix=${prefix} &&
        make &&
        make install
fi

# Build Flint library

cd ${src} &&
    curl -L ${FLINT_SRC} | tar xvfz - &&
    cd ${flint} &&
    ./configure ${FLINT_CONFIGURE_FLAGS} --prefix=${prefix} &&
    make &&
    make install

# Use @rpath in libraries ids for macOS
if [[ ${uname_s} == Darwin* ]]; then
    (cd ${lib} && install_name_tool -id '@rpath/libflint.dylib' libflint.dylib)
fi

cd ${prefix} &&
    tar cvfz ../stegos-external-libs-${arch}.tgz * &&
    echo "var/stegos-external-libs-${arch}.tgz" >artifact.txt
