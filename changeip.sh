#!/data/data/com.termux/files/usr/bin/bash
# Termux → OpenWRT LAN IP change automation (test version)

ROUTER_USER="root"
ROUTER_PASS="Hewl/jel1"
OLD_IP="192.168.1.1"
NEW_IP="192.168.50.1"
ROUTER_SCRIPT_PATH="/root/change_gateway.sh"

echo "[Pre-check] Verifying WiFi connection and gateway..."

# Check if connected to WiFi
WIFI_STATUS=$(termux-wifi-connectioninfo 2>/dev/null | grep -o '"supplicant_state":"COMPLETED"')
if [ -z "$WIFI_STATUS" ]; then
  echo "❌ Not connected to WiFi. Please connect to your router's WiFi first."
  exit 1
fi

# Check default gateway
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
if [ -z "$GATEWAY" ]; then
  echo "❌ No default gateway found. Check your network connection."
  exit 1
fi

if [ "$GATEWAY" != "$OLD_IP" ]; then
  echo "❌ Default gateway is $GATEWAY, but expected $OLD_IP"
  echo "   Please connect to the router with IP $OLD_IP"
  exit 1
fi

echo "✅ Connected to WiFi with gateway $GATEWAY"

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