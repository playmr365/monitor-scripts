#!/bin/bash

# Vytvoření složky pro monitorování a přesun skriptů
mkdir /monitors
# Získání adresáře, kde se nachází tento skript
SCRIPT_DIR=$(dirname "$(realpath "$0")")
# Přechod do tohoto adresáře
cd "$SCRIPT_DIR" || exit 1
mv src/* /monitors/
chmod +x /monitors/*.sh
rm -rf src
source ./setup.sh

# Funkce pro přidání skriptu do crontabu
add_to_crontab() {
    script_name="$1"
    schedule="$2"
    cron_entry="$schedule /monitors/$script_name.sh >/dev/null 2>&1"
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
}

# Funkce pro zapsání výběru serveru do souboru values.sh
# Funkce pro zapsání serverového typu a služeb do values.sh
set_server_type() {
    echo "Vyberte typ serveru:"
    echo "a) Web server"
    echo "b) Mail server"
    echo "c) PMG"
    echo "d) Full stack"
    echo "e) Other"
    read -p "Zadejte volbu (a, b, c, d, e): " server_type

    case $server_type in
        a)  # Web server
            SERVER_TYPE="web"
            SERVICES=("httpd" "haproxy" "zabbix-agent2")
            ;;
        b)  # Mail server
            SERVER_TYPE="mail"
            SERVICES=("postfix" "dovecot" "haproxy" "zabbix-agent2")
            ;;
        c)  # PMG
            SERVER_TYPE="pmg"
            SERVICES=("pmgdaemon" "pmgproxy" "zabbix-agent2")
            ;;
        d)  # Full stack
            SERVER_TYPE="fullstack"
            SERVICES=("httpd" "haproxy" "postfix" "dovecot" "zabbix-agent2")
            ;;
        e)  # Other
            SERVER_TYPE="other"
            SERVICES=()
            ;;
        *)
            echo "Neplatná volba, nebude monitorováno nic."
            SERVER_TYPE="other"
            SERVICES=()
            ;;
    esac


        # Zapsání vybraného typu serveru a služeb do values.sh s uvozovkami kolem názvů služeb
        echo "SERVER_TYPE=\"$SERVER_TYPE\"" > /monitors/values.sh

        # Explicitní zápis služeb s uvozovkami
        echo -n "SERVICES=(" >> /monitors/values.sh
        for service in "${SERVICES[@]}"; do
        echo -n "\"$service\" " >> /monitors/values.sh
        done
        echo ")" >> /monitors/values.sh

}


# Funkce pro kontrolu stavu Zabbix agenta přes systemctl
check_zabbix_agent_version() {
    # Kontrola, zda je nainstalovaný Zabbix agent (verze 1 nebo 2)
    systemctl list-units --type=service | grep -E "zabbix-agent|zabbix-agent2" >/dev/null 2>&1
    zabbix_status=$?

    if [[ $zabbix_status -eq 0 ]]; then
        # Zjištění, zda je aktivní Zabbix agent nebo Zabbix agent 2
        if systemctl is-active --quiet zabbix-agent; then
            echo "Zabbix agent verze 1 je aktivní."
            ZABBIX_AGENT_VERSION="v1"
        elif systemctl is-active --quiet zabbix-agent2; then
            echo "Zabbix agent verze 2 je aktivní."
            ZABBIX_AGENT_VERSION="v2"
        else
            echo "Zabbix agent (verze 1 nebo 2) je nainstalován, ale není aktivní."
            ZABBIX_AGENT_VERSION="inactive"
        fi
    else
        echo "Zabbix agent (verze 1 nebo 2) není nainstalován."
        ZABBIX_AGENT_VERSION="not_installed"
    fi
}



# Funkce pro zapsání NTfy serveru do values.sh
set_ntfy_server() {
    read -p "Zadejte URL pro NTfy server (např. http://ntfy.server.com): " ntfy_server
    echo "NTFY_SERVER=\"$ntfy_server\"" >> /monitors/values.sh
}

# Zapsání serverového typu a služeb do values.sh
set_server_type

# Kontrola verze Zabbix agenta
check_zabbix_agent_version

# Zápis NTfy serveru do values.sh
set_ntfy_server

# Výběr služeb na základě volby
echo "Služby, které budou monitorovány: ${SERVICES[@]}"

# Přidání skriptů do crontabu na základě hodnot
[ "$APP" == "true" ] && add_to_crontab "app" "* * * * *" && echo "Monitoring aplikací byl zapnut"
[ "$RAM" == "true" ] && add_to_crontab "ram" "* * * * *" && echo "Monitoring RAM byl zapnut"
[ "$CPU" == "true" ] && add_to_crontab "cpu" "* * * * *" && echo "Monitoring CPU byl zapnut"
[ "$DISK" == "true" ] && add_to_crontab "disk" "* * * * *" && echo "Monitoring disku byl zapnut"
[ "$LE" == "true" ] && add_to_crontab "LECheck" "0 0 * * *" && echo "Monitoring LE certifikátu byl zapnut"

# Nastavení crontabu zapnuto
echo "Nastavení crontabu zapnuto"
