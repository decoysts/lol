#!/bin/bash

# Переменные для подключения к MySQL (замените на свои данные)
DB_USER="user"
DB_PASS="1"
DB_HOST="localhost"
DB_NAME="metrics"

# Путь к лог-файлу
LOG_FILE="metrics.log"

# Установка значения hdddisk
hdddisk="/dev/mapper/centos-root"  # Измените на нужный диск

# Получение даты и времени
date=$(date +"%H:%M:%S")

# Проверка доступного RAM (в гигабайтах)
ram=$(free -h | grep "Mem:" | awk '{print $7}' | sed 's/[^0-9.]*//g' | sed 's/G//')
if [ -z "$ram" ]; then ram="0"; fi

# Проверка доступного места на диске (в гигабайтах)
hdd=$(df -h | grep "$hdddisk" | awk '{print $4}' | sed 's/[^0-9.]*//g' | sed 's/G//')
if [ -z "$hdd" ]; then hdd="0"; fi

# Проверка использования CPU (исправленная версия)
freecpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | sed 's/[^0-9.]*//g' | awk '{print ($1 > 0) ? $1 : 0}')
if [ -z "$freecpu" ]; then freecpu="0"; fi
cpu=$(echo "scale=2; 100 - $freecpu" | bc)

# Определение статуса
ramStatus=""
hddStatus=""
cpuStatus=""

if [ $(echo "$ram < 1" | bc -l) -eq 1 ]; then ramStatus="low memory"; fi
if [ $(echo "$hdd < 1" | bc -l) -eq 1 ]; then hddStatus="low hdd"; fi
if [ $(echo "$cpu > 89" | bc -l) -eq 1 ]; then cpuStatus="high CPU"; fi

status="${ramStatus}${hddStatus:+ $hddStatus}${cpuStatus:+ $cpuStatus}"
if [ -z "$status" ]; then status="OK"; fi

# Выполнение SQL-запроса
mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" "$DB_NAME" -e "INSERT INTO servers (ram, hdd, cpu, status) VALUES ('$ram', '$hdd', '$cpu', '$status');" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Ошибка выполнения SQL-запроса" >> "$LOG_FILE"
fi

# Вывод в консоль
echo "RAM: $ram GB"
echo "HDD: $hdd GB"
echo "CPU: $cpu%"
echo "Status: $status"

# Запись в лог
echo "$date - RAM: $ram GB, HDD: $hdd GB, CPU: $cpu%, Status: $status" >> "$LOG_FILE"

# Делаем скрипт исполняемым и создаём лог, если его нет
chmod +x "$0"
touch "$LOG_FILE" 2>/dev/null
