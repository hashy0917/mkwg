#!/bin/bash

#ROOTユーザーか確認
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

#mkwgの存在を確認
if [[ ! -e /etc/wireguard/mkwg ]]; then
  echo "mkwg is missing"
  echo "Please run initwg script"
  exit 1
fi

#第一引数が数字か確認
expr "$1" + 1 >/dev/null 2>&1
if [ $? -ge 2 ]; then
  echo "Please specify an integer for the first argument"
  exit 1
fi

#鍵があるか確認
if [[ ! -f /etc/wireguard/mkwg/wg$1server.key ]]; then
  echo "wg$1server.key is missing"
  echo "Please run initwg script"
  exit 1 
fi

#サーバー設定ファイルがある事を確認
if [[ ! -f /etc/wireguard/wg$1.conf ]]; then
  echo "wg$1.conf is missing"
  echo "Please run initwg script"
  exit 1
fi

#クライアント鍵の作成(使い捨て)
wg genkey | tee /etc/wireguard/mkwg/client.key
cat /etc/wireguard/mkwg/client.key | wg pubkey | tee /etc/wireguard/mkwg/client.pub

#サーバー設定ファイル内からClientNUMの取得
grep '#clientNUM' /etc/wireguard/wg$1.conf > /dev/null
if [[ $? -eq 1 ]]; then
  NUM=0
else
  NUM=$(cat /etc/wireguard/wg0.conf | awk '/#clientNUM/ {print $2}' | tail -n 1)
fi

cat << EOT >> /etc/wireguard/wg$1.conf

[Peer]
#clientNUM `echo $(( $NUM + 1 ))`
AllowedIPs = 10.0.25.`echo $(( $NUM + 2 ))`/32
PublicKey = `cat /etc/wireguard/mkwg/client.pub`
EOT

#クライアント側設定ファイルの生成
cat << EOT >> /etc/wireguard/mkwg/mkwg_client$(( NUM + 1 )).conf 
[Peer]
AllowedIPs = 0.0.0.0/0
EndPoint = `curl https://ifconfig.me`:51820
PublicKey = `cat /etc/wireguard/mkwg/wg$1server.pub`

[Interface]
Address = 10.0.25.`echo $(( $NUM + 2 ))`/32
PrivateKey = `cat /etc/wireguard/mkwg/client.key`
EOT

# systemdでwireguardを再起動
systemctl restart wg-quick@wg$1

echo "done!!"
cat /etc/wireguard/mkwg/mkwg_client$(( NUM + 1 )).conf
exit 0
