#!/bin/bash
# ==========================================
# Module 12: Telegram MTProto Proxy (mtg)
# ==========================================

show_mtproto_link() {
    # Пытаемся достать данные из работающего контейнера
    local CONTAINER_INFO=$(docker inspect mtproto-proxy 2>/dev/null)
    if [ -z "$CONTAINER_INFO" ]; then
        log_error "Прокси не запущен или контейнер удален."
        return 1
    fi

    # Парсим секрет и порт напрямую из конфига Docker
    local SECRET=$(echo "$CONTAINER_INFO" | grep "MTG_SECRET=" | cut -d'=' -f2 | tr -d '", ')
    local PORT=$(echo "$CONTAINER_INFO" | grep -A 1 '"HostPort":' | grep -oE '[0-9]+' | head -1)
    local SERVER_IP=$(curl -s https://api.ipify.org)

    # Формируем ссылку (dd префикс для автоматического Fake-TLS в Telegram)
    local TG_LINK="https://t.me/proxy?server=${SERVER_IP}&port=${PORT}&secret=dd${SECRET}"

    log_section "ИНФОРМАЦИЯ О MTPROTO PROXY"
    echo -e "Статус: ${C_GREEN}Запущен${C_NC}"
    echo -e "IP сервера: $SERVER_IP"
    echo -e "Порт: $PORT"
    echo -e "--------------------------------------------------------"
    echo -e "${C_GREEN}ВАША ССЫЛКА ДЛЯ ПОДКЛЮЧЕНИЯ:${C_NC}"
    echo -e "${C_CYAN}${TG_LINK}${C_NC}"
    echo -e "--------------------------------------------------------"
}

run_mtproto_install() {
    # 1. Проверка: если контейнер уже есть, предлагаем управление
    if [ "$(docker ps -aq -f name=mtproto-proxy)" ]; then
        log_section "MTPROTO PROXY УЖЕ УСТАНОВЛЕН"
        echo "1) Показать ссылку для подключения"
        echo "2) Переустановить (с новым секретом/портом)"
        echo "3) Удалить прокси (и закрыть порт)"
        echo "4) Назад"
        read -p "Выберите действие [1-4]: " sub_choice
        
        case $sub_choice in
            1) show_mtproto_link; read -p "Нажмите Enter..."; return ;;
            2) log_info "Начинаем переустановку..." ;;
            3) 
                local OLD_PORT=$(docker inspect mtproto-proxy 2>/dev/null | grep -A 1 '"HostPort":' | grep -oE '[0-9]+' | head -1)
                docker stop mtproto-proxy && docker rm mtproto-proxy
                if command -v ufw &> /dev/null; then sudo ufw delete allow "$OLD_PORT"/tcp; fi
                log_success "Прокси удален, порт $OLD_PORT закрыт."; return ;;
            *) return ;;
        esac
    fi

    log_section "УСТАНОВКА MTPROTO PROXY"
    
    # 2. Настройка параметров
    read -p "Введите порт для прокси [по умолчанию 8443]: " TG_PORT
    TG_PORT=${TG_PORT:-8443}
    
    read -p "Введите домен маскировки [google.com]: " TG_DOMAIN
    TG_DOMAIN=${TG_DOMAIN:-google.com}

    # 3. Настройка Firewall (UFW)
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        log_info "Открытие порта $TG_PORT в UFW..."
        sudo ufw allow "$TG_PORT"/tcp > /dev/null
    fi

    # 4. Генерация секрета и запуск
    log_info "Генерация секретного ключа..."
    local FINAL_SECRET=$(openssl rand -hex 16)
    
    log_info "Запуск Docker контейнера mtg..."
    docker stop mtproto-proxy 2>/dev/null
    docker rm mtproto-proxy 2>/dev/null

    # Запускаем mtg v2. Порт пробрасывается через -p
    docker run -d \
        --name mtproto-proxy \
        --restart always \
        -p "$TG_PORT":8080 \
        -e MTG_SECRET="$FINAL_SECRET" \
        -e MTG_DOMAIN="$TG_DOMAIN" \
        9seconds/mtg:2 > /dev/null

    # 5. Результат
    show_mtproto_link
    read -p "Нажмите Enter, чтобы вернуться в меню..."
}