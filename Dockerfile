# syntax=docker/dockerfile:1.7

FROM rustlang/rust:nightly AS builder
WORKDIR /app
RUN rustup target add x86_64-unknown-linux-musl && \
    apt-get update && \
    apt-get install -y --no-install-recommends musl-tools pkg-config && \
    rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock rust-toolchain.toml ./
COPY src ./src
COPY cmd ./cmd
COPY docs ./docs
COPY packs ./packs
COPY README.md .
COPY .env.example .

ENV RUSTUP_TOOLCHAIN=nightly

RUN cargo build --locked --release --target x86_64-unknown-linux-musl --bin greentic-demo

FROM gcr.io/distroless/static:nonroot AS runtime
WORKDIR /app
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/greentic-demo /usr/local/bin/greentic-demo
ENV RUST_LOG=info
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/greentic-demo"]
