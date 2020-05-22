#!/bin/bash

## @file
## @author CMS GEM DAQ Project
## @copyright MIT
## @version 1.0
## @brief Set of scripts to simplify the configuration of cactus tools on GEM DAQ machines

. utils/helpers.sh


## @defgroup Cactus Cactus Utilities
## @brief Utilities to mange installation of @c cactus related packages (@c ipbus and @c amc13)
## @details
## @note Supported OS releases are (@c centos7|@c centos8)
## @note Currently only AMC13 SW release 1.2 is supported, with no build for @c centos8 nor for compatibility with @c ipbus 2.7
## @note Supported ipbus-sw versions are:
## @li 2.6/2.7 for @c centos7
## @li 2.7 for @c centos8

## @fn get_amc13_repo()
## @brief Create the AMC13 @c yum/dnf repo file for the architecture and release
## @ingroup Cactus
## @param amc13rel AMC13 SW release version
## @param osrel OS release
get_amc13_repo() {

    local amc13rel=
    local osrel=

    if [ -n "$2" ]
    then
        echo "No OS specified, assuming centos7"
        osrel="centos7"
        if [ -n "$1" ]
        then
            echo "No AMC13 SW version specified, assuming ${osrel} default 1.2"
            amc13rel="1.2"
        else
            amc13rel="$1"
        fi
    else
        osrel="$2"
        amc13rel="$1"
    fi

    cat <<EOF> /tmp/etc-yum.repos.d-amc13.repo
[amc13-base]
name     = AMC13 Software Repository
baseurl  = http://www.cern.ch/cactus/release/amc13/${amc13rel}/${osrel}_x86_64/base/RPMS
enabled  = 1
gpgcheck = 0

[amc13-updates]
name     = AMC13 Software Repository updates
baseurl  = http://www.cern.ch/cactus/release/amc13/${amc13rel}/${osrel}_x86_64/updates/RPMS
enabled  = 1
gpgcheck = 0
EOF

    return 0
}


## @fn get_ipbus_repo()
## @brief Create the @c ipbus-sw @c yum/dnf repo file for the architecture and release
## @ingroup Cactus
## @param ipbrel @c ipbus release version
## @param osrel OS release
get_ipbus_repo() {

    local ipbrel=
    local osrel=

    if [ -n "$2" ]
    then
        echo "No OS specified, assuming centos7"
        osrel="centos7"
        if [ -n "$1" ]
        then
            echo "No ipbus SW version specified, assuming ${osrel} default 2.6"
            ipbrel="2.6"
        else
            ipbrel="$1"
        fi
    else
        osrel="$2"
        ipbrel="$1"
    fi

    cat <<EOF> /tmp/etc-yum.repos.d-ipbus-sw.repo
[ipbus-sw-base]
name     = IPBus Software Repository
baseurl  = http://www.cern.ch/ipbus/sw/release/${ipbrel}/repos/${osrel}_x86_64/base/RPMS
enabled  = 1
gpgcheck = 0

[ipbus-sw-updates]
name     = IPBus Software Repository updates
baseurl  = http://www.cern.ch/ipbus/sw/release/${ipbrel}/repos/${osrel}_x86_64/updates/RPMS
enabled  = 1
gpgcheck = 0
EOF

    return 0
}


## @fn get_cactus_repos()
## @brief Create the @c ipbus-sw and AMC13 @c yum/dnf repo file for the architecture and release
## @ingroup Cactus
## @param amc13rel AMC13 SW release version
## @param ipbrel @c ipbus release version
## @param osrel OS release
get_cactus_repos() {

    local amc13rel=
    local ipbrel=
    local osrel=

    if [ -n "$3" ]
    then
        echo "No OS specified, assuming centos7"
        osrel="centos7"
        if [ -n "$2" ]
        then
            echo "No ipbus SW version specified, assuming ${osrel} default 2.6"
            ipbrel="2.6"
        else
            ipbrel="$2"
        fi
        if [ -n "$1" ]
        then
            echo "No AMC13 SW version specified, assuming ${osrel} default 1.2"
            amc13rel="1.2"
        else
            amc13rel="$1"
        fi
    else
        osrel="$3"
        ipbrel="$2"
        amc13rel="$1"
    fi

    get_amc13_repo ${amc13rel} ${osrel}
    get_ipbus_repo ${ipbrel} ${osrel}

    return 0
}


## @fn install_ipbus()
## @brief Install the @c uhal support software file for the architecture and release specified
## @ingroup Cactus
## @param ipbrel @c ipbus release version
## @param osrel OS release
install_ipbus() {

    if ! [ -f /tmp/etc-yum.repos.d-ipbus-sw.repo ]
    then
        if prompt_confirm "ipbus-sw repo file does not exist, create?"
        then
            get_ipbus_repo "$1" "$2"
        else
            printf "\033[1;31m %s \n\033[0m" "Unable to download uhal packags, repo file missing."
            return 1
        fi
    fi

    yum -y groupinstall uhal

    if prompt_confirm "Setup machine as controlhub?"
    then
        new_service controlhub on
    else
        new_service controlhub off
    fi

    return 0
}


## @fn install_amc13()
## @brief Install the AMC13 support software file for the architecture and release specified
## @ingroup Cactus
## @param amc13rel AMC13 SW release version
## @param osrel OS release
install_amc13() {

    if ! [ -f /tmp/etc-yum.repos.d-amc13.repo ]
    then
        if prompt_confirm "AMC13 repo file does not exist, create?"
        then
            get_amc13_repo "$1" "$2"
        else
            printf "\033[1;31m %s \n\033[0m" "Unable to download AMC13 packags, repo file missing."
            return 1
        fi
    fi

    yum -y groupinstall amc13

    return 0
}


## @fn install_cactus()
## @brief Install/update the @c ipbus and AMC13 packages for the specified architecture
## @ingroup Cactus
## @param osrel OS release
## @note @ref setup_machine option @c '-c'
install_cactus() {

    local osrel="$1"

    if ! [[ "${osrel}" =~ centos7|centos8 ]]
    then
        printf "\033[1;31m %s \n\033[0m" "Unsupported OS (${osrel}) specified. Supported values are 'centos7' and 'centos8'"
        return 1
    fi

    echo Installing cactus packages...

    if prompt_confirm "Install uHAL?"
    then
        while true
        do
            read -r -n 1 -p "Select uhal version: 2.6 (1), 2.7 (2) " REPLY
            case $REPLY in
                [1]) echo "Installing ipbus uhal version 2.6"
                     ipbrel="2.6"
                     break
                     ;;
                [2]) echo "Installing ipbus uhal version 2.7"
                     ipbrel="2.7"
                     break
                     ;;
                [sS]) echo "Skipping $REPLY..." ; break ;;
                [qQ]) echo "Quitting..." ; return 0 ;;
                *) printf "\033[1;31m %s \n\033[0m" "Invalid choice, please specify a uhal version, press s(S) to skip, or q(Q) to quit";;
            esac
        done

        install_ipbus ${ipbrel} ${osrel}
    fi

    if prompt_confirm "Install amc13 libraries?"
    then
        if [ ${ipbrel} = "2.7" ]
        then
            printf "\033[1;31m %s \n\033[0m" "AMC13 libraries require version 1.2.15 on ${osrel} for uhal ${ipbrel}"
            amc13rel="1.2"
        elif [[ ${osver} =~ "8" ]]
        then
            printf "\033[1;31m %s \n\033[0m" "AMC13 libraries are currently not available for ${osrel}"
            return 1
        else
            amc13rel="1.2"
        fi

        install_amc13 ${amc13rel} ${osrel}
    fi

    return 0
}
