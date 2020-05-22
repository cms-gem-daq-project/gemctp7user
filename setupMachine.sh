#!/bin/bash

## @file setupMachine.sh
## @author CMS GEM DAQ Project
## @copyright MIT
## @version 1.0
## @brief Script to facilitate the setup of new GEM DAQ machines.


## @defgroup MachineSetup Machine Setup
## @brief These functions directly relate to the setting up of new DAQ PCs.
## @details The linked functions perform all the various steps.
##
## @note Should be run on a compatible architecture (REHL/Centos based).
##
## @par Usage @c setupMachine.sh @c -h
##
##      The main entry point is provided in the function @ref setup_machine.

## @fn cleanup()
## @brief Performs cleanup of the actions taken when running the script
## @ingroup MachineSetup
## @details Called in @c trap on
## @li @c EXIT
## @li @c SIGQUIT
## @li @c SIGINT
## @li @c SIGTERM
## @li @c SIGSEGV
cleanup() {
}

trap cleanup EXIT SIGQUIT SIGINT SIGTERM SIGSEGV

# Imports
. utils/helpers.sh
. utils/xdaq.sh
. utils/cactus.sh
. utils/utca.sh
. utils/extras.sh
. utils/devtools.sh
. utils/accounts.sh
. utils/networking.sh
. utils/xilinx.sh

export arch=`uname -i`
export osver=`expr $(uname -r) : '.*el\([0-9]\)'`
export ostype=centos
export osrel=cc${osver}

if [ "${osver}" = "6" ]
then
    ostype=slc
    osrel=${ostype}${osver}
fi

## @fn usage()
## @brief Usage function for @ref setup_machine
## @ingroup MachineSetup
usage() {
    cat <<EOF
Usage: $0 [options]
  Options:
    -x install xdaq software
    -c Install cactus tools (uhal and amc13)
    -m Install other miscellaneous packages (for development machines)
    -s Install UW system manager
    -r Install ROOT (from repository)
    -p Install additional python versions
    -d Install developer tools
    -n Setup mounting of NAS
    -C Set up CTP7 connections
    -M Install Mellanox 10GbE drivers for uFEDKIT
    -N Set up network interfaces
    -P Install/update xpci drivers
    -R Get repository files
    -U Create common users and groups
    -z Install Xilinx USB drivers
    -v Install Xilinx Vivado
    -e Install Xilinx ISE
    -l Install Xilinx LabTools
    -u <file> Add accounts of NICE users (specified in file)
    -h Print this help menu

  The following options group common actions into a single option, assuming defaults for the detected system, override with appropriate options:
    -A Setup new system with defaults for DAQ with accounts (implies -IUN)
    -D Install extra drivers (implies -MP)
    -I Install only software (implies -xcmrs)
    -X Install Xilinx tooling (implies -zvle)

  Note:
    Full support is only currently provided for CC7 (and soon C8)

  Examples:
    Set up newly installed machine and add CERN NICE users: $0 -Au
    Set up newly installed machine and add uFEDKIT support: $0 -AM

  Plese report bugs to:
    https://github.com/cms-gem-daq-project/cmsgemos
EOF

    exit 1
}

