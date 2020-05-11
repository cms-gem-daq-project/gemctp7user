#!/bin/bash

## @file
## @author CMS GEM DAQ Project <gemdaq@cern.ch>
## @copyright MIT
## @version 1.0
## @brief Functions to facilitate adding developer tools to GEM DAQ machines

. utils/helpers.sh

## @defgroup DevTools Developer Tool Utilities

## @fn install_devtools()
## @brief Propmt to install devtoolset groups
## @ingroup DevTools
## @details Will install make, gcc, oprofile, and valgrind from the group
install_devtools() {
    devtools=( devtoolset-3 devtoolset-4 devtoolset-6 devtoolset-7 devtoolset-7 devtoolset-8 devtoolset-9 )
    for dtool in "${devtools[@]}"
    do
        if prompt_confirm "Install ${dtool} packages?"
        then
            eval yum -y install ${dtool}-{make,gcc,oprofile,valgrind}
        fi
    done

    return 0
}


## @fn install_llvm()
## @brief Propmt to install llvm toolset groups,
## @ingroup DevTools
## @details Will install clang, clang-analyzer, clang-devel, clang-tools-extra from the group
install_llvm() {
    llvmtools=( llvm-toolset-7 llvm-toolset-7.0 )
    for ltool in "${llvmtools[@]}"
    do
        if prompt_confirm "Install ${ltool} packages?"
        then
            eval yum -y install ${ltool}-{clang,clang-analyzer,clang-devel,clang-tools-extra}
        fi
    done

    return 0
}


## @fn install_ruby()
## @brief Propmt to install devtoolset groups
## @ingroup DevTools
install_ruby() {
    rubyvers=( rh-ruby22 rh-ruby23 rh-ruby24 rh-ruby25 rh-ruby26 )
    for rver in "${rubyvers[@]}"
    do
        if prompt_confirm "Install ${rver}?"
        then
            yum -y install ${rver}* --exclude=${rver}*-{build,scldevel}
        fi
    done
}


## @fn install_new_emacs()
## @brief Propmt to install latest emacs from source
## @ingroup DevTools
install_new_emacs() {
    if prompt_confirm "Install updated emacs?"
    then
        builddir=/tmp/emacsbuild
        pushd $builddir
        curl -LO https://alpha.gnu.org/gnu/emacs/pretest/emacs-27.0.91.tar.xz
        tar xJf emacs-27.0.91.tar.xz
        pushd emacs-27.0.91
        ./configure --program-suffix=-27 --program-transform-name=emacs-27.0 --prefix=/usr/local --without-x --with-kerberos5 --with-kerberos --with-json
        make
        make install
        popd
        popd
    fi

    return 0
}


