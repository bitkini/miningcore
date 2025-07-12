#!/usr/bin/env bash
set -e

# 1) Register Microsoft package repo (for libssl, etc)
wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
     -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# 2) Install native build deps (but not dotnet-sdk via apt)
sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
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

# 3) Install .NET 6 via dotnet-install script
wget -q https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
chmod +x dotnet-install.sh
sudo mkdir -p /usr/share/dotnet
sudo ./dotnet-install.sh --channel 6.0 --install-dir /usr/share/dotnet
sudo ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet

# 4) Build MiningCore
(
  cd src/Miningcore
  BUILDDIR=${1:-../../build}
  echo "Building into $BUILDDIR"
  dotnet publish -c Release --framework net6.0 -o "$BUILDDIR"
)
