#!/bin/bash

# --- [0/7] ПРОВЕРКА СИСТЕМЫ ---
echo "--- [0/7] Проверяем, что docker и docker compose (v2) установлены ---"
if ! command -v docker &> /dev/null
then
    echo "!!! Docker не найден. Сначала установите Docker. Скрипт остановлен."
    exit 1
fi

# Проверяем 'docker compose' (v2, БЕЗ ДЕФИСА)
if ! docker compose version &> /dev/null
then
    echo "!!! 'docker compose' (v2) не найден. !!!"
    echo "Похоже, у тебя не установлен 'docker-compose-plugin'."
    echo "Выполни: sudo yum install -y docker-compose-plugin"
    echo "И перезапусти Docker: sudo systemctl restart docker"
    echo "Скрипт остановлен."
    exit 1
fi

echo "--- Все компоненты на месте. Начинаем... ---"

# --- [1/7] Устраняем конфликт порта 80 ---
echo "--- [1/7] Останавливаем Apache (httpd), чтобы освободить порт 80 ---"
sudo systemctl stop httpd
sudo systemctl disable httpd

# --- [2/7] Определяем пути и останавливаем старый стек ---
SOURCE_DIR=~/my-full-stack
DEST_DIR=/opt/my-stack

echo "--- [2/7] Останавливаем и удаляем старые контейнеры ---"
# Переходим в старую папку и все гасим
cd $SOURCE_DIR
# Используем новую команду
sudo docker compose down -v
# И старую, на всякий случай
sudo docker-compose down -v

# --- [3/7] Копируем проект в /opt (для обхода SELinux) ---
echo "--- [3/7] Копируем конфиги в $DEST_DIR ---"
sudo rm -rf $DEST_DIR
sudo mkdir -p $DEST_DIR
# Копируем твои конфиги из старой папки в новую
sudo cp -r $SOURCE_DIR/provisioning $DEST_DIR/

# --- [4/7] Создаем ИДЕАЛЬНЫЙ docker-compose.yml в новой папке ---
echo "--- [4/7] Создаем идеальный docker-compose.yml в $DEST_DIR ---"
# (Он будет использовать healthcheck, чтобы контейнеры ждали друг друга)

# Берем пароли из твоего старого файла
MYSQL_ROOT_PASS=$(grep 'MYSQL_ROOT_PASSWORD' $SOURCE_DIR/docker-compose.yml | head -n 1 | cut -d\' -f2)
WP_DB_PASS=$(grep 'WORDPRESS_DB_PASSWORD' $SOURCE_DIR/docker-compose.yml | head -n 1 | cut -d\' -f2)
GRAFANA_ADMIN_PASS=$(grep 'GF_SECURITY_ADMIN_PASSWORD' $SOURCE_DIR/docker-compose.yml | head -n 1 | cut -d\' -f2)

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
      # Монтируем конфиги из папки (теперь это /opt/my-stack/provisioning)
      - ./provisioning/datasources:/etc/grafana/provisioning/datasources
      - ./provisioning/dashboards:/etc/grafana/provisioning/dashboards
      # Том для данных
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

# --- [5/7] ФИНАЛЬНЫЙ ФИКС SELINUX ---
echo "--- [5/7] Восстанавливаем метки SELinux для $DEST_DIR ---"
# Эта команда 'прописывает' правильный контекст для Docker
sudo restorecon -R $DEST_DIR

echo "--- [6/7] Переходим в новую папку и запускаем (командой v2) ---"
cd $DEST_DIR
sudo docker compose up -d

echo "--- [7/7] Ждем 45 секунд... ---"
sleep 45

echo "--- СМОТРИМ ЛОГ GRAFANA ---"
sudo docker compose logs grafana

IP_ADDR=$(hostname -I | awk '{print $1}')
echo "================================================="
echo "✅ Проверяй. Теперь SELinux не должен мешать."
echo "Grafana: http://$IP_ADDR:3000"
echo "Логин: admin / Пароль: $GRAFANA_ADMIN_PASS"
echo ""
echo "!!! СНАЧАЛА ЗАЙДИ НА http://$IP_ADDR И ЗАВЕРШИ УСТАНОВКУ WORDPRESS !!!"
echo "!!! (ИНАЧЕ В БАЗЕ НЕ БУДЕТ ТАБЛИЦ И GRAFANA ПОКАЖЕТ ОШИБКУ) !!!"
echo "================================================="
