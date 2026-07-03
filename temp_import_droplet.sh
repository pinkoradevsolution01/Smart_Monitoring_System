#!/bin/bash
set -e
sed -i "s/DEFAULT uuid()/DEFAULT (uuid())/g" /tmp/smart_monitoring.sql
mysql -u root -e "DROP DATABASE IF EXISTS smart_monitoring; CREATE DATABASE smart_monitoring;"
mysql -u root smart_monitoring < /tmp/smart_monitoring.sql
echo IMPORT_OK
