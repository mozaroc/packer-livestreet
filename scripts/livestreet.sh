#!/bin/bash -xe


date "+%Y-%m-%d %H:%M:%S"
apt-get update
apt-get -y --force-yes install software-properties-common jq curl mc

add-apt-repository --yes ppa:juju/stable
apt-get -y --force-yes update
apt-get -y --force-yes install juju-core sudo git-core
useradd -G sudo -s /bin/bash -m -d /home/ubuntu ubuntu
mkdir -p /root/.ssh
test -f /root/.ssh/juju || ssh-keygen -t rsa -b 4096 -f /root/.ssh/juju -N ''
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-cloud-init-users"


mkdir -p /home/ubuntu/.ssh/
cat /root/.ssh/juju.pub >> /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu /home/ubuntu

juju generate-config
juju switch manual

cat <<_EOF_ > /root/.juju/environments.yaml
default: manual

lxc-clone: true
lxc-clone-aufs: true

environments:
  manual:
    type: manual
    bootstrap-host: 127.0.0.1
    lxc-clone: true
    lxc-clone-aufs: true
  local:
    type: local
    default-series: trusty
    lxc-clone: true
    lxc-clone-aufs: true
_EOF_

mkdir -p /root/.juju/ssh/
cp /root/.ssh/juju /root/.juju/ssh/juju_id_rsa
cp /root/.ssh/juju.pub /root/.juju/ssh/juju_id_rsa.pub

juju bootstrap --debug

apt-get -y install python-yaml
git clone https://github.com/mozaroc/charm-livestreet.git charms/trusty/livestreet
git clone -b trusty https://github.com/vtolstov/charm-mysql charms/trusty/mysql


juju deploy --repository=/root/charms/ local:trusty/mysql --to 0 --debug

juju set mysql dataset-size=50%
juju set mysql query-cache-type=ON
juju set mysql query-cache-size=-1




for s in mysql ; do # haproxy; do
    while true; do
        juju status $s/0 --format=json | jq ".services.$s.units" | grep -q '"agent-state": "started"' && break
        echo "waiting 5s"
        sleep 5s
    done
done

juju deploy --repository=/root/charms/ local:trusty/livestreet --to 0 --debug

for s in livestreet ; do # haproxy; do
    while true; do
        juju status $s/0 --format=json | jq ".services.$s.units" | grep -q '"agent-state": "started"' && break
        echo "waiting 5s"
        sleep 5s
    done
done

juju add-relation mysql livestreet

for s in mysql livestreet ; do # haproxy; do
    while true; do
        juju status $s/0 --format=json | jq ".services.$s.units" | grep -q '"agent-state": "started"' && break
        echo "waiting 5s"
        sleep 5s
    done
done



while true; do
    curl -L -s http://127.0.0.1/install 2>&1 >/dev/null && break
    echo "waiting 5s"
    sleep 5s
done


date "+%Y-%m-%d %H:%M:%S"


