#!/bin/bash
clear
echo "============================================"
echo " INSTALAÇÃO – OOKLA SPEEDTEST"
echo " Debian 11 Bullseye"
echo "============================================"
echo ""

read -p "Digite seu e-mail para o Certbot: " email
read -p "Digite o domínio (ex: seudominio.com.br): " dominio
read -p "Digite o subdomínio (ex: velocidade.dominio.com.br): " subdominio

echo ""
echo "CONFIRMANDO:"
echo "Email: $email"
echo "domínio: $dominio"
echo "subdomínio: $subdominio"
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
OoklaServer.tcpPorts = 5060,8080
OoklaServer.udpPorts = 5060,8080
OoklaServer.useIPv6 = true

OoklaServer.allowedDomains = *.ookla.com, *.speedtest.net, *.$dominio

OoklaServer.userAgentFilterEnabled = true
OoklaServer.workerThreadPool.capacity = 30000
OoklaServer.ipTracking.maxIdleAgeMinutes = 35
OoklaServer.ipTracking.maxConnPerIp = 5
OoklaServer.ipTracking.maxConnPerBucketPerIp = 10
OoklaServer.clientAuthToken.denyInvalid = true
OoklaServer.websocket.frameSizeLimitBytes = 5242880

openSSL.server.certificateFile = /etc/letsencrypt/live/$subdominio/fullchain.pem
openSSL.server.privateKeyFile = /etc/letsencrypt/live/$subdominio/privkey.pem

openSSL.server.minimumTLSProtocol = 1.2

logging.loggers.app.name = Application
logging.loggers.app.channel.class = ConsoleChannel
logging.loggers.app.channel.pattern = %Y-%m-%d %H:%M:%S [%P - %I] [%p] %t
logging.loggers.app.level = information
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

certbot certonly --standalone -d $subdominio -m $email --agree-tos --no-eff-email --non-interactive

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
echo " Acesse: https://$subdominio:8080"
echo "============================================"

