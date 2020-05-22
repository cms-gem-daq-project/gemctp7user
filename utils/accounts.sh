#!/bin/bash

## @file
## @author CMS GEM DAQ Project
## @copyright MIT
## @version 1.0
## @brief Tools to create standard GEM DAQ accounts and add NICE users

. utils/helpers.sh


## @defgroup Accounts Accounts and Users Utilities
## @brief Utilities to mange setup and creation of users and groups
## @details

## @var GEM_USERS
## @brief List of common GEM DAQ users
## @ingroup Accounts
## @li @c gemuser, historically a general purpose user account for operating the teststand [deprecated?]
## @li @c gempro, at P5 this role is the same as the @c gemuser role used in 904
## @li @c gemdev, at P5 this role allows installation of development versions of software and provides [deprecated?]
## @li @c daqpro, nominally this user was envisioned to create releases of the software [deprecated]
declare -ra GEM_USERS=( gemuser gempro gemdev daqpro )

## @var GEM_GROUPS
## @brief List of common GEM DAQ groups
## @ingroup Accounts
## @li @c gempro, primary group of the @c gempro user
## @li @c gemdev, primary group of the @c gemdev user
## @li @c gemdaq for scoping DAQ expert tasks
## @li @c gemsudoers for scoping admin tasks
declare -ra GEM_GROUPS=( gempro gemdev daqpro gemdaq gemsudoers )

