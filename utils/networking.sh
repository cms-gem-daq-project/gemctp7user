#!/bin/bash

## @file
## @author CMS GEM DAQ Project
## @copyright MIT
## @version 1.0
## @brief Functions to wrap setup of GEM DAQ network interfaces.

. utils/helpers.sh


## @defgroup Networking Network Setup Utilities
## @brief Utilities to mange setup of network devices and connections.
## @details

## @fn configure_interface()
## @brief Configure a network interface for the uTCA or uFEDKIT
## @ingroup Networking
## @param netdev network device name
## @param type type of connection to configure
configure_interface() {

    # option for uTCA+macvlan?
    if [ -z "$2" ] || [[ ! "$2" =~ ^("uTCA"|"uFEDKIT") ]]
    then
        cat <<EOF
"$0" "$1" "$2"
Usage: configure_interface <device> <type>
   device must be listed in /sys/class/net
   type myst be one of:
     uTCA for uTCA on local network
     uTCA for uTCA on local network
     uFEDKIT for uFEDKIT on 10GbE
EOF
        return 1
    fi

    netdev="$1"
    type="$2"

    ipaddr=10.0.0.5
    netmask=255.255.255.0
    network=10.0.0.0
    if [ $type = "uTCA" ]
    then
        read -r -p $'\e[1;34mPlease specify desired IP address:\033[0m ' ipaddr
        read -r -p $'\e[1;34mPlease specify desired network:\033[0m ' network
        read -r -p $'\e[1;34mPlease specify correct netmask:\033[0m ' netmask

    fi

    cfgbase="/etc/sysconfig/network-scripts"
    cfgfile="ifcfg-${netdev}"
    if [ -e ${cfgbase}/${cfgfile} ]
    then
        echo "Old config file is:"
        cat ${cfgbase}/${cfgfile}
        mv ${cfgbase}/${cfgfile} ${cfgbase}/.${cfgfile}.backup
        while IFS='' read -r line <&4 || [[ -n "$line" ]]
        do
            if [[ "${line}" =~ ^("IPADDR"|"NETWORK"|"NETMASK") ]]
            then
                #skip
                :
            elif [[ "${line}" =~ ^("IPV6"|"NM_CON") ]]
            then
                echo "#${line}" >> ${cfgbase}/${cfgfile}
            elif [[ "${line}" =~ ^("BOOTPROTO") ]]
            then
                echo "BOOTPROTO=none" >> ${cfgbase}/${cfgfile}
            elif [[ "${line}" =~ ^("DEFROUTE") ]]
            then
                echo "DEFROUTE=no" >> ${cfgbase}/${cfgfile}
            elif [[ "${line}" =~ ^("USERCTL") ]]
            then
                echo "USERCTL=no" >> ${cfgbase}/${cfgfile}
            elif [[ "${line}" =~ ^("ONBOOT") ]]
            then
                echo "ONBOOT=yes" >> ${cfgbase}/${cfgfile}
            elif [[ "${line}" =~ ^("ZONE") ]]
            then
                echo "ZONE=trusted" >> ${cfgbase}/${cfgfile}
            else
                echo "${line}" >> ${cfgbase}/${cfgfile}
            fi
        done 4< ${cfgbase}/.${cfgfile}.backup
    else
        echo "No config file exists, creating..."
        echo "TYPE=Ethernet" >> ${cfgbase}/${cfgfile}
        echo "NM_CONTROLLED=no" >> ${cfgbase}/${cfgfile}
        echo "BOOTPROTO=none" >> ${cfgbase}/${cfgfile}
        echo "ONBOOT=yes" >> ${cfgbase}/${cfgfile}
        echo "DEFROUTE=no" >> ${cfgbase}/${cfgfile}
        echo "ZONE=trusted" >> ${cfgbase}/${cfgfile}
    fi

    echo "IPADDR=${ipaddr}" >> ${cfgbase}/${cfgfile}
    echo "NETWORK=${network}" >> ${cfgbase}/${cfgfile}
    echo "NETMASK=${netmask}" >> ${cfgbase}/${cfgfile}

    echo "New config file is:"
    cat ${cfgbase}/${cfgfile}

    # Configure firewall:
    # # cc7/cc8
    # firewall-cmd
    # zone trusted
    # sources 192.168.2.0/24

    # # slc6
    # iptables
}


