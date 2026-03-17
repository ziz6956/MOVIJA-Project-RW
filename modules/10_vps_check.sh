#!/bin/bash
# ==========================================
# Module 10: VPS Check (Fusion Monster / goecs)
# ==========================================

run_vps_check() {
    log_section "ДИАГНОСТИКА VPS (FUSION MONSTER)"
    
    # 1. Проверка и установка зависимости unzip
    if ! command -v unzip &> /dev/null; then
        log_info "Установка unzip для распаковки сканера..."
        apt-get update -y -qq > /dev/null
        apt-get install -y unzip -qq > /dev/null
    fi

    # 2. Проверка наличия goecs в системе
    if ! command -v goecs &> /dev/null; then
        log_info "goecs не найден. Начинаем установку..."
        
        # Скачиваем загрузчик во временную папку
        local TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR"
        
        export noninteractive=true
        curl -L https://cdn.spiritlhl.net/https://raw.githubusercontent.com/oneclickvirt/ecs/master/goecs.sh -o goecs.sh
        chmod +x goecs.sh
        
        # Инсталлятор сам скачает нужный бинарник и положит его в PATH
        ./goecs.sh install > /dev/null 2>&1
        
        cd "$WORK_DIR"
        rm -rf "$TMP_DIR"
        
        log_success "goecs успешно установлен."
    fi

    log_info "Запуск интерактивного меню на английском языке..."
    # Запускаем с флагом английского языка
    sudo goecs -l en
}