#!/bin/bash
source /monitors/values.sh
# Získání dostupné paměti v MB pomocí /proc/meminfo
available_memory=$(awk '/MemAvailable/ {print $2 / 1024}' /proc/meminfo)
# Porovnání s hranicí
if (( $(echo "$available_memory > $RAM_MIN" | bc -l) )); then
    echo "ok"   
else
curl -d "free RAM is: ${available_memory}MB which is under monitored value ${RAM_MIN}MB on server ${HOSTNAME}" $NTFY_SERVER
fi

