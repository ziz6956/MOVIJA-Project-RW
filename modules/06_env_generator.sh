#!/bin/bash
# ==========================================
# Module 06: Environment Generator (Fixed)
# ==========================================

run_env_generator() {
    if [ "$INSTALL_TYPE" == "panel" ]; then
        log_section "5. КОНФИГУРАЦИЯ ПАНЕЛИ (.env)"
        # ... (код панели остается без изменений) ...
        log_success "Файл .env для панели успешно сгенерирован."

    elif [ "$INSTALL_TYPE" == "node" ]; then
        log_section "5. СБОР ДАННЫХ ДЛЯ НОДЫ И СЕТИ"
        
        # Поиск всех публичных IPv4
        local LOCAL_IPS=($(ip -4 addr show scope global | grep inet | awk '{ print $2 }' | cut -d/ -f1 | grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'))
        
        if [ ${#LOCAL_IPS[@]} -eq 0 ]; then
            log_error "Публичные IPv4 не найдены. Введите IP вручную."
            read -p "🔹 IP для управления (SSH / API панели): " MANAGEMENT_IP
            read -p "🔹 IP для работы VPN (Xray Node): " NODE_IP
            read -p "🔹 IP для MTProxy Max: " MTPROXY_IP
        else
            echo -e "Обнаружены следующие IP-адреса в системе:"
            for i in "${!LOCAL_IPS[@]}"; do
                echo "  $((i+1))) ${LOCAL_IPS[$i]}"
            done
            echo "------------------------------------------"

            # 1. Выбор Management IP
            while true; do
                read -p "Выберите номер IP для УПРАВЛЕНИЯ (SSH, Caddy API, связь с панелью) [1]: " m_choice
                m_choice=${m_choice:-1}
                if [[ "$m_choice" =~ ^[0-9]+$ ]] && [ "$m_choice" -ge 1 ] && [ "$m_choice" -le "${#LOCAL_IPS[@]}" ]; then
                    MANAGEMENT_IP=${LOCAL_IPS[$((m_choice - 1))]}
                    break
                else
                    log_error "Неверный выбор. Введите число от 1 до ${#LOCAL_IPS[@]}."
                fi
            done

            # 2. Выбор Node IP
            while true; do
                read -p "Выберите номер IP для работы VPN (Xray / Нода) [1]: " n_choice
                n_choice=${n_choice:-1}
                if [[ "$n_choice" =~ ^[0-9]+$ ]] && [ "$n_choice" -ge 1 ] && [ "$n_choice" -le "${#LOCAL_IPS[@]}" ]; then
                    NODE_IP=${LOCAL_IPS[$((n_choice - 1))]}
                    break
                else
                    log_error "Неверный выбор. Введите число от 1 до ${#LOCAL_IPS[@]}."
                fi
            done

            # 3. Выбор MTProxy IP
            while true; do
                read -p "Выберите номер IP для MTProxy Max [2]: " mt_choice
                mt_choice=${mt_choice:-2}
                # Защита на случай, если в системе всего 1 IP
                if [ "$mt_choice" -gt "${#LOCAL_IPS[@]}" ]; then mt_choice=1; fi
                
                if [[ "$mt_choice" =~ ^[0-9]+$ ]] && [ "$mt_choice" -ge 1 ] && [ "$mt_choice" -le "${#LOCAL_IPS[@]}" ]; then
                    MTPROXY_IP=${LOCAL_IPS[$((mt_choice - 1))]}
                    break
                else
                    log_error "Неверный выбор. Введите число от 1 до ${#LOCAL_IPS[@]}."
                fi
            done
        fi

        export MANAGEMENT_IP NODE_IP MTPROXY_IP
        log_success "Сетевые настройки распределены:"
        echo -e "  » IP Управления (SSH/Caddy): \033[1;32m$MANAGEMENT_IP\033[0m"
        echo -e "  » IP VPN Ноды (Xray):        \033[1;36m$NODE_IP\033[0m"
        echo -e "  » IP MTProxy Max:            \033[1;35m$MTPROXY_IP\033[0m"

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