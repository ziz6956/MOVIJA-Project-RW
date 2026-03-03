#!/bin/bash
# ==========================================
# MOVIJA-Project-RW: Swagger Manager
# ==========================================

# Подгружаем логгер, если он есть в папке modules
[ -f "modules/00_logger.sh" ] && source modules/00_logger.sh || echo -e "\e[34m[INFO]\e[0m Swagger Management Tool"

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "\e[31m[ERROR]\e[0m Файл .env не найден! Убедитесь, что панель установлена."
    exit 1
fi

# Получаем текущее состояние (по умолчанию false, если переменной нет)
CURRENT_STATE=$(grep "^IS_DOCS_ENABLED=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
CURRENT_STATE=${CURRENT_STATE:-false}

echo -e "\n------------------------------------------"
if [ "$CURRENT_STATE" == "true" ]; then
    echo -e "Текущий статус Swagger: \e[32mВКЛЮЧЕН (ENABLED)\e[0m"
    echo -e "Документация доступна по пути: /docs"
else
    echo -e "Текущий статус Swagger: \e[31mВЫКЛЮЧЕН (DISABLED)\e[0m"
fi
echo -e "------------------------------------------\n"

read -p "Вы хотите переключить статус Swagger? [y/N]: " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "\e[34m[INFO]\e[0m Действие отменено."
    exit 0
fi

if [ "$CURRENT_STATE" == "true" ]; then
    # Выключаем
    sed -i 's/^IS_DOCS_ENABLED=true/IS_DOCS_ENABLED=false/' "$ENV_FILE"
    NEW_STATUS="DISABLED"
else
    # Включаем
    if grep -q "^IS_DOCS_ENABLED=" "$ENV_FILE"; then
        sed -i 's/^IS_DOCS_ENABLED=false/IS_DOCS_ENABLED=true/' "$ENV_FILE"
    else
        # Если переменной вообще нет в файле — добавляем в конец
        echo -e "\n# --- SWAGGER DOCUMENTATION ---" >> "$ENV_FILE"
        echo "IS_DOCS_ENABLED=true" >> "$ENV_FILE"
        echo "SWAGGER_PATH=/docs" >> "$ENV_FILE"
    fi
    NEW_STATUS="ENABLED"
fi

echo -e "\e[34m[INFO]\e[0m Статус изменен на $NEW_STATUS. Перезапуск контейнеров..."

# Пересоздаем контейнеры для применения переменных окружения
docker compose down && docker compose up -d

echo -e "\n\e[32m[SUCCESS]\e[0m Настройки применены!"
if [ "$NEW_STATUS" == "ENABLED" ]; then
    echo -e "\e[34m[INFO]\e[0m Swagger теперь доступен по адресу вашей панели /docs"
fi