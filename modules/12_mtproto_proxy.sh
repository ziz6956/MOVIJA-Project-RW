#!/bin/bash
# ==========================================
# Module 12: Telegram MTProto Proxy (mtg v2)
# ==========================================

# Вспомогательная функция для получения данных из GitHub и Docker Hub
get_latest_mtg_info() {
    # 1. Тянем версию с GitHub (там живет имя релиза, например v2.2.8)
    local GH_API="https://api.github.com/repos/9seconds/mtg/releases/latest"
    local LATEST_VER=$(curl -s "$GH_API" | grep -oP '"tag_name":\s*"\K[^"]+')

    # 2. Тянем дату обновления с Docker Hub (чтобы знать, свежий ли образ под тегом :2)
    local DH_API="https://hub.docker.com/v2/repositories/nineseconds/mtg/tags/2"
    local LAST_UPDATED=$(curl -s "$DH_API" | grep -oP '"last_updated":"\K[^"]+' | sed 's/T/ /;s/Z//')

    if [ -z "$LATEST_VER" ]; then
        echo "v2.x.x ($LAST_UPDATED)"
    else
        echo "$LATEST_VER ($LAST_UPDATED)"
    fi
}

check_mtproto_updates() {
    log_section "ПРОВЕРКА ОБНОВЛЕНИЙ MTPROTO"

    # 1. Получаем локальную версию
    local LOCAL_VER=$(docker exec mtproto-proxy /mtg --version 2>/dev/null)
    if [ -z "$LOCAL_VER" ]; then
        log_error "Не удалось определить локальную версию. Контейнер запущен?"
        return 1
    fi
    echo -e "Текущая версия на сервере: ${C_CYAN}$LOCAL_VER${C_NC}"

    # 2. Получаем инфо с Docker Hub
    log_info "Запрос данных с Docker Hub..."
    local REMOTE_DATE=$(get_latest_mtg_info)
    
    if [ -z "$REMOTE_DATE" ]; then
        log_error "Не удалось связаться с Docker Hub."
        return 1
    fi
    echo -e "Последнее обновление в репозитории (тег :2): ${C_GREEN}$REMOTE_DATE (UTC)${C_NC}"
    echo -e "--------------------------------------------------------"

    read -p "Желаете выполнить принудительное обновление образа? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        perform_mtproto_update
    fi
}

perform_mtproto_update() {
    log_info "Начало процесса бесшовного обновления..."

    # 1. Извлекаем секрет (ищем в переменных И в аргументах команды Cmd)
    # Регулярка ищет либо значение после MTG_SECRET=, либо любую hex-строку длиннее 32 символов
    local OLD_SECRET=$(docker inspect mtproto-proxy --format='{{range .Config.Env}}{{println .}}{{end}} {{range .Config.Cmd}}{{println .}}{{end}}' | grep -oP '(?<=MTG_SECRET=)[^ ]+|[a-f0-9]{32,}' | head -n 1)
    
    # 2. Извлекаем порт (динамически берем любой HostPort)
    local OLD_PORT=$(docker inspect mtproto-proxy --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with (index $conf 0)}}{{.HostPort}}{{end}}{{break}}{{end}}')

    # Проверка на успех
    if [ -z "$OLD_SECRET" ] || [ -z "$OLD_PORT" ]; then
        log_error "Ошибка: не удалось извлечь параметры автоматически."
        echo "DEBUG: Secret found: $OLD_SECRET"
        echo "DEBUG: Port found: $OLD_PORT"
        return 1
    fi

    log_info "Параметры найдены (Port: $OLD_PORT). Секрет получен. Обновляемся..."

    # 3. Скачиваем новый образ
    docker pull nineseconds/mtg:2

    # 4. Перезапуск (ВАЖНО: запускаем через переменную окружения, как в твоем основном скрипте)
    docker stop mtproto-proxy >/dev/null
    docker rm mtproto-proxy >/dev/null

    docker run -d \
        --name mtproto-proxy \
        --restart always \
        -p "$OLD_PORT":3128 \
        -e MTG_SECRET="$OLD_SECRET" \
        nineseconds/mtg:2

    if [ $? -eq 0 ]; then
        log_success "Обновление завершено! Теперь ты на v2.2.8."
        docker exec mtproto-proxy /mtg --version
    else
        log_error "Критическая ошибка при запуске."
    fi
}

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
        echo "2) Проверить обновления (Version Check)"
        echo "3) Переустановить (сменить порт/домен)"
        echo "4) Удалить прокси"
        echo "5) Назад"
        read -p "Выберите действие [1-5]: " sub_choice
        
        case $sub_choice in
            1) show_mtproto_link; read -p "Нажмите Enter..."; return ;;
            2) check_mtproto_updates; read -p "Нажмите Enter..."; return ;;
            3) docker stop mtproto-proxy >/dev/null && docker rm mtproto-proxy >/dev/null ;;
            4)
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