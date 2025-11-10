#!/bin/bash

# ==============================================================================
# --- НАСТРОЙКИ (!!! ОБЯЗАТЕЛЬНО ЗАПОЛНИ ЭТО !!!) ---
# ==============================================================================

# IP-адрес или хостнейм твоей базы данных
DB_HOST="192.168.9.135"

# Имя базы данных Directus
DB_NAME="directus" # <-- !!! ЗАМЕНИ ЭТО

# Пользователь базы данных (рекомендую создать read-only юзера для Grafana)
DB_USER="user2" # <-- !!! ЗАМЕНИ ЭТО

# Пароль этого пользователя
DB_PASS="1" # <-- !!! ЗАМЕНИ ЭТО

# Пароль для admin-пользователя в Grafana (будет создан при первом запуске)
GRAFANA_ADMIN_PASS="123456" # <-- !!! ЗАМЕНИ ЭТО (или используй admin/admin)

# ==============================================================================
# --- КОНЕЦ НАСТРОЕК ---
# ==============================================================================

set -e

echo "Создаем директории для Grafana..."
mkdir -p ./grafana_data
mkdir -p ./grafana_provisioning/datasources

echo "Создаем файл 'datasource.yml' для подключения к БД..."

cat > ./grafana_provisioning/datasources/datasource.yml << EOL
apiVersion: 1
datasources:
  - name: Directus DB (MySQL)
    type: mysql
    url: ${DB_HOST}:3306
    database: ${DB_NAME}
    user: ${DB_USER}
    isDefault: true
    jsonData:
      sslmode: 'disable' # Можешь поменять на 'require', если у тебя настроен SSL
    secureJsonData:
      password: "${DB_PASS}"
EOL

echo "Создаем 'docker-compose.yml'..."

cat > ./docker-compose.yml << EOL
version: '3.8'

services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      # Хранилище данных Grafana (чтобы не терять дашборды при перезапуске)
      - ./grafana_data:/var/lib/grafana
      # Файл с настройками подключения к БД
      - ./grafana_provisioning/datasources:/etc/grafana/provisioning/datasources
    environment:
      # Устанавливаем пароль админа
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASS}
    restart: unless-stopped
    networks:
      - default

# Примечание: Мы используем 'default' сеть Docker. 
# Если твой Directus и БД тоже в Docker, лучше объединить их в одну сеть.
# Но так как БД на 192.168.9.135, контейнер Grafana должен ее "видеть" по этому IP.

EOL

echo "Запускаем Grafana через docker-compose..."
docker-compose up -d

echo "---"
echo "ГОТОВО!"
echo ""
echo "Grafana запущена и доступна по адресу: http://localhost:3000"
echo "Логин: admin"
echo "Пароль: ${GRAFANA_ADMIN_PASS}"
echo ""
echo "Источник данных 'Directus DB (MySQL)' должен был добавиться автоматически."
echo "Проверь это в 'Configuration' > 'Data Sources' в Grafana."