## @fn new_system_group()
## @brief Create a new system group
## @ingroup Accounts
## @param groupname group name
## @param groupid group ID
new_system_group() {

    if [ -z "$2" ]
    then
        cat <<EOF
"$0" "$1" "$2"
\033[1;33mUsage: new_system_group <groupname> <gid>\033[0m
EOF
        return 1
    fi

    local groupname="$1"
    local groupid="$2"

    printf "\033[1;36m %s \n\033[0m" "Creating group ${groupname} with gid ${groupid}"
    groupadd ${groupname}
    groupmod -g ${groupid} ${groupname}
}


## @fn new_system_user()
## @brief Create a new system user and specify the primary group ID
## @ingroup Accounts
## @param username user name
## @param userid user ID
## @param groupid primary group ID
new_system_user() {

    if [ -z "$3" ]
    then
        cat <<EOF
"$0" "$1" "$2" "$3"
\033[1;33mUsage: new_system_user <username> <uid> <primary gid>\033[0m
EOF
        return 1
    fi

    local username="$1"
    local userid="$2"
    local groupid="$3"

    printf "\033[1;36m %s \n\033[0m" "Creating user ${username} with uid ${userid} in primary group ${groupid}"
    useradd ${username}
    usermod -u ${userid} ${username}
    groupmod -g ${groupid} ${username}

    # machine local directory
    if [ ! -d /home/${username} ]
    then
        mkdir --context=system_u:object_r:user_home_dir_t:s0 /home/${username}
    else
        echo "changing conditions for ${username} home directory"
        mkdir --context=system_u:object_r:user_home_dir_t:s0 /tmp/testcons
        chcon --reference=/tmp/testcons /home/${username}
        rm -rf /tmp/testcons
    fi

    # chmod a+rx /home/${username}
    chown ${username}:${groupid} -R /home/${username}

    if prompt_confirm "Create directory for ${username} on connected NAS?"
    then
        mkdir -p --context=system_u:object_r:nfs_t:s0 /data/bigdisk/users/${username}
        chown -R ${username}:zh /data/bigdisk/users/${username}
    fi

    passwd ${username}

    return 0
}


## @fn create_accounts()
## @brief Create "standard" GEM DAQ users and groups
## @ingroup Accounts
## @details
## @li Create four standard generic users (@ref GEM_USERS):
## @li Create standard common system groups (@ref GEM_GROUPS) for easy management of @c sudo rules
## @li Prompts to create @c gembuild user, used to build and apply patches to software
##
## @note @ref setup_machine option @c '-A'
create_accounts() {

    ### generic gemuser group for running tests
    new_system_user gemuser 5075 5075
    chmod a+rx /home/gemuser

    ### gempro (production) account for running the system as an expert
    new_system_user gempro 5060 5060
    chmod g+rx /home/gempro

    ### gemdev (development) account for running tests
    new_system_user gemdev 5050 5050
    chmod g+rx /home/gemdev

    ### daqpro account for building the releases
    new_system_user daqpro 2055 2055
    chmod g+rx /home/daqpro

    ### gembuild account for building the releases
    if prompt_confirm "Create user gembuild?"
    then
        new_system_user gembuild 2050 2050
    fi

    # Groups for sudo rules only
    ### gemdaq group for DAQ pro tasks on the system
    new_system_group gemdaq 2075

    ### gemsudoers group for administering the system
    new_system_group gemsudoers 1075
}


## @fn create_user()
## @brief Add specified user to the machine and create defaults
## @ingroup Accounts
## @details <tt>Usage: $0 [username]</tt>
## @note If the machine is running on the @c cern.ch domain, @c username must be an existing NICE user
## @details Running this command will perform several actions:
## @li add @c username if not already present in @c /etc/passwd
## @li add @c username to the @c gemuser group
## @li create a directory in @c /home/$USER
## @li create a @c /data/xdaq/username directory and symlink @c /opt/xdaq/htdocs contents
## @li create a @c /data/bigdisk/username area on the NAS
## @param username NICE username
create_user() {

    local username="$1"
    local setupnas=
    if [ `hostname -d` = "cern.ch" ]
    then
        printf "\033[1;36m %s \n\033[0m" "Machine is on the cern.ch domain, adding NICE user ${username}"
        addusercmd=/usr/sbin/addusercern
        setupnas=1
    else
        printf "\033[1;36m %s \n\033[0m" "Machine is not on the cern.ch domain, adding new local user ${username}"
        addusercmd=/usr/sbin/useradd
    fi

    if ! getent passwd ${username} >/dev/null
    then
        ${addusercmd} ${username}
    fi

    if getent group gemuser >/dev/null
    then
        usermod -aG gemuser ${username}
    else
        "Unable to find 'gemuser' group, have you created the standard users and groups on this machine yet?"
    fi

    if [ ! -d /home/${username} ]
    then
        mkdir --context=system_u:object_r:user_home_dir_t:s0 /home/${username}
        chown ${username}:zh -R /home/${username}
        echo "To set the home directory for ${username} to /home/${username}, execute"
        echo "usermod -d /home/${username} ${username}"
    else
        echo "changing conditions for $user home directory"
        mkdir --context=system_u:object_r:user_home_dir_t:s0 /tmp/testconditions
        chcon --reference=/tmp/testconditions /home/${username}
        rm -rf /tmp/testconditions
    fi

    if prompt_confirm "Create xdaq development area for ${username}?"
    then
        if [ ! -d /data/xdaq/${username} ]
        then
            mkdir -p --context=system_u:object_r:usr_t:s0 /data/xdaq/${username}/gemdaq
        else
            echo "changing conditions for $user data directory"
            mkdir --context=system_u:object_r:usr_t:s0 /tmp/testconditions
            chcon --reference=/tmp/testconditions /data/xdaq/${username}/gemdaq
            rm -rf /tmp/testconditions
        fi

        unlink /data/xdaq/${username}/*
        ln -sn /opt/xdaq/htdocs/* /data/xdaq/${username}/
        chown ${username}:zh -R /data/xdaq/${username}

        chown root:root -R /opt/xdaq/htdocs
    fi

    if [ "${setupnas}" = "1" ]
    then
        if [ ! -d /data/bigdisk ]
        then
            printf "\033[1;35m %s \n\033[0m" "Have you configured the NAS automounts?"
        elif [ ! -d /data/bigdisk/users/${username} ]
        then
            if prompt_confirm "Create user area for ${username} on the NAS ()?"
            then
                mkdir -p --context=system_u:object_r:nfs_t:s0 /data/bigdisk/users/${username}
                chown -R ${username}:zh /data/bigdisk/users/${username}
            fi
        fi
    fi

    return 0
}


## @fn add_users()
## @brief Add users, and associate them with different groups
## @ingroup Accounts
## @note @ref setup_machine option @c '-u'
## @param file text file with list of usernames to add to machine
add_users() {

    while true
    do
        read -r -p $'\e[1;34mPlease specify text file with NICE users to add:\033[0m ' REPLY
        if [ -e "$REPLY" ]
        then
            while IFS='' read -r user <&4 || [[ -n "$user" ]]
            do
                ### Skip commented lines TODO
                ### Parse advanced options TODO
                if prompt_confirm "Add ${user} to machine ${HOST}?"
                then
                    if ! getent passwd ${user} 2>1 > /dev/null
                    then
                        echo "Adding user ${user}"
                        create_user ${user}
                    fi

                    for gr in "${GEM_GROUPS[@]}"
                    do
                        if getent group ${gr} 2>1 > /dev/null 
                        then
                            if prompt_confirm "Add ${user} to ${gr} group?"
                            then
                                echo "Adding ${user} to ${gr} group"
                                usermod -aG ${gr} ${user}
                            fi
                        else
                            printf "\033[1;31m %s \n\033[0m" "Unable to find '${gr}' group, have you created the standard users and groups on this machine yet?"
                        fi
                    done
                fi
                printf "\033[1;32m %s \n\033[0m" "Done setting up $user"
            done 4< "$REPLY"
            return 0
        else
            case $REPLY in
                [qQ]) printf "\033[1;35m %s \n\033[0m" "Quitting..." ; return 0 ;;
                *) printf "\033[1;31m %s \n\033[0m" "File does not exist, please specify a file, or press q(Q) to quit";;
            esac
        fi
    done
}
