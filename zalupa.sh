#!/bin/bash

# --- МЕГА-АВТОМАТИЗИРОВАННЫЙ СКРИПТ ДЛЯ СТЕКА WORDPRESS + GRAFANA ---
# Автор: Grok (на основе анализа и улучшений)
# Версия: 1.1 (2025-10-29)
# Описание: Полностью автоматизирует установку стека с WordPress, MariaDB, phpMyAdmin, Grafana.
#           Автоматически настраивает WP, генерирует пароли, проверяет готовность, улучшает дашборд.
#           Исправлена проблема с подключением Grafana к DB: добавлен полный URL с протоколом 'mysql://db:3306'.
#           Добавлены проверки и опциональная установка Docker/Compose, если не найдены (с подтверждением).
#           Только для теста! Не для продакшена.

# --- ФУНКЦИИ ПОМОЩНИКИ ---

# Цветной вывод (используем tput)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /var/log/my-stack-setup.log
}

info() {
    echo "${BLUE}[INFO] $1${RESET}"
    log "INFO: $1"
}

success() {
    echo "${GREEN}[SUCCESS] $1${RESET}"
    log "SUCCESS: $1"
}

warning() {
    echo "${YELLOW}[WARNING] $1${RESET}"
    log "WARNING: $1"
}

error() {
    echo "${RED}[ERROR] $1${RESET}"
    log "ERROR: $1"
    exit 1
}

# Проверка команды
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# Генерация случайного пароля
generate_password() {
    openssl rand -base64 12 | tr -d '/+=' | cut -c1-12
}

# Проверка готовности контейнера
wait_for_container() {
    local container=$1
    local timeout=60
    local counter=0
    info "Ждем готовности $container..."
    while [ $counter -lt $timeout ]; do
        if sudo docker inspect -f '{{.State.Health.Status}}' $container 2>/dev/null | grep -q "healthy"; then
            success "$container готов!"
            return 0
        fi
        sleep 5
        counter=$((counter + 5))
    done
    error "Таймаут ожидания $container."
}

# Установка Docker и Compose (если нужно)
install_docker() {
    warning "Docker не найден. Устанавливаем? (y/n)"
    read -r confirm
    if [[ $confirm != "y" ]]; then
        error "Установка отменена."
    fi
    info "Установка Docker..."
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    success "Docker установлен."
}

# --- ПАРСИНГ АРГУМЕНТОВ (для кастомизации) ---
PROJECT_DIR="/opt/my-stack"
WP_PORT="80"
PMA_PORT="8081"
GRAFANA_PORT="3000"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dir) PROJECT_DIR="$2"; shift ;;
        --wp-port) WP_PORT="$2"; shift ;;
        --pma-port) PMA_PORT="$2"; shift ;;
        --grafana-port) GRAFANA_PORT="$2"; shift ;;
        *) error "Неизвестный аргумент: $1" ;;
    esac
    shift
done

# --- [0/11] ПРЕДУПРЕЖДЕНИЕ И ЛОГИРОВАНИЕ ---
info "Запуск скрипта. Логи в /var/log/my-stack-setup.log"
touch /var/log/my-stack-setup.log || error "Не могу создать лог-файл."

warning "ВНИМАНИЕ: Этот скрипт для ТЕСТИРОВАНИЯ. Генерирует пароли, запускает контейнеры."
warning "Не используйте в продакшене! Нажмите ENTER или CTRL+C."
read

# --- [1/11] ПРОВЕРКА И УСТАНОВКА ПРЕДПОСЫЛОК ---
info "[1/11] Проверка системы..."
check_command openssl || error "openssl не найден. Установите: sudo yum install -y openssl"

if ! check_command docker; then
    install_docker
fi

if ! docker compose version &> /dev/null; then
    warning "Docker Compose v2 не найден. Устанавливаем плагин? (y/n)"
    read -r confirm
    if [[ $confirm != "y" ]]; then
        error "Установка отменена."
    fi
    sudo yum install -y docker-compose-plugin
    sudo systemctl restart docker
    success "Compose установлен."
fi

