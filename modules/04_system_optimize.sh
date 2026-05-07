#!/bin/bash
# ==========================================
# Module 04: System Optimization & Swap
# ==========================================

run_system_optimize() {
    log_section "3. НАСТРОЙКА SWAP И ОПТИМИЗАЦИЯ ЯДРА"

    # 1. Настройка SWAP-файла (2 ГБ)
    log_info "Проверка SWAP-файла..."
    if free | awk '/^Swap:/ {exit !$2}'; then
        log_warn "SWAP уже существует. Пропускаем создание..."
    else
        log_info "Создание SWAP-файла на 2GB..."
        if fallocate -l 2G /swapfile 2>/dev/null; then
            log_success "SWAP файл выделен через fallocate."
        else
            log_warn "fallocate не удался, используем dd (это займет время)..."
            dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
            log_success "SWAP файл выделен через dd."
        fi
        
        chmod 600 /swapfile
        mkswap /swapfile > /dev/null
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        log_success "SWAP успешно создан и активирован."
    fi

    # 2. Оптимизация ядра
    log_info "Применение параметров sysctl (BBR, TCP, Swap)..."
    cp "$CONFIGS_DIR/system/99-custom-tuning.conf" /etc/sysctl.d/99-custom-tuning.conf
    sysctl -p /etc/sysctl.d/99-custom-tuning.conf > /dev/null 2>&1
    log_success "Оптимизация ядра завершена."

    # 3. Настройка лимитов открытых файлов (Защита от Too many open files)
    log_info "Установка системных лимитов (limits.conf)..."
    
    # Очищаем старые записи, если они были, и записываем новые
    sed -i '/nofile/d' /etc/security/limits.conf
    cat <<EOF >> /etc/security/limits.conf
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF
    log_success "Лимиты файловых дескрипторов увеличены до 65535."
}