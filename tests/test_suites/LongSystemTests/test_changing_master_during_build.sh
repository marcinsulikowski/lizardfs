timeout_set '15 minutes'

metaservers_nr=2
MASTERSERVERS=$metaservers_nr \
	CHUNKSERVERS=2 \
	CHUNKSERVER_EXTRA_CONFIG="MASTER_RECONNECTION_DELAY = 1" \
	MFSEXPORTS_EXTRA_OPTIONS="allcanchangequota" \
	MOUNT_EXTRA_CONFIG="mfsacl,mfscachemode=NEVER" \
	setup_local_empty_lizardfs info

wait_for_shadow_to_run_and_sync() {
	shadow_id=$1
	assert_eventually 'test -e "${info[master${shadow_id}_data_path]}/metadata.mfs.lock"'
	assert_eventually 'test -e "${info[master${shadow_id}_data_path]}/changelog.mfs.3"'
}

assert_program_installed git
assert_program_installed cmake

master_kill_loop() {
	# Start shadow masters
	for ((shadow_id=1 ; shadow_id<metaservers_nr; ++shadow_id)); do
		lizardfs_master_n $shadow_id start
		wait_for_shadow_to_run_and_sync $shadow_id
	done

	loop_nr=0
	# Let the master run for few seconds and then replace it with another one
	while true; do
		echo "Loop nr $loop_nr"
		sleep 5

		prev_master_id=$((loop_nr % metaservers_nr))
		new_master_id=$(((loop_nr + 1) % metaservers_nr))
		loop_nr=$((loop_nr + 1))

		# Kill the previous master
		lizardfs_master_daemon kill
		lizardfs_make_conf_for_shadow $prev_master_id

		# Promote a next master
		lizardfs_make_conf_for_master $new_master_id
		lizardfs_master_daemon reload

		# Demote previous master to shadow
		lizardfs_make_conf_for_shadow $prev_master_id
		lizardfs_master_n $prev_master_id start
		wait_for_shadow_to_run_and_sync $prev_master_id

		lizardfs_wait_for_all_ready_chunkservers
	done
}

# Daemonize the master kill loop
master_kill_loop &

cd "${info[mount0]}"
assert_success git clone https://github.com/lizardfs/lizardfs.git
mfssetgoal -r 2 lizardfs
mkdir lizardfs/build
cd lizardfs/build
assert_success cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=../install
assert_success make -j5 install
