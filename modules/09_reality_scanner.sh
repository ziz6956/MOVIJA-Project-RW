#!/bin/bash
# ==========================================
# Module 09: Reality Scanner (XTLS/RealiTLScanner)
# ==========================================

run_reality_scanner() {
    log_section "ПОИСК ОПТИМАЛЬНОГО SNI ДЛЯ REALITY"
    log_info "Инициализация сканера (XTLS/RealiTLScanner)..."

    # Создаем временную директорию
    local SCAN_DIR=$(mktemp -d)
    cd "$SCAN_DIR"

    log_info "Определение последней версии..."
    local VERSION=$(curl -sL -o /dev/null -w %{url_effective} https://github.com/XTLS/RealiTLScanner/releases/latest | grep -oE "[^/]+$")
    
    if [ -z "$VERSION" ]; then
        log_error "Не удалось получить версию сканера через GitHub API. Проверьте сеть."
        cd "$WORK_DIR"
        return 1
    fi
    
    log_info "Загрузка XTLS/RealiTLScanner ${VERSION}..."
    wget -q --show-progress -O RealiTLScanner-linux-64 "https://github.com/XTLS/RealiTLScanner/releases/download/${VERSION}/RealiTLScanner-linux-64"
    chmod +x RealiTLScanner-linux-64

    log_info "Определение IPv4 адресов сервера..."

    # Получаем список локальных белых IPv4 (исключаем локалхост 127.x и серые сети 10.x, 172.16-31.x, 192.168.x)
    # Команда ip вытягивает адреса прямо из активных интерфейсов (что надежнее чтения YAML)
    local LOCAL_IPS=($(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'))
    local PUBLIC_IPV4=""

    if [ ${#LOCAL_IPS[@]} -eq 1 ]; then
        # Нашли ровно один IP
        PUBLIC_IPV4="${LOCAL_IPS[0]}"
        log_info "Обнаружен локальный IPv4: ${PUBLIC_IPV4}"

    elif [ ${#LOCAL_IPS[@]} -gt 1 ]; then
        # Нашли несколько IP — предлагаем выбор
        log_info "Обнаружено несколько IPv4 интерфейсов:"
        local i=1
        for ip in "${LOCAL_IPS[@]}"; do
            echo "  $i) $ip"
            ((i++))
        done
        
        while true; do
            read -p "Выберите IP для сканирования подсети [1-${#LOCAL_IPS[@]}]: " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#LOCAL_IPS[@]}" ]; then
                PUBLIC_IPV4="${LOCAL_IPS[$((choice-1))]}"
                log_info "Выбран IP: $PUBLIC_IPV4"
                break
            else
                log_error "Неверный выбор. Введите число от 1 до ${#LOCAL_IPS[@]}."
            fi
        done

    else
        # IP не найдены локально (например, сервер за NAT) — используем старую логику
        log_warn "Локальные публичные IPv4 не найдены. Обращение к внешнему сервису (icanhazip)..."
        PUBLIC_IPV4=$(curl -4 -s --max-time 3 icanhazip.com || echo "")
    fi

    if [ -z "$PUBLIC_IPV4" ]; then
        log_error "Критическая ошибка: не удалось определить внешний IPv4 адрес."
        cd "$WORK_DIR"
        rm -rf "$SCAN_DIR" # Не забываем убирать за собой даже при ошибке
        return 1
    fi

    # Вычисляем подсеть /24 для маскировки под соседей
    local SUBNET=$(echo "$PUBLIC_IPV4" | cut -d. -f1-3)".0/24"
    
    log_info "Запуск сканирования подсети $SUBNET (Таймаут: 5с)..."
    log_warn "Процесс займет около 10-15 секунд, пожалуйста, подождите..."
    
    # Запуск сканера
    ./RealiTLScanner-linux-64 -addr "$SUBNET" -thread 100 -timeout 5 -out scan_results.csv > /dev/null 2>&1
    
    if [ -f "scan_results.csv" ]; then
        echo -e "\n\033[0;32mТоп рекомендуемых доменов (SNI) из вашей подсети:\033[0m"
        echo -e "IP Address \t\t SNI Domain"
        echo -e "--------------------------------------------------"
        
        # Берем 1-ю (IP) и 3-ю (Домен) колонки. Фильтруем мусор.
        tail -n +2 scan_results.csv | awk -F, '{printf "%-18s %s\n", $1, $3}' | grep -vE '\*\.|sni-.*fastly|vpngemini|toy2025|userapi|porridge|netlify' | head -n 10
        
        echo -e "\n\033[0;33m[СОВЕТ]\033[0m Выберите один из крупных доменов (например, Apple, Microsoft, Google)."
        echo -e "Укажите его в веб-панели Remnawave в полях 'Dest' (с портом :443) и 'Server Names'."
    else
         log_warn "Подходящие домены не найдены. Используйте стандартные SNI (например, images.apple.com)."
    fi
    
    # Удаляем временную папку и возвращаемся
    cd "$WORK_DIR"
    rm -rf "$SCAN_DIR"
    log_success "Работа сканера завершена."
}