## @fn setup_network()
## @brief Configure network interfaces for GEM DAQ machine
## @ingroup Networking
## @note @ref setup_machine option @c '-N'
setup_network() {

    local netdevs=( $(ls /sys/class/net |egrep -v "virb|lo") )
    for netdev in "${netdevs[@]}"
    do
        echo -e "\n\033[1;37mCurrent configuration for ${netdev} is:\033[0m"
        ifconfig ${netdev}
        if prompt_confirm "Configure network device: ${netdev}?"
        then
            while true
            do
                read -r -n 1 -p $'\e[1;34m Select interface type: local uTCA (1) or uFEDKIT (2) or dnsmasq (3)\033[0m ' REPLY
                case $REPLY in
                    [1]) echo -e "\n\033[1;36mConfiguring ${netdev} for local uTCA network...\033[0m"
                         configure_interface ${netdev} uTCA
                         break
                         ;;
                    [2]) echo -e "\n\033[1;36mConfiguring ${netdev} for uFEDKIT...\033[0m"
                         configure_interface ${netdev} uFEDKIT
                         break
                         ;;
                    [3]) echo -e "\n\033[1;36mConfiguring ${netdev} for dnsmasq...\033[0m"
                         cat <<EOF > /etc/dnsmasq.d/ctp7
interface=${netdev}
EOF

                         break
                         ;;
                    [sS]) echo -e "\033[1;33mSkipping $REPLY...\033[0m" ; break ;;
                    [qQ]) echo -e "\033[1;35mQuitting...\033[0m" ; return 0 ;;
                    *) printf "\033[1;31m %s \n\033[0m" "Invalid choice, please specify an interface type, press s(S) to skip, or q(Q) to quit";;
                esac
            done
        fi
    done
}


## @fn setup_nas()
## @brief Configure automount of 904 NAS
## @ingroup Networking
## @note **only for GEM machines at CERN**
## @note @ref setup_machine option @c '-n'
setup_nas() {

    read -r -p $'\e[1;34mPlease specify the hostname of the NAS to set up:\033[0m ' nashost

    if ! ping -c 5 -i 0.01 ${nashost} 2>1 >/dev/null
    then
        echo Unable to ping ${nashost}, are you sure the hostname is correct or the NAS is on?
        return 1
    fi

    echo Connecting to the NAS at ${nashost}
    cat <<EOF>/etc/auto.nas
GEMDAQ_Documentation    -context="system_u:object_r:nfs_t:s0",nosharecache,auto,rw,async,timeo=14,intr,rsize=32768,wsize=32768,tcp,nosuid,noexec,acl               ${nashost}:/share/gemdata/GEMDAQ_Documentation
GEM-Data-Taking         -context="system_u:object_r:httpd_sys_content_t:s0",nosharecache,auto,rw,async,timeo=14,intr,rsize=32768,wsize=32768,tcp,nosuid,noexec,acl ${nashost}:/share/gemdata/GEM-Data-Taking
sw                      -context="system_u:object_r:nfs_t:s0",nosharecache,auto,rw,async,timeo=14,intr,rsize=32768,wsize=32768,tcp,nosuid                          ${nashost}:/share/gemdata/sw
users                   -context="system_u:object_r:nfs_t:s0",nosharecache,auto,rw,async,timeo=14,intr,rsize=32768,wsize=32768,tcp,nosuid,acl                      ${nashost}:/share/gemdata/users
+auto.nas
EOF
    if [ -f /etc/auto.master ]
    then
        if ! fgrep auto.nas /etc/auto.master 2>1 >/dev/null 
        then
            echo "/data/bigdisk   /etc/auto.nas  --timeout=600 --ghost --verbose" >> /etc/auto.master
        fi
    else
        cat <<EOF>/etc/auto.master
+auto.master
/data/bigdisk   /etc/auto.nas   --timeout=360
EOF
    fi

    new_service autofs on
}

