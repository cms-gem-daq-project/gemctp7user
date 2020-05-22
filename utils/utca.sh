#!/bin/bash

## @file
## @author CMS GEM DAQ Project
## @copyright MIT
## @version 1.0
## @brief Functions to facilitate setup of uTCA infrastructure

. utils/helpers.sh


#### Compatibility with CTP7 (NEEDS TO BE WRITTEN)
## @defgroup uTCA uTCA Utilities
## @brief Functions to facilitate configuration of uTCA infrastructure.
## @details

## @fn install_sysmgr()
## @brief Configure machine for usage of UW sysmgr
## @ingroup uTCA
## @details Installs the @c sysmgr service and enables it, if the machine should be the controller of the CTP7s
## @note @ref setup_machine option @c '-S'
install_sysmgr() {
    echo Installing UW sysmgr RPMS...
    wget https://www.hep.wisc.edu/uwcms-repos/el${osver}/release/uwcms.repo -O /etc/yum.repos.d/uwcms.repo
    yum -y install freeipmi-devel libxml++-devel libconfuse-devel xinetd dnsmasq
    yum -y install sysmgr-complete

    if prompt_confirm "Setup machine to communicate directly with CTP7s (receive logs and serve as name and timeserver)?"
    then
        connect_ctp7s
        new_service sysmgr on
        new_service xinetd on
        new_service dnsmasq on
    else
        new_service sysmgr off
        new_service xinetd off
        new_service dnsmasq off
    fi
}


## @fn connect_ctp7s()
## @brief Prepare machine to work with CTP7s
## @ingroup uTCA
## @details Prompts user to add uTCA shelves to the configuration and outputs appropriate configuration files
## @li Configures @c /etc/hosts for GEM aliases
## @li Creates a @c /opt/cmsgemos/etc/maps/connections.xml (moves current file to backup beforehand)
## @li Prompts to configure @c dnsmasq and @c xinitd to serve names and time to the CTP7 through the @c sysmgr
## @note @ref setup_machine option @c '-C'
connect_ctp7s() {
    printf "\033[1;36m %s \n\033[0m" "Setting up for ${hostname} for CTP7 usage"

    # Updated /etc/sysmgr/sysmgr.conf to enable the GenericUW configuration module to support "WISC CTP-7" cards.
    if [ -e /etc/sysmgr/sysmgr.conf ]
    then
        mv /etc/sysmgr/sysmgr.conf /etc/sysmgr/sysmgr.conf.bak
    fi

    authkey="Aij8kpjf"

    cat <<EOF > /etc/sysmgr/sysmgr.conf
socket_port = 4681

# If ratelimit_delay is set, it defines the number of microseconds that the
# system manager will sleep after sending a command to a crate on behalf of a
# client application.  This can be used to avoid session timeouts due to
# excessive rates of requests.
#
# Note that this will suspend only the individual crate thread, and other
# crates will remain unaffected, as will any operation that does not access an
# individual crate.  The default, 0, is no delay.
ratelimit_delay = 100000

# If true, the system manager will run as a daemon, and send stdout to syslog.
daemonize = true

authentication {
	raw = { "${authkey}" }
	manage = { }
	read = { "" }
}

EOF

    # add crates
    # take input from prompt for ipaddress, type, password, and description
    nShelves=0
    while true
    do
        if prompt_confirm "Add uTCA shelf to sysmgr config?"
        then
            while true
            do
                read -r -n 1 -p $'\e[1;34m Add uTCA shelf with MCH of type: VadaTech (1) or NAT (2)\033[0m ' REPLY
                case $REPLY in
                    [1]) printf "\n\033[1;36m %s \n\033[0m" "Adding uTCA shelf with VadaTech MCH..."
                         type="VadaTech"
                         password="vadatech"
                         break
                         ;;
                    [2]) printf "\n\033[1;36m %s \n\033[0m" "Adding uTCA shelf with NAT MCH..."
                         type="NAT"
                         password=""
                         break
                         ;;
                    [sS]) printf "\033[1;33m %s \n\033[0m" "Skipping $REPLY..." ; break ;;
                    [qQ]) printf "\033[1;35m %s \n\033[0m" "Quitting..." ; return 0 ;;
                    *) printf "\033[1;31m %s \n\033[0m" "Invalid choice, please specify an MCH type, press s(S) to skip, or q(Q) to quit";;
                esac
            done

            while true
            do
                read -r -p $'\e[1;34mPlease specify the IPv4 address of the MCH:\033[0m ' REPLY
                rx='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
                oct='(0[0-7]{0,2})|([1-9][0-9])|(1[0-9][0-9])|(2[0-4][0-9])|(25[0-5])'
                rex="^$oct.$ot.$oct.$oct$"
                re1="^([0-9]{1,3}\.){3}(\.?[0-9]{1,3})$"
                re2="^([0-9]{1,3}.){3}(.?[0-9]{1,3})$"
                re3='^([0-9]{1,3}.){3}(.?[0-9]{1,3})$'
                # if ! [[ "$REPLY" =~ $re1 ]]
                # if ! [[ "$REPLY" =~ $re2 ]]
                if ! [[ "$REPLY" =~ $re3 ]]
                then
                    printf "\033[1;31m %s \n\033[0m" "Invalid IPv4 address ${REPLY} specified"
                    continue
                fi
                ipaddr=$REPLY
                break
            done

            read -r -p $'\e[1;34mPlease enter a description for this uTCA shelf:\033[0m ' REPLY
            desc=$REPLY
            cat <<EOF >> /etc/sysmgr/sysmgr.conf
