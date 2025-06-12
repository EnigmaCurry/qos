FROM fedora:42

ENV container podman

RUN dnf -y install systemd ax25-tools ax25-apps procps && \
    dnf clean all

COPY ax25d.sh /usr/local/bin/ax25d.sh
COPY ax25d.service /etc/systemd/system/ax25d.service
RUN ln -s /etc/systemd/system/ax25d.service \
      /etc/systemd/system/multi-user.target.wants/ax25d.service

STOPSIGNAL SIGRTMIN+3

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/usr/sbin/init"]
