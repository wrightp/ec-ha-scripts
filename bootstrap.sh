#!/bin/sh

source servers

echo "Bootstrap Back End Server: $BOOTSTRAP"
echo "Backup Back End Server: $BACKUP"
echo "Front End Servers : $FRONTENDS"

echo "Removing any local known_hosts entries for the configured servers."
for server in $ALL; do
  ssh-keygen -R $server
done

echo "Setting up ssh keys on $BOOTSTRAP"
ssh $BOOTSTRAP "mkdir -p .ssh"
scp ssh/bootstrap/* $BOOTSTRAP:.ssh/
ssh $BOOTSTRAP "chmod -R 600 .ssh/"

for server in $NONBOOTSTRAP_SERVERS; do
  echo "Setting up authorized_keys on $server"
  ssh $server "mkdir -p .ssh"
  scp ssh/key $server:.ssh/
  ssh $server "cd .ssh && cat key >> authorized_keys && rm key"
done

for server in $ALL; do
  echo "Bootstrapping $server (not to be confused with Back End Bootstrap)"
  ssh $server "apt-get update"
  ssh $server "apt-get install -y ntp vim"
  scp hosts $server:/etc/
  ssh $server "mkdir -p /etc/opscode"
  scp private-chef.rb $server:/etc/opscode # gets copied again to all servers, but simplied opscode dir creation
done

echo "Bootstrap Complete!"
