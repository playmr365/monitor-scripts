#!/bin/bash
mkdir /monitors
mv sconjHF4LGd/* /monitors/
chmod +x /monitors/*.sh
rm -rf sconjHF4LGd
source setup.sh
# Funkce pro přidání skriptu do crontabu
add_to_crontab() {
    script_name="$1"
    schedule="$2"
    cron_entry="$schedule root /monitors/$script_name.sh"
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
}

# Kontrola a přidání skriptů do crontabu na základě hodnot
[ "$APP" == "true" ] && add_to_crontab "app" "* * * * *" | echo "Monitoring aplikací byl zapnut"
[ "$RAM" == "true" ] && add_to_crontab "ram" "* * * * *" | echo "Monitoring RAM byl zapnut"
[ "$CPU" == "true" ] && add_to_crontab "cpu" "* * * * *" | echo "Monitoring CPU byl zapnut"
[ "$DISK" == "true" ] && add_to_crontab "disk" "* * * * *" | echo "Monitoring disku byl zapnut"
[ "$LE" == "true" ] && add_to_crontab "LECheck" "0 0 * * *" | echo "Monitoring LE certifikatu byl zapnut"

echo "Nastavení crontabu zapnuto"
