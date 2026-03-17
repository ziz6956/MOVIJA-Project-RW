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

    local PUBLIC_IPV4=$(curl -4 -s icanhazip.com || echo "")
    if [ -z "$PUBLIC_IPV4" ]; then
        log_error "Не удалось определить внешний IPv4 адрес сервера."
        cd "$WORK_DIR"
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
        # Читаем результаты, убираем заголовок и мусорные домены
        tail -n +2 scan_results.csv | awk -F, '{print $1 "\t" $5}' | grep -vE '\*\.|sni-.*fastly|vpngemini|toy2025|userapi|porridge|netlify' | head -n 10
        
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