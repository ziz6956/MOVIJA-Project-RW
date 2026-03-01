#!/bin/bash
# ==========================================
# MOVIJA-Project-RW: Main Orchestrator
# ==========================================

# Включаем Bash Strict Mode для отлова скрытых ошибок
set -euo pipefail

# Глобальные переменные путей
export WORK_DIR=$(pwd)
export MODULES_DIR="$WORK_DIR/modules"
export CONFIGS_DIR="$WORK_DIR/configs"

# 1. Подключение логгера (Критически важно для вывода)
if [ -f "$MODULES_DIR/00_logger.sh" ]; then
    source "$MODULES_DIR/00_logger.sh"
else
    echo -e "\033[0;31m[ERROR]\033[0m Файл логгера $MODULES_DIR/00_logger.sh не найден! Выход."
    exit 1
fi

log_section "СТАРТ УСТАНОВКИ MOVIJA-Project-RW"
log_info "Рабочая директория: $WORK_DIR"

# 2. Подключение модулей
source "$MODULES_DIR/01_preflight_checks.sh"
source "$MODULES_DIR/02_user_management.sh"
source "$MODULES_DIR/03_security_setup.sh"
source "$MODULES_DIR/04_system_optimize.sh"
source "$MODULES_DIR/05_docker_install.sh"
source "$MODULES_DIR/06_env_generator.sh"
source "$MODULES_DIR/07_deploy_cluster.sh"

# 3. Выполнение пайплайна
run_preflight_checks
run_user_management
run_security_setup
run_system_optimize
run_docker_install
run_env_generator
run_deploy_cluster

log_success "Инициализация базового окружения завершена."

# 4. Временный вывод доступов для проверки
log_section "ТЕСТОВЫЙ ВЫВОД СГЕНЕРИРОВАННЫХ ДАННЫХ"
log_info "Новый SSH порт: $SSH_PORT"
log_info "Пользователь: $NEW_USER"
log_info "Пароль пользователя: $USER_PASS"
log_info "Новый пароль root: $ROOT_PASS"
log_info "Порт панели VPN: $PANEL_PORT"