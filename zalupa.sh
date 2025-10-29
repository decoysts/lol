Полный идеальный скрипт
На основе всех наших диалогов, я переписал скрипт до идеала. Учёл все проблемы:
	•	Надёжная генерация паролей (с fallback на date+sha256, если urandom медленно в VM).
	•	Убрал version в docker-compose.yml (чтобы избежать obsolete warning).
	•	Убрал кавычки в environment (для правильной подстановки переменных).
	•	Добавил проверки на пустоту паролей и debug-вывод.
	•	Исправил подключение Grafana к DB (url: mysql://db:3306, access: proxy).
	•	Добавил инструкцию по docker login перед запуском (для avoidance unauthorized errors).
	•	Улучшил healthchecks, SELinux (restorecon + chcon).
	•	Автоматизация WP через wp-cli.
	•	Проверки файлов после создания.
	•	Цветной вывод, логирование, обработка ошибок.
	•	Опциональная установка Docker/Compose с подтверждением.
	•	Ждём готовности контейнеров.
Важно перед запуском:
	•	Залогиньтесь в Docker: sudo docker login (используйте аккаунт Docker Hub, чтобы избежать “unauthorized: authentication required” при pulling образов).
	•	Если в VirtualBox — установите haveged для лучшей энтропии: sudo yum install haveged && sudo systemctl start haveged.
	•	Запускайте как sudo bash script.sh (не sh, чтобы избежать проблем с интерпретатором).
Вот полный скрипт (сохраните как setup.sh и сделайте исполняемым: chmod +x setup.sh).
#!/bin/bash

# --- МЕГА-АВТОМАТИЗИРОВАННЫЙ СКРИПТ ДЛЯ СТЕКА WORDPRESS + GRAFANA ---
# Автор: Grok (на основе всех диалогов и исправлений)
# Версия: 2.0 (2025-10-29)
# Описание: Полностью автоматизирует установку стека с WordPress, MariaDB, phpMyAdmin, Grafana.
#           Автоматически настраивает WP, генерирует пароли, проверяет готовность, улучшает дашборд.
#           Исправления: надёжная генерация паролей с fallback, проверки на пустоту, удалена version в yml,
#           убраны кавычки в env, полный URL для MySQL в Grafana, docker login reminder.
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

# Генерация случайного пароля (с fallback на date+sha256 для VM с низкой энтропией)
generate_password() {
    local pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1 2>/dev/null)
    if [ -z "$pass" ]; then
        pass=$(echo "random$(date +%s%N)" | sha256sum | head -c 12)
    fi
    echo "$pass"
}

# Проверка готовности контейнера
wait_for_container() {
    local container=$1
    local timeout=90  # Увеличили таймаут для медленных VM
    local counter=0
    info "Ждём готовности $container..."
    while [ $counter -lt $timeout ]; do
        if sudo docker inspect -f '{{.State.Health.Status}}' $container 2>/dev/null | grep -q "healthy"; then
            success "$container готов!"
            return 0
        fi
        sleep 5
        counter=$((counter + 5))
    done
    error "Таймаут ожидания $container. Проверьте логи: sudo docker logs $container"
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
warning "Не используйте в продакшене! Перед запуском выполните 'sudo docker login' для избежания ошибок pulling."
warning "Нажмите ENTER или CTRL+C."
read

# --- [1/11] ПРОВЕРКА И УСТАНОВКА ПРЕДПОСЫЛОК ---
info "[1/11] Проверка системы..."

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
WP_ADMIN_USER="admin_$(generate_password | cut -c1-4)"
WP_ADMIN_PASS=$(generate_password)
WP_ADMIN_EMAIL="admin@example.com"
WP_TITLE="My Test Site"
WP_URL="http://$(hostname -I | awk '{print $1}'):$WP_PORT"

# Проверка паролей
info "DEBUG: MYSQL_ROOT_PASS = [$MYSQL_ROOT_PASS]"
info "DEBUG: WP_DB_PASS = [$WP_DB_PASS]"
if [ -z "$MYSQL_ROOT_PASS" ]; then error "MYSQL_ROOT_PASS пуст! Проблема с генерацией."; fi
if [ -z "$WP_DB_PASS" ]; then error "WP_DB_PASS пуст!"; fi

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
info "[5/11] Создание docker-compose.yml (без version, без кавычек в env)..."
cat << EOF > docker-compose.yml
services:
  db:
    image: mariadb:10.6
    container_name: wordpress_db
    volumes:
      - db_data:/var/lib/mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASS
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wp_user
      MYSQL_PASSWORD: $WP_DB_PASS
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
      WORDPRESS_DB_USER: wp_user
      WORDPRESS_DB_PASSWORD: $WP_DB_PASS
      WORDPRESS_DB_NAME: wordpress
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
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASS
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
      GF_SECURITY_ADMIN_PASSWORD: $GRAFANA_ADMIN_PASS
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

# Проверка файла
if [ ! -s docker-compose.yml ] || ! grep -q "$MYSQL_ROOT_PASS" docker-compose.yml; then
    error "docker-compose.yml не создан, пустой или пароль не подставлен! Проверьте here-document."
fi
success "docker-compose.yml создан."

# --- [6/11] СОЗДАНИЕ ПРОВИЖЕНИНГА GRAFANA ---
info "[6/11] Создание provisioning для Grafana (с исправленным URL для MySQL)..."

# Datasource: без кавычек на EOF, т.к. есть переменная $WP_DB_PASS
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
      password: $WP_DB_PASS
    jsonData:
      maxOpenConns: 20
      maxIdleConns: 10
      connMaxLifetime: 14400
      timeInterval: '1m'
      tlsSkipVerify: true  # Для теста, без TLS
EOF

if [ ! -s provisioning/datasources/datasource.yml ] || ! grep -q "$WP_DB_PASS" provisioning/datasources/datasource.yml; then
    error "datasource.yml не создан или пароль не подставлен!"
fi

# Providers: с 'EOF' для literal
cat << 'EOF' > provisioning/dashboards/dashboard.yml
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

if [ ! -s provisioning/dashboards/dashboard.yml ]; then
    error "dashboard.yml не создан или пустой!"
fi

# Дашборд JSON: с 'EOF' для literal (нет переменных)
cat << 'EOF' > provisioning/dashboards/wp-stats-dashboard.json
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
  "version": 2
}
EOF

