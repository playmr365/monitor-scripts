#!/bin/bash
HOSTNAME="$(hostname) ($(curl -4 icanhazip.com))"   #Definice tvoření hostname
ALERT_DISK_ROOT=""                                  # Custom hodnota pro /
ALERT_DISK_DATA=""                                  # Custom hodnota pro /data
LE_EXPIRE="20"                                      #Kolik dní do expirace certifikátu notifikovat
RAM_MIN=""                                      #Při kolika Mb volné RAM notifikovat
NTFY_SERVER="https://test.ntfy.cz/test"             #Na jakou URL volat notifikace do NTFY
