#!/bin/bash
# ==========================================
# Module 07: Cluster Deployment & DNS Check
# ==========================================

run_deploy_cluster() {
    log_section "6. ПРОВЕРКА DNS И ЗАПУСК"

    # Определение публичных IP
    local PUBLIC_IPV4=$(curl -4 -s icanhazip.com || echo "")
    local PUBLIC_IPV6=$(curl -6 -s icanhazip.com || echo "")
    local DISPLAY_IP=${PUBLIC_IPV4:-$PUBLIC_IPV6}

    # Чтение доменов из свежего .env
    local FRONT_DOMAIN=$(grep '^FRONT_END_DOMAIN=' "$WORK_DIR/.env" | cut -d '=' -f2)
    local SUB_DOMAIN=$(grep '^SUB_PUBLIC_DOMAIN=' "$WORK_DIR/.env" | cut -d '=' -f2)

    log_info "Проверка резолва доменов..."
    local DNS_OK=true

    for DOMAIN in "$FRONT_DOMAIN" "$SUB_DOMAIN"; do
        local RESOLVED_IP=$(getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | head -n 1 || echo "")
        if [ "$RESOLVED_IP" != "$PUBLIC_IPV4" ]; then
            log_warn "Домен $DOMAIN (IP: ${RESOLVED_IP:-Не найден}) не указывает на этот сервер ($PUBLIC_IPV4)!"
            DNS_OK=false
        else
            log_success "Домен $DOMAIN корректно настроен."
        fi
    done

    if [ "$DNS_OK" = false ]; then
        log_error "Caddy не сможет выпустить SSL. Запуск кластера прерван."
        log_info "Направьте A-записи доменов на $PUBLIC_IPV4 и запустите: docker compose up -d"
    else
        log_info "Запуск Docker-контейнеров..."
        docker compose up -d
        log_success "Кластер успешно запущен!"
    fi

    # Финальный отчет
    log_section "ИТОГОВЫЕ ДАННЫЕ ДОСТУПА"
    echo -e "ПАНЕЛЬ VPN:   https://$FRONT_DOMAIN:$PANEL_PORT"
    echo -e "ПОДПИСКИ:     https://$SUB_DOMAIN"
    echo -e "------------------------------------------"
    echo -e "IP СЕРВЕРА:   $DISPLAY_IP"
    echo -e "ПОРТ SSH:     $SSH_PORT"
    echo -e "ПОЛЬЗОВАТЕЛЬ: $NEW_USER"
    echo -e "ПАРОЛЬ:       $USER_PASS"
    echo -e "------------------------------------------"
    echo -e "Команда подключения: ssh -p $SSH_PORT $NEW_USER@$DISPLAY_IP"
}