#!/bin/bash
# ==========================================
# Module 08: Backup & Restore Manager (SHA-256 Check)
# ==========================================

HASH_FILE="certs_hash.sha256"

# Функция динамического определения имени архива
get_backup_name() {
    local domain="backup"
    if [ -n "${ENV_PATH:-}" ] && [ -f "$ENV_PATH" ]; then
        if [ "$INSTALL_TYPE" == "panel" ]; then
            domain=$(grep '^FRONT_END_DOMAIN=' "$ENV_PATH" | cut -d '=' -f2 | tr -d '\r')
        elif [ "$INSTALL_TYPE" == "node" ]; then
            domain=$(grep '^SUB_DOMAIN=' "$ENV_PATH" | cut -d '=' -f2 | tr -d '\r')
        fi
    fi
    
    if [ -z "$domain" ]; then
        domain="backup"
    fi
    
    echo "caddy_certs_${domain}.tar.gz"
}

create_certificates_backup() {
    log_section "СОЗДАНИЕ БЭКАПА СЕРТИФИКАТОВ"
    
    local BACKUP_NAME=$(get_backup_name)

    if ! docker volume inspect caddy-data > /dev/null 2>&1; then
        log_error "Docker Volume 'caddy-data' не найден! Панель/Узел должны быть запущены хотя бы раз."
        return 1
    fi

    log_info "Расчет хеш-сумм и упаковка..."
    local TMP_DIR=$(mktemp -d)
    
    # Копируем данные из volume
    docker run --rm -v caddy-data:/data -v "$TMP_DIR":/backup alpine sh -c "cp -rp /data/* /backup/"
    
    # Генерируем хеши всех файлов внутри временной папки
    (cd "$TMP_DIR" && find . -type f -not -name "$HASH_FILE" -exec sha256sum {} + > "$HASH_FILE")
    
    # Архивируем
    tar czf "$WORK_DIR/$BACKUP_NAME" -C "$TMP_DIR" .
    rm -rf "$TMP_DIR"
    
    # Передаем права владельца, если мы под root, чтобы можно было скачать по SCP
    if [ -n "${NEW_USER:-}" ]; then
        chown "$NEW_USER:$NEW_USER" "$WORK_DIR/$BACKUP_NAME"
    fi

    log_success "Архив создан: $WORK_DIR/$BACKUP_NAME"
    log_info "Теперь вы можете скачать этот файл на Windows через SCP."
}

restore_certificates() {
    log_section "ВОССТАНОВЛЕНИЕ СЕРТИФИКАТОВ"
    
    local BACKUP_NAME=$(get_backup_name)
    local DEFAULT_PATH="$WORK_DIR/$BACKUP_NAME"
    read -p "Укажите путь к архиву [по умолчанию: $DEFAULT_PATH]: " USER_PATH
    local ACTUAL_PATH=${USER_PATH:-$DEFAULT_PATH}

    if [ ! -f "$ACTUAL_PATH" ]; then
        log_error "Файл не найден по пути: $ACTUAL_PATH"
        return 1
    fi

    log_info "Проверка целостности архива..."
    local TMP_RESTORE=$(mktemp -d)
    tar xzf "$ACTUAL_PATH" -C "$TMP_RESTORE"

    if [ ! -f "$TMP_RESTORE/$HASH_FILE" ]; then
        log_warn "В архиве отсутствует файл контрольных сумм ($HASH_FILE)."
        read -p "Восстановить без проверки? [y/N]: " FORCE
        [[ ! $FORCE =~ ^[Yy]$ ]] && { rm -rf "$TMP_RESTORE"; return 1; }
    else
        # Сверка хешей
        if (cd "$TMP_RESTORE" && sha256sum -c "$HASH_FILE" > /dev/null 2>&1); then
            log_success "Контрольные суммы совпали. Файлы целы."
        else
            log_error "ВНИМАНИЕ: Файлы в архиве повреждены или изменены!"
            read -p "Хотите прервать восстановление и сгенерировать НОВЫЕ сертификаты? [y/N]: " ABORT
            if [[ $ABORT =~ ^[Yy]$ ]]; then
                rm -rf "$TMP_RESTORE"
                return 1
            fi
        fi
    fi

    log_info "Запись данных в Docker Volume..."
    docker volume create caddy-data > /dev/null
    docker run --rm -v caddy-data:/data -v "$TMP_RESTORE":/backup alpine sh -c "cp -rp /backup/* /data/ && rm -f /data/$HASH_FILE"
    
    rm -rf "$TMP_RESTORE"
    export RESTORED_CERTS=true
    log_success "Сертификаты успешно восстановлены в систему."
}

# Обертка для интеграции в полный setup.sh
run_backup_logic() {
    echo -e "\nЖелаете ли вы использовать бэкап сертификатов?"
    echo "1) Да, восстановить из файла"
    echo "2) Нет, пропустить (будут созданы новые)"
    read -p "Ваш выбор: " b_logic_choice
    if [ "$b_logic_choice" == "1" ]; then
        restore_certificates
    fi
}