## @defgroup DeviceDrivers Device Driver Utilities

## @var mlnxversions
## @brief Array containing known versions of the Mellanox driver
## @ingroup DeviceDrivers
declare -ra mlnxversions=( '5.0-1.0.0.0' '4.7-3.2.9.0' '4.7-1.0.0.1' '4.6-1.0.1.1' '4.5-1.0.1.0' '4.4-2.0.7.0' '4.4-1.0.1.0' '4.3-3.0.2.1' '4.3-1.0.1.0' '4.2-1.0.1.0' )

## @var mlnxverre
## @brief Regex matching known versions of the Mellanox driver
## @ingroup DeviceDrivers
declare -r mlnxverre='^'$(IFS=\|;echo "${mlnxversions[*]}")'$'

## @fn install_mellanox_driver()
## @brief Install drivers for the Mellanox 10GbE NIC used with the uFEDKIT
## @ingroup DeviceDrivers
## @note @ref setup_machine option @c '-M'
install_mellanox_driver() {

    if ! lspci | egrep Mellanox 2>1 >/dev/null
    then
        echo -e "\033[1;31mNo Mellanox device detected, are you sure you have the interface installed?\033[0m"
        return 1
    fi

    local -r crel=$(cat /etc/system-release)
    local -r ncrel=${crel//[!0-9.]/}
    local -r sncrel=${ncrel%${ncrel:3}}
    local mlnxver=4.2-1.0.1.0

    local tmpdir=$(mktemp -d /tmp/tmp.XXXXXX)
    pushd ${tmpdir}

    while true
    do
        read -r -p $'\e[1;34mSelect Mellanox driver version number to install:\033[0m ' REPLY
        case $REPLY in
            [qQ]) echo ; exit 1   ;;
            *)    echo ;
                  if ! [[ "${REPLY}" =~ ${mlnxverre} ]]
                  then
                      printf "\033[1;31m %s \n\033[0m" "${REPLY} not found in ${mlnxverre}"
                  else
                      mlnxver=${REPLY}
                      break
                  fi
                  ;;
        esac
    done 3<&0

    local drvfile=mlnx-en-${mlnxver}-rhel${sncrel}-x86_64.tgz
    printf "\033[1;36m %s \n\033[0m" "Will download ${drvfile}"

    if ! curl -LO http://www.mellanox.com/downloads/ofed/MLNX_EN-${mlnxver}/${drvfile}
    then
        printf "\033[1;31m %s \n\033[0m" "Unable to download Mellanox driver, trying NAS installed version..."
        if [ -e /data/bigdisk/sw/${drvfile} ]
        then
            cp /data/bigdisk/sw/${drvfile} .
        else
            printf "\033[1;31m %s \n\033[0m" "${drvfile} not found, exiting"
            popd
            return 1
        fi
    fi

    tar xzf ${drvfile}
    pushd mlnx-en-${mlnxver}-rhel${sncrel}-x86_64

    # Install the RPM with YUM
    rpm --import RPM-GPG-KEY-Mellanox
    cat <<EOF > /etc/yum.repos.d/mellanox.repo
[mlnx_en]
name=MLNX_EN Repository
baseurl=file://${PWD}/RPMS_ETH
enabled=0
gpgkey=file://${PWD}/RPM-GPG-KEY-Mellanox
gpgcheck=1
EOF
    yum -y install mlnx-en-eth-only --disablerepo=* --enablerepo=mlnx_en

    # Load the driver.
    new_service mlnx-en.d on
    popd
    popd

    rm -rf ${tmpdir}

    return 0
}
