#!/bin/bash
HOSTNAME="$(hostname) ($(curl -4 icanhazip.com))"
SERVICES=("haproxy" "httpd" "zabbix-agent2")
ALERT_DISK="5"
LE_EXPIRE="20"
RAM_MIN="2048" # 2GB
NTFY_SERVER="https://ntfy.slamaci.eu/servery"
