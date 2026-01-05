FROM swift:6.0-noble

# Install SQLite, build tools, and other dependencies
RUN apt-get update && apt-get install -y \
    sqlite3 \
    libsqlite3-dev \
    curl \
    gnupg \
    unzip \
    clang \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Bazelisk (cross-platform Bazel launcher)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then BAZEL_ARCH="amd64"; \
    elif [ "$ARCH" = "aarch64" ]; then BAZEL_ARCH="arm64"; \
    else BAZEL_ARCH="$ARCH"; fi && \
    curl -L -o /usr/local/bin/bazel "https://github.com/bazelbuild/bazelisk/releases/download/v1.25.0/bazelisk-linux-${BAZEL_ARCH}" && \
    chmod +x /usr/local/bin/bazel

WORKDIR /workspace
