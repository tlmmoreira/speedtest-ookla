#!/bin/bash
clear
echo "============================================"
echo " INSTALAÇÃO – OOKLA SPEEDTEST"
echo " Debian 11 Bullseye"
echo "============================================"
echo ""

read -p "Digite seu e-mail para o Certbot: " email
read -p "Digite o domínio (ex: seudominio.com.br): " dominio

echo ""
echo "CONFIRMANDO:"
echo "Email: $email"
echo "Subdomínio: $dominio"
echo ""

read -p "Os dados estão corretos? (s/n): " ok
[[ "$ok" != "s" ]] && echo "Cancelado!" && exit 1

apt update -y
apt install -y vim wget unzip net-tools psmisc curl

cat >> /etc/sysctl.conf <<EOF

vm.swappiness = 5
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
net.core.somaxconn = 65535
net.ipv4.tcp_mem = 4096 87380 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 15
net.core.netdev_max_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

sysctl -p

for module in tcp_illinois tcp_westwood tcp_htcp; do
    modprobe -a $module
    echo "$module" >> /etc/modules
done

mkdir -p /usr/local/src/ooklaserver
cd /usr/local/src/ooklaserver

wget https://install.speedtest.net/ooklaserver/ooklaserver.sh
chmod +x ooklaserver.sh
./ooklaserver.sh install <<< "y"

./ooklaserver.sh stop || killall -9 OoklaServer

cat > /usr/local/src/ooklaserver/OoklaServer.properties <<EOF
#
# This is a sample configuration file for OoklaServer
#

#
# OoklaServer Options
#

# The server listens to TCP port 5060 and 8080 by default. These ports are required for
# speedtest.net servers, although more can be added.
#
# For Speedtest Custom, this can be changed to other ports if desired; you will need to
# contact support to update your server record.
#
# At least one port is required for this setting.
#
OoklaServer.tcpPorts = 5060,8080

# The server listens to UDP port 5060 and 8080 by default. These ports are required for
# speedtest.net servers, although more can be added.
#
# For Speedtest Custom, this can be changed to other ports if desired; you will need to
# contact support to update your server record.
#
# At least one port is required for this setting.
#
OoklaServer.udpPorts = 5060,8080

# Bind OoklaServer to IPv6
#
OoklaServer.useIPv6 = true

# OoklaServer.allowedDomains allows you to limit access to your OoklaServer.
#
# The default ("*") allows all domains access.
# Uncomment to allow access from ookla.com, speedtest.net, and simply add your
# own domain(s):
#
# OoklaServer.allowedDomains = *.ookla.com, *.speedtest.net
OoklaServer.allowedDomains = *.ookla.com, *.speedtest.net, *.$dominio

# Uncomment this to enable filtering of known bad user agents. This can help alleviate traffic
# from non-official client sources.
#
# OoklaServer.userAgentFilterEnabled = true
OoklaServer.userAgentFilterEnabled = true

# Max size of worker thread pool. Might be smaller if the number of open files allows
# is smaller (i.e it is at most `ulimit -n -H`). 
#
# OoklaServer.workerThreadPool.capacity = 30000
OoklaServer.workerThreadPool.capacity = 30000

# Thread stack size for worker threads.
#
# OoklaServer.workerThreadPool.stackSizeBytes = 102400

# Enable auto updates (default)
#
# OoklaServer.enableAutoUpdate = true

#####
# IP Tracking / Blocking settings
#####
# Time between garbage collecting ip statistics.
#
# OoklaServer.ipTracking.gcIntervalMinutes = 5

# Max amount of time to keep statistics for a specific ip address after its last connection was recorded.
#
# OoklaServer.ipTracking.maxIdleAgeMinutes = 35
OoklaServer.ipTracking.maxIdleAgeMinutes = 35

# Size in minutes of the buckets used to collect ip statistics. This is used to keep a 
# sliding window of statistics for an ip when accumulating data. Max number of
# buckets is maxIdleAgeMinutes / slidingWindowBucketLengthMinutes. 

# OoklaServer.ipTracking.slidingWindowBucketLengthMinutes = 5

# Number of ip's to include when upload metrics.
#
# OoklaServer.ipTracking.metricTopIpCount = 5
#

# Max concurrent connections allowed for a single ip address. The actual number 
# is at least 50, and at most 10% of OoklaServer.workerThreadPool.capacity.
#
# OoklaServer.ipTracking.maxConnPerIp = 500
OoklaServer.ipTracking.maxConnPerIp = 5

# Max connection attempts in a bucket (duration defined above) allowed for a single ip address. The minimum value is
# 200 connections per minute (variable depending on bucket duration).
# When the next bucket is created, the count is reset and connections are allowed again.
#
# OoklaServer.ipTracking.maxConnPerBucketPerIp = 20000
OoklaServer.ipTracking.maxConnPerBucketPerIp = 10

