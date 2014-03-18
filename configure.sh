#!/bin/sh

source servers

for server in $BACKENDS; do
  echo "Installing lvm and drdb packages on $server"
  ssh $server "apt-get install -y lvm2 drbd8-utils"
  echo "Formatting data partition on $server. This is required for Rackspace instances."
  ssh $server "mkfs.ext3 /dev/xvde1" # format data partition for rackspace
  echo "Creating drbd opscode volume on $server"
  ssh $server "pvcreate /dev/xvde1 && \
               vgcreate opscode /dev/xvde1 && \
               lvcreate -L 70G --name drbd opscode" 
done

echo "=Reconfigure $BOOTSTRAP="
ssh $BOOTSTRAP "private-chef-ctl reconfigure < /dev/null > reconfigure.out 2>&1 &"

kill_reconfigure () {
  echo "Checking if reconfigure is ready to abort"
  ssh $BOOTSTRAP "grep -Fq 'Press CTRL-C to abort' reconfigure.out"
  if [ $? == 0 ]; then
    echo "Aborting reconfigure"
    ssh $BOOTSTRAP "pkill chef-solo"
    kill_status=0
  else
    kill_status=1
  fi
}

start_time=$(date '+%s')

until [[ $kill_status == 0 ]] ; do
  current_time=$(date '+%s')
  if [[ $(( current_time - start_time )) > 60 ]]; then
  	echo "Reconfigure failed. Log file in reconfigure.out on remote server" 
  	exit 1
  else
    sleep 5
  fi
  kill_reconfigure
done

echo "Removing .local from server names in pc0.res file"
ssh $BOOTSTRAP "sed -i s/.local/\/ /var/opt/opscode/drbd/etc/pc0.res"

echo "Set up DRBD"
ssh $BOOTSTRAP "yes | /etc/init.d/drbd stop"
ssh $BOOTSTRAP "yes yes | drbdadm create-md pc0"
ssh $BOOTSTRAP "yes | /etc/init.d/drbd start"
ssh $BOOTSTRAP "drbdadm disconnect pc0"
ssh $BOOTSTRAP "drbdadm detach pc0"
ssh $BOOTSTRAP "drbdadm up pc0"

echo "Copying configuration to $BACKUP"
ssh $BOOTSTRAP "scp -r /etc/opscode $BACKUP:/etc"


echo "=Reconfigure $BACKUP="
ssh $BACKUP "private-chef-ctl reconfigure < /dev/null > reconfigure.out 2>&1 &"


### I did not refactor this - copy and paste :(
start_time=$(date '+%s')

until [[ $kill_status == 0 ]]; do
  current_time=$(date '+%s')
  if [[ $(( current_time - start_time )) > 60 ]]; then
    echo "Reconfigure failed. Log file in reconfigure.out on remote server" 
    exit 1
  else
    sleep 5
  fi
  kill_reconfigure
done

echo "Removing .local from server names in pc0.res file"
ssh $BACKUP "sed -i s/.local/\/ /var/opt/opscode/drbd/etc/pc0.res"

echo "Set up DRBD"
ssh $BACKUP "yes | /etc/init.d/drbd stop"
ssh $BACKUP "yes yes | drbdadm create-md pc0"
ssh $BACKUP "yes | /etc/init.d/drbd start"
ssh $BACKUP "drbdadm disconnect pc0"
ssh $BACKUP "drbdadm detach pc0"
ssh $BACKUP "drbdadm up pc0"

echo "Configuring $BOOTSTRAP as DRBD primary"
ssh $BOOTSTRAP "drbdadm -- --overwrite-data-of-peer primary pc0"

echo "Formatting and mounting DRBD primary"
ssh $BOOTSTRAP "mkfs.ext3 /dev/drbd0 && \
                mkdir -p /var/opt/opscode/drbd/data && \
                mount /dev/drbd0 /var/opt/opscode/drbd/data"

echo "Sync DRBD process"
ssh $BOOTSTRAP "drbdsetup /dev/drbd0 syncer -r 1100M"

echo "Waiting for sync to complete. This may take a while..."
ssh $BOOTSTRAP "until grep -q 'UpToDate/UpToDate' /proc/drbd; do sleep 15; done" # doesn't timeout


for server in $BACKENDS; do # assuming the servers are listed in order
  echo "Marking $server as DRBD ready and running reconfigure"
  ssh $server "touch /var/opt/opscode/drbd/drbd_ready"
  ssh $server "private-chef-ctl reconfigure"
done

for server in $FRONTENDS; do
  echo "Copying configuration to $server Front End and running reconfigure"
  ssh $BOOTSTRAP "scp -r /etc/opscode $server:/etc && private-chef-ctl reconfigure"
done

echo "Configure Complete!"