## @fn install_arm()
## @brief Install a helper script to facilitate installing any ARM compiler toolchain from linaro or arm developer
## @ingroup DevTools
install_arm() {
    # Install ARM compilers
    ARM_DIR=/tmp/opt-arm
    mkdir -p ${ARM_DIR}
#ifndef DOXYGEN_IGNORE_THIS
    echo -e \
$'#!/bin/bash -e

declare -A allowedversions=(
    ### provided by linaro, but the filename *sometimes* requires a specific subversion...
    ["4.9-2016.02"]="4.9-2016.02"
    ["4.9-2017.01"]="4.9.4-2017.01"
    ["5.1-2015.08"]="5.1-2015.08"
    ["5.2-2015.11"]="5.2-2015.11"
    ["5.2-2015.11-1"]="5.2-2015.11-1"
    ["5.2-2015.11-2"]="5.2-2015.11-2"
    ["5.3-2016.02"]="5.3-2016.02"
    ["5.3-2016.05"]="5.3.1-2016.05"
    ["5.4-2017.01"]="5.4.1-2017.01"
    ["5.4-2017.05"]="5.4.1-2017.05"
    ["5.5-2017.10"]="5.5.0-2017.10"
    ["6.1-2016.08"]="6.1.1-2016.08"
    ["6.2-2016.11"]="6.2.1-2016.11"
    ["6.3-2017.02"]="6.3.1-2017.02"
    ["6.3-2017.05"]="6.3.1-2017.05"
    ["6.4-2017.08"]="6.4.1-2017.08"
    ["6.4-2017.11"]="6.4.1-2017.11"
    ["6.4-2018.05"]="6.4.1-2018.05"
    ["6.5-2018.12"]="6.5.0-2018.12"
    ["7.1-2017.05"]="7.1.1-2017.05"
    ["7.1-2017.08"]="7.1.1-2017.08"
    ["7.2-2017.11"]="7.2.1-2017.11"
    ["7.3-2018.05"]="7.3.1-2018.05"
    ["7.4-2019.02"]="7.4.1-2019.02"
    ["7.5-2019.12"]="7.5.0-2019.12"
    ### provided by ARM developer
    ["8.2-2018.08"]="8.2-2018.08"
    ["8.2-2018.11"]="8.2-2018.11"
    ["8.2-2019.01"]="8.2-2019.01"
    ["8.3-2019.03"]="8.3-2019.03"
    ["9.2-2019.12"]="9.2-2019.12"
)

usage() {
    cat <<EOF
Script usage: "$0" <compiler date> <arch>
This script will find the appropriate download location, depending on the version and architecture
The allowed versions are ${!allowedversions[@]}
EOF
}

version="$1"
arch="$2"

baseurl=""
fileurl=""
runtimeurl=""
sysrooturl=""

fversion=${allowedversions[${version}]}

if ! [ "${fversion}" == "" ]
then
    if [[ ${version} =~ ^[4-7]\.[0-9]+-20[0-9]{2} ]]
    then
        baseurl="https://releases.linaro.org/components/toolchain/binaries"
        arch="arm-linux-gnueabihf"
        fileurl="${baseurl}/${version}/${arch}/gcc-linaro-${fversion}-x86_64_${arch}.tar.xz"
    elif [[ ${version} =~ ^[8-9]\.[0-9]+-20[0-9]{2} ]]
    then
        baseurl="https://developer.arm.com/-/media/Files/downloads/gnu-a"
        arch="arm-linux-gnueabihf"
        binrel=""
        if [[ ${version} =~ ^8\.2-20[0-9]{2} ]]
        then
            binrel=""
        elif [[ ${version} =~ ^9\.[0-9]+-20[0-9]{2} ]]
        then
            binrel="/binrel"
            arch="arm-none-linux-gnueabihf"
        else
            binrel="/binrel"

        fi
        fileurl="${baseurl}/${version}${binrel}/gcc-arm-${version}-x86_64-${arch}.tar.xz"
    else
        echo ${helpstring}
        exit 1
    fi
else
    echo "Unknown version: ${version}"
    echo ${helpstring}
    exit 1
fi

ARM_DIR=/opt/arm
mkdir -p ${ARM_DIR}
fname="${fileurl##*/}"
curl -o "${ARM_DIR}/${fname}" -L ${fileurl}
pushd $(dirname ${ARM_DIR}/${fname})
tar xJf ${fname}
popd' > ${ARM_DIR}/getarm.sh
# endif DOXYGEN_IGNORE_THIS

    return 0
}


## @fn install_developer_tools()
## @brief Propmt to install additional tools for developing software
## @ingroup DevTools
## @note @ref setup_machine option @c '-d'
install_developer_tools() {
    echo Installing developer tools RPMS...

    if prompt_confirm "Install rh-git29?"
    then
       yum -y install rh-git29*
    fi

    if prompt_confirm "Install git-lfs?"
    then
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | bash
        yum -y install git-lfs
    fi

    install_devtools
    install_llvm
    install_ruby
    install_arm

    return 0
}


## @fn install_misc_rpms()
## @brief Propmt to install additional tools that may be required for various developments
## @ingroup DevTools
## @note @ref setup_machine option @c '-m'
install_misc_rpms() {
    echo Installing miscellaneous RPMS...
    yum -y install tree telnet htop arp-scan screen tmux cppcheck

    yum -y install libuuid-devel e2fsprogs-devel readline-devel ncurses-devel curl-devel boost-devel \
        numactl-devel libusb-devel libusbx-devel \
        protobuf-devel protobuf-lite-devel pugixml-devel

    if [ "${osver}" = "6" ]
    then
        yum -y install mysql-devel mysql-server
        yum -y install sl-release-scl
    elif [ "${osver}" = "7" ]
    then
        yum -y install mariadb-devel mariadb-server
        yum -y install centos-release-scl
    else
        echo "Unknown release ${osver}"
    fi

    return 0
}