crate {
	host = "${ipaddr}"
	mch = "${type}"
	username = ""
	password = "${password}"
	authtype = none
	description = "${desc}"
}
EOF
            nShelves=$((nShelves+1))
        elif [ "$?" = "1" ]
        then
            printf "\n\033[1;36m %s \n\033[0m" "Done adding ${nShelves} shelves, now moving on to configs"
            break
        fi
    done

    cat <<EOF >> /etc/sysmgr/sysmgr.conf
# *** Modules ***
#
# These modules will be loaded in the order specified here.  When a new card is
# detected, they will be checked in reverse order to determine which module
# will service that card.  If no module claims a card, it will be serviced by
# the system manager with no special functionality.

cardmodule {
	module = "GenericUW.so"
	config = {
		"ivtable=ipconfig.xml",
 		"poll_count=12",
 		"poll_delay=15"
	}
}

cardmodule {
        module = "GenericUW.so"
        config = {
                "ivtable=ipconfig.xml",
                # "poll_count=27448000",
                "poll_count=52596000",
                "poll_delay=30",
                "support=WISC CTP-6",
                "support=WISC CIOX",
                "support=WISC CIOZ",
                "support=BU AMC13"
        }
}

cardmodule {
	module = "UWDirect.so"
	config = {
		"ivtable=ipconfig.xml",
                # "poll_count=27448000",
		"poll_count=105192000",
		"poll_delay=15",
		"support=WISC CTP-7#19",
		"support=WISC CIOZ#14"
	}
}

EOF

    ### Created /etc/sysmgr/ipconfig.xml to map geographic address assignments for crates 1 and 2 matching the /24
    ### subnets associated with the MCHs listed for them in /etc/sysmgr/sysmgr.conf.
    ### These addresses will occupy 192.168.*.40 to 192.168.*.52 which nmap confirms are not in use.
    if [ -e /etc/sysmgr/ipconfig.xml ]
    then
        mv /etc/sysmgr/ipconfig.xml /etc/sysmgr/ipconfig.xml.bak
    fi

    if [ -d /etc/cmsgemos ]
    then
        if [ -e /opt/cmsgemos/etc/maps/connections.xml ]
        then
            mv /opt/cmsgemos/etc/maps/connections.xml /opt/cmsgemos/etc/maps/connections.xml.bak
        fi
    else
        mkdir /etc/cmsgemos
    fi

    printf "\033[1;36m %s \n\033[0m" "Creating configuratinos assuming a 'local' network topology and only CTP7s, if this is not appropriate for your use case, please modify the resulting files found at /etc/sysmgr/ipconfig.xml,  /opt/cmsgemos/etc/maps/connections.xml"
    authkey="Aij8kpjf"

    cat <<EOF > /opt/cmsgemos/etc/maps/connections.xml
<?xml version="1.0" encoding="UTF-8"?>

<connections>
EOF
    cat <<EOF > /etc/sysmgr/ipconfig.xml
<IVTable>
EOF
    if [ ${nShelves} = "0" ]
    then
        nShelves=1
    fi

    for crate in $(eval echo "{1..$nShelves}")
    do
        cid=$(printf '%02d' ${crate})
        cat <<EOF >> /etc/sysmgr/ipconfig.xml
    <Crate number="${crate}">
