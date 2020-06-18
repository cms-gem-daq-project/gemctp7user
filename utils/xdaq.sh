#!/bin/bash

## @file
## @author CMS GEM DAQ Project
## @copyright MIT
## @version 1.0
## @brief Set of scripts to simplify the configuration of xdaq on GEM DAQ machines
##
## @details
## @note Supported OS releases are (@c cc7|@c cc8)
## @note Supported versions of @c xdaq are:
## @li @c 14 is only available for @c cc7, using the @c svn release
## @li @c 14-6 is only available for @c cc7, using the GitLab release
## @li @c 15 is only available for @c cc7, using the GitLab release
## @li @c 16 is only available for @c C8, using the GitLab release

. utils/helpers.sh


## @defgroup xDAQ xDAQ Utilities
## @brief Functions to facilitate installation of xdaq dependencies.
## @details

### File globals
## @var installpkg
## @brief Alias to @c yum/dnf install a package
## @ingroup xDAQ
declare -r installpkg="yum install -y"

## @var installgrp
## @brief Alias to @c yum/dnf install a group
## @ingroup xDAQ
declare -r installgrp="yum groupinstall -y"

## @var slc6re
## @brief Regular expression matching valid @c xdaq releases for @c slc6
## @ingroup xDAQ
declare -r slc6re='^13$'

## @var cc7re
## @brief Regular expression matching valid @c xdaq releases for @c cc7
## @ingroup xDAQ
declare -r cc7re='^(14|14-6|15)$'

## @var cc8re
## @brief Regular expression matching valid @c xdaq releases for @c cc8
## @ingroup xDAQ
declare -r cc8re='^16$'

## @var glre
## @brief Regular expression matching @c xdaq releases from GitLab
## @ingroup xDAQ
declare -r glre='^(14-6|15|16)$'

## @var xdaqre
## @brief Regular expression matching any valid @c xdaq release verison
## @ingroup xDAQ
declare -r xdaqre="(${slc6re}|${cc7re}|${cc8re})"

## @fn get_xdaq_repo()
## @brief Create the @c xdaq @c yum/dnf repo file for the architecture and xdaq version
## @ingroup xDAQ
## @param xdaqver @c xdaq version
## @param osrel OS release
get_xdaq_repo() {

    local osrel=
    local xdaqver=

    if [ -n "$1" ]
    then
        echo "No XDAQ version specified, assuming 14 (default for legacy)"
        xdaqver="14"
    else
        xdaqver="$1"
    fi

    if [ -n "$2" ]
    then
        echo "No OS specified, assuming cc7 (default for legacy)"
        osrel="cc7"
    else
        osrel="$2"
    fi

    if ! [[ "${xdaqver}" =~ ${xdaqre} ]]
    then
        printf "\033[1;31m %s \n\033[0m" "Invalid XDAQ version ($xdaqver) specified"
        return 1
    fi

    if [[ "${osrel}" = "slc6" ]] && [[ "${xdaqver}" =~ ${slc6re} ]]
    then
        echo "Generating repo file for XDAQ${xdaqver} on ${osrel}"
        cat <<EOF > /tmp/etc-yum.repos.d-xdaq.repo
EOF
    elif [[ "${osrel}" = "cc7" ]] && [[ "${xdaqver}" =~ ${cc7re} ]]
    then
        echo "Generating repo file for XDAQ${xdaqver} on ${osrel}"
        if [[ "${xdaqver}" = "14" ]]
        then
            cat <<EOF > /tmp/etc-yum.repos.d-xdaq.repo
[xdaq-base]
name     = XDAQ Software Base
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/${xdaqver}/${osrel}/x86_64/base/RPMS/
enabled  = 1
gpgcheck = 0

[xdaq-updates]
name     = XDAQ Software Updates
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/${xdaqver}/${osrel}/x86_64/updates/RPMS/
enabled  = 1
gpgcheck = 0

[xdaq-extras]
name     = XDAQ Software Extras
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/${xdaqver}/${osrel}/x86_64/extras/RPMS/
enabled  = 1
gpgcheck = 0

[xdaq-kernel-modules]
name     = XDAQ Kernel Modules
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/${xdaqver}/${osrel}/x86_64/kernel_modules/RPMS/
enabled  = 1
gpgcheck = 0
EOF
        else
            cat <<EOF > /tmp/etc-yum.repos.d-xdaq.repo
[xdaq-core]
name     = XDAQ ${xdaqver} Core Software
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/core/${xdaqver}/${osrel}/x86_64/RPMS/
enabled  = 1
gpgcheck = 0

[xdaq-worksuite]
name     = XDAQ ${xdaqver} Worksuite Software
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/worksuite/${xdaqver}/${osrel}/x86_64/RPMS/
enabled  = 1
gpgcheck = 0

[xdaq-xaas]
name     = XDAQ ${xdaqver} XaaS Software
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/xaas/${xdaqver}/${osrel}/x86_64/RPMS/
enabled  = 1
gpgcheck = 0
EOF
        fi
    elif [[ "${osrel}" = "cc8" ]] && [[ "${xdaqver}" =~ ${cc8re} ]]
    then
        echo "Generating repo file for XDAQ${xdaqver} on ${osrel}"
        cat <<EOF > /tmp/etc-yum.repos.d-xdaq.repo
[xdaq-core]
name     = XDAQ ${xdaqver} Core Software
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/core/${xdaqver}/${osrel}/x86_64/RPMS/
enabled  = 1
gpgcheck = 0

[xdaq-worksuite]
name     = XDAQ ${xdaqver} Worksuite Software
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/worksuite/${xdaqver}/${osrel}/x86_64/RPMS/
enabled  = 1
gpgcheck = 0

[xdaq-xaas]
name     = XDAQ ${xdaqver} XaaS Software
baseurl  = http://xdaq.web.cern.ch/xdaq/repo/xaas/${xdaqver}/${osrel}/x86_64/RPMS/
enabled  = 1
gpgcheck = 0
EOF
    else
        printf "\033[1;31m %s \n\033[0m" "Unable to find a compatible match for XDAQ${xdaqver} on ${osrel}"
        return 1
    fi
}


