#!/bin/bash
# ==========================================
# Module 13: Bedolaga Bot Installer
# ==========================================

run_bot_install() {
    log_section "УСТАНОВКА BEDOLAGA БОТА"

    # Проверка, установлена ли панель
    if [ ! -f "$ENV_PATH" ] || [ ! -f "$COMPOSE_DIR/docker-compose.yml" ]; then
        log_error "Конфигурация панели не найдена! Сначала установите основную панель (пункт 1)."
        exit 1
    fi

    # Проверка, не установлен ли бот уже
    if grep -q "BOT_TOKEN=" "$ENV_PATH"; then
        log_warn "Бот уже настроен в файле .env! Прерываем во избежание дублирования."
        exit 1
    fi

    log_info "Для установки бота потребуются некоторые данные."
    read -p "Токен Telegram-бота (от @BotFather): " INPUT_BOT_TOKEN
    read -p "Telegram ID администратора(ов) через запятую: " INPUT_ADMIN_IDS
    read -p "Домен для API бота (напр. api.example.com): " INPUT_BOT_API_DOMAIN
    read -p "Ссылка на будущий Кабинет (для CORS, напр. https://cabinet.example.com): " INPUT_CABINET_ORIGIN
    
    echo -e "\033[0;33m[ВАЖНО]\033[0m Если у вас еще нет API-токена, зайдите в веб-панель -> Settings -> API Tokens, создайте его и скопируйте сюда."
    read -p "API-токен панели Remnawave: " INPUT_API_KEY

    log_info "Генерация паролей для изолированной БД бота..."
    local BOT_DB_PASS=$(openssl rand -hex 16)
    local BOT_REDIS_PASS=$(openssl rand -hex 16)
    local WEB_API_TOKEN=$(openssl rand -hex 32)

    # 1. Добавляем переменные в .env
    cat <<EOF >> "$ENV_PATH"

# ==========================================
# BEDOLAGA BOT SETTINGS
# ==========================================
BOT_TOKEN=${INPUT_BOT_TOKEN}
ADMIN_IDS=${INPUT_ADMIN_IDS}
BOT_RUN_MODE=polling
REMNAWAVE_API_KEY=${INPUT_API_KEY}

DATABASE_MODE=auto
POSTGRES_BOT_USER=remnawave_bot_user
POSTGRES_BOT_PASSWORD=${BOT_DB_PASS}
POSTGRES_BOT_DB=remnawave_bot
REDIS_BOT_PASSWORD=${BOT_REDIS_PASS}

WEB_API_ENABLED=true
WEB_API_HOST=0.0.0.0
WEB_API_PORT=8080
WEB_API_ALLOWED_ORIGINS=${INPUT_CABINET_ORIGIN}
WEB_API_DEFAULT_TOKEN=${WEB_API_TOKEN}
BOT_API_DOMAIN=${INPUT_BOT_API_DOMAIN}
EOF

    # 2. Создаем docker-compose.override.yml (Docker сам склеит его с основным файлом)
    log_info "Создание конфигурации сервисов бота (docker-compose.override.yml)..."
    cat <<EOF > "$COMPOSE_DIR/docker-compose.override.yml"
services:
  bot-postgres:
    image: postgres:15-alpine
    container_name: bot-postgres
    restart: always
    environment:
      POSTGRES_USER: \${POSTGRES_BOT_USER}
      POSTGRES_PASSWORD: \${POSTGRES_BOT_PASSWORD}
      POSTGRES_DB: \${POSTGRES_BOT_DB}
    volumes:
      - bot-postgres-data:/var/lib/postgresql/data

  bot-redis:
    image: redis:7-alpine
    container_name: bot-redis
    restart: always
    command: redis-server --requirepass \${REDIS_BOT_PASSWORD}
    volumes:
      - bot-redis-data:/data

  bedolaga-bot:
    image: ghcr.io/bedolaga-dev/remnawave-bedolaga-telegram-bot:latest
    container_name: bedolaga-bot
    restart: always
    # env_file не используется для предотвращения конфликта DATABASE_URL с основной панелью
    environment:
      POSTGRES_HOST: bot-postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: \${POSTGRES_BOT_USER}
      POSTGRES_PASSWORD: \${POSTGRES_BOT_PASSWORD}
      POSTGRES_DB: \${POSTGRES_BOT_DB}
      DATABASE_MODE: 'auto'
      REDIS_URL: redis://:\${REDIS_BOT_PASSWORD}@bot-redis:6379/0
      REMNAWAVE_API_URL: http://remnawave:3000
      REMNAWAVE_API_KEY: \${REMNAWAVE_API_KEY}
      BOT_TOKEN: \${BOT_TOKEN}
      ADMIN_IDS: \${ADMIN_IDS}
      BOT_RUN_MODE: polling
      WEB_API_ENABLED: 'true'
      WEB_API_HOST: 0.0.0.0
      WEB_API_PORT: 8080
      WEB_API_ALLOWED_ORIGINS: \${WEB_API_ALLOWED_ORIGINS}
      WEB_API_DEFAULT_TOKEN: \${WEB_API_DEFAULT_TOKEN}
    depends_on:
      - bot-postgres
      - bot-redis
      - remnawave
    volumes:
      - ./bot_data/logs:/app/logs
      - ./bot_data/data:/app/data

volumes:
  bot-postgres-data:
  bot-redis-data:
EOF

    # 3. Обновляем Caddyfile для проксирования API бота
    log_info "Настройка маршрутизации в Caddy..."
    if ! grep -q "{\$BOT_API_DOMAIN}" "$CONFIGS_DIR/caddy/Caddyfile"; then
        cat <<EOF >> "$CONFIGS_DIR/caddy/Caddyfile"

{\$BOT_API_DOMAIN} {
    reverse_proxy bedolaga-bot:8080
}
EOF
    fi

    # 4. Создаем директории и выдаем права
    log_info "Подготовка файловой системы..."
    mkdir -p "$COMPOSE_DIR/bot_data/logs" \
             "$COMPOSE_DIR/bot_data/data/backups" \
             "$COMPOSE_DIR/bot_data/data/referral_qr"

    chmod -R 755 "$COMPOSE_DIR/bot_data"
    chown -R 1000:1000 "$COMPOSE_DIR/bot_data"

    # 5. Запускаем контейнеры
    log_info "Запуск новых сервисов в кластере Docker..."
    cd "$COMPOSE_DIR"
    docker compose up -d --remove-orphans
    
    log_info "Перезагрузка Caddy для применения нового домена..."
    docker compose restart caddy

    log_success "Бот Bedolaga успешно интегрирован и запущен!"
    echo -e "------------------------------------------"
    echo -e "Внешний API бота доступен по адресу: https://$INPUT_BOT_API_DOMAIN"
    echo -e "Веб-токен для Cabineta: $WEB_API_TOKEN"
    echo -e "------------------------------------------"
}