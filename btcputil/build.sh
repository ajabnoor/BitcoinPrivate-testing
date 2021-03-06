#!/usr/bin/env bash

# this will make execution of bash scripts safer. For more info visit
# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -eu -o pipefail

# Allow user overrides to $MAKE. Typical usage for users who need it:
#   MAKE=gmake ./btcputil/build.sh -j$(nproc)
# assign default value to override after the (-). See this https://wiki.bash-hackers.org/syntax/pe#use_a_default_value
if [[ -z "${MAKE-}" ]]; then
    MAKE=make
fi

# Allow overrides to $BUILD and $HOST for porters. Most users will not need it.
#   BUILD=i686-pc-linux-gnu ./btcputil/build.sh
if [[ -z "${BUILD-}" ]]; then
    BUILD=x86_64-unknown-linux-gnu
fi
if [[ -z "${HOST-}" ]]; then
    HOST=x86_64-unknown-linux-gnu
fi

# Allow override to $CC and $CXX for porters. Most users will not need it.
if [[ -z "${CC-}" ]]; then
    CC=gcc
fi
if [[ -z "${CXX-}" ]]; then
    CXX=g++
fi

# By putting x on both sides it's the same as just comparing the variables directly 
# but the two sides will always be non-empty. see this 
# https://stackoverflow.com/questions/1805663/shell-script-purpose-of-x-in-xvariable/
if [ "x$*" = 'x--help' ]
then

# diplay help on the screen
    cat <<EOF
Usage:

$0 --help
  Show this help message and exit.

$0 [ --enable-lcov || --disable-tests ] [ --disable-mining ] [ --disable-rust ] [ --enable-proton ] [ --disable-libs ] [ MAKEARGS... ]
  Build Bitcoin Private and most of its transitive dependencies from
  source. MAKEARGS are applied to both dependencies and Bitcoin Private itself.

  If --enable-lcov is passed, Bitcoin Private is configured to add coverage
  instrumentation, thus enabling "make cov" to work.
  If --disable-tests is passed instead, the Bitcoin Private tests are not built.

  If --disable-mining is passed, Bitcoin Private is configured to not build any mining
  code. It must be passed after the test arguments, if present.

  If --disable-rust is passed, Bitcoin Private is configured to not build any Rust language
  assets. It must be passed after test/mining arguments, if present.

  If --enable-proton is passed, Bitcoin Private is configured to build the Apache Qpid Proton
  library required for AMQP support. This library is not built by default.
  It must be passed after the test/mining/Rust arguments, if present.

  If --disable-libs is passed, Bitcoin Private is configured to not build any libraries like
  'libzcashconsensus'.
EOF
    exit 0
fi

# The -x option causes bash to print each command before executing it.
set -x

# return to the absolute path of BitcoinPrivate Directory ==>
# readlink -f "$0" converts current relative path to absolute paths with bash at the end /home/xxxxx/BitcoinPrivate/btcutil/build.sh
# dir="$(dirname $dir)"   # Returns "/home/xxxxx/BitcoinPrivate/btcutil/"
# then /..
cd "$(dirname "$(readlink -f "$0")")/.."

# If --enable-lcov is the first argument, enable lcov coverage support:
LCOV_ARG=''
HARDENING_ARG='--enable-hardening'
TEST_ARG=''
if [ "x${1:-}" = 'x--enable-lcov' ]
then
    LCOV_ARG='--enable-lcov'
    HARDENING_ARG='--disable-hardening'
    shift
elif [ "x${1:-}" = 'x--disable-tests' ]
then
    TEST_ARG='--enable-tests=no'
    shift
fi

# If --disable-mining is the next argument, disable mining code:
MINING_ARG=''
if [ "x${1:-}" = 'x--disable-mining' ]
then
    MINING_ARG='--enable-mining=no'
    shift
fi

# If --disable-rust is the next argument, disable Rust code:
RUST_ARG=''
if [ "x${1:-}" = 'x--disable-rust' ]
then
    RUST_ARG='--enable-rust=no'
    shift
fi

# If --enable-proton is the next argument, enable building Proton code:
PROTON_ARG='--enable-proton=no'
if [ "x${1:-}" = 'x--enable-proton' ]
then
    PROTON_ARG=''
    shift
fi

# If --disable-libs is the next argument, build without libs:
LIBS_ARG=''
if [ "x${1:-}" = 'x--disable-libs' ]
then
    LIBS_ARG='--without-libs'
    shift
fi

PREFIX="$(pwd)/depends/$BUILD/"

eval "$MAKE" --version
eval "$CC" --version
eval "$CXX" --version
as --version
ld -v

HOST="$HOST" BUILD="$BUILD" NO_RUST="$RUST_ARG" NO_PROTON="$PROTON_ARG" "$MAKE" "$@" -C ./depends/ V=1
./autogen.sh
CC="$CC" CXX="$CXX" ./configure --prefix="${PREFIX}" --host="$HOST" --build="$BUILD" "$RUST_ARG" "$HARDENING_ARG" "$LCOV_ARG" "$TEST_ARG" "$MINING_ARG" "$PROTON_ARG" "$LIBS_ARG" CXXFLAGS='-fwrapv -fno-strict-aliasing -Wno-builtin-declaration-mismatch -Werror -g'
"$MAKE" "$@" V=1
