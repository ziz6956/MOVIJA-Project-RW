#!/bin/bash
# ==========================================
# Module 12: Telegram MTProto Proxy (mtg)
# ==========================================

show_mtproto_link() {
    local SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org || curl -s --max-time 5 https://ifconfig.me)
    local CONTAINER_INFO=$(docker inspect mtproto-proxy 2>/dev/null)
    
    if [ -z "$CONTAINER_INFO" ]; then
        log_error "Контейнер mtproto-proxy не найден."
        return 1
    fi

    local SECRET=$(docker inspect -f '{{range .Config.Env}}{{if expr (index (split . "=") 0 | eq "MTG_SECRET")}}{{index (split . "=") 1}}{{end}}{{end}}' mtproto-proxy)
    local PORT=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' mtproto-proxy)

    if [ -z "$SECRET" ] || [ -z "$PORT" ]; then
        log_error "Не удалось получить параметры из контейнера."
        return 1
    fi

    local TG_LINK="https://t.me/proxy?server=${SERVER_IP}&port=${PORT}&secret=dd${SECRET}"

    log_section "ИНФОРМАЦИЯ О MTPROTO PROXY"
    echo -e "Статус: ${C_GREEN}Запущен и работает${C_NC}"
    echo -e "Сервер: $SERVER_IP"
    echo -e "Порт: $PORT"
    echo -e "--------------------------------------------------------"
    echo -e "${C_GREEN}ВАША ССЫЛКА ДЛЯ ПОДКЛЮЧЕНИЯ:${C_NC}"
    echo -e "${C_CYAN}${TG_LINK}${C_NC}"
    echo -e "--------------------------------------------------------"
}

run_mtproto_install() {
    if [ "$(docker ps -aq -f name=mtproto-proxy)" ]; then
        log_section "УПРАВЛЕНИЕ MTPROTO"
        echo "1) Показать ссылку"
        echo "2) Переустановить"
        echo "3) Удалить"
        echo "4) Назад"
        read -p "Выбор [1-4]: " sub_choice
        case $sub_choice in
            1) show_mtproto_link; read -p "Нажмите Enter..."; return ;;
            2) docker stop mtproto-proxy >/dev/null && docker rm mtproto-proxy >/dev/null ;;
            3) 
                local OLD_PORT=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' mtproto-proxy 2>/dev/null)
                docker stop mtproto-proxy && docker rm mtproto-proxy
                if [ ! -z "$OLD_PORT" ] && command -v ufw &> /dev/null; then sudo ufw delete allow "$OLD_PORT"/tcp; fi
                log_success "Прокси удален."; return ;;
            *) return ;;
        esac
    fi

    log_section "УСТАНОВКА MTPROTO PROXY"
    read -p "Введите порт [8443]: " TG_PORT
    TG_PORT=${TG_PORT:-8443}
    read -p "Домен маскировки [google.com]: " TG_DOMAIN
    TG_DOMAIN=${TG_DOMAIN:-google.com}

    if netstat -tuln 2>/dev/null | grep -q ":$TG_PORT "; then
        log_error "Порт $TG_PORT уже занят! Выберите другой."
        read -p "Enter..."
        return 1
    fi

    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        log_info "Открытие порта $TG_PORT в UFW..."
        sudo ufw allow "$TG_PORT"/tcp > /dev/null
    fi

    local FINAL_SECRET=$(openssl rand -hex 16)
    
    log_info "Скачивание образа и запуск..."
    # Используем GHCR (GitHub Registry) - это надежнее, чем Docker Hub
    docker run -d \
        --name mtproto-proxy \
        --restart always \
        -p "$TG_PORT":8080 \
        -e MTG_SECRET="$FINAL_SECRET" \
        -e MTG_DOMAIN="$TG_DOMAIN" \
        ghcr.io/9seconds/mtg:2

    if [ $? -eq 0 ]; then
        log_success "Контейнер запущен!"
        sleep 3
        show_mtproto_link
    else
        log_error "Ошибка запуска Docker."
    fi
    echo ""
    read -p "Нажмите Enter..."
}