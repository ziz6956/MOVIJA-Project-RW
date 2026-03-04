#!/bin/bash
# ==========================================
# Module 06: Environment Generator
# ==========================================

run_env_generator() {
    log_section "5. КОНФИГУРАЦИЯ ПАНЕЛИ (.env)"

    if [ ! -f "$WORK_DIR/.env.example" ]; then
        log_error "Файл .env.example не найден в $WORK_DIR"
        exit 1
    fi

    # --- Специфичная логика для панели: Порт и Firewall ---
    while true; do
        export PANEL_PORT=$((RANDOM % 50000 + 10000))
        if [[ "$PANEL_PORT" != "$SSH_PORT" && "$PANEL_PORT" != "2222" && "$PANEL_PORT" != "3000" && "$PANEL_PORT" != "3010" && "$PANEL_PORT" != "5432" && "$PANEL_PORT" != "6379" && "$PANEL_PORT" != "8080" ]]; then
            if ! ss -tuln | grep -q ":$PANEL_PORT "; then
                break
            fi
        fi
    done
    log_info "Сгенерирован порт Панели: $PANEL_PORT"

    ufw allow "$PANEL_PORT"/tcp comment 'Panel Port'
    ufw reload > /dev/null
    log_success "Порт панели $PANEL_PORT открыт в UFW."
    # --------------------------------------------------------

    log_info "Пожалуйста, введите данные для настройки:"

    while true; do
        read -p "Основной домен панели (например, panel.example.com): " INPUT_FRONT_DOMAIN
        [ -n "$INPUT_FRONT_DOMAIN" ] && break
        log_error "Поле не может быть пустым."
    done

    while true; do
        read -p "Поддомен для подписок (например, sub.example.com): " INPUT_SUB_DOMAIN
        [ -n "$INPUT_SUB_DOMAIN" ] && break
        log_error "Поле не может быть пустым."
    done

    while true; do
        read -p "Название вашего VPN проекта: " INPUT_META_TITLE
        [ -n "$INPUT_META_TITLE" ] && break
        log_error "Поле не может быть пустым."
    done

    cp "$WORK_DIR/.env.example" "$WORK_DIR/.env"
    sed -i 's/\r$//' "$WORK_DIR/.env"

    sed -i "s/__FRONT_DOMAIN__/$INPUT_FRONT_DOMAIN/g" "$WORK_DIR/.env"
    sed -i "s/__SUB_DOMAIN__/$INPUT_SUB_DOMAIN/g" "$WORK_DIR/.env"
    sed -i "s/__PANEL_PORT__/$PANEL_PORT/g" "$WORK_DIR/.env"
    sed -i "s|__META_TITLE__|$INPUT_META_TITLE|g" "$WORK_DIR/.env"

    log_info "Генерация уникальных ключей и паролей БД..."
    sed -i "s/__POSTGRES_PASS__/$(openssl rand -hex 16)/g" "$WORK_DIR/.env"
    sed -i "s/__REDIS_PASS__/$(openssl rand -hex 16)/g" "$WORK_DIR/.env"
    sed -i "s/__JWT_AUTH__/$(openssl rand -hex 64)/g" "$WORK_DIR/.env"
    sed -i "s/__JWT_API__/$(openssl rand -hex 64)/g" "$WORK_DIR/.env"
    sed -i "s/__METRICS_USER__/$(openssl rand -hex 8)/g" "$WORK_DIR/.env"
    sed -i "s/__METRICS_PASS__/$(openssl rand -hex 16)/g" "$WORK_DIR/.env"

    chmod 600 "$WORK_DIR/.env"
    log_success "Файл .env успешно сгенерирован."
}