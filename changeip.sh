cat > change_openwrt_ip_termux.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Termux → OpenWRT LAN IP change automation (test version)

ROUTER_USER="root"
OLD_IP="192.168.1.1"
NEW_IP="192.168.50.1"
ROUTER_SCRIPT_PATH="/root/change_gateway.sh"

echo "Enter router password for $ROUTER_USER@$OLD_IP:"
read -s ROUTER_PASS

echo "[1/5] Creating remote script..."
cat > /tmp/change_gateway.sh <<INNER
#!/bin/sh
OLD_IP="$OLD_IP"
NEW_IP="$NEW_IP"
INTERFACE="lan"

echo "Changing LAN IP from \$OLD_IP to \$NEW_IP..."
uci set network.\$INTERFACE.ipaddr="\$NEW_IP"
uci commit network
/etc/init.d/network restart
echo "Done! LAN IP is now \$NEW_IP"
INNER
chmod +x /tmp/change_gateway.sh

echo "[2/5] Uploading script to router..."
sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no /tmp/change_gateway.sh ${ROUTER_USER}@${OLD_IP}:${ROUTER_SCRIPT_PATH}

if [ $? -ne 0 ]; then
  echo "❌ Upload failed. Check Wi-Fi or SSH access."
  exit 1
fi

echo "[3/5] Executing script remotely..."
sshpass -p "$ROUTER_PASS" ssh -o StrictHostKeyChecking=no ${ROUTER_USER}@${OLD_IP} "sh ${ROUTER_SCRIPT_PATH}"

echo "[4/5] Waiting 30 seconds for router to restart..."
sleep 30

echo "[5/5] Testing new IP..."
ping -c 2 ${NEW_IP} > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Success! Router IP is now ${NEW_IP}"
else
  echo "⚠️ Could not reach ${NEW_IP}. Try reconnecting Wi-Fi."
fi
EOF
