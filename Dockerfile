FROM almalinux:8.6

ENV USER_HOME /home/docker
ENV LANG en_US.UTF-8

# Ensure locale is UTF-8
RUN dnf install --assumeyes \
    glibc-langpack-en \
    glibc-locale-source \ 
 && localedef --force --inputfile=en_US --charmap=UTF-8 en_US.UTF-8 \
 && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
 && dnf clean all \
 && rm -rf /var/cache/dnf /var/cache/yum

# Create non-root user
RUN groupadd --gid 1000 docker \
 && adduser --uid 1000 --gid 1000 --home ${USER_HOME} docker \
 && usermod -L docker

# Install EPEL and base packages
RUN dnf install --assumeyes glibc-langpack-en \
 && dnf install --assumeyes https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
 && dnf install --assumeyes dnf-plugins-core \
 && dnf config-manager --set-enabled powertools \
 && dnf update --assumeyes \
 && dnf install --assumeyes \
    ca-certificates \
    curl \
    git \
    jq \
    python36 \
    npm \
    nmap \
    psmisc \
    procps-ng \
    wget \
    tini \
 && dnf clean all \
 && rm -rf /var/cache/dnf /var/cache/yum

 #Install nodejs and enable module nodejs:16
RUN dnf module reset --assumeyes nodejs \
 && dnf module enable --assumeyes nodejs:16 \
 && dnf module install --assumeyes nodejs:16 

#Install elixir version 1.13.0 and erlang version 25.0.3
RUN wget https://packages.erlang-solutions.com/erlang/rpm/centos/8/x86_64/elixir_1.13.0-1~centos~8_all.rpm \
 && wget https://packages.erlang-solutions.com/erlang/rpm/centos/8/x86_64/esl-erlang_24.1.7-1~centos~8_amd64.rpm \
 && dnf install --assumeyes \
    elixir_1.13.0-1~centos~8_all.rpm \ 
    esl-erlang_24.1.7-1~centos~8_amd64.rpm \
 && rm -rf esl-erlang_24.1.7-1~centos~8_amd64.rpm \
   elixir_1.13.0-1~centos~8_all.rpm

# Install extra utilities
RUN dnf module enable --assumeyes postgresql:12 \
 && dnf install --assumeyes postgresql \
 && dnf update \
 && dnf clean all \
 && rm -rf /var/cache/dnf /var/cache/yum \
 && update-ca-trust extract

# Set environment to development
ENV MIX_ENV dev

# Copy over source code
RUN mkdir -p /app/assets \
 && chown -R docker:docker /app

COPY --chown=docker:docker mix.exs mix.lock /app/

USER docker

WORKDIR /app

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix deps.compile

COPY --chown=docker:docker assets/package*.json /app/assets/
RUN cd assets && npm install

COPY --chown=docker:docker config /app/config
COPY --chown=docker:docker scripts /app/scripts
COPY --chown=docker:docker priv /app/priv
COPY --chown=docker:docker lib /app/lib
COPY --chown=docker:docker assets /app/assets
COPY --chown=docker:docker test /app/test
COPY --chown=docker:docker .iex.exs /app
COPY --chown=docker:docker .bashrc $USER_HOME

RUN mix compile
RUN mix assets.deploy

ENV HOST ${HOST:-localhost}
ENV PORT ${PORT:-4000}
ENV BIND_ADDR ${BIND_ADDR:-0.0.0.0}

ENTRYPOINT [ "tini", "--" ]
CMD [ "./scripts/start-in-docker.sh" ]
