#!/bin/bash

set -eu

ROOT=$(realpath ".")
PREFIX=$(realpath "local")
BUILD=$(realpath "build")

rm -rf "$PREFIX" "$BUILD"

mkdir -p "$BUILD/SDL"
cd "$ROOT/SDL"
./configure --prefix="$PREFIX" && make && make install

mkdir -p "$BUILD/SDL_image"
cd "$ROOT/SDL_image"
./configure --prefix="$PREFIX" && make && make install

mkdir -p "$BUILD/SDL_ttf"
cd "$ROOT/SDL_ttf"
./configure --prefix="$PREFIX" && make && make install
