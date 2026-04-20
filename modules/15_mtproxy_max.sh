#!/bin/bash
# ==========================================
# Module 15: MTProxy Max (Multi-IP & SNI Scanner)
# ==========================================

run_mtproxy_max_install() {
    log_section "УСТАНОВКА MTPROXY MAX"

    # 1. Сбор всех публичных IP
    local LOCAL_IPS=($(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'))
    
    log_info "Анализ доступных IP-адресов и порта 443:"
    local i=1
    for ip in "${LOCAL_IPS[@]}"; do
        if ss -tulpn | grep -q "$ip:443"; then
            echo -e "  $i) $ip - ${C_RED}Порт 443 ЗАНЯТ${C_NC}"
        else
            echo -e "  $i) $ip - ${C_GREEN}Порт 443 СВОБОДЕН${C_NC}"
        fi
        ((i++))
    done
    echo -e "  $i) Добавить и использовать НОВЫЙ IP"

    # 2. Выбор IP
    local TARGET_IP=""
    read -p "Выберите номер [1-$i]: " ip_choice

    if [ "$ip_choice" -eq "$i" ]; then
        read -p "Введите новый IPv4 адрес: " NEW_IP
        log_info "Добавление IP $NEW_IP на интерфейс eth0..."
        # Добавляем алиас (в Ubuntu 24.04 это сработает до ребута, для вечности нужно в netplan)
        ip addr add "$NEW_IP/32" dev eth0 || { log_error "Не удалось добавить IP"; return 1; }
        TARGET_IP=$NEW_IP
        log_success "IP $TARGET_IP успешно добавлен."
    else
        TARGET_IP="${LOCAL_IPS[$((ip_choice-1))]}"
    fi

    # 3. Интеграция со сканером SNI (используем уже выбранный TARGET_IP)
    if [ -f "$MODULES_DIR/09_reality_scanner.sh" ]; then
        echo ""
        log_info "Запуск сканера для IP: $TARGET_IP"
        source "$MODULES_DIR/09_reality_scanner.sh"
        # Передаем IP в сканер, чтобы он не спрашивал снова
        export PUBLIC_IPV4=$TARGET_IP
        run_reality_scanner
    fi

    log_section "НАСТРОЙКА FAKE TLS"
    read -p "Введите домен маскировки [github.com]: " PROXY_DOMAIN
    PROXY_DOMAIN=${PROXY_DOMAIN:-github.com}

    log_info "Генерация ключа Fake-TLS..."
    local RAND_HEX=$(head -c 16 /dev/urandom | xxd -p)
    local DOMAIN_HEX=$(echo -n "$PROXY_DOMAIN" | xxd -p | tr -d '\n')
    local PROXY_SECRET="ee${RAND_HEX}${DOMAIN_HEX}"

    # 4. Запуск контейнера с жесткой привязкой к IP
    log_info "Запуск MTProxy Max на $TARGET_IP..."
    docker run -d \
        --name mtproxy-max \
        --restart always \
        -p $TARGET_IP:443:443 \
        -e SECRET=$PROXY_SECRET \
        -e DOMAIN=$PROXY_DOMAIN \
        -e IP=$TARGET_IP \
        samm-git/mtproxy-max:latest 

    if [ $? -eq 0 ]; then
        log_success "MTProxy Max запущен на $TARGET_IP:443"
        echo -e "--------------------------------------------------------"
        echo -e "Ссылка: ${C_CYAN}tg://proxy?server=${TARGET_IP}&port=443&secret=${PROXY_SECRET}${C_NC}"
        echo -e "--------------------------------------------------------"
        
        # Сохраняем в .env для будущего использования
        sed -i "/^MTPROXY_IP=/d" "$ENV_PATH"
        echo "MTPROXY_IP=$TARGET_IP" >> "$ENV_PATH"
    fi
}