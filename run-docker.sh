#!/bin/sh
# Runs swift-format lint, the tests and a release build in the official Swift
# image, so your local Swift does not matter. Usage: ./run-docker.sh
set -e
docker run --rm -v "$PWD":/app -w /app swift:6.0 sh -c '
  set -e
  swift format lint --strict --recursive Package.swift Sources Tests
  swift build --scratch-path .build-linux --build-tests
  swift test --scratch-path .build-linux --skip-build
  swift build --scratch-path .build-linux -c release
  echo "All checks passed."
'
