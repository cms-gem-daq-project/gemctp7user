#!/bin/bash

## @file
## @author CMS GEM DAQ Project <gemdaq@cern.ch>
## @copyright MIT
## @version 1.0
## @brief Functions to wrap installation of extra tooling

. utils/helpers.sh

## @defgroup Extras Extra Tooling Utilities

## @fn install_root()
## @brief Install ROOT from the standard repository
## @ingroup Extras
## @note @ref setup_machine option @c '-r'
install_root() {
    echo Installing root...
    yum -y install root root-\*

    return 0
}


## @fn install_python()
## @brief Propmt to install additional versions of python
## @ingroup Extras
## @note @ref setup_machine option @c '-p'
install_python() {
    sclpyvers=( python27 python33 python34 )
    for sclpy in "${sclpyvers[@]}"
    do
        if prompt_confirm "Install ${sclpy}?"
        then
            eval yum -y install ${sclpy}*
        fi
    done

    rhpyvers=( rh-python34 rh-python35 rh-python36 )
    for rhpy in "${rhpyvers[@]}"
    do
        if prompt_confirm "Install ${rhpy}?"
        then
            eval yum -y install ${rhpy}*
        fi
    done

    return 0
}
