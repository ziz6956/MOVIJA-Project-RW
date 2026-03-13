#!/bin/bash
# ==========================================
# Module 07: Cluster Deployment & DNS Check
# ==========================================

run_deploy_cluster() {
    log_section "6. ПРОВЕРКА DNS И ЗАПУСК"

    local PUBLIC_IPV4=$(curl -4 -s icanhazip.com || echo "")
    local PUBLIC_IPV6=$(curl -6 -s icanhazip.com || echo "")
    local DISPLAY_IP=${PUBLIC_IPV4:-$PUBLIC_IPV6}

    local DOMAINS_TO_CHECK=()
    
    if [ "$INSTALL_TYPE" == "panel" ]; then
        local FRONT_DOMAIN=$(grep '^FRONT_END_DOMAIN=' "$ENV_PATH" | cut -d '=' -f2)
        local SUB_DOMAIN=$(grep '^SUB_PUBLIC_DOMAIN=' "$ENV_PATH" | cut -d '=' -f2)
        DOMAINS_TO_CHECK+=("$FRONT_DOMAIN")
        local EXPECTED_CONTAINERS=4
    else
        local SUB_DOMAIN=$(grep '^SUB_DOMAIN=' "$ENV_PATH" | cut -d '=' -f2)
        local CABINET_DOMAIN=$(grep '^CABINET_DOMAIN=' "$ENV_PATH" | cut -d '=' -f2)
        DOMAINS_TO_CHECK+=("$SUB_DOMAIN" "$CABINET_DOMAIN")
        local EXPECTED_CONTAINERS=3
    fi

    local DNS_OK=true
    for DOMAIN in "${DOMAINS_TO_CHECK[@]}"; do
        if [ -n "$DOMAIN" ]; then
            log_info "Проверка резолва домена $DOMAIN..."
            local RESOLVED_IP=$(getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | head -n 1 || echo "")
            if [ "$RESOLVED_IP" != "$PUBLIC_IPV4" ]; then
                log_warn "Домен $DOMAIN не указывает на этот сервер ($PUBLIC_IPV4)!"
                DNS_OK=false
            else
                log_success "Домен $DOMAIN корректно настроен."
            fi
        fi
    done

    local DEPLOY_ALLOWED=false
    if [ "$DNS_OK" = true ]; then
        DEPLOY_ALLOWED=true
    elif [ "${RESTORED_CERTS:-false}" = "true" ]; then
        log_warn "DNS не настроен, но сертификаты восстановлены из бэкапа. Пробую запустить..."
        DEPLOY_ALLOWED=true
    else
        log_error "Caddy не сможет выпустить SSL. Запуск прерван."
        return 1
    fi

    if [ "$DEPLOY_ALLOWED" = true ]; then
        log_info "Запуск Docker-контейнеров..."
        cd "$COMPOSE_DIR"
        docker compose up -d --remove-orphans

        log_info "Ожидание стабилизации сервисов (30 сек)..."
        local ATTEMPTS=0
        local MAX_ATTEMPTS=6

        while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
            if docker compose ps | grep -E "restarting|exited" > /dev/null; then
                log_warn "Один из контейнеров в процессе перезагрузки или упал. Ожидаем..."
            elif [ $(docker compose ps --filter "status=running" -q | wc -l) -eq $EXPECTED_CONTAINERS ]; then
                log_success "Все ключевые сервисы запущены и работают!"
                break
            fi
            sleep 5
            ATTEMPTS=$((ATTEMPTS + 1))
        done
    fi

    # Финальный отчет
    log_section "ИТОГОВЫЕ ДАННЫЕ ДОСТУПА"
    if [ "$INSTALL_TYPE" == "panel" ]; then
        echo -e "ПАНЕЛЬ VPN:   https://$FRONT_DOMAIN:$PANEL_PORT"
        echo -e "ПОДПИСКИ:     https://$SUB_DOMAIN"
    else
        echo -e "ПОДПИСКИ:     https://$SUB_DOMAIN:$SUB_PORT"
        echo -e "КАБИНЕТ:      https://$CABINET_DOMAIN:$SUB_PORT"
        echo -e "ДИРЕКТОРИЯ:   $PROJECT_DIR"
    fi
    echo -e "------------------------------------------"
    echo -e "IP СЕРВЕРА:   $DISPLAY_IP"
    echo -e "ПОРТ SSH:     $SSH_PORT"
    echo -e "ПОЛЬЗОВАТЕЛЬ: $NEW_USER"
    echo -e "ПАРОЛЬ:       $USER_PASS"
    echo -e "------------------------------------------"
    echo -e "Команда подключения: ssh -p $SSH_PORT $NEW_USER@$DISPLAY_IP"
}