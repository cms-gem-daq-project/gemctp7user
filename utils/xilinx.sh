#!/bin/bash

## @file
## @author CMS GEM DAQ Project <gemdaq@cern.ch>
## @copyright MIT
## @version 1.0
## @brief Functions to wrap installation of Xilinx tooling

. utils/helpers.sh

if [ -n ${XILINX_DIR} ]
then
    XILINX_DIR=/opt/Xilinx
fi

## @defgroup Xilinx Xilinx Utilities

## @fn install_usb_cable_driver()
## @brief Install Xilinx programmer box USB drivers
## @ingroup DeviceDrivers
## @note @ref setup_machine option @c '-z'
install_usb_cable_driver() {
    mkdir -p ${XILINX_DIR}
    git clone git://git.zerfleddert.de/usb-driver
    pushd usb-driver
    make
    ./setup_pcusb
    popd

    return 0
}


## @fn install_labtools()
## @brief Install Xilinx ISE LabTools
## @ingroup Xilinx
## @note @ref setup_machine option @c '-l'
install_labtools() {
    echo "Not implemnted"

    return 0
}


## @fn install_ise()
## @brief Install Xilinx ISE
## @ingroup Xilinx
## @note @ref setup_machine option @c '-e'
install_ise() {
    echo "Not implemnted"

    return 0
}


## @fn install_vivado()
## @brief Install Xilinx Vivado
## @ingroup Xilinx
## @note @ref setup_machine option @c '-v'
install_vivado() {
    echo "Not implemnted"

    return 0
}
