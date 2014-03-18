#!/bin/sh

source servers

dl_url=$1

echo "Downloading private-chef to $BOOTSTRAP"
ssh $BOOTSTRAP "wget -q -O private-chef.deb '$dl_url'"

for server in $NONBOOTSTRAP_SERVERS; do
  echo "Copying private-chef to $server"
  ssh $BOOTSTRAP "scp private-chef.deb $server:"
done

for server in $ALL; do
  echo "Installing private-chef on $server"
  ssh $server "dpkg -i private-chef.deb"
done

echo "Install Chef Complete!"
