FROM fedora:42

ENV container podman

# Install dependencies
RUN dnf -y install systemd git procps python3 python3-pip iputils iproute && \
    dnf clean all

# Create unprivileged user
RUN useradd -m -s /bin/bash bbs

# Clone repo and install requirements as root
ARG APRS_BBS_GIT_REPO=https://github.com/TheCommsChannel/TC2-APRS-BBS.git
RUN git clone ${APRS_BBS_GIT_REPO} /bbs && \
    chown -R bbs:bbs /bbs && \
    pip3 install -r /bbs/requirements.txt --root-user-action=ignore

# Switch to unprivileged user
USER bbs
WORKDIR /bbs
COPY config.ini /bbs/config.ini
# Default command (optional)
CMD ["bash"]
