CARGO ?= cargo +nightly
BIN ?= greentic-demo
DOCKER_IMAGE ?= greentic-demo:dev

PORT ?= 8080
ifneq (,$(wildcard .env))
PORT := $(shell grep -E '^PORT=' .env | tail -1 | cut -d'=' -f2)
endif

.PHONY: run docker-build docker-run tunnel fmt test

.env:
	@test -f .env || (cp .env.example .env && echo "Created .env from .env.example")

run: .env
	@set -a; \
		. ./.env; \
		$(CARGO) run --locked --bin $(BIN)

fmt:
	$(CARGO) fmt

test:
	$(CARGO) test --locked

# Build a static binary and package it into a tiny distroless image.
docker-build:
	docker build --target runtime -t $(DOCKER_IMAGE) .

# Run the previously built container with the current .env file.
docker-run: .env
	docker run --rm --env-file .env -p $(PORT):8080 $(DOCKER_IMAGE)

# Expose the local server using Cloudflare Tunnel for quick demos.
tunnel: .env
	@command -v cloudflared >/dev/null 2>&1 || (echo "cloudflared is required for make tunnel" && exit 1)
	@set -a; \
		. ./.env; \
		cloudflared tunnel --url "http://127.0.0.1:$${PORT:-8080}"
