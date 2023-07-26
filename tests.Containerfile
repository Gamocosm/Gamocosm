FROM docker.io/fedora:38

WORKDIR /gamocosm

RUN dnf -y upgrade
RUN dnf -y install vim tmux git
RUN dnf -y install openssh-server
RUN dnf -y install python3 python3-devel python3-pip python3-systemd
RUN dnf -y install unzip

RUN systemctl enable sshd

RUN ssh-keygen -t ed25519 -N '' -f /etc/ssh/ssh_host_ed25519_key

COPY id_gamocosm /root/.ssh/id_gamocosm
RUN ssh-keygen -y -f /root/.ssh/id_gamocosm > /root/.ssh/authorized_keys

RUN ln -s /usr/bin/true /usr/local/bin/passwd
RUN ln -s /usr/bin/true /usr/local/bin/chattr
# swapon exists but doesn't seem work inside a container ("swapon failed: Operation not permitted")...
RUN ln -s /usr/bin/true /usr/local/bin/swapon
RUN ln -s /usr/bin/true /usr/local/bin/firewall-cmd
RUN ln -s /usr/bin/true /usr/local/bin/semodule
RUN ln -s /usr/bin/true /usr/local/bin/semanage

ENTRYPOINT [ "/sbin/init" ]
