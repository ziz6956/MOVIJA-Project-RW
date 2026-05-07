#!/bin/bash
# ==========================================
# Module 12: Telegram MTProto Proxy (mtg v2) - Host Network & CONNMARK
# ==========================================

# Вспомогательная функция для получения данных из GitHub и Docker Hub
get_latest_mtg_info() {
    local GH_API="https://api.github.com/repos/9seconds/mtg/releases/latest"
    local LATEST_VER=$(curl -s "$GH_API" | grep -oP '"tag_name":\s*"\K[^"]+')

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

    local LOCAL_VER=$(docker exec mtproto-proxy /mtg --version 2>/dev/null)
    if [ -z "$LOCAL_VER" ]; then
        log_error "Не удалось определить локальную версию. Контейнер запущен?"
        return 1
    fi
    echo -e "Текущая версия на сервере: ${C_CYAN}$LOCAL_VER${C_NC}"

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
        log_info "Скачиваем новый образ..."
        docker pull nineseconds/mtg:2
        docker restart mtproto-proxy
        log_success "Обновление завершено!"
    fi
}

show_mtproto_link() {
    if [ ! -f "/etc/mtg.toml" ]; then
        log_error "Конфигурационный файл /etc/mtg.toml не найден."
        return 1
    fi

    local SERVER_IP=$(grep 'bind-to' /etc/mtg.toml | grep -oP '\d+\.\d+\.\d+\.\d+')
    local SECRET=$(grep 'secret' /etc/mtg.toml | grep -oP '"\K[^"]+')
    local TG_LINK="tg://proxy?server=${SERVER_IP}&port=443&secret=${SECRET}"

    log_section "ИНФОРМАЦИЯ О MTPROTO PROXY"
    echo -e "Статус: ${C_GREEN}Запущен и работает (Host Network)${C_NC}"
    echo -e "Сервер: $SERVER_IP"
    echo -e "Порт: 443"
    echo -e "--------------------------------------------------------"
    echo -e "${C_GREEN}ВАША ССЫЛКА ДЛЯ ПОДКЛЮЧЕНИЯ:${C_NC}"
    echo -e "${C_CYAN}${TG_LINK}${C_NC}"
    echo -e "--------------------------------------------------------"
    echo -e "Просмотр логов в реальном времени:"
    echo -e "${C_YELLOW}sudo docker logs --tail 20 -f mtproto-proxy${C_NC}"
    echo -e "--------------------------------------------------------"
}

setup_asymmetric_routing() {
    local TARGET_IP=$1
    log_info "Настройка правил маршрутизации CONNMARK для $TARGET_IP..."

    # Установка iptables-persistent для сохранения правил
    if ! dpkg -l | grep -q iptables-persistent; then
        log_info "Установка iptables-persistent..."
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
        apt-get install -y iptables-persistent -qq > /dev/null
    fi

    # Очистка старых правил
    iptables -t mangle -D PREROUTING -d "$TARGET_IP" -p tcp --dport 443 -m conntrack --ctstate NEW -j CONNMARK --set-mark 200 2>/dev/null || true
    iptables -t mangle -D OUTPUT -m connmark --mark 200 -j CONNMARK --restore-mark 2>/dev/null || true

    # Применение новых правил
    iptables -t mangle -A PREROUTING -d "$TARGET_IP" -p tcp --dport 443 -m conntrack --ctstate NEW -j CONNMARK --set-mark 200
    iptables -t mangle -A OUTPUT -m connmark --mark 200 -j CONNMARK --restore-mark
    netfilter-persistent save > /dev/null

    # Создание службы для сохранения ip rule (т.к. iptables-persistent не сохраняет маршруты ip)
    cat <<EOF > /etc/systemd/system/mtg-fwmark.service
[Unit]
Description=Restore fwmark 200 for MTProto Asymmetric Routing
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ip rule add fwmark 200 table 200
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    ip rule add fwmark 200 table 200 2>/dev/null || true
    systemctl daemon-reload
    systemctl enable --now mtg-fwmark.service > /dev/null 2>&1

    log_success "Асимметричная маршрутизация настроена и сохранена в автозагрузку."
}

