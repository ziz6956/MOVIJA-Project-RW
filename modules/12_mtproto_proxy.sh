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

    # MTG v2 слушает на 3128. Вытаскиваем секрет и порт.
    local SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Env}}{{println .}}{{end}}' | grep '^MTG_SECRET=' | cut -d'=' -f2)
    local PORT=$(docker inspect mtproto-proxy --format='{{(index (index .NetworkSettings.Ports "3128/tcp") 0).HostPort}}')

    if [ -z "$SECRET" ] || [ -z "$PORT" ]; then
        log_error "Не удалось получить параметры. Попробуйте переустановить прокси."
        return 1
    fi

    # Формируем ссылку с префиксом dd для Fake-TLS
    local TG_LINK="https://t.me/proxy?server=${SERVER_IP}&port=${PORT}&secret=dd${SECRET}"

    log_section "ИНФОРМАЦИЯ О MTPROTO PROXY"
    echo -e "Статус: ${C_GREEN}Запущен и работает${C_NC}"
    echo -e "Порт на сервере: $PORT"
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
        read -p "Выберите действие [1-4]: " sub_choice
        case $sub_choice in
            1) show_mtproto_link; read -p "Enter..."; return ;;
            2) docker stop mtproto-proxy >/dev/null && docker rm mtproto-proxy >/dev/null ;;
            3) 
                local OLD_PORT=$(docker inspect mtproto-proxy --format='{{(index (index .NetworkSettings.Ports "3128/tcp") 0).HostPort}}' 2>/dev/null)
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

    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        sudo ufw allow "$TG_PORT"/tcp > /dev/null
    fi

    local FINAL_SECRET=$(openssl rand -hex 16)
    
    log_info "Запуск контейнера (порт 3128 внутри)..."
    # ИСПРАВЛЕНО: мапим внешний порт на 3128
    docker run -d \
        --name mtproto-proxy \
        --restart always \
        -p "$TG_PORT":3128 \
        -e MTG_SECRET="$FINAL_SECRET" \
        -e MTG_DOMAIN="$TG_DOMAIN" \
        ghcr.io/9seconds/mtg:2

    if [ $? -eq 0 ]; then
        log_success "Контейнер запущен!"
        sleep 2
        show_mtproto_link
    else
        log_error "Ошибка Docker."
    fi
    read -p "Нажмите Enter..."
}