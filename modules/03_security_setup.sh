#!/bin/bash
# ==========================================
# Module 03: Security & Firewall Setup
# ==========================================

run_security_setup() {
    log_section "2. БЕЗОПАСНОСТЬ SSH И FIREWALL"

    # 1. Настройка SSH
    log_info "Отключение root и парольной аутентификации..."
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

    mkdir -p /etc/systemd/system/ssh.socket.d
    
    # Берем чистый шаблон из конфигов и подставляем порт
    cp "$CONFIGS_DIR/security/ssh_listen.conf" /etc/systemd/system/ssh.socket.d/listen.conf
    sed -i "s/__SSH_PORT__/$SSH_PORT/g" /etc/systemd/system/ssh.socket.d/listen.conf

    systemctl daemon-reload
    systemctl restart ssh.socket
    systemctl restart ssh.service
    log_success "Служба SSH перенастроена. Новый порт активирован."

    # 2. Настройка UFW и Fail2ban
    log_info "Настройка UFW и Fail2ban..."
    apt-get install -y ufw fail2ban -qq > /dev/null

    ufw --force reset > /dev/null
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow $SSH_PORT/tcp
    ufw allow $PANEL_PORT/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable > /dev/null
    log_success "UFW активирован и настроен (порты: $SSH_PORT, $PANEL_PORT, 80, 443)."

    # Берем шаблон для Fail2ban и подставляем порт
    cp "$CONFIGS_DIR/security/fail2ban.jail.local" /etc/fail2ban/jail.local
    sed -i "s/__SSH_PORT__/$SSH_PORT/g" /etc/fail2ban/jail.local

    systemctl enable fail2ban -q
    systemctl restart fail2ban
    log_success "Fail2ban настроен и запущен."
}