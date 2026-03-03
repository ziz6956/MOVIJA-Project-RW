#!/bin/bash
# ==========================================
# MOVIJA-Project-RW: Node Orchestrator
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
    echo -e "\033[0;31m[ERROR]\033[0m Файл логгера не найден!"
    exit 1
fi

# 2. Подключение переиспользуемых модулей
source "$MODULES_DIR/05_docker_install.sh"

log_section "СТАРТ УСТАНОВКИ УЗЛА (NODE) MOVIJA-Project-RW"

run_node_preflight() {
    log_section "1. БАЗОВЫЕ ПРОВЕРКИ И НАСТРОЙКИ"
    
    if [ "$EUID" -ne 0 ]; then
        log_error "Запустите скрипт от имени root (sudo)."
        exit 1
    fi

    if [ ! -d "$NODE_TEMPLATE_DIR" ]; then
        log_error "Папка с шаблонами node/ не найдена! Убедитесь, что вы склонировали репозиторий полностью."
        exit 1
    fi

    log_info "Обновление системы и установка зависимостей..."
    apt-get update -qq && apt-get install -y -qq curl wget git nano ufw fail2ban iptables logrotate > /dev/null
    log_success "Подготовка завершена."
}

run_node_input() {
    log_section "2. СБОР ДАННЫХ ДЛЯ НОДЫ"
    
    local RANDOM_SSH=$(shuf -i 10000-60000 -n 1)
    
    read -p "Укажите имя домена ноды для маскировки [по умолчанию vpn-node]: " INPUT_HOSTNAME
    export NODE_HOSTNAME=${INPUT_HOSTNAME:-vpn-node}

    # Исправлено: оставили только один запрос порта
    read -p "Укажите новый SSH порт [по умолчанию $RANDOM_SSH]: " INPUT_SSH_PORT
    export SSH_PORT=${INPUT_SSH_PORT:-$RANDOM_SSH}

    read -p "IP-адрес основной ПАНЕЛИ (для доступа к порту 2222): " PANEL_IP
    export PANEL_IP

    read -p "Секретный ключ для Xray Node (SECRET_KEY): " NODE_SECRET
    export NODE_SECRET

    # Исправлено: убрали твой личный домен из примеров
    read -p "URL основной панели [напр. https://panel.example.com]: " PANEL_URL
    export PANEL_URL

    read -p "Домен страницы подписок [напр. sub.example.com]: " SUB_DOMAIN
    export SUB_DOMAIN

    read -p "Домен веб-кабинета [напр. lk.example.com]: " CABINET_DOMAIN
    export CABINET_DOMAIN

    read -p "URL API вашего бота [напр. http://127.0.0.1:8080]: " INPUT_BOT
    export BOT_API_URL=${INPUT_BOT:-http://127.0.0.1:8080}
}

run_node_security() {
    log_section "3. НАСТРОЙКА БЕЗОПАСНОСТИ"

    log_info "Маскировка системного имени (Hostname)..."
    hostnamectl set-hostname "$NODE_HOSTNAME"
    if ! grep -q "127.0.0.1 $NODE_HOSTNAME" /etc/hosts; then
        echo "127.0.0.1 $NODE_HOSTNAME" >> /etc/hosts
    fi
    
    log_info "Перенос SSH на порт $SSH_PORT..."
    if systemctl is-active --quiet ssh.socket 2>/dev/null; then
        mkdir -p /etc/systemd/system/ssh.socket.d
        cat <<EOF > /etc/systemd/system/ssh.socket.d/listen.conf
[Socket]
ListenStream=
ListenStream=$SSH_PORT
EOF
        systemctl daemon-reload
        systemctl restart ssh.socket
    else
        sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
        systemctl restart ssh
    fi

    log_info "Настройка UFW..."
    ufw --force reset > /dev/null
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "$SSH_PORT"/tcp comment 'Custom SSH'
    ufw allow 80/tcp comment 'HTTP for Caddy'
    ufw allow 443/tcp comment 'HTTPS for Caddy'
    ufw allow 443/udp comment 'HTTP3 for Caddy'
    
    if [ -n "${PANEL_IP:-}" ]; then
        ufw allow from "$PANEL_IP" to any port 2222 proto tcp comment 'Panel Access'
    fi
    ufw --force enable > /dev/null

    log_info "Настройка Fail2ban..."
    cat <<EOF > /etc/fail2ban/jail.d/sshd-custom.conf
[sshd]
enabled = true
port = $SSH_PORT
backend = systemd
bantime = 24h
maxretry = 3
EOF
    systemctl enable fail2ban -q
    systemctl restart fail2ban
    log_success "Безопасность настроена."
}

run_node_deploy() {
    log_section "4. РАЗВЕРТЫВАНИЕ ПРОЕКТА"
    
    log_info "Создание директорий..."
    mkdir -p "$PROJECT_DIR"
    mkdir -p "/var/log/remnanode"
    
    log_info "Копирование файлов из репозитория..."
    cp "$NODE_TEMPLATE_DIR/docker-compose.yml" "$PROJECT_DIR/"
    cp "$NODE_TEMPLATE_DIR/Caddyfile" "$PROJECT_DIR/"
    cp -r "$NODE_TEMPLATE_DIR/cabinet" "$PROJECT_DIR/"

    log_info "Генерация файла переменных окружения (.env)..."
    cat <<EOF > "$PROJECT_DIR/.env"
NODE_SECRET_KEY=$NODE_SECRET
PANEL_URL=$PANEL_URL
SUB_DOMAIN=$SUB_DOMAIN
CABINET_DOMAIN=$CABINET_DOMAIN
BOT_API_URL=$BOT_API_URL
EOF

    log_info "Настройка ротации логов..."
    cat <<EOF > /etc/logrotate.d/remnanode
/var/log/remnanode/*.log {
    size 50M
    rotate 5
    compress
    missingok
    copytruncate
}
EOF

    log_info "Запуск контейнеров..."
    cd "$PROJECT_DIR"
    docker compose up -d --remove-orphans
    log_success "Узел успешно запущен!"
}

# ==========================================
# ВЫПОЛНЕНИЕ ПАЙПЛАЙНА
# ==========================================
run_node_preflight
run_node_input
run_node_security
run_docker_install
run_node_deploy

PUBLIC_IP=$(curl -s ifconfig.me)
log_section "ИТОГОВЫЕ ДАННЫЕ УЗЛА"
echo -e "IP СЕРВЕРА:        $PUBLIC_IP"
echo -e "ПОРТ SSH:          $SSH_PORT"
echo -e "Команда для входа: ssh root@$PUBLIC_IP -p $SSH_PORT"
echo -e "----------------------------------------------------"
echo -e "Директория узла:   $PROJECT_DIR"
echo -e "----------------------------------------------------"