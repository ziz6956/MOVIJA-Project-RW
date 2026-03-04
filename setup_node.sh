#!/bin/bash
# ==========================================
# MOVIJA-Project-RW: Node Orchestrator (Stable NYC Edition)
# ==========================================

set -euo pipefail

export WORK_DIR=$(pwd)
export MODULES_DIR="$WORK_DIR/modules"
export NODE_TEMPLATE_DIR="$WORK_DIR/node"
export PROJECT_DIR="/opt/remnanode"

# 1. Подключение логгера
if [ -f "$MODULES_DIR/00_logger.sh" ]; then
    source "$MODULES_DIR/00_logger.sh"
else
    echo -e "\033[0;31m[ERROR]\033[0m Файл логгера не найден в $MODULES_DIR!"
    exit 1
fi

# 2. Подключение установки Docker
if [ -f "$MODULES_DIR/05_docker_install.sh" ]; then
    source "$MODULES_DIR/05_docker_install.sh"
else
    log_error "Модуль установки Docker не найден!"
    exit 1
fi

run_node_preflight() {
    log_section "1. БАЗОВЫЕ ПРОВЕРКИ И НАСТРОЙКИ"
    if [ "$EUID" -ne 0 ]; then
        log_error "Запустите скрипт от имени root (sudo)."
        exit 1
    fi
    log_info "Обновление системы и установка зависимостей..."
    apt-get update -qq && apt-get install -y -qq curl wget git nano ufw fail2ban iptables logrotate > /dev/null
    log_success "Подготовка завершена."
}

run_node_input() {
    log_section "2. СБОР ДАННЫХ ДЛЯ НОДЫ"
    
    local RANDOM_SSH=$(shuf -i 10000-60000 -n 1)
    
    read -p "🔹 Имя хоста ноды [по умолчанию vpn-node]: " INPUT_HOSTNAME
    export NODE_HOSTNAME=${INPUT_HOSTNAME:-vpn-node}

    read -p "🔹 Новый SSH порт [по умолчанию $RANDOM_SSH]: " INPUT_SSH_PORT
    export SSH_PORT=${INPUT_SSH_PORT:-$RANDOM_SSH}

    read -p "🔹 IP основной ПАНЕЛИ (для доступа к API 2222): " PANEL_IP
    export PANEL_IP

    read -p "🔹 Секретный ключ ноды (NODE_SECRET_KEY): " NODE_SECRET
    export NODE_SECRET

    read -p "🔹 URL основной панели (напр. https://panel.site.ru): " PANEL_URL
    export PANEL_URL

    read -p "🔹 API-токен панели (Settings -> API Tokens): " INPUT_API_TOKEN
    export REMNAWAVE_API_TOKEN=${INPUT_API_TOKEN}

    read -p "🔹 Домен подписок (напр. sub.site.ru): " SUB_DOMAIN
    export SUB_DOMAIN

    read -p "🔹 Домен кабинета (напр. cabinet.site.ru): " CABINET_DOMAIN
    export CABINET_DOMAIN
}

run_node_security() {
    log_section "3. НАСТРОЙКА БЕЗОПАСНОСТИ"

    log_info "Маскировка Hostname..."
    hostnamectl set-hostname "$NODE_HOSTNAME"
    
    log_info "Перенос SSH на порт $SSH_PORT..."
    sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    systemctl restart ssh

    log_info "Настройка Firewall (UFW)..."
    ufw --force reset > /dev/null
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "$SSH_PORT"/tcp comment 'Custom SSH'
    ufw allow 80/tcp comment 'Caddy HTTP'
    ufw allow 443/tcp comment 'Caddy HTTPS'
    ufw allow 443/udp comment 'Caddy HTTP3'
    
    if [ -n "${PANEL_IP:-}" ]; then
        ufw allow from "$PANEL_IP" to any port 2222 proto tcp comment 'Panel Access'
    fi
    ufw --force enable > /dev/null
    log_success "Безопасность и Firewall настроены."
}

run_node_deploy() {
    log_section "4. РАЗВЕРТЫВАНИЕ ПРОЕКТА"
    
    log_info "Создание директории $PROJECT_DIR..."
    mkdir -p "$PROJECT_DIR"
    
    log_info "Копирование конфигураций..."
    # Убедись, что эти файлы лежат в твоей папке node/ внутри репозитория
    cp "$NODE_TEMPLATE_DIR/docker-compose.yml" "$PROJECT_DIR/"
    cp "$NODE_TEMPLATE_DIR/Caddyfile" "$PROJECT_DIR/"
    
    # Если папка cabinet существует, копируем её
    if [ -d "$NODE_TEMPLATE_DIR/cabinet" ]; then
        cp -r "$NODE_TEMPLATE_DIR/cabinet" "$PROJECT_DIR/"
    fi

    log_info "Генерация финального .env..."
    cat <<EOF > "$PROJECT_DIR/.env"
SUB_DOMAIN=$SUB_DOMAIN
CABINET_DOMAIN=$CABINET_DOMAIN
PANEL_URL=$PANEL_URL
REMNAWAVE_API_TOKEN=$REMNAWAVE_API_TOKEN
NODE_SECRET_KEY=$NODE_SECRET
EOF

    log_info "Запуск Docker Compose..."
    cd "$PROJECT_DIR"
    docker compose up -d --remove-orphans
    log_success "Узел успешно запущен!"
}

# --- ЗАПУСК ПАЙПЛАЙНА ---
run_node_preflight
run_node_input
run_node_security
run_docker_install
run_node_deploy

PUBLIC_IP=$(curl -s ifconfig.me)
log_section "ИТОГОВЫЕ ДАННЫЕ УЗЛА"
echo -e "🔗 Страница подписок: https://$SUB_DOMAIN"
echo -e "🔗 Личный кабинет:   https://$CABINET_DOMAIN"
echo -e "----------------------------------------------------"
echo -e "🔑 SSH порт:         $SSH_PORT"
echo -e "🏠 Директория:       $PROJECT_DIR"
echo -e "----------------------------------------------------"