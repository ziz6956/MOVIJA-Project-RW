#!/bin/bash

run_mtproxy_patch() {
    local TARGET="/opt/mtproxymax/mtproxymax"

    echo "🛠 Начинаю операцию по лечению MTProxyMax..."

    if [ ! -f "$TARGET" ]; then
        echo "❌ Ошибка: Файл $TARGET не найден! Сначала установите MTProxy Max."
        return 1
    fi

    echo "🌐 Определение доступных IPv4 адресов..."
    local LOCAL_IPS=($(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'))

    if [ ${#LOCAL_IPS[@]} -eq 0 ]; then
        echo "❌ Ошибка: Не найдено публичных IPv4 адресов!"
        return 1
    fi

    echo "Доступные IP-адреса для привязки:"
    for i in "${!LOCAL_IPS[@]}"; do
        echo "  $((i+1))) ${LOCAL_IPS[$i]}"
    done

    read -p "Выберите номер IP, на котором должен работать MTProxy Max [1-${#LOCAL_IPS[@]}]: " ip_choice

    if [[ "$ip_choice" =~ ^[0-9]+$ ]] && [ "$ip_choice" -ge 1 ] && [ "$ip_choice" -le "${#LOCAL_IPS[@]}" ]; then
        local SELECTED_IP="${LOCAL_IPS[$((ip_choice-1))]}"
        echo "✅ Выбран IP: $SELECTED_IP"
    else
        echo "❌ Неверный выбор!"
        return 1
    fi

    echo "🌐 Привязываю IPv4 к $SELECTED_IP..."
    sudo sed -i 's/listen_addr_ipv4 = "0.0.0.0"/listen_addr_ipv4 = "${CUSTOM_IP:-0.0.0.0}"/g' "$TARGET"
    sudo sed -i "s/listen_addr_ipv4 = \"0.0.0.0\"/listen_addr_ipv4 = \"$SELECTED_IP\"/g" "$TARGET"
    sudo sed -i "s/listen_addr_ipv4 = \"\${CUSTOM_IP:-0.0.0.0}\"/listen_addr_ipv4 = \"$SELECTED_IP\"/g" "$TARGET"

    echo "👁 Отключаю блокировку при занятом порте 443..."
    sudo sed -i 's/if ! is_port_available "$PROXY_PORT"; then/if false; then/g' "$TARGET"
    sudo sed -i '/is already in use by another process/{n;s/return 1/# return 1/}' "$TARGET"

    echo "🔄 Перезапускаю прокси для применения изменений..."
    sudo mtproxymax restart

    echo "📊 Текущий статус системы:"
    sudo mtproxymax status

    echo "✅ Операция завершена!"
}