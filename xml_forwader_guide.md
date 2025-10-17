# XML Forwarder HTTP Installation Guide

## 1. Requirements
- Linux system with Python 3 installed
- Root or sudo access

Check Python version:
    python3 --version

## 2. Create a dedicated user
It is recommended to run the service under a dedicated system account:

    sudo useradd --system --no-create-home --shell /usr/sbin/nologin xmlproxy
    sudo mkdir -p /var/log/xml_forwarder
    sudo chown xmlproxy:xmlproxy /var/log/xml_forwarder

## 3. Install the script
Save the xml_forwarder_http.py script into /usr/local/bin:

    sudo nano /usr/local/bin/xml_forwarder_http.py

Paste the script code, then run:

    sudo chmod +x /usr/local/bin/xml_forwarder_http.py
    sudo chown root:root /usr/local/bin/xml_forwarder_http.py

## 4. Create a systemd service
Create a unit file at /etc/systemd/system/xml-forwarder-http.service:

    sudo nano /etc/systemd/system/xml-forwarder-http.service

Paste this content:

    [Unit]
    Description=XML Forwarder HTTP (listen 7070 -> forward 7071, \0 separator)
    After=network.target

    [Service]
    Type=simple
    User=xmlproxy
    Group=xmlproxy
    ExecStart=/usr/bin/python3 /usr/local/bin/xml_forwarder_http.py
    Restart=always
    RestartSec=3

    [Install]
    WantedBy=multi-user.target

## 5. Enable and start the service
Reload systemd, enable and start the service:

    sudo systemctl daemon-reload
    sudo systemctl enable xml-forwarder-http.service
    sudo systemctl start xml-forwarder-http.service

Check status:

    systemctl status xml-forwarder-http.service --no-pager -l

## 6. Test it
1. Open a listener on port 7071:

       nc -l 7071

2. Send a test POST request with two events separated by \0:

       curl -X POST http://localhost:7070 -d $'TestEvent1\0TestEvent2'

Expected result on port 7071:

       TestEvent1
       TestEvent2

## 7. Logs
Logs are written to:

    /var/log/xml_forwarder/xml_forwarder_http.log

To watch logs:

    tail -f /var/log/xml_forwarder/xml_forwarder_http.log

## 8. Firewall
If events will be sent from other machines, allow port 7070:

Ubuntu/Debian:

    sudo ufw allow 7070/tcp

CentOS/RHEL:

    sudo firewall-cmd --add-port=7070/tcp --permanent
    sudo firewall-cmd --reload
