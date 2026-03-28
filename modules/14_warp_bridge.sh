#!/bin/bash
# ==========================================
# Module 14: WARP SOCKS Bridge Setup
# ==========================================

run_warp_bridge_setup() {
    log_section "НАСТРОЙКА WARP SOCKS BRIDGE"

    # 1. Проверка наличия интерфейса warp
    if ! ip link show warp > /dev/null 2>&1; then
        log_warn "Интерфейс 'warp' не найден. Убедитесь, что туннель поднят."
        log_info "Рекомендуется использовать WTM (Warp Terminal Manager) для создания интерфейса."
        return 1
    fi

    # 2. Установка Xray на хост (если нет)
    if ! command -v xray &> /dev/null; then
        log_info "Установка Xray на хост..."
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
    fi

    # 3. Создание конфигурации моста
    log_info "Создание конфига /usr/local/etc/xray/config.json..."
    mkdir -p /usr/local/etc/xray
    cat <<EOF > /usr/local/etc/xray/config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 40000,
      "protocol": "socks",
      "settings": { "auth": "noauth", "udp": true },
      "tag": "socks-in"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": { "domainStrategy": "UseIP" },
      "streamSettings": { "sockopt": { "interface": "warp" } },
      "tag": "warp-out"
    }
  ]
}
EOF

    # 4. Перезапуск службы
    log_info "Перезапуск службы Xray..."
    systemctl daemon-reload
    systemctl enable xray
    systemctl restart xray
    log_success "Xray Bridge запущен и слушает порт 40000"

# 5. Проверка связи из контейнера
    log_info "Проверка связи из контейнера remnanode..."
    
    # Получаем IP-адрес шлюза докер-сети
    local DOCKER_GATEWAY=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}' remnanode)
    
    if [ -z "$DOCKER_GATEWAY" ]; then
        log_warn "Не удалось определить шлюз Docker. Используем 172.17.0.1 по умолчанию."
        DOCKER_GATEWAY="172.17.0.1"
    fi

    log_info "Тестируем мост через шлюз: $DOCKER_GATEWAY"
    
    # Слово "warp" без "on", так как иногда Cloudflare отдает warp=plus
    if docker run --rm --network remnawave-network curlimages/curl curl -s --socks5 "$DOCKER_GATEWAY:40000" https://cloudflare.com/cdn-cgi/trace | grep -q "warp="; then
        log_success "СВЯЗЬ ЕСТЬ! Мост успешно принимает трафик из Docker."
    else
        log_error "ОШИБКА: Контейнер не может достучаться до моста на $DOCKER_GATEWAY:40000. Проверьте фаервол."
    fi
}