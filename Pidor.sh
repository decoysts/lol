#!/bin/bash
# ==============================================================================
# Скрипт автоматической настройки (CentOS + Docker + Grafana + osTicket + MariaDB)
# Основан на предоставленных фотографиях.
# ==============================================================================
# ------------------------------------------------------------------------------
# ШАГ 8: СБОРКА И ЗАПУСК OSTICKET (Docker) (из Фото 3)
# ------------------------------------------------------------------------------
echo "## 8. Сборка и запуск контейнера osTicket..."
mkdir -p /osticket
cd /osticket

echo "Создание osTicket Dockerfile..."
# ПРИМЕЧАНИЕ: Я добавил 'DEBIAN_FRONTEND=noninteractive' для apt-get,
# чтобы избежать интерактивных запросов во время сборки.
# Также удалена команда 'RUN service apache2 start' - она неверна для Dockerfile.
cat <<'EOF' > Dockerfile
FROM ubuntu:18.04
ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget nano unzip apache2 \
    php php-apcu php-imap php-intl php-cli php-fpm php-json php-common \
    php-mysql php-zip php-gd php-mbstring php-curl php-xml php-pear php-bcmath

# --- ИСПРАВЛЕННЫЙ БЛОК ---
# Скачиваем osTicket v1.15.8 с официального GitHub
RUN cd /var/www/html/ && \
    wget https://github.com/osTicket/osTicket/releases/download/v1.15.8/osTicket-v1.15.8.zip && \
    unzip osTicket-v1.15.8.zip && \
    rm -rf osTicket-v1.15.8.zip

# Перемещаем файлы в корень
RUN cd /var/www/html/ && mv ./upload/* /var/www/html/

# Скачиваем русский языковой пакет (ru.phar) с официального сайта
RUN wget -O /var/www/html/include/i18n/ru.phar https://osticket.com/download/go?dl=lang%2Fru.phar&v=1.15
# --- КОНЕЦ ИСПРАВЛЕНИЙ ---

RUN cd /var/www/html/ && cp include/ost-sampleconfig.php include/ost-config.php && chmod 0666 include/ost-config.php && rm -rf index.html

# Эта строка из вашего фото (RUN cp... ru.phar) больше не нужна, 
# так как мы скачали язык сразу в нужную папку.

EOF

docker build -t osticket .

echo "Запуск контейнера osTicket..."
# Используем тот же метод -ti /bin/bash, что и для Grafana
docker run -d --name osticket -p 80:80 -ti osticket /bin/bash
docker ps
echo "Запуск сервиса Apache внутри контейнера..."
docker exec osticket service apache2 start

# ------------------------------------------------------------------------------
# ШАГ 9: ЗАВЕРШЕНИЕ
# ------------------------------------------------------------------------------
echo " "
echo "##################################################################"
echo "### АВТОМАТИЧЕСКАЯ НАСТРОЙКА ЗАВЕРШЕНА! ###"
echo " "
echo "Дальнейшие шаги (ТРЕБУЕТСЯ РУЧНАЯ НАСТРОЙКА):"
echo " "
echo "1.  УСТАНОВКА OSTICKET:"
echo "    - Откройте в браузере: http://<ВАШ_IP_АДРЕС>:80"
echo "    - Пройдите веб-установщик osTicket."
echo "    - При настройке БД используйте:"
echo "      - Сервер MySQL: IP-адрес вашего *хост-сервера* (НЕ localhost или 127.0.0.1)."
echo "      - Имя БД: (придумайте, например 'osticket_db')"
echo "      - Пользователь: user"
echo "      - Пароль: 1"
echo " "
echo "2.  ДОСТУП К GRAFANA:"
echo "    - http://<ВАШ_IP_АДРЕС>:3000 (логин/пароль по умолчанию: admin/admin)"
echo " "
echo "3.  ДОСТУП К PHPMYADMIN:"
echo "    - http://<ВАШ_IP_АДРЕС>:81/pma (логин: root, пароль: 1)"
echo "##################################################################"

