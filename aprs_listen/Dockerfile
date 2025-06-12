ARG BASE_IMAGE=fedora:42
FROM ${BASE_IMAGE}
ENV container podman

RUN dnf -y install systemd git procps python3 python3-pip iputils iproute && \
    dnf clean all
RUN useradd -m -s /bin/bash aprs

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt --root-user-action=ignore

USER aprs
WORKDIR /aprs

COPY aprs_listen.py .

ENV DEVICE=/tmp/rfcomm0
ENV BAUDRATE=9600

CMD ["python3", "aprs_listen.py"]
