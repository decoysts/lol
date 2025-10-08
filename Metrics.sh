#!/bin/bash

# Изменение значения hdddisk
hdddisk="/dev/sdb1"
hdd=$hdddisk  # change /dev/sdb1 to your value
date=$(date +"%H:%M:%S")

# Проверка метрик
checkRamUnits=$(free -h | grep Mem | awk '{print $7}')
checkHddUnits=$(df -h | grep $hdd | awk '{print $4}')

# Обработка RAM
if [[ $checkRamUnits == "0" ]]; then
    ram=$(free -h | grep Mem | awk '{print $7}') sed 's/[^0-9.]//g' | sed -r 's/([0-9]+\.[0-9])[GM]/\1/'
else
    ram=$(free -h | grep Mem | awk '{print $7}') sed 's/[^0-9.]//g' | sed -r 's/([0-9]+\.[0-9])[GM]/\1/'
fi

# Обработка HDD
if [[ $checkHddUnits == "0" ]]; then
    hdd=$(df -h | grep $hdd | awk '{print $4}') sed 's/[^0-9.]//g' | sed -r 's/([0-9]+\.[0-9])[GM]/\1/'
else
    hdd=$(df -h | grep $hdd | awk '{print $4}') sed 's/[^0-9.]//g' | sed -r 's/([0-9]+\.[0-9])[GM]/\1/'
fi

# Обработка CPU
freecpu=$(top -n 1 | grep %Cpu | awk '{print $8}')
cpu=$((100 - $freecpu))

# Обработка статуса
#DataProcessing
if [[ $checkRamUnits == "0" ]]; then ramStatus="low memory"; fi
if [[ $checkHddUnits == "0" ]]; then hddStatus="low hdd"; fi
if [[ $cpu > 89 ]]; then cpuStatus="high CPU"; fi

status="${ramStatus} ${hddStatus} ${cpuStatus}"

checkStatus=$(echo $status | wc -m)
if [[ $checkStatus < 10 ]]; then status="OK"; fi

# Запрос в БД
echo "INSERT INTO servers (ram, hdd, cpu, status) VALUES ('$ram', '$hdd', '$cpu', '$status');"

# Вывод в консоль
echo $ram
echo $hdd
echo $cpu
echo $status

# Лог
echo "$date >> /scripts/metrics.log"
chmod +x metrics.sh
touch metrics.log
