#!/usr/bin/env bash

# Source: Gamocosm

NUM_CPUS=$(grep --count '^processor' /proc/cpuinfo)
TOTAL_RAM=$(awk '/MemTotal/ { print $2; }' /proc/meminfo)

# convert to bytes, half or ram, split between cpus
DEVICE_SIZE=$((TOTAL_RAM * 1024 / 2 / NUM_CPUS));

case "$1" in
"start")
	modprobe zram "num_devices=$NUM_CPUS"
	for ((i = 0; i < $NUM_CPUS; i++)); do
		echo $DEVICE_SIZE > "/sys/block/zram${i}/disksize"
		mkswap "/dev/zram${i}"
		swapon --priority 100 "/dev/zram${i}"
	done
	;;
"stop")
	for device in $(awk '/zram/ { print $1; }' /proc/swaps); do
		swapoff "$device"
	done
	rmmod zram
	;;
*)
	echo "Usage: zram [start|stop]"
	;;
esac
