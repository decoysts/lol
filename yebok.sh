#!/bin/bash

# --- НАЧАЛО СКРИПТА ---

# 0. Предупреждение о безопасности
echo "==================================================================="
echo "ВНИМАНИЕ: Этот скрипт устанавливает ПО и генерирует пароли."
echo "Он предназначен только для ТЕСТИРОВАНИЯ. Не для продакшена."
echo "Нажмите ENTER для продолжения или CTRL+C для отмены..."
read

# 1. Установка Docker и Docker Compose
echo "--- [1/7] Установка Docker и Docker Compose ---"
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io

# Установка Docker Compose
LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "tag_name" | cut -d'"' -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

sudo systemctl start docker
sudo systemctl enable docker

# 2. Настройка Firewall
echo "--- [2/7] Настройка Firewalld ---"
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo firewall-cmd --add-port=80/tcp --permanent    # WordPress
sudo firewall-cmd --add-port=8081/tcp --permanent # phpMyAdmin
sudo firewall-cmd --add-port=3000/tcp --permanent # Grafana
sudo firewall-cmd --reload

# 3. Генерация паролей и создание директорий
echo "--- [3/7] Генерация конфигураций и паролей ---"
PROJECT_DIR=~/my-full-stack
mkdir -p $PROJECT_DIR/provisioning/datasources
mkdir -p $PROJECT_DIR/provisioning/dashboards

# Генерируем случайные безопасные пароли
MYSQL_ROOT_PASS=qazwsx6
WP_DB_PASS=qazwsx6
GRAFANA_ADMIN_PASS=qazwsx6

cd $PROJECT_DIR

# 4. Создание docker-compose.yml
echo "--- [4/7] Создание docker-compose.yml ---"
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

  wordpress:
    image: wordpress:latest
    container_name: wordpress_app
    depends_on:
      - db
    ports:
      - "80:80"
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
      - db
    ports:
      - "8081:80"
    restart: always
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: '$MYSQL_ROOT_PASS'
    networks:
      - app_network

  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana_app
    ports:
      - "3000:3000"
    restart: always
    environment:
      GF_SECURITY_ADMIN_PASSWORD: '$GRAFANA_ADMIN_PASS'
    volumes:
      - grafana_data:/var/lib/grafana
      # Автоматическая настройка (Provisioning)
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

# 5. Создание файлов авто-настройки (Provisioning) для Grafana
echo "--- [5/7] Создание файлов provisioning для Grafana ---"

# 5.1. Источник данных (datasource)
cat << EOF > provisioning/datasources/datasource.yml
apiVersion: 1

datasources:
  - name: 'WordPress DB (MariaDB)'
    type: mysql
    uid: 'wp-mysql-ds' # Уникальный ID
    host: db:3306
    user: wp_user
    database: wordpress
    secureJsonData:
      password: '$WP_DB_PASS' # Используем пароль
    jsonData:
      sslmode: 'disable'
      maxOpenConns: 10
      maxIdleConns: 5
      connMaxLifetime: 14400
EOF

# 5.2. Загрузчик дашбордов
cat << EOF > provisioning/dashboards/dashboard.yml
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# 5.3. Сам дашборд (JSON)
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
      "title": "Пользователи",
      "gridPos": { "h": 6, "w": 8, "x": 0, "y": 0 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [
        {
          "refId": "A",
          "rawSql": "SELECT COUNT(*) FROM wp_users;",
          "format": "table"
        }
      ],
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }
    },
    {
      "id": 2,
      "type": "stat",
      "title": "Опубликованные страницы",
      "gridPos": { "h": 6, "w": 8, "x": 8, "y": 0 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [
        {
          "refId": "A",
          "rawSql": "SELECT COUNT(*) FROM wp_posts WHERE post_type = 'page' AND post_status = 'publish';",
          "format": "table"
        }
      ],
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }
    },
    {
      "id": 3,
      "type": "stat",
      "title": "Одобренные комментарии",
      "gridPos": { "h": 6, "w": 8, "x": 16, "y": 0 },
      "datasource": { "type": "mysql", "uid": "wp-mysql-ds" },
      "targets": [
        {
          "refId": "A",
          "rawSql": "SELECT COUNT(*) FROM wp_comments WHERE comment_approved = '1';",
          "format": "table"
        }
      ],
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }
    }
  ],
  "refresh": "10s",
  "schemaVersion": 36,
  "style": "dark",
  "tags": [],
  "templating": { "list": [] },
  "time": { "from": "now-6h", "to": "now" },
  "timepicker": {},
  "timezone": "browser",
  "title": "WordPress Stats",
  "uid": "wp-stats-dashboard",
  "version": 1
}
EOF

# 6. Применение меток SELinux (ОЧЕНЬ ВАЖНО для CentOS)
echo "--- [6/7] Применение меток SELinux для томов ---"
# Это нужно, чтобы Docker-контейнер мог читать файлы, созданные в домашней директории
sudo chcon -Rt svirt_sandbox_file_t $PROJECT_DIR/provisioning

# 7. Запуск
echo "--- [7/7] Запуск контейнеров (docker-compose up -d) ---"
sudo docker-compose up -d

echo ""
echo "--- ОЖИДАНИЕ ЗАПУСКА (30 секунд) ---"
sleep 30

# --- ВЫВОД ДАННЫХ ---
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "==================================================================="
echo "✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo "==================================================================="
echo ""
echo "🌍 WordPress: http://$IP_ADDR"
echo "   (Пройдите первоначальную настройку WordPress)"
echo ""
echo "🗃️ phpMyAdmin: http://$IP_ADDR:8081"
echo "   (Сервер: 'db', Логин: 'root', Пароль (root): '$MYSQL_ROOT_PASS')"
echo "   (Логин (WP): 'wp_user', Пароль (WP): '$WP_DB_PASS')"
echo ""
echo "📊 Grafana: http://$IP_ADDR:3000"
echo "   Логин: admin"
echo "   Пароль: $GRAFANA_ADMIN_PASS"
echo ""
echo "   Дашборд 'WordPress Stats' должен появиться автоматически!"
echo "   (Если данных пока нет, зайдите на WordPress и создайте пользователя/страницы)"
echo ""
echo "==================================================================="

# --- КОНЕЦ СКРИПТА ---
