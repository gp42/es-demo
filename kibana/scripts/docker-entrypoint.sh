#!/usr/bin/env bash

DEFAULT_CONFIG="${DEFAULT_CONFIG:-/etc/kibana/kibana.yml}"
EXTRA_CONFIGS="$(awk -vRS=',' '{if ($0 != "\n") printf " -c %s", $0 }' <<< "$EXTRA_CONFIGS")"

exec chroot --userspec=kibana:kibana / /usr/share/kibana/bin/kibana -c "$DEFAULT_CONFIG" $EXTRA_CONFIGS
