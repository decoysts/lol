#!/bin/bash
# ==============================================================================
# Скрипт автоматической настройки (CentOS + Docker + Grafana + osTicket + MariaDB)
# Основан на предоставленных фотографиях.
# ==============================================================================

echo "### НАЧАЛО АВТОМАТИЧЕСКОЙ НАСТРОЙКИ ###"

# ------------------------------------------------------------------------------
# ШАГ 1: НАСТРОЙКА РЕПОЗИТОРИЕВ CENTOS (из Фото 1)
# ------------------------------------------------------------------------------
echo "## 1. Настройка репозиториев CentOS..."
sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/CentOS*
sed -i 's/^#baseurl/baseurl/g' /etc/yum.repos.d/CentOS*
sed -i 's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS*
yum update -y

# ------------------------------------------------------------------------------
# ШАГ 2: УСТАНОВКА ПАКЕТОВ (MariaDB, HTTPD, PHP) (из Фото 1)
# ------------------------------------------------------------------------------
echo "## 2. Установка системных пакетов (YUM)..."
yum install -y nano wget epel-release yum-utils httpd mariadb-server
yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --disable remi-php54
yum-config-manager --enable remi-php72
yum install -y php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mcrypt php-mbstring php-curl php-xml php-pear php-bcmath php-json

# ------------------------------------------------------------------------------
# ШАГ 3: НАСТРОЙКА MARIADB (БАЗА ДАННЫХ) (из Фото 3)
# ------------------------------------------------------------------------------
echo "## 3. Настройка MariaDB..."
systemctl start mariadb
systemctl enable mariadb

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!! ВНИМАНИЕ: ТРЕБУЕТСЯ РУЧНОЕ ВМЕШАТЕЛЬСТВО !!!"
echo "Сейчас запустится 'mysql_secure_installation'."
echo "Согласно вашим запискам, вводите: y, 1, 1, y, n, y, y"
echo "Это установит пароль root для MySQL в '1'."
echo "Нажмите [Enter] для продолжения..."
read -r
mysql_secure_installation
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

echo "Создание пользователя БД для osTicket (user / 1)..."
# Мы используем пароль '1', который вы (предположительно) установили на предыдущем шаге.
mysql -u root -p'1' -e "CREATE USER 'user'@'%' IDENTIFIED BY '1';"
mysql -u root -p'1' -e "GRANT ALL PRIVILEGES ON *.* TO 'user'@'%';"
mysql -u root -p'1' -e "FLUSH PRIVILEGES;"

# ------------------------------------------------------------------------------
# ШАГ 4: НАСТРОЙКА PHPMYADMIN (из Фото 1)
# ------------------------------------------------------------------------------
echo "## 4. Настройка phpMyAdmin..."
cd /var/www/html
wget https://files.phpmyadmin.net/phpMyAdmin/4.9.10/phpMyAdmin-4.9.10-all-languages.zip
unzip phpMyAdmin-4.9.10-all-languages.zip
rm -rf phpMyAdmin-4.9.10-all-languages.zip
mv phpMyAdmin-4.9.10-all-languages pma

echo "Настройка httpd на порт 81..."
sed -i 's/Listen 80/Listen 81/' /etc/httpd/conf/httpd.conf
systemctl start httpd
systemctl enable httpd

# ------------------------------------------------------------------------------
# ШАГ 5: УСТАНОВКА DOCKER (из Фото 1)
# ------------------------------------------------------------------------------
echo "## 5. Установка Docker..."
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl start docker
systemctl enable docker

# ------------------------------------------------------------------------------
# ШАГ 6: НАСТРОЙКА FIREWALL (из Фото 1)
# ------------------------------------------------------------------------------
echo "## 6. Настройка Firewall..."
# Открываем порты: 80 (osTicket), 81 (phpMyAdmin), 3000 (Grafana), 3306 (MariaDB)
firewall-cmd --permanent --zone=public --add-port={80,81,3000,3306}/tcp
firewall-cmd --reload

# ------------------------------------------------------------------------------
# ШАГ 7: СБОРКА И ЗАПУСК GRAFANA (Docker) (из Фото 1 и 3)
# ------------------------------------------------------------------------------
echo "## 7. Сборка и запуск контейнера Grafana..."
mkdir -p /grafana
cd /grafana

echo "Создание Grafana Dockerfile..."
cat <<'EOF' > Dockerfile
FROM ubuntu:18.04
RUN apt-get update -y
RUN apt-get install -y nano wget libfontconfig1
RUN cd / && wget https://bppk.info/schedule/grafana-enterprise_9.1.0_amd64.deb
RUN cd / && dpkg -i grafana-enterprise_9.1.0_amd64.deb
EOF

docker build -t grafana .

echo "Запуск контейнера Grafana..."
# Мы используем -ti и /bin/bash, как в ваших записях, чтобы контейнер не выключался
docker run -d --name grafana -p 3000:3000 -ti grafana /bin/bash
docker ps
echo "Запуск сервиса Grafana внутри контейнера..."
docker exec grafana service grafana-server start

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
RUN cd /var/www/html/ && wget https://bppk.info/schedule/osTicket-1.15.zip && unzip osTicket-1.15.zip && rm -rf osTicket-1.15.zip
RUN cd /var/www/html/ && wget https://bppk.info/schedule/osTicket-v1.15.8.zip && unzip osTicket-v1.15.8.zip && rm -rf osTicket-v1.15.8.zip
RUN cd /var/www/html/ && mv ./upload/* /var/www/html/
RUN cd /var/www/html/ && cp include/ost-sampleconfig.php include/ost-config.php && chmod 0666 include/ost-config.php && rm -rf index.html
RUN cp /var/www/html/ru.phar /var/www/html/include/i18n/
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

