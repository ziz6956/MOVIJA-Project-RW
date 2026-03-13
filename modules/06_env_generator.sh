#!/bin/bash
# ==========================================
# Module 06: Environment Generator
# ==========================================

run_env_generator() {
    if [ "$INSTALL_TYPE" == "panel" ]; then
        log_section "5. КОНФИГУРАЦИЯ ПАНЕЛИ (.env)"

        if [ ! -f "$WORK_DIR/.env.example" ]; then
            log_error "Файл .env.example не найден"
            exit 1
        fi

        while true; do
            export PANEL_PORT=$((RANDOM % 50000 + 10000))
            if [[ "$PANEL_PORT" != "$SSH_PORT" && "$PANEL_PORT" != "2222" && "$PANEL_PORT" != "3000" && "$PANEL_PORT" != "5432" && "$PANEL_PORT" != "6379" ]]; then
                if ! ss -tuln | grep -q ":$PANEL_PORT "; then break; fi
            fi
        done
        log_info "Сгенерирован порт Панели: $PANEL_PORT"

        ufw allow "$PANEL_PORT"/tcp comment 'Panel Port'
        ufw reload > /dev/null
        log_success "Порт панели $PANEL_PORT открыт в UFW."

        log_info "Пожалуйста, введите данные для настройки:"
        read -p "Основной домен панели (например, panel.example.com): " INPUT_FRONT_DOMAIN
        read -p "Поддомен для подписок (будет работать на узле, напр. sub.example.com): " INPUT_SUB_DOMAIN
        read -p "Название вашего VPN проекта: " INPUT_META_TITLE

        cp "$WORK_DIR/.env.example" "$ENV_PATH"
        sed -i 's/\r$//' "$ENV_PATH"
        sed -i "s/__FRONT_DOMAIN__/$INPUT_FRONT_DOMAIN/g" "$ENV_PATH"
        sed -i "s/__SUB_DOMAIN__/$INPUT_SUB_DOMAIN/g" "$ENV_PATH"
        sed -i "s/__PANEL_PORT__/$PANEL_PORT/g" "$ENV_PATH"
        sed -i "s|__META_TITLE__|$INPUT_META_TITLE|g" "$ENV_PATH"

        log_info "Генерация уникальных ключей и паролей БД..."
        sed -i "s/__POSTGRES_PASS__/$(openssl rand -hex 16)/g" "$ENV_PATH"
        sed -i "s/__REDIS_PASS__/$(openssl rand -hex 16)/g" "$ENV_PATH"
        sed -i "s/__JWT_AUTH__/$(openssl rand -hex 64)/g" "$ENV_PATH"
        sed -i "s/__JWT_API__/$(openssl rand -hex 64)/g" "$ENV_PATH"
        sed -i "s/__METRICS_USER__/$(openssl rand -hex 8)/g" "$ENV_PATH"
        sed -i "s/__METRICS_PASS__/$(openssl rand -hex 16)/g" "$ENV_PATH"
        chmod 600 "$ENV_PATH"
        log_success "Файл .env успешно сгенерирован."

    elif [ "$INSTALL_TYPE" == "node" ]; then
        log_section "5. СБОР ДАННЫХ ДЛЯ НОДЫ"
        
        read -p "🔹 Имя хоста ноды [по умолчанию vpn-node]: " INPUT_HOSTNAME
        export NODE_HOSTNAME=${INPUT_HOSTNAME:-vpn-node}
        hostnamectl set-hostname "$NODE_HOSTNAME"

        read -p "🔹 IP основной ПАНЕЛИ (для доступа к API 2222): " PANEL_IP
        export PANEL_IP

        echo -e "\n\033[0;33m[ВНИМАНИЕ]\033[0m Нода должна быть предварительно создана в вашей веб-панели!"
        read -p "🔹 Секретный ключ ноды (SECRET_KEY): " NODE_SECRET
        export NODE_SECRET

        read -p "🔹 URL основной панели (включая порт, напр. https://panel.site.ru:14732): " PANEL_URL
        export PANEL_URL

        read -p "🔹 API-токен панели (Settings -> API Tokens): " REMNAWAVE_API_TOKEN
        export REMNAWAVE_API_TOKEN

        read -p "🔹 Домен подписок (напр. sub.site.ru): " SUB_DOMAIN
        export SUB_DOMAIN

        read -p "🔹 Домен кабинета (напр. cabinet.site.ru): " CABINET_DOMAIN
        export CABINET_DOMAIN

        # Генерация порта подписок из списка поддерживаемых Cloudflare HTTPS
        local CF_PORTS=(2053 2083 2087 2096 8443)
        export SUB_PORT=${CF_PORTS[$((RANDOM % ${#CF_PORTS[@]}))]}
        log_info "Сгенерирован порт подписок и кабинета: $SUB_PORT"
    fi
}