#!/bin/bash

# Проверка, запущен ли скрипт от root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен от пользователя root"
    exit 1
fi

# Обновление системы и установка необходимых пакетов
echo "Обновление системы и установка необходимых пакетов..."
apt update && apt upgrade -y
apt install -y curl unzip

# Загрузка и установка Xray-core
echo "Загрузка и установка Xray-core..."
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install

# Генерация ключей для Reality
echo "Генерация ключей для Reality..."
PRIVATE_KEY=$(/usr/local/bin/xray x25519)
PUBLIC_KEY=$(/usr/local/bin/xray x25519 -i $PRIVATE_KEY --public)
SHORT_ID=$(openssl rand -hex 8)

# Сохранение ключей в файл
echo "PRIVATE_KEY=$PRIVATE_KEY" > /etc/xray/reality_keys.env
echo "PUBLIC_KEY=$PUBLIC_KEY" >> /etc/xray/reality_keys.env
echo "SHORT_ID=$SHORT_ID" >> /etc/xray/reality_keys.env

# Создание конфигурационного файла Xray
echo "Создание конфигурационного файла Xray..."
cat << EOF > /etc/xray/config.json
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "dl.google.com:443",
          "serverNames": [
            "dl.google.com"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ]
}
EOF

# Установка прав на исполнение скрипта
chmod +x /etc/xray/config.json

# Перезапуск Xray сервиса
echo "Перезапуск Xray сервиса..."
systemctl enable xray
systemctl restart xray

echo "Установка и настройка VLESS + XTLS + Reality завершена!"
echo "Ваши ключи и ShortId сохранены в /etc/xray/reality_keys.env"
echo "Конфигурация сервера находится в /etc/xray/config.json"


