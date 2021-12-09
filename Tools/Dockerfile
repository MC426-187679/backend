# Use a ubuntu based swift image
FROM swift:5.5.1-focal as build

# Install OS updates, python3 and NodeJS
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q upgrade -y \
    && apt-get -q install -y unzip zsh gcc make wget curl nano git build-essential

# Install swiftlint binary
COPY ./swiftlint /usr/bin/swiftlint
# Install Oh My Zsh
COPY ./oh-my-zsh.sh /oh-my-zsh.sh
RUN sh /oh-my-zsh.sh && rm /oh-my-zsh.sh

EXPOSE 8080