## @fn install_xdaq()
## @brief Install development @c xdaq packages and any non-dependent packages
## @ingroup xDAQ
## @param xdaqver @c xdaq version
## @param osrel OS release
## @note @ref setup_machine option @c '-x'
install_xdaq() {

    local xdaqver="$1"
    local osrel="$2"

    if ! [ -f /tmp/etc-yum.repos.d-xdaq.repo ]
    then
        if prompt_confirm "xdaq repo file does not exist, create?"
        then
            get_xdaq_repo ${xdaqver} ${osrel}
        fi
    else
        printf "\033[1;31m %s \n\033[0m" "Unable to download xdaq packags, repo file missing."
        return 1
    fi

    echo Installing XDAQ...

    # generic XDAQ
    if [[ "${xdaqver}" =~ ${glre} ]]
    then
        xdaqpkgs="cmsos_core cmsos_worksuite cmsos_dcs_worksuite"
        xdaqdbgp="cmsos_core_debuginfo cmsos_worksuite_debuginfo cmsos_dcs_worksuite_debuginfo"
        xdaqexcl="--exclude=cmsos-worksuite-psxsapi --exclude=cmsos-worksuite-psx --exclude=cmsos-worksuite-dipbridge"
        kmods="cmsos-worksuite-fedkit cmsos-worksuite-xpcidrv"
    else
        xdaqpkgs="coretools extern_coretools database_worksuite general_worksuite hardware_worksuite powerpack extern_powerpack"
        xdaqdbgp="coretools_debuginfo exetern_coretools_debuginfo database_worksuite_debuginfo general_worksuite_debuginfo dcs_worksuite_debuginfo hardware_worksuite_debuginfo powerpack_debuginfo extern_powerpack_debuginfo"
        # # broken currently
        # xdaqpkgs="${xdaqpkgs} dcs_worksuite"
        xdaqexcl="--exclude=daq-psx"
        kmods="daq-fedkit daq-xpcidrv"
    fi
    cmd="${installgrp} ${xdaqpkgs} ${xdaqexcl}"
    echo ${cmd}
    # eval ${cmd}

    # for fedKit
    if prompt_confirm "Install kernel modules for uFEDKIT?"
    then
        cmd="${installpkg} ${kmods}"
        echo ${cmd}
        # eval ${cmd}
    fi

    # debug modules
    if prompt_confirm "Install xdaq debuginfo modules?"
    then
        cmd="${installgrp} ${xdaqdbgp} ${xdaqexcl}"
        echo ${cmd}
        # eval ${cmd}
    fi

    return 0
}


## @fn update_xpci_driver()
## @brief Update @c xpci driver for uFEDKIT after a kernel update
## @ingroup xDAQ
## @details Rebuilds, packages, and reinstalls the @c xpcidrv package and kernel module
##  The @c rpmbuild actions are done as @c gembuild
## @warning unloading and reloading the @c xpci driver may cause the machine to reboot
## @note @ref setup_machine option @c '-P'
update_xpci_driver() {

    tmpdir=$(sudo -u gembuild mktemp -d /tmp/tmp.XXXXXX)
    pushd ${tmpdir}

    pkgname=cmsos-worksuite-xpcidrv
    if ! yumdownloader --source -y ${pkgname}
    then
        pkgname=daq-xpcidrv
        if ! yumdownloader --source -y ${pkgname}
        then
            printf "\033[1;31m %s \n\033[0m" "Failed to download ${pkgname} sources"
            return 1
        fi
    fi

    yum-builddep -y ${pkgname}-*.src.rpm

    # this part should be run as non-root
    builddir=${tmpdir}/rpmbuild
    echo "Entering user subshell"
    sudo -u gembuild echo "Entered user subshell"
    sudo -u gembuild rpm -ihv ${pkgname}-*.src.rpm
    sudo -u gembuild mkdir -p ${builddir}
    sudo -u gembuild rpmbuild --define "_topdir ${builddir}" -bb ${builddir}/SPECS/${pkgname}*.spec
    sudo -u gembuild echo "Leaving user subshell"

    # should be run with elevated privileges
    yum -y remove ${pkgname} ${pkgname}-debuginfo ${pkgname}-devel
    yum -y install ${builddir}/RPMS/x86_64/kernel-module-${pkgname}-*.rpm
    yum -y install ${builddir}/RPMS/x86_64/${pkgname}-*.rpm

    if ! (lsmod | fgrep xpci 2>1 >/dev/null)
    then
        modprobe xpci
    fi
    popd

    rm -rf ${tmpdir}

    return 0
}
