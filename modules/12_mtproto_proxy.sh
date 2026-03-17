#!/bin/bash
# ==========================================
# Module 12: Telegram MTProto Proxy (mtg v2)
# ==========================================

show_mtproto_link() {
    local SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org || curl -s --max-time 5 https://ifconfig.me)
    local CONTAINER_INFO=$(docker inspect mtproto-proxy 2>/dev/null)
    
    if [ -z "$CONTAINER_INFO" ]; then
        log_error "Контейнер mtproto-proxy не найден."
        return 1
    fi

    # Извлекаем нативный секрет v2 (он уже содержит в себе домен маскировки)
    local SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Env}}{{println .}}{{end}}' | grep '^MTG_SECRET=' | cut -d'=' -f2)
    local PORT=$(docker inspect mtproto-proxy --format='{{(index (index .NetworkSettings.Ports "3128/tcp") 0).HostPort}}')

    # Формируем чистую ссылку по стандарту v2
    # ВАЖНО: префикс dd и домен маскировки УЖЕ зашиты в этот SECRET
    local TG_LINK="https://t.me/proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}"

    log_section "ИНФОРМАЦИЯ О MTPROTO PROXY"
    echo -e "Статус: ${C_GREEN}Запущен и работает${C_NC}"
    echo -e "Сервер: $SERVER_IP"
    echo -e "Порт: $PORT"
    echo -e "--------------------------------------------------------"
    echo -e "${C_GREEN}ВАША ССЫЛКА ДЛЯ ПОДКЛЮЧЕНИЯ:${C_NC}"
    echo -e "${C_CYAN}${TG_LINK}${C_NC}"
    echo -e "--------------------------------------------------------"
    echo -e "${C_YELLOW}СОВЕТ:${C_NC} Скопируйте ссылку и отправьте её себе в «Избранное» в Telegram."
}

run_mtproto_install() {
    if [ "$(docker ps -aq -f name=mtproto-proxy)" ]; then
        log_section "УПРАВЛЕНИЕ MTPROTO"
        echo "1) Показать ссылку для подключения"
        echo "2) Переустановить (сменить порт/домен)"
        echo "3) Удалить прокси"
        echo "4) Назад"
        read -p "Выберите действие [1-4]: " sub_choice
        
        case $sub_choice in
            1) show_mtproto_link; read -p "Нажмите Enter..."; return ;;
            2) docker stop mtproto-proxy >/dev/null && docker rm mtproto-proxy >/dev/null ;;
            3) 
                local OLD_PORT=$(docker inspect mtproto-proxy --format='{{(index (index .NetworkSettings.Ports "3128/tcp") 0).HostPort}}' 2>/dev/null)
                docker stop mtproto-proxy && docker rm mtproto-proxy
                if [ ! -z "$OLD_PORT" ] && command -v ufw &> /dev/null; then sudo ufw delete allow "$OLD_PORT"/tcp; fi
                log_success "Прокси удален."; return ;;
            *) return ;;
        esac
    fi

    log_section "УСТАНОВКА MTPROTO PROXY (mtg v2)"
    
    read -p "Введите порт для прокси [8443]: " TG_PORT
    TG_PORT=${TG_PORT:-8443}
    read -p "Введите домен маскировки [google.com]: " TG_DOMAIN
    TG_DOMAIN=${TG_DOMAIN:-google.com}

    # Открытие портов в Firewall
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        log_info "Открытие порта $TG_PORT в UFW..."
        sudo ufw allow "$TG_PORT"/tcp > /dev/null
    fi

    # Генерируем секрет через временный запуск контейнера (согласно README)
    log_info "Генерация нативного секрета для $TG_DOMAIN..."
    local FINAL_SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret "$TG_DOMAIN")

    log_info "Запуск основного контейнера..."
    # Мапим внешний порт на внутренний 3128 (стандарт mtg v2)
    docker run -d \
        --name mtproto-proxy \
        --restart always \
        -p "$TG_PORT":3128 \
        -e MTG_SECRET="$FINAL_SECRET" \
        nineseconds/mtg:2

    if [ $? -eq 0 ]; then
        log_success "Контейнер успешно запущен!"
        sleep 2
        show_mtproto_link
    else
        log_error "Не удалось запустить Docker."
    fi
    read -p "Нажмите Enter, чтобы вернуться в меню..."
}