## @fn setup_machine()
## @brief Runs the machine setup
## @ingroup MachineSetup
## @details The available flags are:
##
##  These flags aggregate some of the individual options for ease of use
## @li @c -A Setup new system with defaults for DAQ with accounts (implies @c -IUN)
## @li @c -D Install extra drivers (implies @c -MP)
## @li @c -I Install only software (implies @c -xcmrs)
## @li @c -X Install Xilinx tooling (implies @c -zvle)
##
##  Individual options
## @li @c -x install @c xdaq software with @ref install_xdaq
## @li @c -c Install cactus tools (@c uhal and @c amc13) with @ref install_cactus
## @li @c -m Install other miscellaneous packages (for development machines) with @ref install_misc_rpms
## @li @c -s Install UW system manager with @ref install_sysmgr
## @li @c -r Install ROOT (from repository) with @ref install_root
## @li @c -p Install additional @c python versions with @ref install_python
## @li @c -d Install developer tools with @ref install_developer_tools
## @li @c -n Setup mounting of NAS with @ref setup_nas
## @li @c -C Set up CTP7 connections with @ref connect_ctp7s
## @li @c -M Install Mellanox 10GbE drivers for uFEDKITs with @ref install_mellanox_driver
## @li @c -N Set up network interfaces with @ref setup_network
## @li @c -P Install/update @c xpci drivers for uFEDKITs with @ref update_xpci_driver
## @li @c -R Get repository files with @ref get_xdaq_repo, with @ref get_cactus_repos, with @ref get_gemos_repo
## @li @c -U Create common users and groups with @ref create_accounts
## @li @c -z Install Xilinx USB cable drivers with @ref install_usb_cable_driver
## @li @c -v Install Xilinx Vivado with @ref install_vivado
## @li @c -e Install Xilinx ISE with @ref install_ise
## @li @c -l Install Xilinx LabTools with @ref install_labtools
## @li @c -u @c file Add accounts of NICE users (specified in @c file) with @ref add_users
## @li @c -h Print this help menu
##
setup_machine() {
    declare -r baseopts="hxcmsrpdnCMNPRUu"
    declare -r groupopts="ADIX"
    declare -r xilopts="zvle"
    declare -r allopts=${baseopts}${groupopts}${xilopts}

    while getopts "${allopts}" opt
    do
        case $opt in
            A)
                printf "\033[1;36m %s \n\033[0m" "Doing all steps necessary for new machine"
                GET_REPO_FILES=1
                INSTALL_XDAQ=1
                INSTALL_CACTUS=1
                INSTALL_ROOT=1
                INSTALL_SYSMGR=1
                INSTALL_MISC_RPMS=1
                CREATE_ACCOUNTS=1
                SETUP_NETWORK=1
                ;;
            I)
                print "\e[48;5;221m\e[38;5;15m"
                print "\e[33;5;0m\e[38;5;221m"

                printf "\033[1;36m %s \n\033[0m" "Installing necessary packages"
                GET_REPO_FILES=1
                INSTALL_XDAQ=1
                INSTALL_CACTUS=1
                INSTALL_ROOT=1
                INSTALL_SYSMGR=1
                INSTALL_MISC_RPMS=1
                ;;
            D)
                printf "\033[1;36m %s \n\033[0m" "Installing optional drivers"
                INSTALL_MELLANOX_DRIVER=1
                UPDATE_XPCI_DRIVER=1
                INSTALL_USB_DRIVER=1
                ;;
            X)
                printf "\033[1;36m %s \n\033[0m" "Installing optional Xilinx tooling"
                INSTALL_USB_DRIVER=1
                INSTALL_VIVADO=1
                INSTALL_ISE=1
                INSTALL_LABTOOLS=1
                ;;
            x)
                INSTALL_XDAQ=1 ;;
            c)
                INSTALL_CACTUS=1 ;;
            m)
                INSTALL_MISC_RPMS=1 ;;
            s)
                INSTALL_SYSMGR=1 ;;
            r)
                INSTALL_ROOT=1 ;;
            p)
                INSTALL_PYTHON=1 ;;
            d)
                INSTALL_DEVELOPER_TOOLS=1 ;;
            n)
                SETUP_NAS=1 ;;
            C)
                CONNECT_CTP7S=1 ;;
            M)
                INSTALL_MELLANOX_DRIVER=1 ;;
            N)
                SETUP_NETWORK=1 ;;
            R)
                GET_REPO_FILES=1 ;;
            P)
                UPDATE_XPCI_DRIVER=1 ;;
            U)
                CREATE_ACCOUNTS=1 ;;
            z)
                INSTALL_USB_DRIVER=1 ;;
            v)
                INSTALL_VIVADO=1 ;;
            e)
                INSTALL_ISE=1 ;;
            l)
                INSTALL_LABTOOLS=1 ;;
            u)
                ADD_USERS=1 ;;
            h)
                echo >&2 ; usage ; exit 1 ;;
            \?)
                printf "\033[1;31m %s \n\033[0m" "Invalid option: -$OPTARG" >&2 ; usage ; exit 1 ;;
            [?])
                echo >&2 ; usage ; exit 1 ;;
        esac
    done

    ## execute the specified steps
    if [ "${GET_REPO_FILES}" = "1" ]
    then
        read -r -p $'\e[1;34mPlease specify desired xDAQ version:\033[0m ' xdaqver
        get_xdaq_repo ${xdaqver} ${osrel}
        get_cactus_repo ${osrel}
        get_gemos_repo ${osrel}
    fi

    if [ "${INSTALL_XDAQ}" = "1" ]
    then
        read -r -p $'\e[1;34mPlease specify desired xDAQ version:\033[0m ' xdaqver
        install_xdaq ${xdaqver} ${osrel}
    fi

    if [ "${INSTALL_CACTUS}" = "1" ]
    then
        install_cactus ${ostype}${osver}
    fi

    if [ "${INSTALL_MISC_RPMS}" = "1" ]
    then
        install_misc_rpms
    fi

    if [ "${INSTALL_SYSMGR}" = "1" ]
    then
        install_sysmgr
    fi

    if [ "${INSTALL_ROOT}" = "1" ]
    then
        install_root
    fi

    if [ "${INSTALL_PYTHON}" = "1" ]
    then
        install_python
    fi

    if [ "${INSTALL_DEVELOPER_TOOLS}" = "1" ]
    then
        install_developer_tools
    fi

    if [ "${SETUP_NAS}" = "1" ]
    then
        setup_nas
    fi

    if [ "${SETUP_NETWORK}" = "1" ]
    then
        setup_network
    fi

    if [ "${CONNECT_CTP7S}" = "1" ]
    then
        connect_ctp7s
    fi

    if [ "${INSTALL_MELLANOX_DRIVER}" = "1" ]
    then
        install_mellanox_driver
    fi

    if [ "${UPDATE_XPCI_DRIVER}" = "1" ]
    then
        update_xpci_driver
    fi

    if [ "${CREATE_ACCOUNTS}" = "1" ]
    then
        create_accounts
    fi

    if [ "${ADD_USERS}" = "1" ]
    then
        add_users
    fi

    if [ "${INSTALL_USB_DRIVER}" = "1" ]
    then
        install_usb_cable_driver
    fi

    if [ "${INSTALL_VIVADO}" = "1" ]
    then
        install_vivado
    fi

    if [ "${INSTALL_ISE}" = "1" ]
    then
        install_ise
    fi

    if [ "${INSTALL_LABTOOLS}" = "1" ]
    then
        install_labtools
    fi


    printf "\033[1;32m %s \n\033[0m" "Your machine should now be configured!"
}

(setup_machine)