EOF
    cat <<EOF >> /etc/hosts

192.168.${crate}.10 mch-c${cid} mch-c${cid}.utca
192.168.1.13 amc-c${cid}-s13-t1 amc-c${cid}-s13-t1.utca
192.168.1.14 amc-c${cid}-s13-t2 amc-c${cid}-s13-t2.utca
EOF
    cat <<EOF >> /opt/cmsgemos/etc/maps/connections.xml
  <!-- uTCA shelf ${crate} -->
  <connection id="gem.shelf${cid}.amc13.T1" uri="chtcp-2.0://localhost:10203?target=amc-c${cid}-13-t1:50001"
              address_table="file://${AMC13_ADDRESS_TABLE_PATH}/AMC13XG_T1.xml" />
  <connection id="gem.shelf${cid}.amc13.T2" uri="chtcp-2.0://localhost:10203?target=amc-c${cid}-13-t2:50001"
              address_table="file://${AMC13_ADDRESS_TABLE_PATH}/AMC13XG_T2.xml" />
EOF
        for slot in {1..12}
        do
            sid=$(printf '%02d' $slot)
            cat <<EOF >> /etc/sysmgr/ipconfig.xml
        <Slot number="${slot}">
            <Card type="WISC CTP-7">
                <FPGA id="0">${slot} 192 1.0 ${crate} $((slot+40)) 255 255 0 0 192 1.0 0 180 192 1.0 0 180 0 0</FPGA>
            </Card>
        </Slot>
EOF
            cat <<EOF >> /etc/hosts
192.168.1.$((slot+40)) amc-c${cid}-s${sid} amc-c${cid}-s${sid}.utca
EOF
            cat <<EOF >> /opt/cmsgemos/etc/maps/connections.xml
  <!-- AMC slot ${slot} shelf ${crate} -->
  <connection id="gem.shelf${cid}.amc03" uri="ipbustcp-2.0://amc-c${cid}-s${sid}:60002"
	      address_table="file://${GEM_ADDRESS_TABLE_PATH}/uhal_gem_amc_ctp7_amc.xml" />
EOF
            for lin in {0..11}
            do
                lid=$(printf '%02d' $lin)
            cat <<EOF >> /opt/cmsgemos/etc/maps/connections.xml
  <connection id="gem.shelf${cid}.amc03.optohybrid${lid}" uri="ipbustcp-2.0://amc-c${cid}-s${sid}:60002"
	      address_table="file://${GEM_ADDRESS_TABLE_PATH}/uhal_gem_amc_ctp7_link${lid}.xml" />
EOF
                done
            cat <<EOF >> /opt/cmsgemos/etc/maps/connections.xml

EOF
        done
        cat <<EOF >> /etc/sysmgr/ipconfig.xml
        <Slot number="13">
            <Card type="BU AMC13">
                <FPGA id="0">13 255 255 0 0 192 1.0 ${crate} 14</FPGA> <!-- T2 -->
                <FPGA id="1">13 255 255 0 0 192 1.0 ${crate} 13</FPGA> <!-- T1 -->
            </Card>
        </Slot>
EOF
        cat <<EOF >> /etc/hosts
EOF
        cat <<EOF >> /etc/sysmgr/ipconfig.xml
    </Crate>
EOF
        cat <<EOF >> /opt/cmsgemos/etc/maps/connections.xml

EOF
    done
    cat <<EOF >> /etc/sysmgr/ipconfig.xml
</IVTable>
EOF

    cat <<EOF >> /opt/cmsgemos/etc/maps/connections.xml
</connections>
EOF

    ### Set up host machine to act as time server
    if [ -e /etc/xinetd.d/time-stream ]
    then
        line=$(sed -n '/disable/=' /etc/xinetd.d/time-stream)
        cp /etc/xinetd.d/{time-stream,time-stream.bak}
        sed -i "$line s|yes|no|g" /etc/xinetd.d/time-stream
        ### restart xinetd
        # new_service xinetd on
    fi

    ### Set up rsyslog
    cat <<EOF > /etc/logrotate.d/ctp7
$ModLoad imudp

$UDPServerAddress 192.168.0.180
$UDPServerRun 514

$template RemoteLog,"/var/log/remote/%HOSTNAME%/messages.log"
:fromhost-ip, startswith, "192.168." ?RemoteLog
EOF

    ### Configure logrotate to rotate ctp7 logs
    cat <<\EOF > /etc/logrotate.d/ctp7
