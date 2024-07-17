#!/bin/bash

#formát hostnamu uvedeného ve zprávě
HOSTNAME="$(hostname) ($(curl -4 icanhazip.com))"

#Určení služeb k monitoringu běhu
SERVICES=("haproxy" "httpd" "zabbix-agent2")

#počet GB kdy začne posílat hlášky
ALERT_DISK="5"
#počet dní do expirace LE certu
LE_EXPIRE="20"
#množstvý ram v MB do posílání hlášek
RAM_MIN="2048" # 2GB
#Odkaz na ntfy server
NTFY_SERVER=""

#zapnutí jednotlivích částí monitoringu
APP="true"
RAM="true"
CPU="true"
DISK="true"
LE="true"
