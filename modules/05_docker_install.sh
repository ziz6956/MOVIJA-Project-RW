#!/bin/bash
# ==========================================
# Module 05: Docker Installation
# ==========================================

run_docker_install() {
    log_section "4. УСТАНОВКА DOCKER И ПЛАГИНОВ"

    if ! command -v docker &> /dev/null; then
        log_info "Docker не найден. Начинаем установку..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh > /dev/null 2>&1
        rm -f get-docker.sh
        
        # Включаем Docker в автозагрузку
        systemctl enable docker > /dev/null 2>&1
        systemctl start docker
        
        log_success "Docker и Docker Compose успешно установлены."
    else
        log_warn "Docker уже установлен в системе. Пропускаем..."
    fi

    # Небольшая проверка работоспособности
    if docker compose version &> /dev/null; then
        log_success "Плагин docker compose доступен: $(docker compose version --short)"
    else
        log_error "Плагин docker compose не найден! Убедитесь, что установка прошла корректно."
    fi
}