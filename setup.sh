#!/bin/bash
# ==========================================
# MOVIJA-Project-RW: Smart Orchestrator
# ==========================================

set -euo pipefail

# Глобальные переменные
export INSTALL_TYPE="panel"
export WORK_DIR=$(dirname "$(readlink -f "$0")")
export MODULES_DIR="$WORK_DIR/modules"
export CONFIGS_DIR="$WORK_DIR/configs"
export ENV_PATH="$WORK_DIR/.env"
export COMPOSE_DIR="$WORK_DIR"

# Выдаем права на исполнение всем модулям
chmod +x "$MODULES_DIR"/*.sh

# 1. Проверка целостности самого репозитория
if [ ! -d "$MODULES_DIR" ] || [ ! -f "$MODULES_DIR/00_logger.sh" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m Папка modules или логгер не найдены! Проверьте файлы."
    exit 1
fi

source "$MODULES_DIR/00_logger.sh"

check_dependencies() {
    log_info "Проверка системных зависимостей..."
    local deps=("sha256sum" "tar" "docker" "curl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            if [ "$dep" == "docker" ]; then
                log_warn "Docker не установлен. Режим полного развертывания сам установит его."
            else
                log_error "Утилита $dep не найдена. Попробуйте: apt-get install coreutils"
                exit 1
            fi
        fi
    done
}

show_menu() {
    log_section "ГЛАВНОЕ МЕНЮ MOVIJA-Project-RW"
    echo "1) Полная установка панели (на чистую Ubuntu)"
    echo "2) Установить Telegram-бота Bedolaga (к уже работающей панели)"
    echo "3) Только бэкап сертификатов (создать архив с хешем)"
    echo "4) Только восстановление сертификатов (из архива)"
    echo "5) Выход"
    echo -e "------------------------------------------"
    read -p "Выберите действие [1-5]: " main_choice

    case $main_choice in
        1) run_full_install ;;
        2) source "$MODULES_DIR/13_bedolaga_install.sh"; run_bot_install ;;
        3) source "$MODULES_DIR/08_backup_manager.sh"; create_certificates_backup ;;
        4) source "$MODULES_DIR/08_backup_manager.sh"; restore_certificates ;;
        5) log_info "Выход."; exit 0 ;;
        *) log_error "Неверный выбор."; show_menu ;;
    esac
}

run_full_install() {
    source "$MODULES_DIR/01_preflight_checks.sh"
    source "$MODULES_DIR/02_user_management.sh"
    source "$MODULES_DIR/03_security_setup.sh"
    source "$MODULES_DIR/04_system_optimize.sh"
    source "$MODULES_DIR/05_docker_install.sh"
    source "$MODULES_DIR/06_env_generator.sh"
    source "$MODULES_DIR/07_deploy_cluster.sh"
    source "$MODULES_DIR/08_backup_manager.sh"

    run_preflight_checks
    run_user_management
    run_security_setup
    run_system_optimize
    run_docker_install
    run_env_generator
    run_backup_logic 
    run_deploy_cluster
}

check_dependencies
show_menu