#!/bin/sh
# Build the mock OmniMIDI library and run the test suite with LuaJIT.
set -e
cd "$(dirname "$0")/.."
out="${TMPDIR:-/tmp}/libmock_omnimidi.so"
${CC:-cc} -shared -fPIC -o "$out" test/mock_omnimidi.c
luajit test/test.lua "$out"