check_command firewall-cmd || warning "Firewall не найден, пропускаем настройку."
check_command getenforce && if [[ $(getenforce) != "Disabled" ]]; then info "SELinux включен — обработаем."; fi

# Останавливаем конфликтующие сервисы
sudo systemctl stop httpd &>/dev/null
sudo systemctl disable httpd &>/dev/null
success "Конфликты устранены."

# --- [2/11] ОЧИСТКА ПРЕДЫДУЩИХ УСТАНОВОК ---
info "[2/11] Полная очистка..."
sudo docker compose -f $PROJECT_DIR/docker-compose.yml down -v --rmi local --remove-orphans &>/dev/null
sudo rm -rf $PROJECT_DIR /root/my-full-stack ~/my-full-stack
success "Очистка завершена."

# --- [3/11] СОЗДАНИЕ ДИРЕКТОРИЙ И ГЕНЕРАЦИЯ ПАРОЛЕЙ ---
info "[3/11] Создание директорий и генерация паролей..."
sudo mkdir -p $PROJECT_DIR/provisioning/{datasources,dashboards}
cd $PROJECT_DIR || error "Не могу перейти в $PROJECT_DIR."

MYSQL_ROOT_PASS=$(generate_password)
WP_DB_PASS=$(generate_password)
GRAFANA_ADMIN_PASS=$(generate_password)
WP_ADMIN_USER="admin_$(openssl rand -hex 4)"
WP_ADMIN_PASS=$(generate_password)
WP_ADMIN_EMAIL="admin@example.com"
WP_TITLE="My Test Site"
WP_URL="http://$(hostname -I | awk '{print $1}'):$WP_PORT"

success "Пароли сгенерированы (будут выведены в конце)."

# --- [4/11] НАСТРОЙКА FIREWALL ---
if check_command firewall-cmd; then
    info "[4/11] Настройка firewall..."
    sudo systemctl start firewalld &>/dev/null
    sudo systemctl enable firewalld &>/dev/null
    sudo firewall-cmd --add-port=$WP_PORT/tcp --permanent
    sudo firewall-cmd --add-port=$PMA_PORT/tcp --permanent
    sudo firewall-cmd --add-port=$GRAFANA_PORT/tcp --permanent
    sudo firewall-cmd --reload
    success "Firewall настроен."
else
    warning "Firewall не найден — пропускаем."
fi

# --- [5/11] СОЗДАНИЕ docker-compose.yml ---
info "[5/11] Создание docker-compose.yml..."
cat << EOF > docker-compose.yml
version: '3.8'

services:
  db:
    image: mariadb:10.6
    container_name: wordpress_db
    volumes:
      - db_data:/var/lib/mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: '$MYSQL_ROOT_PASS'
      MYSQL_DATABASE: 'wordpress'
      MYSQL_USER: 'wp_user'
      MYSQL_PASSWORD: '$WP_DB_PASS'
    networks:
      - app_network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p\$MYSQL_ROOT_PASSWORD"]
      interval: 10s
      timeout: 5s
      retries: 5

  wordpress:
    image: wordpress:latest
    container_name: wordpress_app
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "$WP_PORT:80"
    restart: always
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: 'wp_user'
      WORDPRESS_DB_PASSWORD: '$WP_DB_PASS'
      WORDPRESS_DB_NAME: 'wordpress'
    volumes:
      - wp_files:/var/www/html
    networks:
      - app_network

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: phpmyadmin_app
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "$PMA_PORT:80"
    restart: always
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: '$MYSQL_ROOT_PASS'
    networks:
      - app_network

  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana_app
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "$GRAFANA_PORT:3000"
    restart: always
    environment:
      GF_SECURITY_ADMIN_PASSWORD: '$GRAFANA_ADMIN_PASS'
    volumes:
      - grafana_data:/var/lib/grafana
      - ./provisioning/datasources:/etc/grafana/provisioning/datasources
      - ./provisioning/dashboards:/etc/grafana/provisioning/dashboards
    networks:
      - app_network

networks:
  app_network:
    driver: bridge

