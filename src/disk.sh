#!/bin/bash

# Načtení hodnot ze souboru
source /opt/monitor-slama/values.sh

# Funkce pro získání celkové a volné kapacity disku (v GB)
get_disk_info() {
    mountpoint=$1
    total_space=$(df -B1G "$mountpoint" | awk 'NR==2 {print $2}') # Celková kapacita
    free_space=$(df -B1G "$mountpoint" | awk 'NR==2 {print $4}') # Volné místo
    echo "$total_space $free_space"
}

# Funkce pro kontrolu volného místa na konkrétním mountpointu
check_disk_space() {
    mountpoint=$1
    total_space=$(echo "$2" | awk '{print $1}')
    free_space=$(echo "$2" | awk '{print $2}')

    # Pokud je custom hodnota nastavena, použij ji. Jinak vypočítej 10 %.
    if [[ "$mountpoint" == "/" && -n "$ALERT_DISK_ROOT" ]]; then
        min_space=$ALERT_DISK_ROOT
    elif [[ "$mountpoint" == "/data" && -n "$ALERT_DISK_DATA" ]]; then
        min_space=$ALERT_DISK_DATA
    else
        min_space=$((total_space / 10)) # 10 % z celkové kapacity
    fi

    # Kontrola volného místa
    if [ "$free_space" -ge "$min_space" ]; then
        echo "OK: $mountpoint má $free_space GB volného místa (min $min_space GB)"
    else
        curl -d "Free space on $mountpoint is: ${free_space}GB, which is below the monitored value: ${min_space}GB on server ${HOSTNAME}" "$NTFY_SERVER"
    fi
}

# Iterace přes všechny reálné disky
df -T | awk '$2 ~ /^(ext4|xfs|btrfs)$/' | while read -r line; do
    mountpoint=$(echo "$line" | awk '{print $NF}')
    disk_info=$(get_disk_info "$mountpoint")

    # Kontrola volného místa na aktuálním mountpointu
    check_disk_space "$mountpoint" "$disk_info"
done
