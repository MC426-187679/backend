# Use a ubuntu based swift image
FROM swift:5.5.1-focal as build

# Install OS updates, python3 and NodeJS
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y unzip \
    && rm -rf /var/lib/apt/lists/*

# Install swiftlint binary
ADD https://github.com/realm/SwiftLint/releases/latest/download/swiftlint_linux.zip ./swiftlint.zip
RUN unzip ./swiftlint.zip swiftlint \
    && mv ./swiftlint /usr/bin/swiftlint \
    && chmod +x /usr/bin/swiftlint \
    && rm ./swiftlint.zip

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.swift ./Package.resolved ./
RUN swift package resolve
