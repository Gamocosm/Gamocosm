FROM fedora:20
MAINTAINER Raekye

RUN yum -y update
RUN yum -y install openssh-server
RUN yum -y install wget
RUN yum -y install yum-plugin-security firewalld java-1.7.0-openjdk-headless python3 python3-devel python3-pip git tmux
RUN ssh-keygen -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key

RUN mkdir /root/.ssh
RUN chmod 700 /root/.ssh
ADD id_rsa.pub /root/.ssh/authorized_keys
RUN chmod 644 /root/.ssh/authorized_keys

RUN echo 'PATH="$HOME/bin:$PATH"' >> /root/.bashrc
RUN mkdir /root/bin
ADD swapon.sh /root/bin/swapon
RUN chmod u+x /root/bin/swapon
ADD firewall-cmd.sh /root/bin/firewall-cmd
RUN chmod u+x /root/bin/firewall-cmd
ADD systemctl.sh /root/bin/systemctl
RUN chmod u+x /root/bin/systemctl

ENTRYPOINT ["/usr/sbin/sshd", "-D"]
