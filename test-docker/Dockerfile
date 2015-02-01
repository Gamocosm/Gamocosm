FROM fedora:20
MAINTAINER Raekye

RUN yum -y install openssh-server
RUN ssh-keygen -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key

RUN mkdir /root/.ssh
RUN chmod 700 /root/.ssh

ADD id_rsa.pub /root/.ssh/authorized_keys
RUN chmod 644 /root/.ssh/authorized_keys

ENTRYPOINT ["/usr/sbin/sshd", "-D"]
