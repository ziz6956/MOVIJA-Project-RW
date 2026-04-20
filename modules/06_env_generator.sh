#!/bin/bash
# ==========================================
# Module 06: Environment Generator (Updated)
# ==========================================

run_env_generator() {
    if [ "$INSTALL_TYPE" == "panel" ]; then
        # Твой существующий код для ПАНЕЛИ остается без изменений
        log_section "5. КОНФИГУРАЦИЯ ПАНЕЛИ (.env)"
        # ... (код панели) ...
        log_success "Файл .env для панели успешно сгенерирован."

    elif [ "$INSTALL_TYPE" == "node" ]; then
        log_section "5. СБОР ДАННЫХ ДЛЯ НОДЫ И СЕТИ"
        
        # Поиск всех публичных IPv4
        local LOCAL_IPS=($(ip -4 addr show scope global | grep inet | awk '{ print $2 }' | cut -d/ -f1 | grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'))
        
        if [ ${#LOCAL_IPS[@]} -eq 0 ]; then
            log_error "Публичные IPv4 не найдены. Введите IP вручную."
            read -p "🔹 Основной IP для ноды: " NODE_IP
            read -p "🔹 IP для MTProxy Max: " MTPROXY_IP
        elif [ ${#LOCAL_IPS[@]} -eq 1 ]; then
            log_info "Обнаружен один IP: ${LOCAL_IPS[0]}"
            NODE_IP=${LOCAL_IPS[0]}
            MTPROXY_IP=${LOCAL_IPS[0]}
            log_warn "Внимание: Для разделения трафика рекомендуется иметь 2 разных IPv4."
        else
            echo -e "Обнаружены следующие IP-адреса:"
            for i in "${!LOCAL_IPS[@]}"; do
                echo "  $((i+1))) ${LOCAL_IPS[$i]}"
            done
            
            read -p "Выберите номер IP для ноды Remnawave [1]: " choice1
            choice1=${choice1:-1}
            NODE_IP=${LOCAL_IPS[$((choice1 - 1))]}
            
            read -p "Выберите номер IP для MTProxy Max [2]: " choice2
            choice2=${choice2:-2}
            # Если выбран индекс больше доступного, берем первый IP
            MTPROXY_IP=${LOCAL_IPS[$((choice2 - 1))]:-${LOCAL_IPS[0]}}
        fi

        export NODE_IP MTPROXY_IP
        log_success "Сетевые настройки: Node ($NODE_IP), MTProxy ($MTPROXY_IP)"

        # Сбор остальных данных
        read -p "🔹 Имя хоста ноды [vpn-node]: " INPUT_HOSTNAME
        export NODE_HOSTNAME=${INPUT_HOSTNAME:-vpn-node}
        hostnamectl set-hostname "$NODE_HOSTNAME"

        read -p "🔹 IP основной ПАНЕЛИ: " PANEL_IP
        export PANEL_IP

        read -p "🔹 Секретный ключ ноды (SECRET_KEY): " NODE_SECRET
        export NODE_SECRET

        read -p "🔹 URL основной панели (напр. https://panel.site.ru:14732): " PANEL_URL
        export PANEL_URL

        read -p "🔹 API-токен панели: " REMNAWAVE_API_TOKEN
        export REMNAWAVE_API_TOKEN

        read -p "🔹 Домен подписок: " SUB_DOMAIN
        export SUB_DOMAIN

        read -p "🔹 Домен кабинета: " CABINET_DOMAIN
        export CABINET_DOMAIN

        local CF_PORTS=(2053 2083 2087 2096 8443)
        export SUB_PORT=${CF_PORTS[$((RANDOM % ${#CF_PORTS[@]}))]}
        log_info "Сгенерирован порт подписок: $SUB_PORT"
    fi
}