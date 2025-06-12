# Stage 1: Build
ARG BASE_IMAGE=fedora:42
FROM ${BASE_IMAGE} AS builder

# Define build-time arguments
ARG TNCATTACH_GIT_REPO=https://github.com/markqvist/tncattach.git
ARG TNCATTACH_BRANCH=master

# Install build dependencies
RUN dnf -y install git make gcc iputils iproute && dnf clean all

# Clone and checkout the specified branch
RUN git clone --branch ${TNCATTACH_BRANCH} ${TNCATTACH_GIT_REPO} /src

# Build the project
WORKDIR /src
RUN make

# Stage 2: Runtime
FROM ${BASE_IMAGE}

# Copy the built binary from the builder stage
COPY --from=builder /src/tncattach /usr/local/bin/tncattach

# Optional: Create a non-root user (comment out if not needed)
# RUN useradd -m appuser
# USER appuser

# Set default command
ENTRYPOINT ["tncattach"]
