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

    # В v2 секрет - это одна строка, в которой уже есть всё
    local SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Env}}{{println .}}{{end}}' | grep '^MTG_SECRET=' | cut -d'=' -f2)
    local PORT=$(docker inspect mtproto-proxy --format='{{(index (index .NetworkSettings.Ports "3128/tcp") 0).HostPort}}')

    # В v2 префикс dd не нужен, он уже зашит в секрет
    local TG_LINK="https://t.me/proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}"

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
        read -p "Выбор [1-3]: " sub_choice
        case $sub_choice in
            1) show_mtproto_link; read -p "Enter..."; return ;;
            2) docker stop mtproto-proxy >/dev/null && docker rm mtproto-proxy >/dev/null ;;
            3) docker stop mtproto-proxy && docker rm mtproto-proxy; return ;;
            *) return ;;
        esac
    fi

    log_section "УСТАНОВКА MTPROTO PROXY"
    read -p "Введите порт [8443]: " TG_PORT
    TG_PORT=${TG_PORT:-8443}
    read -p "Домен маскировки [google.com]: " TG_DOMAIN
    TG_DOMAIN=${TG_DOMAIN:-google.com}

    # Открываем порт в UFW
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        sudo ufw allow "$TG_PORT"/tcp > /dev/null
    fi

    log_info "Генерация нативного секрета для v2..."
    # Генерируем секрет через сам контейнер mtg
    local NEW_SECRET=$(docker run --rm ghcr.io/9seconds/mtg:2 generate-secret "$TG_DOMAIN")

    log_info "Запуск прокси..."
    docker run -d \
        --name mtproto-proxy \
        --restart always \
        -p "$TG_PORT":3128 \
        -e MTG_SECRET="$NEW_SECRET" \
        ghcr.io/9seconds/mtg:2

    if [ $? -eq 0 ]; then
        log_success "Контейнер запущен!"
        sleep 2
        show_mtproto_link
    else
        log_error "Ошибка запуска."
    fi
    read -p "Нажмите Enter..."
}