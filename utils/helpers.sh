#!/bin/bash

## @file
## @author CMS GEM DAQ Project
## @copyright MIT
## @version 1.0
## @brief Set of utility functions used for setting up GEM DAQ machines.


## @defgroup HelperFunctions Helper Functions
## @brief Various utility and helper functions used in other scripts.
## @details

## @fn prompt_confirm()
## @brief Display a message and ask for confirmation.
## @ingroup HelperFunctions
## @details Message is displayed in the format:
##
##    @c Message? [y/N/q]:
##
##  The default message is @c Continue, if none is provided
##
## @param msg Message to display
## @returns @c 0 for yes
## @returns @c 1 for no or other
## @result sends @c exit for quit
prompt_confirm() {

    while true
    do
        read -u 3 -r -n 1 -p $'\e[1;35m'"${1:-Continue?}"$' [y/N/q]:\033[0m ' REPLY
        case $REPLY in
            [yY]) echo ; return 0 ;;
            [nN]) echo ; return 1 ;;
            [qQ]) echo ; exit 1   ;;
            *)    echo ; return 1 ;;
        esac
    done 3<&0
}


## @fn new_service()
## @brief Enable/disable a system service
## @ingroup HelperFunctions
## @param svcname service name
## @param status service status (@c off|@c on)
new_service() {

    if [ -z "$2" ] || [[ ! "$2" =~ ^("on"|"off") ]]
    then
        printf "\033[1;34m %s \n\033[0m" "Please specify a service to configure, and whether it should be enabled ('on') or not ('off')"
        return 1
    fi

    local svcname="$1"
    local status="$2"

    if [ "${osver}" = "6" ]
    then
        # for slc6 machines
        chkconfig --level 345 ${svcname} ${status}
        if [ "${status}" = "on" ]
        then
           service ${svcname} restart
        else
           service ${svcname} stop
        fi
    elif [ "${osver}" =~ "7|8" ]
    then
        # for cc7/c8 machines
        if [ "${status}" = "on" ]
        then
            svsta="enable"
            svcmd="restart"
        else
            svsta="disable"
            svcmd="stop"
        fi
        systemctl ${svsta} ${svcname}.service
        systemctl daemon-reload
        systemctl ${svcmd} ${svcname}.service
    fi
}

## @fn get_gemos_repo()
## @brief download the @c gemos @c yum/dnf repo file
## @ingroup HelperFunctions
## @param osver OS version
## @returns 0 if successful
## @returns 1 if unsuccessful
get_gemos_repo() {
    local osver="$1"
    local repourl="https://cmsgemdaq.web.cern.ch/cmsgemdaq/sw/gemos/repos/releases/legacy"
    local repofile="gemos_release_${osver}_x86_64.repo"
    local repopath="/etc/yum.repos.d/gemos.repo"
    if ! (curl -L ${repourl}/${repofile} -o ${repopath})
    then
        printf "\033[1;31m %s \n\033[0m" "Unable do download ${repofile} from ${repourl} to ${repopath}"
        return 1
    fi

    return 0
}
