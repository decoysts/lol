#!/bin/bash

echo "--- [1/6] Останавливаем и УДАЛЯЕМ старый проект из домашней папки ---"
cd ~/my-full-stack
sudo docker-compose down -v
cd ~
sudo rm -rf ~/my-full-stack

echo "--- [2/6] Копируем проект в /opt/my-stack (это системная папка) ---"
# SELinux 'доверяет' папке /opt намного больше, чем /root
sudo mkdir -p /opt/my-stack
# Копируем только нужные файлы
sudo cp ~/Dockerfile.grafana /opt/my-stack/
sudo cp ~/docker-compose.yml /opt/my-stack/
sudo mkdir -p /opt/my-stack/provisioning/datasources
sudo cp ~/provisioning/datasources/datasource.yml /opt/my-stack/provisioning/datasources/
sudo mkdir -p /opt/my-stack/provisioning/dashboards
sudo cp ~/provisioning/dashboards/*.yml /opt/my-stack/provisioning/dashboards/
sudo cp ~/provisioning/dashboards/*.json /opt/my-stack/provisioning/dashboards/

echo "--- [3/6] Переходим в новую папку ---"
cd /opt/my-stack

echo "--- [4/6] Восстанавливаем метки SELinux для новой папки ---"
# Эта команда 'прописывает' правильный контекст для Docker
sudo restorecon -R /opt/my-stack

echo "--- [5/6] Запускаем все (старой командой docker-compose С ДЕФИСОМ) ---"
# Мы используем простой docker-compose.yml (без 'build')
# (Скрипт скопировал старый yml)
sudo docker-compose up -d

echo "--- [6/6] Ждем 45 секунд... ---"
sleep 45

echo "--- СМОТРИМ НОВЫЙ ЛОГ GRAFANA ---"
sudo docker-compose logs grafana

IP_ADDR=$(hostname -I | awk '{print $1}')
PASS=$(grep GF_SECURITY_ADMIN_PASSWORD docker-compose.yml | cut -d\' -f2)

echo "================================================="
echo "✅ Проверяй. Теперь SELinux не должен мешать."
echo "Grafana: http://$IP_ADDR:3000"
echo "Логин: admin / Пароль: $PASS"
echo ""
echo "!!! СНАЧАЛА ЗАЙДИ НА http://$IP_ADDR И ЗАВЕРШИ УСТАНОВКУ WORDPRESS !!!"
echo "!!! (ИНАЧЕ В БАЗЕ НЕ БУДЕТ ТАБЛИЦ) !!!"
echo "================================================="
