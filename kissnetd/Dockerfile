ARG BASE_IMAGE=fedora:42
FROM ${BASE_IMAGE}

RUN dnf -y install systemd ax25-tools ax25-apps procps socat && \
    dnf clean all

COPY --chmod=0555 start.sh /usr/local/bin/start.sh


# How many virtual serial devices to create?
ENV COUNT=3
# Should the first serial device be bound to another DEVICE via socat?
# If blank, no.
ENV DEVICE=

CMD ["/usr/local/bin/start.sh"]
