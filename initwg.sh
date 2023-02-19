#!/bin/bash

#ROOTユーザーか確認
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

#第一引数が数字か確認
expr "$1" + 1 >/dev/null 2>&1
if [ $? -ge 2 ]; then
  echo "Please specify an integer for the first argument"
  exit 1
fi

#mkwgの存在を確認
if [[ ! -e /etc/wireguard/mkwg ]]; then
  # ついでにwireguardをインストールする
  apt update
  apt install -y wireguard
  # 無ければ作る
  mkdir /etc/wireguard/mkwg
else
  echo "skip install wireguard"
fi

#ポートの開放(UFW)
ufw allow 51820/udp

#IPフォワードの設定
grep 'net.ipv4.ip_forward=1' /etc/sysctl.conf | grep -v '^#.*' > /dev/null
if [[ $? -eq 1 ]]; then
    #設定されていないなら設定
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

grep 'net.ipv6.conf.all.forwarding=1' /etc/sysctl.conf | grep -v '^#.*' > /dev/null
if [[ $? -eq 1 ]]; then
    #設定されていないなら設定
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
fi
# 設定を反映
sysctl -p >> /dev/null

# デフォルトルートのインターフェイス名をロード
DEFAULT_IFACE=$(ip route show | awk '/default/ {print $5}')

# mkwgディレクトリで鍵の作成
if [[ ! -f /etc/wireguard/mkwg/wg$1server.key ]]; then
  echo "create wg$1server.key"
  wg genkey | tee /etc/wireguard/mkwg/wg$1server.key
  cat /etc/wireguard/mkwg/wg$1server.key | wg pubkey | tee /etc/wireguard/mkwg/wg$1server.pub
fi
# Wireguardのサーバー用ファイルを生成
if [[ -f /etc/wireguard/wg$1.conf ]]; then
  # wgNがある場合は警告を出し中止する
  echo "wg$1 already exists"
  exit 1
else
  touch /etc/wireguard/wg$1.conf
  cat << EOT >> /etc/wireguard/wg$1.conf
[Interface]
PostUp = ufw route allow in on wg$1 out on $DEFAULT_IFACE
PostUp = iptables -t nat -I POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE
PostUp = ip6tables -t nat -I POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE
PreDown = ufw route delete allow in on wg0 out on $DEFAULT_IFACE
PreDown = iptables -t nat -D POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE
PreDown = ip6tables -t nat -D POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE

Address = 10.0.25.1/24
ListenPort = 51820
PrivateKey = `cat /etc/wireguard/mkwg/wg$1server.key`
EOT
fi

# 全部正常に終了したら0を返す
echo "done!"
exit 0
