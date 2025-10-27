#!/bin/bash

echo "--- [1/5] Переходим в папку проекта ---"
cd ~/my-full-stack

echo "--- [2/5] Останавливаем все, что запущено (новой командой) ---"
# 'docker compose' (без дефиса)
sudo docker compose down -v
# 'docker-compose' (с дефисом), на всякий случай
sudo docker-compose down -v

echo "--- [3/5] Возвращаем простой docker-compose.yml (БЕЗ СБОРКИ) ---"
# Он снова будет использовать 'image: grafana...'
# Мы также добавим healthcheck, чтобы Grafana ждала базу

# Получаем пароли из старого файла, чтобы не генерить новые
MYSQL_ROOT_PASS=$(grep 'MYSQL_ROOT_PASSWORD' docker-compose.yml | head -n 1 | cut -d\' -f2)
WP_DB_PASS=$(grep 'WORDPRESS_DB_PASSWORD' docker-compose.yml | head -n 1 | cut -d\' -f2)
GRAFANA_ADMIN_PASS=$(grep 'GF_SECURITY_ADMIN_PASSWORD' docker-compose.yml | head -n 1 | cut -d\' -f2)

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
    # Проверка, что база данных готова принимать подключения
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
        condition: service_healthy # Ждем, пока 'db' будет 'healthy'
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
      # Возвращаем старый способ монтирования
      - grafana_data:/var/lib/grafana
      - ./provisioning/datasources:/etc/grafana/provisioning/datasources
      - ./provisioning/dashboards:/etc/grafana/provisioning/dashboards
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

echo "--- [4/5] ГЛАВНЫЙ ФИКС: Применяем метки SELinux к папке provisioning ---"
# Эта команда 'говорит' SELinux, что файлы в этой папке можно читать контейнерам
sudo chcon -Rt svirt_sandbox_file_t $PROJECT_DIR/provisioning

echo "--- [5/5] Запускаем все (старой командой docker-compose С ДЕФИСОМ) ---"
# Она проще и не требует buildx
sudo docker-compose up -d

echo "--- Ждем 45 секунд... ---"
sleep 45

echo "--- СМОТРИМ ЛОГ GRAFANA ---"
sudo docker-compose logs grafana

IP_ADDR=$(hostname -I | awk '{print $1}')
echo "================================================="
echo "✅ Проверяй. Теперь конфиг должен был прочитаться."
echo "Grafana: http://$IP_ADDR:3000"
echo "Логин: admin / Пароль: $GRAFANA_ADMIN_PASS"
echo ""
echo "!!! НЕ ЗАБУДЬ СНАЧАЛА ЗАЙТИ НА http://$IP_ADDR И ЗАВЕРШИТЬ УСТАНОВКУ WORDPRESS !!!"
echo "================================================="
