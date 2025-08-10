#!/bin/bash

# Проверка, запущен ли скрипт от root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен от пользователя root"
    exit 1
fi

# Путь к файлу с ключами Reality
REALITY_KEYS_FILE="/etc/xray/reality_keys.env"

# Путь к конфигурационному файлу Xray
XRAY_CONFIG_FILE="/etc/xray/config.json"

# Загрузка ключей Reality
if [ -f "$REALITY_KEYS_FILE" ]; then
    source "$REALITY_KEYS_FILE"
else
    echo "Ошибка: Файл с ключами Reality не найден. Запустите install_reality.sh сначала."
    exit 1
fi

# Функция для добавления пользователя
add_user() {
    read -p "Введите имя пользователя: " USER_NAME
    USER_UUID=$(/usr/local/bin/xray uuid)

    # Добавление пользователя в конфигурацию Xray
    jq ".inbounds[0].settings.clients += [{ \"id\": \"$USER_UUID\", \"flow\": \"xtls-rprx-vision\", \"email\": \"$USER_NAME\" }]" $XRAY_CONFIG_FILE > temp.json && mv temp.json $XRAY_CONFIG_FILE

    echo "Пользователь $USER_NAME (UUID: $USER_UUID) добавлен."
    echo "Перезапуск Xray для применения изменений..."
    systemctl restart xray

    generate_client_config $USER_UUID $USER_NAME
}

# Функция для генерации клиентской конфигурации
generate_client_config() {
    USER_UUID=$1
    USER_NAME=$2

    SERVER_IP=$(curl -s ifconfig.me)
    SERVER_DOMAIN="dl.google.com"

    cat << EOF > "${USER_NAME}_client_config.json"
{
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$SERVER_IP",
            "port": 443,
            "users": [
              {
                "id": "$USER_UUID",
                "flow": "xtls-rprx-vision",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": "chrome",
          "serverName": "$SERVER_DOMAIN",
          "publicKey": "$PUBLIC_KEY",
          "shortId": "$SHORT_ID",
          "spiderX": "/" 
        }
      }
    }
  ]
}
EOF
    echo "Клиентская конфигурация для $USER_NAME сохранена в ${USER_NAME}_client_config.json"
}

# Основное меню
case "$1" in
    add)
        add_user
        ;;
    generate)
        read -p "Введите UUID пользователя для генерации конфига: " UUID_TO_GENERATE
        read -p "Введите имя пользователя для генерации конфига: " NAME_TO_GENERATE
        generate_client_config $UUID_TO_GENERATE $NAME_TO_GENERATE
        ;;
    *)
        echo "Использование:"
        echo "  $0 add         - Добавить нового пользователя и сгенерировать конфиг"
        echo "  $0 generate   - Сгенерировать конфиг для существующего пользователя"
        ;;
esac


