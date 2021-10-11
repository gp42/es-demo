#!/usr/bin/env bash

# Allow to inject extra Elasticsearch parameters with environment variables
# in the floowing format:
#   ESCONF_PARAMETER___NAME=value
# this will be converted to:
#   parameter.name=value
declare -a es_opts
while IFS='=' read -r envvar_key envvar_value
do
  if [[ "$envvar_key" =~ ^ESCONF_[a-z0-9_]+ ]]; then
    if [[ ! -z $envvar_value ]]; then
      key="${envvar_key#ESCONF_}"
      key="${key//__/.}"
      es_opt="-E${key,,}=${envvar_value}"
      es_opts+=("${es_opt}")
    fi
  fi
done < <(env)

#until [ -f "/tmp/foo" ]; do
#  sleep 5
#done

if [ "$BOOTSTRAP_CLUSTER" = "true" ]; then
  echo "BOOTSTRAP_CLUSTER is set to 'true'. Bootstrapping cluster..."
  es_opts+=("-Ecluster.initial_master_nodes=${HOSTNAME}")
fi

if [ -f "/var/run/secrets/elasticsearch/secret.env" ]; then
  echo "Setting up Elastic passwords..."
  
  . /var/run/secrets/elasticsearch/secret.env
  . /var/run/secrets/elasticsearch/kibana.env

  printf "%s" "$ELASTIC_PASSWORD" |\
    /usr/share/elasticsearch/bin/elasticsearch-keystore add "bootstrap.password"

  /usr/share/elasticsearch/bin/elasticsearch-keystore has-passwd > /dev/null ||\
    printf "%s\n%s" "$KEYSTORE_PASSWORD" "$KEYSTORE_PASSWORD" |\
      /usr/share/elasticsearch/bin/elasticsearch-keystore passwd

  /usr/share/elasticsearch/bin/elasticsearch-users useradd "$KIBANA_USER" \
    -p "$KIBANA_PASSWORD" \
    -r kibana_system
fi

exec chroot --userspec=elasticsearch:elasticsearch / /usr/share/elasticsearch/bin/elasticsearch "${es_opts[@]}" <<<"$KEYSTORE_PASSWORD"