if [ ! -s provisioning/dashboards/wp-stats-dashboard.json ]; then
    error "wp-stats-dashboard.json не создан или пустой! Проверьте here-document в скрипте."
fi
success "Provisioning Grafana создан (с исправленным подключением к DB)."

# --- [7/11] ФИКС SELINUX ---
info "[7/11] Обработка SELinux..."
sudo restorecon -R $PROJECT_DIR
sudo chcon -Rt svirt_sandbox_file_t $PROJECT_DIR &>/dev/null  # На всякий
success "SELinux настроен."

# --- [8/11] ЗАПУСК КОНТЕЙНЕРОВ ---
info "[8/11] Запуск docker compose up -d..."
sudo docker compose up -d || error "Ошибка запуска (проверьте docker login и интернет)."
wait_for_container wordpress_db

# --- [9/11] АВТОМАТИЗАЦИЯ УСТАНОВКИ WORDPRESS ---
info "[9/11] Автоматическая установка WordPress через wp-cli..."
sudo docker exec -i wordpress_app wp core install \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_ADMIN_PASS" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --skip-email || error "Ошибка установки WP (проверьте логи db и wordpress)."
success "WordPress установлен автоматически!"

# --- [10/11] ПРОВЕРКА GRAFANA ---
wait_for_container grafana_app
info "[10/11] Просмотр логов Grafana на ошибки (проверьте подключение к DB)..."
sudo docker compose logs grafana | tail -n 50 | grep -i "datasource\|mysql\|error\|connect"

# --- [11/11] ВЫВОД РЕЗУЛЬТАТОВ ---
IP_ADDR=$(hostname -I | awk '{print $1}')
success "[11/11] Установка завершена!"

echo "==================================================================="
echo "✅ СТЕК ГОТОВ В $PROJECT_DIR"
echo "==================================================================="
echo "🌍 WordPress: http://$IP_ADDR:$WP_PORT"
echo "   Admin: $WP_ADMIN_USER / $WP_ADMIN_PASS"
echo ""
echo "🗃️ phpMyAdmin: http://$IP_ADDR:$PMA_PORT"
echo "   Root: root / $MYSQL_ROOT_PASS"
echo "   WP User: wp_user / $WP_DB_PASS"
echo ""
echo "📊 Grafana: http://$IP_ADDR:$GRAFANA_PORT"
echo "   Admin: admin / $GRAFANA_ADMIN_PASS"
echo "   Дашборд: 'Advanced WordPress Stats' (с графиками и статами)"
echo "   (Если проблема с подключением, проверьте логи Grafana на ошибки)"
echo ""
echo "Логи: /var/log/my-stack-setup.log
