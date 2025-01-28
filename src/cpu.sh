#!/bin/bash
source /opt/monitor-slama/values.sh
# Hranice vytížení CPU pro upozornění (v procentech)
cpu_threshold=70

# Získání aktuálního vytížení CPU pomocí top
cpu_idle=$(mpstat | grep -oE '[0-9]+\.[0-9]+' |tail -1)
cpu_usage=$(echo "100 - $cpu_idle" | bc)
# Porovnání s hranicí
if (( $(echo "$cpu_usage > $cpu_threshold" | bc -l) )); then
curl -d "CPU Utlilization is ${cpu_usage}% on server ${HOSTNAME}" $NTFY_SERVER
#e lse
fi

