#!/bin/bash
source /monitors/values.sh

# Získání dostupné paměti v MB pomocí /proc/meminfo
available_memory=$(awk '/MemAvailable/ {print $2 / 1024}' /proc/meminfo)

# Pokud je definováno custom RAM_MIN, použije se ta hodnota
if [ -z "$RAM_MIN" ]; then
    RAM_MIN=1024  # Pokud není definováno, použije se výchozí hodnota (například 1024MB)
fi

# Vypočítání 20% z celkové RAM
total_memory=$(awk '/MemTotal/ {print $2 / 1024}' /proc/meminfo)
ram_threshold=$(echo "$total_memory * 0.2" | bc)

# Porovnání s hranicí (buď minimální hodnota nebo 20% dostupné RAM)
if (( $(echo "$available_memory > $RAM_MIN" | bc -l) )) && (( $(echo "$available_memory > $ram_threshold" | bc -l) )); then
    echo "ok"   
else
    curl -d "free RAM is: ${available_memory}MB which is under monitored value ${RAM_MIN}MB or 20% threshold (${ram_threshold}MB) on server ${HOSTNAME}" $NTFY_SERVER
fi
