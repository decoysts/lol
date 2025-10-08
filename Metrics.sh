#!/bin/bash
connect="mysql -u user -p1"
hdddisk="/dev/mapper/centos-root" # change /dev/sdb1 to your value
date=$(date +"%H:%M:%S")

#ScanMetrics
checkRamUnits=$(free -h | grep Mem | awk '{print $7}') | grep G | wc -l
if [[ $checkRamUnits == 1 ]]; then ram=$(free -h | grep Mem | awk '{print $7}') | sed 's/[^0-9.]//g' | sed -r 's/([0-9]+\.[0-9])[GM]/\1/'
else
    ram=$(free -h | grep Mem | awk '{print $7}') | sed 's/[^0-9.]//g' | sed -r 's/([0-9]+\.[0-9])[GM]/\1/'
fi

checkHddUnits=$(df -h | grep $hdd | awk '{print $4}') | grep G | wc -l
if [[ $checkHddUnits == 1 ]]; then hdd=$(df -h | grep $hdd | awk '{print $4}') | sed 's/[^0-9.]//g' | sed -r 's/([0-9]+\.[0-9])[GM]/\1/'
else
    hdd=$(df -h | grep $hdd | awk '{print $4}') | sed 's/[^0-9.]//g' | sed -r 's/([0-9]+\.[0-9])[GM]/\1/'
fi

freecpu=$(top -n 1 | grep %Cpu | awk '{print $8}') | sed -r 's/[^0-9.]//g'
cpu=$((100 - $freecpu))

#DataProcessing
if [[ $checkRamUnits == 0 ]]; then ramStatus="low memory"; fi
if [[ $checkHddUnits == 0 ]]; then hddStatus="low hdd"; fi
if [[ $cpu > 89 ]]; then cpuStatus="high CPU"; fi

status="${ramStatus} ${hddStatus} ${cpuStatus}"

checkStatus=$(echo $status | wc -m)
if [[ $checkStatus < 10 ]]; then status="OK"; fi

#Query in DB
echo "INSERT INTO servers (ram, hdd, cpu, status) VALUES ('$ram', '$hdd', '$cpu', '$status');"

#View in console
echo $ram
echo $hdd
echo $cpu
echo $status

#Log journal
date >> /scripts/metrics.log

chmod +x metrics.sh
touch metrics.log
