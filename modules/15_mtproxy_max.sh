#!/bin/bash

# Функция запуска модуля
run_mtproxy_max_module() {
    log_section "УСТАНОВКА MTPROXY MAX"

    # Определяем активный сетевой интерфейс (обычно eth0, но скрипт найдет точный)
    local DEFAULT_IFACE=$(ip route get 8.8.8.8 | grep -Po '(?<=dev )(\S+)' | head -1)
    if [ -z "$DEFAULT_IFACE" ]; then
        DEFAULT_IFACE="eth0"
    fi

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

    # 2. Выбор IP и автоматизация Netplan
    local TARGET_IP=""
    local ip_choice
    read -p "Выберите номер [1-$i]: " ip_choice

    if [ "$ip_choice" -eq "$i" ]; then
        read -p "Введите новый IPv4 адрес (например, 89.125.137.60): " NEW_IP
        log_info "Добавление IP $NEW_IP на интерфейс $DEFAULT_IFACE..."
        
        # Временное добавление (чтобы инсталлятор сразу увидел IP)
        ip addr add "$NEW_IP/32" dev "$DEFAULT_IFACE" 2>/dev/null
        
        # АВТОМАТИЗАЦИЯ NETPLAN: Создаем drop-in конфиг
        log_info "Создание конфигурации Netplan для сохранения IP..."
        local NETPLAN_FILE="/etc/netplan/99-custom-ip-${NEW_IP//./_}.yaml"
        
        cat <<EOF | sudo tee "$NETPLAN_FILE" > /dev/null
network:
  version: 2
  ethernets:
    $DEFAULT_IFACE:
      addresses:
      - $NEW_IP/32
EOF

        echo -e "${C_YELLOW}Сейчас запустится тестирование сети (netplan try).${C_NC}"
        echo -e "${C_YELLOW}Если вы не потеряли связь с сервером, нажмите ENTER для подтверждения!${C_NC}"
        echo ""
        sudo netplan try
        
        TARGET_IP=$NEW_IP
        log_success "IP $TARGET_IP успешно добавлен и закреплен в системе."
    else
        TARGET_IP="${LOCAL_IPS[$((ip_choice-1))]}"
    fi

    # 3. Открытие порта 443 специально для выбранного IP
    log_info "Настройка UFW: открываем порт 443 для $TARGET_IP..."
    ufw allow from any to $TARGET_IP port 443 proto tcp comment "MTProxy Max - $TARGET_IP"
    ufw reload > /dev/null

    # 4. Интеграция со сканером SNI
    if [ -f "$MODULES_DIR/09_reality_scanner.sh" ]; then
        echo ""
        log_info "Запуск сканера доноров для IP: $TARGET_IP"
        source "$MODULES_DIR/09_reality_scanner.sh"
        export PUBLIC_IPV4=$TARGET_IP
        run_reality_scanner
        
        echo ""
        echo -e "${C_YELLOW}!!! ВНИМАНИЕ ПЕРЕД УСТАНОВКОЙ !!!${C_NC}"
        echo -e "1. Скопируйте подходящий домен-донор (например, github.com) для Fake-TLS."
        echo -e "2. В синем меню установщика ${C_RED}ОБЯЗАТЕЛЬНО укажите порт 443${C_NC}."
        echo -e "   (Именно этот порт мы только что открыли в фаерволе)."
        echo ""
        read -n 1 -s -r -p "Нажмите любую клавишу, когда будете готовы перейти к установке..."
        echo ""
    else
        log_warn "Модуль 09_reality_scanner.sh не найден. Пропускаем поиск доноров."
    fi

    # 5. Установка в чистую директорию
    log_info "Загрузка официального инсталлятора..."
    local WORK_DIR="/tmp/mtproxy_install_$(date +%s)"
    mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

    wget -q https://raw.githubusercontent.com/samnet-dev/mtproxymax/main/install.sh -O install.sh
    chmod +x install.sh

    log_info "Запуск интерактивной установки..."
    ./install.sh

    # 6. Очистка временных файлов
    cd "$PROJECT_ROOT"
    rm -rf "$WORK_DIR"

    log_success "Модуль установки MTProxy Max завершил работу."
    
    # 7. Финальные инструкции
    echo ""
    echo -e "${C_GREEN}✅ Установка завершена.${C_NC}"
    echo -e "Проверьте статус службы командой: ${C_YELLOW}systemctl status mtproxymax${C_NC}"
    
    # Предупреждение о Prometheus
    echo -e ""
    echo -e "${C_CYAN}📊 Интеграция с Prometheus:${C_NC}"
    echo -e "По умолчанию метрики доступны на порту 9090. Если у вас уже работает"
    echo -e "основной Prometheus, измените порт в файле ${C_YELLOW}/opt/mtproxymax/settings.conf${C_NC}"
    echo -e "на другой (например, 9091) и выполните: systemctl restart mtproxymax"
    echo -e "📖 Документация: ${C_CYAN}https://github.com/SamNet-dev/MTProxyMax${C_NC}"
    echo ""
}

run_mtproxy_max_module