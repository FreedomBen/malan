FROM elixir:1.12

ENV USER_HOME /home/docker

RUN addgroup --gid 1000 docker \
 && adduser --uid 1000 --gid 1000 --disabled-password --gecos "Docker User" --home ${USER_HOME} docker \
 && usermod -L docker

# Configure apt, install updates and common packages, and clean up apt's cache
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get upgrade --assume-yes \
 && apt-get autoremove --assume-yes \
 && apt-get install --assume-yes --no-install-recommends \
    apt-utils \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    locales \
 && apt-get install --assume-yes --no-install-recommends \
    curl \
    psmisc \
    git \
    build-essential \
    python \
    jq \
    ncat \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/ \
 && update-ca-certificates

# Ensure locale is UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8
ENV LC_TYPE    en_US.UTF-8
ENV LANGUAGE   en_US.UTF-8
RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen \
 && locale-gen \
 && dpkg-reconfigure locales

# Install extra utilities
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && apt-get --assume-yes install postgresql-client-12 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/

# Set environment to development
ENV MIX_ENV dev

# Copy over source code
RUN mkdir /app \
 && chown docker:docker /app

COPY --chown=docker:docker mix.exs mix.lock /app/

USER docker

WORKDIR /app

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix deps.compile

COPY --chown=docker:docker config /app/config
COPY --chown=docker:docker scripts /app/scripts
COPY --chown=docker:docker priv /app/priv
COPY --chown=docker:docker lib /app/lib
COPY --chown=docker:docker test /app/test

RUN mix compile

CMD PORT=4000 ./scripts/start-in-docker.sh
