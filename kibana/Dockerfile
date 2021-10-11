FROM debian:10-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008,DL3009
RUN apt-get update &&\
  apt-get install -y --no-install-recommends \
    wget \
    gnupg2 \
    apt-transport-https \
    apt-utils \
    curl \
    ca-certificates

# hadolint ignore=DL3009
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - &&\ 
  echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" |  tee /etc/apt/sources.list.d/elastic-7.x.list &&\
    apt-get update &&\ 
      apt-get install -y --no-install-recommends "kibana=7.15.0"

# cleanup
RUN apt-get remove -y \
    wget \
    gnupg2 \
    apt-transport-https &&\
      apt-get clean &&\
        rm -rf /var/lib/apt/lists/*

COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod ug+x /usr/local/bin/docker-entrypoint.sh &&\
    chmod a-wx /etc/kibana/* &&\
    mkdir -p /var/log/kibana &&\
    chown kibana \
      /etc/kibana \
      /usr/local/bin/docker-entrypoint.sh \
      /var/log/kibana &&\
    usermod -d /usr/share/kibana kibana &&\
      cp /etc/skel/.bashrc /usr/share/kibana/.bash_profile

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
