FROM fedora:42

ENV container podman

RUN dnf -y install ax25-tools ax25-apps procps && \
    dnf clean all

RUN mkdir -p /etc/ax25
COPY ax25ipd.conf /etc/ax25/ax25ipd.conf

ENV DEVICE=/dev/rfcomm0
CMD ["ax25ipd", "-c", "/etc/ax25/ax25ipd.conf", "-d", "${DEVICE}"]
