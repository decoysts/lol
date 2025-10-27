#!/bin/bash

# --- [0/7] ПРОВЕРКА СИСТЕМЫ ---
echo "--- [0/7] Проверяем, что docker и docker compose (v2) установлены ---"
if ! command -v docker &> /dev/null
then
    echo "!!! Docker не найден. Сначала установите Docker. Скрипт остановлен."
    exit 1
fi
if ! docker compose version &> /dev/null
then
    echo "!!! 'docker compose' (v2) не найден. !!!"
    echo "Выполни: sudo yum install -y docker-compose-plugin"
    echo "И перезапусти Docker: sudo systemctl restart docker"
    echo "Скрипт остановлен."
    exit 1
fi

echo "--- Все компоненты на месте. Начинаем... ---"
echo "Нажмите ENTER для продолжения..."
read

# --- [1/7] Устраняем конфликт порта 80 ---
echo "--- [1/7] Останавливаем Apache (httpd), чтобы освободить порт 80 ---"
sudo systemctl stop httpd
sudo systemctl disable httpd

# --- [2/7] Очистка и создание папки проекта ---
DEST_DIR=/opt/my-stack
echo "--- [2/7] Полностью чистим $DEST_DIR и ~/my-full-stack ---"
sudo docker compose -f $DEST_DIR/docker-compose.yml down -v 2>/dev/null
sudo docker-compose -f /root/my-full-stack/docker-compose.yml down -v 2>/dev/null
sudo rm -rf $DEST_DIR
sudo rm -rf /root/my-full-stack

echo "--- Создаем $DEST_DIR ---"
sudo mkdir -p $DEST_DIR/provisioning/datasources
sudo mkdir -p $DEST_DIR/provisioning/dashboards
cd $DEST_DIR

# --- [3/7] Генерация паролей ---
echo "--- [3/7] Генерация паролей ---"
MYSQL_ROOT_PASS='qazwsx6'
WP_DB_PASS='qazwsx6'
GRAFANA_ADMIN_PASS='qazwsx6'

# --- [4/7] Создание docker-compose.yml (с healthcheck) ---
echo "--- [4/7] Создаем docker-compose.yml в $DEST_DIR ---"
cat << EOF > $DEST_DIR/docker-compose.yml
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
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p$MYSQL_ROOT_PASS"]
      interval: 10s
      timeout: 5s
      retries: 5

  wordpress:
    image: wordpress:latest
    container_name: wordpress_app
    depends_on:
      db:
        condition: service_healthy # Ждет, пока 'db' будет 'healthy'
    ports:
      - "80:80"
    restart: always
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: 'wp_user'
      WORDPRESS_DB_PASSWORD: '$WP_DB_PASS'
      WORDPRESS_DB_NAME: 'wordpress'
    volumes:
      - wp_files:/var/lib/html
    networks:
      - app_network

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: phpmyadmin_app
    depends_on:
      db:
        condition: service_healthy
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
      # Монтируем конфиги из этой же папки
      - ./provisioning/datasources:/etc/grafana/provisioning/datasources
      - ./provisioning/dashboards:/etc/grafana/provisioning/dashboards
      - grafana_data:/var/lib/grafana
    networks:
      - app_network
    depends_on:
      db:
        condition: service_healthy # Grafana тоже ждет базу

networks:
  app_network:
    driver: bridge

volumes:
  db_data:
  wp_files:
  grafana_data:
EOF

# --- [5/7] Создание конфигов Grafana ---
echo "--- [5/7] Создаем конфиги Grafana в $DEST_DIR ---"

# 5.1. Источник данных
cat << EOF > $DEST_DIR/provisioning/datasources/datasource.yml
apiVersion: 1
datasources:
  - name: 'WordPress DB (MariaDB)'
    type: mysql
    uid: 'wp-mysql-ds'
    host: db:3306
    user: wp_user
    database: wordpress
    secureJsonData:
      password: '$WP_DB_PASS'
    jsonData:
      sslmode: 'disable'
EOF

# 5.2. Загрузчик дашбордов
cat << EOF > $DEST_DIR/provisioning/dashboards/dashboard.yml
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
cat << EOF > $DEST_DIR/provisioning/dashboards/wp-stats-dashboard.json
{
  "__inputs": [],"__requires": [],"annotations": { "list": [] },"editable": true,"gnetId": null,"graphTooltip": 0,"id": null,"links": [],"panels": [
    {"id": 1,"type": "stat","title": "Пользователи","gridPos": { "h": 6, "w": 8, "x": 0, "y": 0 },"datasource": { "type": "mysql", "uid": "wp-mysql-ds" },"targets": [{"refId": "A","rawSql": "SELECT COUNT(*) FROM wp_users;","format": "table"}],"options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }},
    {"id": 2,"type": "stat","title": "Опубликованные страницы","gridPos": { "h": 6, "w": 8, "x": 8, "y": 0 },"datasource": { "type": "mysql", "uid": "wp-mysql-ds" },"targets": [{"refId": "A","rawSql": "SELECT COUNT(*) FROM wp_posts WHERE post_type = 'page' AND post_status = 'publish';","format": "table"}],"options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }},
    {"id": 3,"type": "stat","title": "Одобренные комментарии","gridPos": { "h": 6, "w": 8, "x": 16, "y": 0 },"datasource": { "type": "mysql", "uid": "wp-mysql-ds" },"targets": [{"refId": "A","rawSql": "SELECT COUNT(*) FROM wp_comments WHERE comment_approved = '1';","format": "table"}],"options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto" }}
  ],"refresh": "10s","schemaVersion": 36,"style": "dark","tags": [],"templating": { "list": [] },"time": { "from": "now-6h", "to": "now" },"timepicker": {},"timezone": "browser","title": "WordPress Stats","uid": "wp-stats-dashboard","version": 1
}
EOF

# --- [6/7] ФИНАЛЬНЫЙ ФИКС SELINUX ---
echo "--- [6/7] Восстанавливаем метки SELinux для $DEST_DIR ---"
# Эта команда 'прописывает' правильный контекст для Docker
sudo restorecon -R $DEST_DIR

echo "--- [7/7] Запускаем (командой v2 'docker compose') ---"
# 'docker compose' (без дефиса)
sudo docker compose up -d

echo "--- Ждем 45 секунд... ---"
sleep 45

echo "--- СМОТРИМ ЛОГ GRAFANA ---"
sudo docker compose logs grafana

IP_ADDR=$(hostname -I | awk '{print $1}')
echo "================================================="
echo "✅ ВСЕ. Проект в /opt/my-stack"
echo "Grafana: http://$IP_ADDR:3000"
echo "Логин: admin / Пароль: $GRAFANA_ADMIN_PASS"
echo ""
echo "!!! СНАЧАЛА ЗАЙДИ НА http://$IP_ADDR И ЗАВЕРШИ УСТАНОВКУ WORDPRESS !!!"
echo "!!! (ИНАЧЕ В БАЗЕ НЕ БУДЕТ ТАБЛИЦ И GRAFANA ПОКАЖЕТ ОШИБКУ) !!!"
echo "================================================="
