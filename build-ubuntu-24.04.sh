#!/usr/bin/env bash
set -e

# Ubuntu 24 includes dotnet-sdk-6.0 out of the box
sudo apt-get update
sudo apt-get install -y \
  dotnet-sdk-6.0 \
  git \
  cmake \
  build-essential \
  libssl-dev \
  pkg-config \
  libboost-all-dev \
  libsodium-dev \
  libzmq5 \
  libzmq3-dev \
  golang-go \
  libgmp-dev \
  libc++-dev \
  zlib1g-dev \
  ninja-build \
  clang

# Build MiningCore
(
  cd src/Miningcore
  BUILDDIR=${1:-../../build}
  echo "Building into $BUILDDIR"
  dotnet publish -c Release --framework net6.0 -o "$BUILDDIR"
)
