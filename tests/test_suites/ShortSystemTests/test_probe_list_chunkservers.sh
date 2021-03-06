CHUNKSERVERS=4 \
	MASTER_EXTRA_CONFIG="REPLICATIONS_DELAY_INIT = 100000" \
	MOUNT_EXTRA_CONFIG="mfscachemode=NEVER" \
	USE_RAMDISK=YES \
	setup_local_empty_lizardfs info

cd "${info[mount0]}"
goals="3 4"
for goal in $goals; do
	mkdir dir_$goal
	mfssetgoal $goal dir_$goal
	echo a > dir_$goal/file
done

list_chunkservers() {
	lizardfs-probe list-chunkservers --porcelain localhost "${info[matocl]}"
}

export MESSAGE="Veryfing chunkservers list with all the chunkservers up"
expect_eventually \
	'(($(list_chunkservers | awk "{chunks += \$3} END {print chunks}") == 7))' \
	'30 seconds'
cslist=$(list_chunkservers)
expect_equals 4 $(wc -l <<< "$cslist")
expect_equals 4 $(awk -v version="$LIZARDFS_VERSION" '$2 == version' <<< "$cslist" | wc -l)

export MESSAGE="Veryfing chunkservers list with one chunkserver down"
mfschunkserver -c "${info[chunkserver0_config]}" stop
lizardfs_wait_for_ready_chunkservers 3
cslist=$(list_chunkservers)
expect_equals 3 $(awk '$5 != "0"' <<< "$cslist" | wc -l)
chunks=$(awk '{chunks += $3} END {print chunks}' <<< "$cslist")
expect_equals 1 $((chunks == 5 || chunks == 6))
