# ------------------------------------
# Stage 1: builder
# ------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:6.0-jammy AS builder
ENV DEBIAN_FRONTEND=noninteractive

# 1) Build dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git cmake build-essential clang ninja-build \
      libssl-dev pkg-config libboost-all-dev \
      libsodium-dev libzmq5 libzmq3-dev \
      golang-go libgmp-dev libc++-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# 2) Clone your fork (full history) and unshallow
RUN git clone --branch master https://github.com/bitkini/miningcore.git . \
 && git fetch --unshallow || true

# 3) Prepare output dir
RUN mkdir -p /build_output

# 4) Build native libraries
RUN cd /src/src/Native/libmultihash   && make clean && make && mv libmultihash.so   /build_output/ \
 && cd /src/src/Native/libethhash     && make clean && make && mv libethhash.so       /build_output/ \
 && cd /src/src/Native/libcryptonote  && make clean && make && mv libcryptonote.so  /build_output/ \
 && cd /src/src/Native/libcryptonight && make clean && make && mv libcryptonight.so /build_output/

# 5) RandomX
RUN cd /tmp \
 && rm -rf RandomX \
 && git clone https://github.com/tevador/RandomX \
 && cd RandomX && git checkout tags/v1.1.10 \
 && mkdir build && cd build \
 && cmake -DARCH=native -DBUILD_TESTS=OFF .. \
 && make \
 && cp librandomx.a /src/src/Native/librandomx/ \
 && cd /src/src/Native/librandomx \
 && make clean && make \
 && mv librandomx.so /build_output/

# 6) RandomARQ
RUN cd /tmp \
 && rm -rf RandomARQ \
 && git clone https://github.com/arqma/RandomARQ \
 && cd RandomARQ && git checkout 14850620439045b319fa6398f5a164715c4a66ce \
 && mkdir build && cd build \
 && cmake -DARCH=native -DBUILD_TESTS=OFF .. \
 && make \
 && cp librandomx.a /src/src/Native/librandomarq/ \
 && cd /src/src/Native/librandomarq \
 && make clean && make \
 && mv librandomarq.so /build_output/

# 7) Publish .NET app
WORKDIR /src/src/Miningcore
RUN dotnet publish -c Release --framework net6.0 -o /build_output/

# ------------------------------------
# Stage 2: runtime
# ------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:6.0-jammy AS runtime
ENV DEBIAN_FRONTEND=noninteractive

# 1) Runtime deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libssl-dev libsodium-dev libzmq5 libzmq3-dev curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN rm -rf coins.json

# 2) Copy build outputs
COPY --from=builder /build_output/ ./

# 3) Expose ports
EXPOSE 4000 4066 4067

# 4) Entrypoint & Default args
ENTRYPOINT ["./Miningcore"]
CMD ["-c", "config.json"]
