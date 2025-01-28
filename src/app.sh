#!/bin/bash
source /monitors/values.sh
for service_name in "${SERVICES[@]}"; do
    if systemctl is-failed --quiet "$service_name"; then
        curl -d "application ${service_name} is down on server {$HOSTNAME}" $NTFY_SERVER
    fi
done

