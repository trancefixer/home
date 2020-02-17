FROM letfn/python

ENV DEBIAN_FRONTEND=noninteractive
ENV container docker

USER root
ENV HOME=/root
WORKDIR /root

RUN apt-get update && apt-get install -y openssh-server curl sudo tzdata \
    locales iputils-ping iproute2 net-tools pass gnupg pinentry-curses tmux expect \
    man-db manpages groff docker.io libusb-1.0-0 libusb-1.0-0-dev vim-nox \
    apt-transport-https make

RUN cd /usr/local/bin && curl -sSL -O https://github.com/drone/drone-cli/releases/download/v1.2.1/drone_linux_amd64.tar.gz \
    && tar xvfz drone_linux_amd64.tar.gz \
    && rm -f drone_linux_amd64.tar.gz \
    && chmod 755 drone

RUN cd /usr/local/bin && curl -sSL -O https://github.com/justjanne/powerline-go/releases/download/v1.15.0/powerline-go-linux-amd64 \
    && mv powerline-go-linux-amd64 powerline-go \
    && chmod 755 powerline-go

RUN cd /usr/local/bin && curl -sSL -O https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && mv jq-linux64 jq \
    && chmod 755 jq

RUN cd /usr/local/bin && curl -o docker-compose -sSL https://github.com/docker/compose/releases/download/1.25.4/docker-compose-Linux-x86_64 \
    && chmod 755 docker-compose

RUN cd /usr/local/bin && curl -sSL -O https://github.com/segmentio/aws-okta/releases/download/v0.27.0/aws-okta-v0.27.0-linux-amd64 \
    && mv aws-okta-v0.27.0-linux-amd64 aws-okta \
    && chmod 755 aws-okta

RUN cd /usr/local/bin && curl -sSL -O https://github.com/segmentio/chamber/releases/download/v2.7.5/chamber-v2.7.5-linux-amd64 \
    && mv chamber-v2.7.5-linux-amd64 chamber \
    && chmod 755 chamber

RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime
RUN dpkg-reconfigure -f noninteractive tzdata

RUN locale-gen en_US.UTF-8
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN rm -f /usr/bin/gs

RUN mkdir -p /run/sshd /var/run/sshd /run && chown -R app:app /var/run/sshd /run /etc/ssh

RUN echo "app ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN echo "Defaults !requiretty" >> /etc/sudoers

COPY --chown=app:app home /app/src

USER app
ENV HOME=/app/src
WORKDIR /app/src

RUN chmod 700 /app/src/.ssh
RUN chmod 600 /app/src/.ssh/authorized_keys
RUN chmod 700 /app/src/.gnupg

RUN mkdir -p /app/src/.aws && ln -nfs /efs/config/aws/config /app/src/.aws/
RUN ln -nfs /efs/config/pass /app/src/.password-store
RUN ln -nfs /efs/config/terraform/.terraform.d /app/src/
RUN ln -nfs /efs/config/terraform/.terraformrc /app/src/

COPY --chown=app:app .dotfiles /app/src/.dotfiles
RUN make -f .dotfiles/Makefile dotfiles

COPY --chown=app:app requirements.txt /app/src/
RUN . /app/venv/bin/activate && pip install --no-cache-dir -r /app/src/requirements.txt
COPY --chown=app:app src /app/src

COPY service /service

RUN sudo apt-get update && sudo apt-get upgrade -y

ENTRYPOINT [ "/tini", "--", "/service" ]