volumes:
  db_data:
  wp_files:
  grafana_data:
EOF
success "docker-compose.yml создан."

# --- [6/11] СОЗДАНИЕ ПРОВИЖЕНИНГА GRAFANA ---
info "[6/11] Создание provisioning для Grafana (с исправленным URL для MySQL)..."

# Datasource с исправлением: полный URL с 'mysql://' и дополнительными полями из docs
cat << EOF > provisioning/datasources/datasource.yml
apiVersion: 1

datasources:
  - name: 'WordPress DB (MariaDB)'
    type: mysql
    uid: 'wp-mysql-ds'
    access: proxy
    url: mysql://db:3306
    user: wp_user
    database: wordpress
    secureJsonData:
      password: '$WP_DB_PASS'
    jsonData:
      maxOpenConns: 20
      maxIdleConns: 10
      connMaxLifetime: 14400
      timeInterval: '1m'
      tlsSkipVerify: true  # Для теста, без TLS
EOF

# Providers
cat << EOF > provisioning/dashboards/dashboard.yml
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Улучшенный дашборд: добавлены time-series графики
cat << EOF > provisioning/dashboards/wp-stats-dashboard.json
{
  "__inputs": [],
  "__requires": [],
  "annotations": { "list": [] },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "id": 1,
      "type": "stat",
      "title": "Всего пользователей",
      "gridPos": { "h": 6, "w": 6, "x": 0, "y": 0 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [{ "refId": "A", "rawQuery": true, "query": "SELECT COUNT(*) as value FROM wp_users;", "format": "table" }],
      "fieldConfig": { "defaults": { "color": { "mode": "thresholds" } } },
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }
    },
    {
      "id": 2,
      "type": "stat",
      "title": "Опубликованные посты/страницы",
      "gridPos": { "h": 6, "w": 6, "x": 6, "y": 0 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [{ "refId": "A", "rawQuery": true, "query": "SELECT COUNT(*) as value FROM wp_posts WHERE post_status = 'publish';", "format": "table" }],
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }
    },
    {
      "id": 3,
      "type": "stat",
      "title": "Одобренные комментарии",
      "gridPos": { "h": 6, "w": 6, "x": 12, "y": 0 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [{ "refId": "A", "rawQuery": true, "query": "SELECT COUNT(*) as value FROM wp_comments WHERE comment_approved = '1';", "format": "table" }],
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }
    },
    {
      "id": 4,
      "type": "stat",
      "title": "Медиа-файлы",
      "gridPos": { "h": 6, "w": 6, "x": 18, "y": 0 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [{ "refId": "A", "rawQuery": true, "query": "SELECT COUNT(*) as value FROM wp_posts WHERE post_type = 'attachment';", "format": "table" }],
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }
    },
    {
      "id": 5,
      "type": "timeseries",
      "title": "Новые посты по времени",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 6 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [{ "refId": "A", "rawQuery": true, "query": "SELECT post_date as time, COUNT(*) as value FROM wp_posts WHERE post_status = 'publish' GROUP BY DATE(post_date);", "format": "time_series" }],
      "fieldConfig": { "defaults": { "custom": { "lineWidth": 2 } } },
      "options": { "legend": { "displayMode": "list" } }
    },
    {
      "id": 6,
      "type": "timeseries",
      "title": "Новые комментарии по времени",
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 6 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [{ "refId": "A", "rawQuery": true, "query": "SELECT comment_date as time, COUNT(*) as value FROM wp_comments WHERE comment_approved = '1' GROUP BY DATE(comment_date);", "format": "time_series" }],
      "fieldConfig": { "defaults": { "custom": { "lineWidth": 2 } } },
      "options": { "legend": { "displayMode": "list" } }
    }
  ],
  "refresh": "30s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["wordpress", "stats"],
  "templating": { "list": [] },
  "time": { "from": "now-24h", "to": "now" },
  "timepicker": { "refresh_intervals": ["5s", "10s", "30s", "1m"] },
  "timezone": "browser",
  "title": "Advanced WordPress Stats",
  "uid": "wp-stats-dashboard",
  "
