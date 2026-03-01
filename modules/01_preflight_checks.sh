#!/bin/bash
# ==========================================
# Module 01: Preflight Checks
# ==========================================

run_preflight_checks() {
    log_section "0. ПРЕДВАРИТЕЛЬНЫЕ ПРОВЕРКИ"

    # Проверка прав суперпользователя
    if [ "$EUID" -ne 0 ]; then
        log_error "Пожалуйста, запустите скрипт с правами root (например: sudo bash setup.sh)"
        exit 1
    fi
    log_success "Права root подтверждены."

    # Проверка наличия необходимых базовых утилит
    local required_cmds=("curl" "openssl" "awk" "grep" "ss")
    local missing_cmds=()

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [ ${#missing_cmds[@]} -ne 0 ]; then
        log_warn "Не найдены утилиты: ${missing_cmds[*]}. Попытка установки..."
        apt-get update -y -qq > /dev/null
        apt-get install -y "${missing_cmds[@]}" -qq > /dev/null || {
            log_error "Не удалось установить базовые зависимости. Проверьте подключение к сети."
            exit 1
        }
        log_success "Отсутствующие утилиты установлены."
    else
        log_success "Базовые зависимости в наличии."
    fi
}