#!/bin/bash
# ==========================================
# Module 02: User & Port Management
# ==========================================

run_user_management() {
    log_section "1. ГЕНЕРАЦИЯ ДАННЫХ И ПОЛЬЗОВАТЕЛЕЙ"

    # Генерация SSH порта
    while true; do
        export SSH_PORT=$((RANDOM % 50000 + 10000))
        if [[ "$SSH_PORT" != "2222" && "$SSH_PORT" != "3000" && "$SSH_PORT" != "3010" && "$SSH_PORT" != "5432" && "$SSH_PORT" != "6379" && "$SSH_PORT" != "8080" ]]; then
            if ! ss -tuln | grep -q ":$SSH_PORT "; then
                break
            fi
        fi
    done
    log_info "Сгенерирован SSH порт: $SSH_PORT"

    # Генерация порта панели
    while true; do
        export PANEL_PORT=$((RANDOM % 50000 + 10000))
        if [[ "$PANEL_PORT" != "$SSH_PORT" && "$PANEL_PORT" != "2222" && "$PANEL_PORT" != "3000" && "$PANEL_PORT" != "3010" && "$PANEL_PORT" != "5432" && "$PANEL_PORT" != "6379" && "$PANEL_PORT" != "8080" ]]; then
            if ! ss -tuln | grep -q ":$PANEL_PORT "; then
                break
            fi
        fi
    done
    log_info "Сгенерирован порт Панели: $PANEL_PORT"

    export ROOT_PASS=$(openssl rand -base64 18)
    echo "root:$ROOT_PASS" | chpasswd
    log_success "Пароль root успешно изменен."

    local PREFIXES=("super" "cyber" "star" "sky" "zen" "quantum" "flux" "neon")
    local SUFFIXES=("admin" "pilot" "coder" "user" "rooter" "ghost" "wolf" "fox")
    local PREFIX_INDEX=$((RANDOM % ${#PREFIXES[@]}))
    local SUFFIX_INDEX=$((RANDOM % ${#SUFFIXES[@]}))
    local RANDOM_NUMBER=$((RANDOM % 900 + 100))
    export NEW_USER="${PREFIXES[$PREFIX_INDEX]}${SUFFIXES[$SUFFIX_INDEX]}$RANDOM_NUMBER"
    export USER_PASS=$(openssl rand -base64 18)

    if id "$NEW_USER" &>/dev/null; then
        log_warn "Пользователь $NEW_USER уже существует. Пропускаем создание..."
    else
        useradd -m -s /bin/bash "$NEW_USER"
        echo "$NEW_USER:$USER_PASS" | chpasswd
        usermod -aG sudo "$NEW_USER"
        log_success "Создан суперпользователь: $NEW_USER"
    fi

    if [ -f /root/.ssh/authorized_keys ]; then
        mkdir -p /home/$NEW_USER/.ssh
        cp /root/.ssh/authorized_keys /home/$NEW_USER/.ssh/
        chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
        chmod 700 /home/$NEW_USER/.ssh
        chmod 600 /home/$NEW_USER/.ssh/authorized_keys
        log_success "SSH ключи скопированы новому пользователю."
    else
        log_warn "Файл /root/.ssh/authorized_keys не найден. Ключи не скопированы."
    fi
}