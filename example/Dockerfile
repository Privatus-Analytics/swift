# Conformance example app (Vapor + Leaf). Build with the package folder as the
# context: docker build -f example/Dockerfile .
FROM swift:6.0 AS build
WORKDIR /swift
# The package from this repo's own source (a path dependency). The folder must
# be called swift: SwiftPM names a path dependency after its folder.
COPY Package.swift ./
COPY Sources/ Sources/
COPY example/ example/
WORKDIR /swift/example
RUN swift build -c release --static-swift-stdlib \
  && cp "$(swift build -c release --show-bin-path)/Example" /Example

FROM ubuntu:noble
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates tzdata \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /Example /app/Example
COPY example/Resources/ /app/Resources/
EXPOSE 8080
USER 65534
ENTRYPOINT ["/app/Example"]
CMD ["serve", "--env", "production"]
