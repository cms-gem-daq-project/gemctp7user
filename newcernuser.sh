#!/bin/sh

## @file
## @author CMS GEM DAQ Project <gemdaq@cern.ch>
## @copyright MIT
## @version 1.8
## @brief Script to add NICE users to a GEM DAQ managed machine
## @details
##
## @par Usage
##
## @par URL

usage() {
    cat <<EOF
Usage: $0 <username>
    <username> must be an existing NICE user

  Running this script will perform several actions:
    * add <username> if not already present in /etc/passwd
    * add <username> to the gemuser group
    * create a directory in /home/<username>
    * create a /data/xdaq/<username> directory and symlink /opt/xdaq/htdocs contents
    * create a /data/bigdisk/<username> area on the NAS
EOF
}

if [ ! "$(fgrep ${1} /etc/passwd)" ]
then
    /usr/sbin/addusercern $1
fi

if [ "$(fgrep gemuser /etc/group)" ]
then
    usermod -aG gemuser ${1}
else
    "Unable to find 'gemuser' group, have you created the standard users and groups on this machine yet?"
fi

if [ ! -d /home/$1 ]
then
    mkdir --context=system_u:object_r:user_home_dir_t:s0 /home/$1
    chown $1:zh -R /home/$1
    echo "To set the home directory for $1 to /home/$1, execute"
    echo "usermod -d /home/$1 $1"
else
    echo "changing conditions for $user home directory"
    mkdir --context=system_u:object_r:user_home_dir_t:s0 /tmp/testconditions
    chcon --reference=/tmp/testconditions /home/$1
    rm -rf /tmp/testconditions
fi

if [ ! -d /data/xdaq/$1 ]
then
    mkdir -p --context=system_u:object_r:usr_t:s0 /data/xdaq/$1/gemdaq
else
    echo "changing conditions for $user data directory"
    mkdir --context=system_u:object_r:usr_t:s0 /tmp/testconditions
    chcon --reference=/tmp/testconditions /data/xdaq/$1/gemdaq
    rm -rf /tmp/testconditions
fi

unlink /data/xdaq/$1/*
ln -sn /opt/xdaq/htdocs/* /data/xdaq/$1/
chown $1:zh -R /data/xdaq/$1

chown root:root -R /opt/xdaq/htdocs

if [ ! -d /data/bigdisk/users/$1 ]
then
    mkdir -p --context=system_u:object_r:nfs_t:s0 /data/bigdisk/users/$1
    chown -R $1:zh /data/bigdisk/users/$1
fi