# When set to true requests with an invalid or expired client authentication token are denied.
# Legacy and third-party clients that don't send a token at all will continue to work properly.
OoklaServer.clientAuthToken.denyInvalid = true

# Frame size limit for websocket connections. This is the maximum size of a websocket frame that
# OoklaServer will accept. The default is 5MB. This should be set to a value that is large enough
# for testing, yet small enough to prevent malicious clients from sending large frames that could
# cause the server to run out of memory.
#
# OoklaServer.websocket.frameSizeLimitBytes = 5242880
OoklaServer.websocket.frameSizeLimitBytes = 5242880

# Maximum size of all headers in bytes for HTTP(S) requests. Lowers the risk of someone exploiting large requests
# to make the server run out of memory. This limit doesn't include the URL itself.
#
# OoklaServer.http.maxHeadersSize = 65536

# SSL Options
#

# Enable Let's Encrypt certificate generation (default)
#
# OoklaServer.ssl.useLetsEncrypt = true

# To use a custom certificate, create a certificate and private key and set the path to them here:
# (Note, this will disable Let's Encrypt certificate generation)
# openSSL.server.certificateFile = cert.pem
# openSSL.server.privateKeyFile = key.pem

# openSSL.server.certificateFile = cert.pem
# openSSL.server.privateKeyFile = key.pem

openSSL.server.certificateFile = /etc/letsencrypt/live/velocidade.$dominio/fullchain.pem
openSSL.server.privateKeyFile = /etc/letsencrypt/live/velocidade.$dominio/privkey.pem

# Restrict openssl server to TLSv1.2 and above
# Options are 1.3, 1.2 (default), 1.1, and 1.0
openSSL.server.minimumTLSProtocol = 1.2

#
# Logging Options
#

# Log to the Console
#
logging.loggers.app.name = Application
logging.loggers.app.channel.class = ConsoleChannel
logging.loggers.app.channel.pattern = %Y-%m-%d %H:%M:%S [%P - %I] [%p] %t
logging.loggers.app.level = information

# Log to files
# See https://docs.pocoproject.org/current/Poco.FileChannel.html for information about FileChannel settings.
# Set rotation to "never" to disable default log rotation. Note that log rotation settings are only supported
# when using the FileChannel class.
#
#logging.loggers.app.name = Application
#logging.loggers.app.channel.class = FileChannel
#logging.loggers.app.channel.pattern = %Y-%m-%d %H:%M:%S [%P - %I] [%p] %t
#logging.loggers.app.channel.path = ${application.dir}/ooklaserver.log
#logging.loggers.app.level = information
#logging.loggers.app.channel.rotation = 10M
#logging.loggers.app.channel.archive = timestamp
#logging.loggers.app.channel.compress = true
#logging.loggers.app.channel.purgeCount = 10

#
# Optional access log for HTTP and Websocket requests
#
# logging.loggers.access.name = AccessLog
# logging.loggers.access.channel.class = FileChannel
# logging.loggers.access.channel.pattern = %[client] - %[session] [%d/%b/%Y:%H:%M:%S %Z] "%t" %[status] %[size] "%[referer]" "%[useragent]"
# logging.loggers.access.channel.path = ${application.dir}/ooklaserver-access.log
# logging.loggers.access.channel.rotation = 10M
# logging.loggers.access.channel.archive = timestamp
# logging.loggers.access.channel.compress = true
# logging.loggers.access.channel.purgeCount = 5

EOF

cp /usr/local/src/ooklaserver/OoklaServer.properties /usr/local/src/ooklaserver/OoklaServer.properties.default

cat > /lib/systemd/system/ooklaserver.service <<EOF
[Unit]
Description=OoklaServer-SpeedTest
After=network.target

[Service]
User=root
Group=root
Type=simple
RemainAfterExit=yes

WorkingDirectory=/usr/local/src/ooklaserver
ExecStart=/usr/local/src/ooklaserver/ooklaserver.sh start
ExecReload=/usr/local/src/ooklaserver/ooklaserver.sh restart
ExecStop=/usr/bin/killall -9 OoklaServer

TimeoutStartSec=60
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
Alias=speedtest.service
EOF

systemctl daemon-reload
systemctl enable ooklaserver

apt install -y certbot

certbot certonly --standalone -d $dominio -m $email --agree-tos --no-eff-email --non-interactive

systemctl restart ooklaserver

cat > /usr/local/src/ooklaserver/renova-certificado <<EOF
#!/bin/bash
/usr/bin/certbot renew -q
sleep 30
/usr/bin/systemctl restart ooklaserver
EOF

chmod +x /usr/local/src/ooklaserver/renova-certificado

echo "00 00   1 * *   root    /usr/local/src/ooklaserver/renova-certificado" >> /etc/crontab

systemctl restart cron

echo ""
echo "============================================"
echo " INSTALAÇÃO CONCLUÍDA!"
echo " Acesse: https://$dominio"
echo "============================================"
