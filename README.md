# mkwg
WireGuardの初期設定を自動的に行ってくれるスクリプトです
Ubuntu20.04以上で動作する事を想定しています

第一引数にwgNを指定します

1. `sudo bash ./initwg.sh 0`を実行
2. `sudo bash ./mkwg.sh 0`を実行するとクライアント設定ファイルを出力します

設定ファイルなどは`/etc/wireguard/mkwg`配下に保存されます
