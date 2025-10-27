#!/bin/bash

echo "--- [1/5] Переходим в папку проекта ---"
cd ~/my-full-stack

# Убедимся, что WordPress установлен. ЕСЛИ ТЫ ЭТОГО НЕ СДЕЛАЛ, СДЕЛАЙ СЕЙЧАС.
echo "!!! ВНИМАНИЕ !!!"
echo "Убедись, что ты зашел на http://192.168.10.138 и ЗАВЕРШИЛ установку WordPress."
echo "Если нет, сделай это, пока скрипт работает. Нажми ENTER."
read

echo "--- [2/5] Останавливаем все и чистим старый том Grafana ---"
sudo docker-compose down
sudo docker volume rm -f my-full-stack_grafana_data

echo "--- [3/5] Чиним DNS и интернет для Docker (перезапуск служб) ---"
sudo systemctl restart firewalld
sudo systemctl restart docker
# Ждем, пока Docker проснется
sleep 10

echo "--- [4/5] Создаем Dockerfile.grafana (чтобы встроить конфиги) ---"
cat << EOF > Dockerfile.grafana
# Используем базовый образ
FROM grafana/grafana-oss:latest
# Копируем наши конфиги ПРЯМО ВНУТРЬ образа, обходя SELinux
COPY ./provisioning /etc/grafana/provisioning
EOF

# Генерируем пароли заново (на всякий случай, если они потерялись)
MYSQL_ROOT_PASS=qazwsx6
WP_DB_PASS=qazwsx6
GRAFANA_ADMIN_PASS=qazwsx6
IP_ADDR=$(hostname -I | awk '{print $1}')

echo "--- [5/5] Перезаписываем docker-compose.yml, чтобы он собирал новый образ ---"
# Этот compose-файл отличается от старого в секции 'grafana'
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

  # --- ВОТ ИЗМЕНЕНИЯ ---
  grafana:
    # Вместо 'image:', мы используем 'build:'
    build:
      context: .
      dockerfile: Dockerfile.grafana
    container_name: grafana_app
    ports:
      - "3000:3000"
    restart: always
    environment:
      GF_SECURITY_ADMIN_PASSWORD: '$GRAFANA_ADMIN_PASS'
    volumes:
      # Мы убрали монтирование папки provisioning
      # Теперь используется только том для данных
      - grafana_data:/var/lib/grafana
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

echo "--- ЗАПУСК! ---"
echo "Собираем новый образ Grafana и запускаем все. Это займет ~1 минуту..."
# --build заставит его собрать новый образ grafana
sudo docker-compose up -d --build

echo "Ждем 45 секунд, пока все запустится..."
sleep 45

echo "--- СМОТРИМ НОВЫЙ ЛОГ ---"
# Теперь в логе не должно быть ошибок 127.0.0.1
sudo docker-compose logs grafana

echo "================================================="
echo "✅ ВСЕ! Теперь должно работать."
echo "Проверь Grafana: http://$IP_ADDR:3000"
echo "Логин: admin / Пароль: $GRAFANA_ADMIN_PASS"
echo "(Если дашборд пустой, убедись, что ты завершил установку WordPress)"
echo "================================================="
