ARG DOCKER_IMAGE
FROM ${DOCKER_IMAGE}
RUN useradd -m swiftbot
ADD . /UpdateSwiftCompilerDiscordBot
RUN cd /UpdateSwiftCompilerDiscordBot && \
    SWIFTPM_FLAGS="--configuration release --static-swift-stdlib" && \
    swift build $SWIFTPM_FLAGS && \
    mv `swift build $SWIFTPM_FLAGS --show-bin-path`/Run /usr/bin/UpdateSwiftCompilerDiscordBot && \
    cd / && \
    rm -rf UpdateSwiftCompilerDiscordBot

USER swiftbot
CMD UpdateSwiftCompilerDiscordBot serve --env production --port $PORT --hostname 0.0.0.0
