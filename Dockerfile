# ------------------------------------
# Stage 1: Builder (SDK + native libs)
# ------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:6.0-jammy AS BUILDER

# Prevent apt prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install apt deps for both .NET and native builds
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git \
      cmake build-essential clang ninja-build \
      libssl-dev pkg-config libboost-all-dev \
      libsodium-dev libzmq5 libzmq3-dev \
      golang-go libgmp-dev libc++-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# Clone your fork (master branch)
WORKDIR /src
RUN git clone --branch master --depth 1 \
      https://github.com/bitkini/miningcore.git .

# Build native libraries into /src/build/
RUN mkdir -p build

# libmultihash, libethhash, libcryptonote, libcryptonight
RUN cd Native/libmultihash   && make clean && make \
 && mv libmultihash.so /src/build/
RUN cd Native/libethhash     && make clean && make \
 && mv libethhash.so   /src/build/
RUN cd Native/libcryptonote  && make clean && make \
 && mv libcryptonote.so /src/build/
RUN cd Native/libcryptonight && make clean && make \
 && mv libcryptonight.so /src/build/

# RandomX
RUN cd /tmp \
 && rm -rf RandomX \
 && git clone https://github.com/tevador/RandomX \
 && cd RandomX && git checkout tags/v1.1.10 \
 && mkdir build && cd build \
 && cmake -DARCH=native -DBUILD_TESTS=OFF .. \
 && make \
 && cp librandomx.a /src/Native/librandomx/ \
 && cd /src/Native/librandomx \
 && make clean && make \
 && mv librandomarq.so /src/build/ || true \
 && mv librandomx.so  /src/build/

# RandomARQ
RUN cd /tmp \
 && rm -rf RandomARQ \
 && git clone https://github.com/arqma/RandomARQ \
 && cd RandomARQ && git checkout 14850620439045b319fa6398f5a164715c4a66ce \
 && mkdir build && cd build \
 && cmake -DARCH=native -DBUILD_TESTS=OFF .. \
 && make \
 && cp librandomx.a /src/Native/librandomarq/ \
 && cd /src/Native/librandomarq \
 && make clean && make \
 && mv librandomarq.so /src/build/

# Publish the .NET app into the same build folder
WORKDIR /src/src/Miningcore
RUN dotnet publish -c Release --framework net6.0 -o /src/build/

# ------------------------------------
# Stage 2: Runtime
# ------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:6.0-jammy AS RUNTIME

# Prevent apt prompts
ENV DEBIAN_FRONTEND=noninteractive

# Only need runtime deps here
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libssl-dev libsodium-dev libzmq5 libzmq3-dev curl \
 && rm -rf /var/lib/apt/lists/*

# Create app dir
WORKDIR /app

# Copy published binaries + native libs
COPY --from=BUILDER /src/build/            ./

# Expose API & Stratum ports
EXPOSE 4000 4066 4067

# Default args: expects a `config.json` in /app
ENTRYPOINT ["./Miningcore", "-c", "config.json"]