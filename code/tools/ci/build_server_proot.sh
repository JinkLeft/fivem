#!/bin/sh
set -e

# update local package lists
apk update

# install build dependencies
apk add curl git xz sudo

# announce building
text="Woop, building a new $CI_PROJECT_NAME $CI_BUILD_REF_NAME SERVER/LINUX-PROOT build, triggered by $GITLAB_USER_EMAIL"

escapedText=$(echo $text | sed 's/"/\"/g' | sed "s/'/\'/g" )
json="{\"text\":\"$escapedText\"}"

curl -s -d "$json" "$TG_WEBHOOK" || true
curl -s -d "$json" "$DISCORD_WEBHOOK" || true

# get an alpine rootfs
curl -sLo alpine-minirootfs-3.6.1-x86_64.tar.gz http://mirrors.gigenet.com/alpinelinux/latest-stable/releases/x86_64/alpine-minirootfs-3.6.1-x86_64.tar.gz

# get our patched proot build
# source code: https://runtime.fivem.net/build/proot-v5.1.1.tar.gz
curl -sLo proot-x86_64 https://runtime.fivem.net/build/proot-x86_64
chmod +x proot-x86_64

cd ..

# clone fivem-private
if [ ! -d fivem-private ]; then
	git clone $FIVEM_PRIVATE_URI
else
	cd fivem-private
	git fetch origin
	git reset --hard origin/master
	cd ..
fi

echo "private_repo '../../fivem-private/'" > fivem/code/privates_config.lua

# start building
cd fivem

# make a temporary build user
adduser -D -u 1000 build

# extract the alpine root FS
mkdir alpine
cd alpine
tar xf ../alpine-minirootfs-3.6.1-x86_64.tar.gz
cd ..

# change ownership of the build root
chown -R build:build .

# build
sudo -u build ./proot-x86_64 -S $PWD/alpine/ -b $PWD/:/src/ -b $PWD/../fivem-private/:/fivem-private/ /bin/sh /src/code/tools/ci/build_server_2.sh

# package artifacts
cp data/server_proot/run.sh run.sh
mv proot-x86_64 proot

tar cJf fx.tar.xz alpine/ proot run.sh

# announce build end
text="Woop, building a SERVER/LINUX-PROOT build completed!"

escapedText=$(echo $text | sed 's/"/\"/g' | sed "s/'/\'/g" )
json="{\"text\":\"$escapedText\"}"

curl -s -d "$json" "$TG_WEBHOOK" || true
curl -s -d "$json" "$DISCORD_WEBHOOK" || true
