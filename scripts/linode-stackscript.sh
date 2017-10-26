#!/bin/bash
#
# Base server that sets a root SSH key and disables password auth. Installs latest Docker CE.
# <UDF name="HOSTNAME"                  Label="Hostname" />
# <UDF name="USERNAME"                  Label="Username" />
# <UDF name="PASSWORD"                  Label="Password" />
# <UDF name="SSH_KEY"                   Label="SSH Key" />
# <UDF name="LETSENCRYPT_HOST"          Label="Let's Encrypt Domain">
# <UDF name="LETSENCRYPT_EMAIL"         Label="Let's Encrypt Email">
# <UDF name="MYSQL_PASSWORD"            Label="MySQL Password" />
# <UDF name="MYSQL_ROOT_PASSWORD"       Label="MySQL Root Password" />
# <UDF name="DATA_FILE_PATH"            Label="Data Volume Path " />

exec >/root/stackscript.log 2>/root/stackscript_error.log

###########################################################
# Users and Authentication
###########################################################

function user_add_sudo {
    # Installs sudo if needed and creates a user in the sudo group.
    #
    # $1 - Required - username
    # $2 - Required - password
    USERNAME="$1"
    USERPASS="$2"

    if [ ! -n "$USERNAME" ] || [ ! -n "$USERPASS" ]; then
        echo "No new username and/or password entered"
        return 1;
    fi

    apt-get -y install sudo
    adduser $USERNAME --disabled-password --gecos ""
    echo "$USERNAME:$USERPASS" | chpasswd
    usermod -aG sudo $USERNAME
}

function user_add_pubkey {
    # Adds the users public key to authorized_keys for the specified user. Make sure you wrap your input variables in double quotes, or the key may not load properly.
    #
    #
    # $1 - Required - username
    # $2 - Required - public key
    USERNAME="$1"
    USERPUBKEY="$2"

    if [ ! -n "$USERNAME" ] || [ ! -n "$USERPUBKEY" ]; then
        echo "Must provide a username and the location of a pubkey"
        return 1;
    fi

    if [ "$USERNAME" == "root" ]; then
        mkdir /root/.ssh
        echo "$USERPUBKEY" >> /root/.ssh/authorized_keys
        return 1;
    fi

    mkdir -p /home/$USERNAME/.ssh
    echo "$USERPUBKEY" >> /home/$USERNAME/.ssh/authorized_keys
    chown -R "$USERNAME":"$USERNAME" /home/$USERNAME/.ssh
}

function ssh_disable_root {
    # Disables root SSH access.
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    touch /tmp/restart-ssh

}

function ssh_disable_password {
    # Disables password authentication SSH.
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
}

###########################################################
# Other niceties!
###########################################################

function goodstuff {
    # Installs the REAL vim, wget, less, and enables color root prompt and the "ll" list long alias

    apt-get -y install wget vim less
    sed -i -e 's/^#PS1=/PS1=/' /root/.bashrc # enable the colorful root bash prompt
    sed -i -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /root/.bashrc # enable ll list long alias <3
}

function system_set_hostname {
    # $1 - The hostname to define
    HOSTNAME="$1"

    if [ ! -n "$HOSTNAME" ]; then
        echo "Hostname undefined"
        return 1;
    fi

    echo "$HOSTNAME" > /etc/hostname
    hostname -F /etc/hostname
}

function system_add_host_entry {
    # $1 - The IP address to set a hosts entry for
    # $2 - The FQDN to set to the IP
    IPADDR="$1"
    FQDN="$2"

    if [ -z "$IPADDR" -o -z "$FQDN" ]; then
        echo "IP address and/or FQDN Undefined"
        return 1;
    fi

    echo $IPADDR $FQDN  >> /etc/hosts
}


function setup_data_volume {
    local data_path=${1}
    local mount_path=${2:-/mnt/nextcloud}
    mkfs.ext4 ${data_path}
    mkdir ${mount_path}
    mount ${data_path} ${mount_path}
}

################################################

export DEBIAN_FRONTEND=noninteractive

IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')

goodstuff
# Basic Stuff
ssh_disable_root
ssh_disable_password
user_add_sudo "$USERNAME" "$PASSWORD"
user_add_pubkey "$USERNAME" "$SSH_KEY"
system_set_hostname "$HOSTNAME"
system_add_host_entry "$IPADDR" "$HOSTNAME"
system_add_host_entry "$IPADDR" "$LETSENCRYPT_HOST"
service sshd restart

# Install packages
apt-get -y update && \
apt-get install \
    -q \
    -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    jq \
    python-software-properties \
    software-properties-common \
    python-pip

echo 'admin ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"

apt-get -y update && apt-get -y install docker-ce

pip install --upgrade pip docker-compose

usermod -aG docker $USERNAME

setup_data_volume ${DATA_FILE_PATH}

mkdir -p /opt/nextcloud

git clone -q https://github.com/chiefy/terraform-linode-nextcloud.git /opt/nextcloud

cat << EOF >/opt/nextcloud/docker-compose/nextcloud.env
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_HOST=db
CERT_NAME=
LETSENCRYPT_HOST=${LETSENCRYPT_HOST}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
NEXTCLOUD_DATA_DIR=/mnt/nextcloud
NEXTCLOUD_ADMIN_USER=${USERNAME}
NEXTCLOUD_ADMIN_PASSWORD=${PASSWORD}
EOF

cd /opt/nextcloud

docker network create proxy-tier

make run VIRTUAL_HOST=${LETSENCRYPT_HOST}
