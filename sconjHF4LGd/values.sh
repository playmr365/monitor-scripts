#!/bin/bash
HOSTNAME="$(hostname) ($(curl -4 icanhazip.com))"   #Definice tvoření hostname
SERVICES=("haproxy" "httpd" "zabbix-agent2")        #Definice služeb k monitoringu
ALERT_DISK="5"                                      #Definice při kolika GB bude chodit alert
LE_EXPIRE="20"                                      #Kolik dní do expirace certifikátu notifikovat
RAM_MIN="2048"                                      #Při kolika Mb volné RAM notifikovat
NTFY_SERVER="https://test.ntfy.cz/test"             #Na jakou URL volat notifikace do NTFY
