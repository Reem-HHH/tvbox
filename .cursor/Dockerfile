# Cloud Agent base image for the Kids TV Launcher (Android TV) project.
# Provides JDK 17 (matches CI) and the Android SDK needed by ./gradlew assembleDebug,
# plus python3 for the browser preview server (tools/preview.py).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless \
        ca-certificates \
        curl \
        unzip \
        git \
        python3 \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk

# Android command-line tools (pinned) used to install the SDK packages below.
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -fsSL -o /tmp/cmdtools.zip \
        https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    && unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools \
    && mv /tmp/cmdtools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm -rf /tmp/cmdtools.zip /tmp/cmdtools

ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

# SDK packages that match the project (compileSdk/targetSdk 35, AGP 8.7.3 build-tools).
RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" \
    && chown -R ubuntu:ubuntu ${ANDROID_HOME}

USER ubuntu