run_mtproto_install() {
    if [ "$(docker ps -aq -f name=mtproto-proxy)" ]; then
        log_section "УПРАВЛЕНИЕ MTPROTO"
        echo "1) Показать ссылку для подключения и логи"
        echo "2) Проверить обновления (Version Check)"
        echo "3) Переустановить (сменить IP/домен)"
        echo "4) Удалить прокси"
        echo "5) Назад"
        read -p "Выберите действие [1-5]: " sub_choice
        
        case $sub_choice in
            1) show_mtproto_link; read -p "Нажмите Enter..."; return ;;
            2) check_mtproto_updates; read -p "Нажмите Enter..."; return ;;
            3) docker stop mtproto-proxy >/dev/null && docker rm mtproto-proxy >/dev/null ;;
            4)
                docker stop mtproto-proxy && docker rm mtproto-proxy
                rm -f /etc/mtg.toml
                systemctl disable --now mtg-fwmark.service 2>/dev/null || true
                rm -f /etc/systemd/system/mtg-fwmark.service
                log_success "Прокси и настройки маршрутизации удалены."; return ;;
            *) return ;;
        esac
    fi

    log_section "УСТАНОВКА MTPROTO PROXY (HOST NETWORK)"
    
    # 1. Поиск локальных IP адресов
    local LOCAL_IPS=($(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'))
    
    if [ ${#LOCAL_IPS[@]} -eq 0 ]; then
        log_error "Не найдено публичных IPv4 адресов на сервере."
        return 1
    fi

    log_info "Анализ интерфейсов и занятости порта 443:"
    local i=1
    for ip in "${LOCAL_IPS[@]}"; do
        if ss -tulpn | grep -q "$ip:443"; then
            echo -e "  $i) $ip - ${C_RED}Порт 443 ЗАНЯТ${C_NC} (Здесь работает Xray/Caddy)"
        else
            echo -e "  $i) $ip - ${C_GREEN}Порт 443 СВОБОДЕН${C_NC} (Рекомендуется для MTProxy)"
        fi
        ((i++))
    done

    # 2. Выбор IP
    local SELECTED_IP=""
    while true; do
        read -p "Выберите номер IP-адреса для MTProto [1-${#LOCAL_IPS[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#LOCAL_IPS[@]}" ]; then
            SELECTED_IP="${LOCAL_IPS[$((choice-1))]}"
            break
        else
            log_error "Неверный выбор."
        fi
    done
    log_success "Выбран IP-адрес: $SELECTED_IP"

    # 3. Интеграция со сканером SNI
    if [ -f "$MODULES_DIR/09_reality_scanner.sh" ]; then
        echo ""
        log_info "Сейчас будет запущен сканер для поиска идеального домена маскировки."
        echo -e "${C_YELLOW}ВАЖНО: В меню сканера выберите тот же IP-адрес ($SELECTED_IP)!${C_NC}"
        sleep 3
        source "$MODULES_DIR/09_reality_scanner.sh"
        run_reality_scanner
    fi

    # 4. Ввод домена и генерация
    log_section "НАСТРОЙКА FAKE TLS"
    read -p "Введите домен маскировки (из результатов выше или свой) [google.com]: " TG_DOMAIN
    TG_DOMAIN=${TG_DOMAIN:-google.com}

    log_info "Генерация секрета для $TG_DOMAIN..."
    local FINAL_SECRET=$(docker run --rm nineseconds/mtg:2 generate-secret "$TG_DOMAIN")

    # 5. Создание конфига
    log_info "Создание файла конфигурации /etc/mtg.toml..."
    cat <<EOF > /etc/mtg.toml
secret = "$FINAL_SECRET"
bind-to = "$SELECTED_IP:443"
EOF

    # 6. Открытие порта в фаерволе
    if command -v ufw &> /dev/null; then
        ufw allow 443/tcp > /dev/null
    fi

    # 7. Настройка ядра (CONNMARK)
    setup_asymmetric_routing "$SELECTED_IP"

    # 8. Запуск контейнера в сети хоста
    log_info "Запуск MTProto Proxy..."
    docker run -d \
        --name mtproto-proxy \
        --network host \
        --restart always \
        -v /etc/mtg.toml:/config.toml \
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