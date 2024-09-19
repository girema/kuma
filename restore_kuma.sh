#!/bin/bash

# Replace <ip_kuma> and <token> with your KUMA IP address and user API token information:
curl -k --request POST 'https://<ip_kuma>:7223/api/v1/system/restore' --header 'Authorization: Bearer <token>'  --data-binary '/opt/kaspersky/kuma/backup/backup.tar.gz'