/var/log/remote/*/messages.log {
        sharedscripts
        missingok
        create 0644 root wheel
        compress
        dateext
        weekly
        rotate 4
        lastaction
                /bin/kill -HUP `cat /var/run/syslogd.pid 2> /dev/null` 2> /dev/null || true
                /bin/kill -HUP `cat /var/run/rsyslogd.pid 2> /dev/null` 2> /dev/null || true
        endscript
}

EOF
    ### Restart rsyslog
    # new_service rsyslog on

    ### Set up dnsmasq
    if [ -e /etc/xinetd.d/time-stream ]
    then
        cp /etc/{dnsmasq.conf,dnsmasq.conf.bak}
        line=$(sed -n '/log-queries/=' /etc/dnsmasq.conf)
        sed -i "$line s|#log-queries|log-queries|g" /etc/dnsmasq.conf
        line=$(sed -n '/log-dhcp/=' /etc/dnsmasq.conf)
        sed -i "$line s|#log-dhcp|log-dhcp|g" /etc/dnsmasq.conf
    fi

    # Create configuration file /etc/dnsmasq.d/ctp7, needs interface name
    setup_network
    cat <<EOF >> /etc/dnsmasq.d/ctp7
bind-interfaces
dhcp-range=192.168.249.1,192.168.249.254,1h
dhcp-option=option:ntp-server,0.0.0.0 # autotranslated to server ip
domain=utca
local=/utca/

dhcp-host=00:04:a3:a4:a1:8e,192.168.250.1  # falcon1
dhcp-host=00:04:a3:62:9f:d9,192.168.250.2  # falcon2
dhcp-host=00:04:a3:a4:dc:c1,192.168.250.3  # raven1
dhcp-host=00:04:a3:a4:bc:54,192.168.250.4  # raven2
dhcp-host=00:04:a3:a4:60:b2,192.168.250.5  # raven3
dhcp-host=00:04:a3:a4:d7:40,192.168.250.6  # raven4
dhcp-host=00:04:a3:a4:67:56,192.168.250.7  # raven5
dhcp-host=00:04:a3:a4:bf:e7,192.168.250.8  # raven6
dhcp-host=00:1e:c0:85:ef:ad,192.168.250.9  # eagle1
dhcp-host=00:1e:c0:85:ef:96,192.168.250.10 # eagle2
dhcp-host=00:1e:c0:86:2a:b8,192.168.250.11 # eagle3
dhcp-host=00:1e:c0:85:a2:36,192.168.250.12 # eagle4
dhcp-host=00:1e:c0:85:73:6c,192.168.250.13 # eagle5
dhcp-host=00:1e:c0:85:b1:99,192.168.250.14 # eagle6
dhcp-host=00:1e:c0:85:c3:16,192.168.250.15 # eagle7
dhcp-host=00:1e:c0:85:ad:48,192.168.250.16 # eagle8
dhcp-host=00:1e:c0:86:34:7f,192.168.250.17 # eagle9
dhcp-host=00:1e:c0:85:96:42,192.168.250.18 # eagle10
dhcp-host=00:1e:c0:85:de:4b,192.168.250.19 # eagle11
dhcp-host=00:1e:c0:86:35:fb,192.168.250.20 # eagle12
dhcp-host=00:1e:c0:86:22:7a,192.168.250.21 # eagle13
dhcp-host=00:1e:c0:85:94:66,192.168.250.22 # eagle14
dhcp-host=00:1e:c0:85:af:b3,192.168.250.23 # eagle15
dhcp-host=00:1e:c0:85:88:79,192.168.250.24 # eagle16
dhcp-host=00:1e:c0:85:af:a2,192.168.250.25 # eagle17
dhcp-host=00:1e:c0:86:0c:91,192.168.250.26 # eagle18
dhcp-host=00:1e:c0:86:16:d1,192.168.250.27 # eagle19
dhcp-host=00:1e:c0:86:36:97,192.168.250.28 # eagle20
dhcp-host=00:1e:c0:86:0c:30,192.168.250.29 # eagle21
dhcp-host=00:1e:c0:86:14:9a,192.168.250.30 # eagle22
dhcp-host=00:1e:c0:85:f9:ea,192.168.250.31 # eagle23
dhcp-host=00:1e:c0:85:73:9d,192.168.250.32 # eagle24
dhcp-host=00:1e:c0:85:bf:5a,192.168.250.33 # eagle25
dhcp-host=00:1e:c0:85:ec:45,192.168.250.34 # eagle26
dhcp-host=00:1e:c0:85:bd:62,192.168.250.35 # eagle27
dhcp-host=00:1e:c0:86:16:f9,192.168.250.36 # eagle28
dhcp-host=00:1e:c0:86:26:17,192.168.250.37 # eagle29
dhcp-host=00:1e:c0:85:96:06,192.168.250.38 # eagle30
dhcp-host=00:1e:c0:85:96:14,192.168.250.39 # eagle31
dhcp-host=00:1e:c0:86:2b:3f,192.168.250.40 # eagle32
dhcp-host=00:1e:c0:85:7d:24,192.168.250.41 # eagle33
dhcp-host=00:1e:c0:86:2d:9d,192.168.250.42 # eagle34
dhcp-host=00:1e:c0:85:c2:a7,192.168.250.43 # eagle35
dhcp-host=00:1e:c0:85:a1:70,192.168.250.44 # eagle36
dhcp-host=00:1e:c0:85:73:cb,192.168.250.45 # eagle37
dhcp-host=00:1e:c0:85:7f:bd,192.168.250.46 # eagle38
dhcp-host=00:1e:c0:86:17:92,192.168.250.47 # eagle39
dhcp-host=00:1e:c0:85:ec:3a,192.168.250.48 # eagle40
dhcp-host=00:1e:c0:85:b0:78,192.168.250.49 # eagle41
dhcp-host=00:1e:c0:85:74:01,192.168.250.50 # eagle42
dhcp-host=00:1e:c0:85:b2:60,192.168.250.51 # eagle43
dhcp-host=00:1e:c0:85:a4:54,192.168.250.52 # eagle44
dhcp-host=00:1e:c0:85:d0:da,192.168.250.53 # eagle45
dhcp-host=00:1e:c0:86:2b:6b,192.168.250.54 # eagle46
dhcp-host=00:1e:c0:85:73:7b,192.168.250.55 # eagle47
dhcp-host=00:1e:c0:85:9f:30,192.168.250.56 # eagle48
dhcp-host=00:1e:c0:85:96:fc,192.168.250.57 # eagle49
dhcp-host=00:1e:c0:85:ee:b1,192.168.250.58 # eagle50
dhcp-host=00:1e:c0:86:0c:7d,192.168.250.59 # eagle51
dhcp-host=00:1e:c0:85:86:5c,192.168.250.60 # eagle52
dhcp-host=00:1e:c0:85:bc:ca,192.168.250.61 # eagle53
dhcp-host=00:1e:c0:85:73:b3,192.168.250.62 # eagle54
dhcp-host=00:1e:c0:85:97:3a,192.168.250.63 # eagle55
dhcp-host=00:1e:c0:85:bc:8a,192.168.250.64 # eagle56
dhcp-host=00:1e:c0:86:34:00,192.168.250.65 # eagle57
dhcp-host=00:1e:c0:86:0c:05,192.168.250.66 # eagle58
dhcp-host=00:1e:c0:85:bc:f4,192.168.250.67 # eagle59
dhcp-host=00:1e:c0:86:2b:5f,192.168.250.68 # eagle60
dhcp-host=00:1e:c0:85:f9:ed,192.168.250.69 # eagle61
dhcp-host=00:1e:c0:85:e1:b4,192.168.250.70 # eagle62
dhcp-host=00:1e:c0:85:72:c9,192.168.250.71 # eagle63
dhcp-host=00:1e:c0:86:2a:7e,192.168.250.72 # eagle64
dhcp-host=00:1e:c0:85:ca:01,192.168.250.73 # eagle65
EOF
    ### Restart dnsmasq
    # new_service dnsmasq on

    ### Update /etc/hosts with CTP7-related dns (bird) names
    cat <<EOF >> /etc/hosts

# falcons
EOF
    for bird in {1..2}
    do
        cat <<EOF >> /etc/hosts
192.168.250.$bird falcon$bird falcon$bird.utca
EOF
    done

    cat <<EOF >> /etc/hosts

# ravens
EOF
    for bird in {1..6}
    do
        cat <<EOF >> /etc/hosts
192.168.250.$((2+bird)) raven$bird raven$bird.utca
EOF
    done

    cat <<EOF >> /etc/hosts

# eagles
EOF
    for bird in {1..65}
    do
        cat <<EOF >> /etc/hosts
192.168.250.$((9+bird)) eagle$bird eagle$bird.utca
EOF
    done
}
