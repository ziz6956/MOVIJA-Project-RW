#!/bin/bash
# ==========================================
# MOVIJA-Project-RW: Node Orchestrator
# ==========================================

set -euo pipefail

export INSTALL_TYPE="node"
export WORK_DIR=$(pwd)
export MODULES_DIR="$WORK_DIR/modules"
export CONFIGS_DIR="$WORK_DIR/configs"
export NODE_TEMPLATE_DIR="$WORK_DIR/node"
export PROJECT_DIR="/opt/remnanode"
export ENV_PATH="$PROJECT_DIR/.env"
export COMPOSE_DIR="$PROJECT_DIR"

if [ ! -d "$MODULES_DIR" ] || [ ! -f "$MODULES_DIR/00_logger.sh" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m Файл логгера не найден в $MODULES_DIR!"
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
                log_error "Утилита $dep не найдена."
                exit 1
            fi
        fi
    done
}

show_node_menu() {
    log_section "ГЛАВНОЕ МЕНЮ (УЗЕЛ / НОДА)"
    echo "1) Полная установка узла (на чистую Ubuntu)"
    echo "2) Только бэкап сертификатов (создать архив с хешем)"
    echo "3) Только восстановление сертификатов (из архива)"
    echo "4) Поиск лучшего SNI для Reality (Сканер)"
    echo "5) Диагностика VPS (Fusion Monster / goecs)"
    echo "6) Информация об анализаторе логов (Xray Log Analyzer)"
    echo "7) Установить Telegram MTProto Proxy (Fake-TLS)"
    echo "8) Запустить WARP & Tor Manager от dignezzz (создание интерфейса)"
    echo "9) Настроить WARP SOCKS Bridge (для Google/OpenAI)"
    echo "10) Установить MTProxy Max (Модуль 15 - Тестовый)"
    echo "11) Патч MTProxy Max (Модуль 16 - Тестовый)"
    echo "12) Выход"
    echo -e "------------------------------------------"
    read -p "Выберите действие [1-12]: " main_choice

    case $main_choice in
        1) run_full_node_install ;;
        2) source "$MODULES_DIR/08_backup_manager.sh"; create_certificates_backup ;;
        3) source "$MODULES_DIR/08_backup_manager.sh"; restore_certificates ;;
        4) source "$MODULES_DIR/09_reality_scanner.sh"; run_reality_scanner ;;
        5) source "$MODULES_DIR/10_vps_check.sh"; run_vps_check ;;
        6) source "$MODULES_DIR/11_xray_analyzer.sh"; run_log_analyzer_info ;;        
        7) source "$MODULES_DIR/12_mtproto_proxy.sh"; run_mtproto_install ;;
        8) echo -e "\n[INFO] Скачивание и запуск WARP & Tor Manager..."
        wget -O wtm.sh https://raw.githubusercontent.com/dignezzz/remnawave-scripts/main/wtm.sh && chmod +x wtm.sh && ./wtm.sh
        ;;
        9) source "$MODULES_DIR/14_warp_bridge.sh"; run_warp_bridge_setup ;;
        10) source "$MODULES_DIR/15_mtproxy_max.sh"; run_mtproxy_max_install ;;
        11) source "$MODULES_DIR/16_patch_mtproxy.sh"; run_mtproxy_patch ;;
        12) exit 0 ;;
        *) show_node_menu ;;
    esac
}

run_node_prepare() {
    log_section "ПОДГОТОВКА ФАЙЛОВ НОДЫ"
    mkdir -p "$PROJECT_DIR"
    cp "$NODE_TEMPLATE_DIR/docker-compose.yml" "$PROJECT_DIR/"
    cp "$NODE_TEMPLATE_DIR/Caddyfile" "$PROJECT_DIR/"
    if [ -d "$NODE_TEMPLATE_DIR/cabinet" ]; then
        cp -r "$NODE_TEMPLATE_DIR/cabinet" "$PROJECT_DIR/"
    fi
    
    log_info "Генерация финального .env..."
    cat <<EOF > "$ENV_PATH"
NODE_IP=$NODE_IP
MTPROXY_IP=$MTPROXY_IP
SUB_DOMAIN=$SUB_DOMAIN
CABINET_DOMAIN=$CABINET_DOMAIN
PANEL_URL=$PANEL_URL
REMNAWAVE_API_TOKEN=$REMNAWAVE_API_TOKEN
NODE_SECRET_KEY=$NODE_SECRET
SUB_PORT=$SUB_PORT
EOF
}

run_full_node_install() {
    source "$MODULES_DIR/01_preflight_checks.sh"
    source "$MODULES_DIR/02_user_management.sh"
    source "$MODULES_DIR/03_security_setup.sh"
    source "$MODULES_DIR/04_system_optimize.sh"
    source "$MODULES_DIR/05_docker_install.sh"
    source "$MODULES_DIR/06_env_generator.sh"
    source "$MODULES_DIR/07_deploy_cluster.sh"
    source "$MODULES_DIR/08_backup_manager.sh"
    source "$MODULES_DIR/14_warp_bridge.sh"

    run_preflight_checks
    run_env_generator
    run_user_management
    run_security_setup
    run_system_optimize
    run_docker_install
    run_node_prepare
    run_backup_logic
    run_deploy_cluster

    # 3. Финальное уведомление вместо автоматического запуска
    echo -e "\n"
    log_section "УСТАНОВКА УЗЛА ЗАВЕРШЕНА УСПЕШНО!"
    
    echo -e "\033[1;32m✅ Все основные компоненты и Docker-контейнеры запущены.\033[0m"
    echo -e "----------------------------------------------------------------------"
    echo -e "\033[1;33m[ВАЖНО] СЛЕДУЮЩИЕ ШАГИ ДЛЯ НАСТРОЙКИ ОБХОДА БЛОКИРОВОК:\033[0m"
    echo -e "Для того чтобы OpenAI и Google работали корректно, выполните вручную:"
    echo -e ""
    echo -e "  1) Выберите пункт \033[1;36m8\033[0m в меню (Запустить WARP & Tor Manager от dignezzz (создание интерфейса))."
    echo -e "     (Следуйте инструкциям WTM для регистрации Free-аккаунта)."
    echo -e ""
    echo -e "  2) После успешного запуска WARP выберите пункт \033[1;36m9\033[0m (Настроить WARP SOCKS Bridge (для Google/OpenAI))."
    echo -e "     (Это свяжет Docker-контейнеры с туннелем Cloudflare)."
    echo -e "----------------------------------------------------------------------"
    echo -e "\nНажмите Enter, чтобы вернуться в главное меню..."
    read -r
}

check_dependencies
show_node_menu