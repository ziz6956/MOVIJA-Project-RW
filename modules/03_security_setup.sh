#!/bin/bash
# ==========================================
# Module 03: Security & Firewall Setup
# ==========================================

run_security_setup() {
    log_section "2. БЕЗОПАСНОСТЬ SSH И FIREWALL"

    log_info "Отключение root и парольной аутентификации..."
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

    # Настройка сокета
    mkdir -p /etc/systemd/system/ssh.socket.d
    cp "$CONFIGS_DIR/security/ssh_listen.conf" /etc/systemd/system/ssh.socket.d/listen.conf
    sed -i "s/__SSH_PORT__/$SSH_PORT/g" /etc/systemd/system/ssh.socket.d/listen.conf

    # --- СТРАХОВКА ОТ ПАДЕНИЯ SSHD В UBUNTU 24.04 ---
    mkdir -p /run/sshd
    chmod 0755 /run/sshd
    # ------------------------------------------------

    systemctl daemon-reload
    systemctl restart ssh.socket
    systemctl restart ssh.service
    log_success "Служба SSH перенастроена. Новый порт активирован."

    log_info "Настройка UFW и Fail2ban..."
    apt-get install -y ufw fail2ban -qq > /dev/null

    ufw --force reset > /dev/null
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "$SSH_PORT"/tcp comment 'Custom SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'

    # --- СПЕЦИФИЧНЫЕ ПРАВИЛА ДЛЯ НОДЫ ---
    if [ "$INSTALL_TYPE" == "node" ]; then
        ufw allow 443/udp comment 'Caddy HTTP3'
        ufw allow "$SUB_PORT"/tcp comment 'Caddy Subscriptions'
        
        # --- ПРАВИЛА ДЛЯ WARP SOCKS BRIDGE ---
        # Разрешаем доступ к порту моста из подсетей Docker (172.16.0.0/12)
        ufw allow from 172.16.0.0/12 to any port 40000 proto tcp comment 'WARP Bridge TCP'
        ufw allow from 172.16.0.0/12 to any port 40000 proto udp comment 'WARP Bridge UDP'
        ufw allow in on docker0 to any port 40000
        ufw allow in on br-+ to any port 40000

        if [ -n "${PANEL_IP:-}" ]; then
            ufw allow from "$PANEL_IP" to any port 2222 proto tcp comment 'Panel Access'
        fi
    fi

    ufw --force enable > /dev/null
    log_success "UFW активирован и настроен."

    cp "$CONFIGS_DIR/security/fail2ban.jail.local" /etc/fail2ban/jail.local
    sed -i "s/__SSH_PORT__/$SSH_PORT/g" /etc/fail2ban/jail.local

    systemctl enable fail2ban -q
    systemctl restart fail2ban
    log_success "Fail2ban настроен и запущен."
}