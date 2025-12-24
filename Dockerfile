FROM almalinux:10.1

ENV USER_HOME /home/docker
ENV LANG en_US.UTF-8

ARG OTP_VERSION=28.3
ARG ELIXIR_VERSION=1.19.4
ARG ELIXIR_ZIP=elixir-otp-28.zip
ENV PATH /usr/local/elixir-otp-28/bin:${PATH}

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
 && dnf install --assumeyes https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm \
 && dnf install --assumeyes dnf-plugins-core \
 && dnf config-manager --set-enabled crb \
 && dnf update --assumeyes \
 && dnf install --assumeyes \
    autoconf \
    ca-certificates \
    curl \
    gcc \
    gcc-c++ \
    git \
    jq \
    make \
    perl \
    nmap \
    npm \
    ncurses-devel \
    openssl-devel \
    psmisc \
    procps-ng \
    tar \
    unixODBC-devel \
    unzip \
    wget \
    nodejs \
    zlib-devel \
 && dnf clean all \
 && rm -rf /var/cache/dnf /var/cache/yum

# Build and install Erlang/OTP (GitHub release)
RUN set -eux \
 && OTP_TARBALL="otp_src_${OTP_VERSION}.tar.gz" \
 && curl -fsSL "https://github.com/erlang/otp/releases/download/OTP-${OTP_VERSION}/${OTP_TARBALL}" -o "/tmp/${OTP_TARBALL}" \
 && curl -fsSL "https://github.com/erlang/otp/releases/download/OTP-${OTP_VERSION}/${OTP_TARBALL}.sigstore" -o "/tmp/${OTP_TARBALL}.sigstore" \
 && tar -xzf "/tmp/${OTP_TARBALL}" -C /tmp \
 && cd "/tmp/otp_src_${OTP_VERSION}" \
 && ./configure --without-wx \
 && make -j"$(nproc)" \
 && make install \
 && rm -rf "/tmp/otp_src_${OTP_VERSION}" "/tmp/${OTP_TARBALL}" "/tmp/${OTP_TARBALL}.sigstore"

# Install Elixir (GitHub release)
RUN set -eux \
 && curl -fsSL "https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/${ELIXIR_ZIP}" -o "/tmp/${ELIXIR_ZIP}" \
 && curl -fsSL "https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/${ELIXIR_ZIP}.sha256sum" -o "/tmp/${ELIXIR_ZIP}.sha256sum" \
 && (cd /tmp && sha256sum --check "${ELIXIR_ZIP}.sha256sum") \
 && unzip -q "/tmp/${ELIXIR_ZIP}" -d /usr/local \
 && ln -sf /usr/local/elixir-otp-28/bin/* /usr/local/bin/ \
 && rm -f "/tmp/${ELIXIR_ZIP}" "/tmp/${ELIXIR_ZIP}.sha256sum"

# Install extra utilities
#RUN dnf module enable --assumeyes postgresql:12 \
# && dnf install --assumeyes postgresql \
# && dnf update \
# && dnf clean all \
# && rm -rf /var/cache/dnf /var/cache/yum \
# && update-ca-trust extract

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
COPY --chown=docker:docker scripts /app/scripts
RUN cd assets && npm install

COPY --chown=docker:docker config /app/config
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

CMD [ "./scripts/start-in-docker.sh" ]
