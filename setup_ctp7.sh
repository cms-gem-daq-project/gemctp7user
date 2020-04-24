#!/bin/sh

set -o pipefail

### Globals
declare CARD_GEMDAQ_DIR=/mnt/persistent/gemdaq

## If not set in the calling shell, use the default
## Path to local storage of bitfiles and xml files for each FW version
## Useful?
echo ${GEM_FW_DIR:=/opt/gemdaq/fw}

## If not set in the calling shell, use the default
echo ${GEM_ADDRESS_TABLE_ROOT:=/opt/cmsgemos/etc/maps}

## If not set in the calling shell, use the default
echo ${XHAL_ROOT:=/opt/xhal}

declare tmpdir=
declare tmpcard=
declare gesuf=

create_tmp_card() {

    if ! [ -n "${tmpcard}" ] || ! [ -d  "${tmpcard}" ]
    then
        echo "Downloading artifacts to ${tmpdir}"
        ## Create a local temp structure for the artifacts
        tmpdir=$(mktemp -d /tmp/tmp.XXXXXX)

        ## Create a local tree to mimic the card tree structure
        tmpcard=${tmpdir}${CARD_GEMDAQ_DIR}
        mkdir -p ${tmpcard}/{fw,oh_fw,scripts,xml,gemloader,vfat3}
    else
        echo "Temp area already exists at ${tmpdir}"
    fi

    return 0
}

cleanup() {

    if ! [ -n "${KEEP_ARTIFACTS}" ] && [ -n "${tmpdir}" ]
    then
        echo "Cleaning up ${tmpdir}"
        rm -rf ${tmpdir}
    else
        echo "Not removing ${tmpdir}, make sure to clean up after yourself!"
    fi

}

trap cleanup EXIT SIGQUIT SIGINT SIGTERM SIGSEGV

update_lmdb() {

    echo "Update LMDB address table on the CTP7, make a new .pickle file and resync xml folder"
    pushd ${tmpcard}/xml

    ${DEBUG} ${DRYRUN} set -x
    ${DRYRUN} rm -rf ${GEM_ADDRESS_TABLE_ROOT}/amc_address_table_top.pickle
    ${DRYRUN} python ${XHAL_ROOT}/bin/gem_reg.py -n ${ctp7host} \
           -e update_lmdb ${CARD_GEMDAQ_DIR}/xml/gem_amc_top.xml
    ${DRYRUN} cp -rfp ${GEM_ADDRESS_TABLE_ROOT}/amc_address_table_top.pickle gem_amc_top_v${ctp7fw//./_}.pickle
    ${DRYRUN} ln -sf gem_amc_v${ctp7fw//./_}.pickle gem_amc_top.pickle
    ${DEBUG} ${DRYRUN} set +x

    ## Partially update card
    ${DRYRUN} rsync -ach --progress --partial --links ${tmpcard}/xml root@${ctp7host}:${CARD_GEMDAQ_DIR}/

    echo "New pickle file has been copied to the CTP7, make sure you modify it correctly"

    popd

    return 0
}

get_gem_generation() {
    ${DEBUG} echo ge_gen ${ge_gen:="$1"}

    local -r genre='^([01]|(2[12]?))$'

    if [ -n "${ge_gen}" ]
    then
        if ! [[ "${ge_gen}" =~ ${genre} ]]
        then
            echo "Invalid GEM generation specified ${ge_gen}"
            usage
        fi

        if [[ "${ge_gen}" = ^21$ ]]
        then
            echo "Using GE2/1 OHv1"
            gesuf="ge21v1_"
        elif [[ "${ge_gen}" =~ "2" ]]
        then
            echo "Using GE2/1 OHv2"
            gesuf="ge21v2_"
        elif [[ "${ge_gen}" = ^0$ ]]
        then
            echo "Using ME0 OH"
            gesuf="me0_"
        else
            echo "Using GE1/1 OH"
            gesuf="ge11_"
        fi
    else
        echo "Using GE1/1 OH (default)"
        gesuf="ge11_"
    fi

    return 0
}

check_gemuser() {
    ${DRYRUN} ssh -tq root@${ctp7host} cat /etc/passwd|egrep gemuser >/dev/null
}

create_gemuser() {
    if ! check_gemuser
    then
        while true
        do
            read -u 3 -r -n 1 -p "Create CTP7 user account: gemuser (y|n) : " create
            case $create in
                [yY]* )
                    ${DEBUG} ${DRYRUN} set -x
                    ${DRYRUN} ssh -tq root@${ctp7host} '/usr/sbin/adduser gemuser -h /mnt/persistent/gemuser && /bin/save_passwd'
                    ${DRYRUN} ssh -tq gemuser@${ctp7host} 'mkdir -p ~/logs'
                    ${DRYRUN} rsync -aXch --progress --partial --links .profile .bashrc .vimrc .inputrc gemuser@${ctp7host}:~/
                    ${DEBUG} ${DRYRUN} set +x
                    break;;
                [nN]* ) break;;
                * )
                    echo
                    echo "Enter y or n (case insensitive)";;
            esac
        done 3<&0
    else
        echo "CTP7 user gemuser already exists"
    fi

    return 0
}

update_oh_fw() {

    local -r ohfw="$1"
    local -r ohfwre='^[3]\.[0-9]+\.[0-9]+\.(1C|C|2A)$'
    declare -r OH_FW_DOWNLOAD_DIR=https://github.com/cms-gem-daq-project/OptoHybridv3/releases/download

    if [[ "${ohfw}" =~ ${ohfwre} ]]
    then
        echo "Downloading V3 firmware with tag ${ohfw}"

        create_tmp_card

        pushd ${tmpdir}

        ${DEBUG} ${DRYRUN} set -x
        ${DRYRUN} curl -LO ${OH_FW_DOWNLOAD_DIR}/${ohfw%.*}.X/OH_${ohfw}.tar.gz
        ${DEBUG} ${DRYRUN} set +x
        echo "Untar and copy firmware files and xml address table to relevant locations"
        ${DEBUG} ${DRYRUN} set -x
        ${DRYRUN} tar xvf OH_${ohfw}.tar.gz
        ${DRYRUN} cp -rfp OH_${ohfw}/OH_${ohfw//_/-}.bit ${tmpcard}/oh_fw/optohybrid_${ohfw}.bit
        ${DRYRUN} cp -rfp OH_${ohfw}/oh_registers_${ohfw}.xml ${tmpcard}/xml/oh_registers_${ohfw}.xml
        ${DRYRUN} ln -sf optohybrid_${ohfw}.bit ${tmpcard}/oh_fw/optohybrid_top.bit
        ${DRYRUN} ln -sf oh_registers_${ohfw}.xml ${tmpcard}/xml/optohybrid_registers.xml
        ${DRYRUN} rm -rf OH_${ohfw}*

        ## Update the card
        ${DRYRUN} rsync -ach --progress --partial --links ${tmpcard}/{oh_fw,xml} \
                  root@${ctp7host}:${CARD_GEMDAQ_DIR}/

        ## Update the PC
        ${DRYRUN} cp -rfp ${tmpcard}/xml/{optohybrid_registers.xml,oh_registers_${ohfw}.xml} ${GEM_ADDRESS_TABLE_ROOT}/
        ${DEBUG} ${DRYRUN} set +x

        popd

        update_lmdb
    else
        echo "Invalid OptoHybrid firmware version specified (${ohfw})"
        echo "Valid versions usually look like X.Y.Z.C (GE1/1 long)"
        echo " or X.Y.Z.1C (GE1/1 short)"
        echo " or X.Y.Z.2A (GE2/1)"
        usage
    fi

    return 0
}

update_ctp7_fw() {

    local -r ctp7fw="$1"
    local -r ctp7fwre='^[3]\.[0-9]+\.[0-9]+$'

    declare -r AMC_FW_DOWNLOAD_DIR=https://github.com/cms-gem-daq-project/GEM_AMC/releases/download
    declare -r AMC_FW_RAW_DIR=https://raw.githubusercontent.com/cms-gem-daq-project/GEM_AMC

    if ! [[ "${ctp7fw}" =~ ${ctp7fwre} ]]
    then
        echo "Unsupported CTP7 FW version (${ctp7fw})"
        usage
    fi

    local -r fwbase="v${ctp7fw//./_}_${gesuf}${nlinks}oh"
    local -r fwfile="gem_ctp7_${fwbase}.bit"

    create_tmp_card

    pushd ${tmpcard}/fw
    echo "Downloading CTP7 firmware ${fwfile}"
    ${DEBUG} ${DRYRUN} set -x
    ${DRYRUN} curl -LO ${AMC_FW_DOWNLOAD_DIR}/v${ctp7fw}/${fwfile}
    ${DRYRUN} ln -sf ${fwfile} gem_ctp7.bit
    ${DEBUG} ${DRYRUN} set +x
    popd

    pushd ${tmpdir}

    echo "Downloading CTP7 address table address_table_${fwbase}.zip"
    ${DEBUG} ${DRYRUN} set -x
    ${DRYRUN} curl -LO ${AMC_FW_DOWNLOAD_DIR}/v${ctp7fw}/address_table_${fwbase}.zip
    ${DRYRUN} unzip address_table_${fwbase}.zip
    ${DRYRUN} rm address_table_${fwbase}.zip
    ${DRYRUN} cp -rfp address_table_${fwbase}/gem_amc_top_new_style.xml ${tmpcard}/xml/gem_amc_${fwbase}.xml
    ${DRYRUN} ln -sf gem_amc_${fwbase}.xml ${tmpcard}/xml/gem_amc_v${ctp7fw//./_}.xml
    ${DRYRUN} ln -sf gem_amc_v${ctp7fw//./_}.xml ${tmpcard}/xml/gem_amc_top.xml
    ${DRYRUN} ln -sf gem_amc_top.xml ${tmpcard}/xml/amc_address_table_top.xml
    ${DEBUG} ${DRYRUN} set +x

    pushd address_table_${fwbase}
    ${DRYRUN} rename .xml _${fwbase}.xml uhal*.xml
    for uh in $( ls uhal*.xml )
    do
        uhbase=${uh%%_v*}
        ${DRYRUN} ln -sf ${uh} ${uhbase}.xml
    done
    popd
    popd

    echo "Download gemloader scripts"
    pushd ${tmpcard}/gemloader
    declare -a gemloaderArray=(
        "gemloader_clear_header.sh"
        "gemloader_configure.sh"
        "gemloader_load_test_data.sh"
        "gemloader_read.sh"
    )
    for gemloaderFile in "${gemloaderArray[@]}"
    do
        ${DEBUG} ${DRYRUN} set -x
        ${DRYRUN} curl -LO ${AMC_FW_RAW_DIR}/v${ctp7fw}/scripts/gemloader/${gemloaderFile}
        ${DEBUG} ${DRYRUN} set +x
    done
    popd

    ## Update the card
    ${DRYRUN} rsync -ach --progress --partial --links ${tmpcard}/{fw,gemloader,xml} \
              root@${ctp7host}:${CARD_GEMDAQ_DIR}/

    ## Update the PC
    ${DRYRUN} cp -rfp ${tmpdir}/address_table_${fwbase}/uhal*.xml ${GEM_ADDRESS_TABLE_ROOT}/
    ${DRYRUN} cp -rfp ${tmpcard}/xml/*.xml ${GEM_ADDRESS_TABLE_ROOT}/

    update_lmdb

    return 0
}

update_ctp7_sw() {
    local -r GEMDAQ_DOWNLOAD_URL=https://cern.ch/cmsgemdaq/sw/gemos/repos/releases/legacy/base/tarballs

    echo "Creating/updating CTP7 gemdaq directory structure"
    create_tmp_card

    ${DEBUG} ${DRYRUN} set -x
    ${DRYRUN} ssh -tq root@${ctp7host} "echo Setting up ${CARD_GEMDAQ_DIR} && \
mkdir -p ${CARD_GEMDAQ_DIR} && \
mkdir -p ${CARD_GEMDAQ_DIR}/address_table.mdb && \
touch ${CARD_GEMDAQ_DIR}/address_table.mdb/data.mdb && \
touch ${CARD_GEMDAQ_DIR}/address_table.mdb/lock.mdb && \
chmod -R 777 ${CARD_GEMDAQ_DIR}/address_table.mdb"
    ${DEBUG} ${DRYRUN} set +x

    pushd scripts
    gesuf=${gesuf%*_}
    gesuf=${gesuf%%v*}
    ${DRYRUN} cp -rfp ${gesuf}/*.sh .
    popd

    ${DRYRUN} cp -rfp -t ${tmpcard} bin lib scripts
    ${DRYRUN}
    rm -rf ${tmpcard}/scripts/{ge11,ge21,me0}

    ${DRYRUN} find ${tmpcard} -type d -print0 -exec chmod a+rx {} \+ > /dev/null
    ${DRYRUN} find ${tmpcard} -type f -print0 -exec chmod a+r  {} \+ > /dev/null
    ${DRYRUN} find ${tmpcard}/bin -type f -print0 -exec chmod a+rx {} \+ > /dev/null
    ${DRYRUN} find ${tmpcard}/lib -type f -print0 -exec chmod a+rx {} \+ > /dev/null

    pushd ${tmpdir}

    ## Take latest versions
    tarballs=(
        ctp7-base.tgz     ## ipbus, liblmdb.so
        reedmuller.tgz    ## libreedmuller.so, rmencode, rmdecode
        rwreg.tgz         ## librwreg.so
        reg_interface.tgz ## reg_interface
        xhal.tgz          ## libxhal.so, reg_interface_gem
        ctp7_modules-${gesuf%%_*}.tgz
    )

    ${DEBUG} ${DRYRUN} set -x
    for tb in ${tarballs[@]}
    do
        if [[ "${tb}" =~ xhal ]]
        then
            ## Override if a specific version is specified
            if [ -n "${xhaltag}" ]
            then
                ${DRYRUN} curl -L ${GEMDAQ_DOWNLOAD_URL}/xhal/xhal-${xhaltag}.tgz -o xhal.tgz
            else
                ${DRYRUN} curl -LO ${GEMDAQ_DOWNLOAD_URL}/${tb%%.tgz*}/${tb}
            fi
        elif [[ "${tb}" =~ modules ]]
        then
            if [ -n "${ctp7modtag}" ]
            then
                ${DRYRUN} curl -L ${GEMDAQ_DOWNLOAD_URL}/ctp7_modules/ctp7_modules-${ctp7modtag}-${gesuf%%_*}.tgz -o ctp7_modules-${gesuf%%_*}.tgz
            else
                ${DRYRUN} curl -LO ${GEMDAQ_DOWNLOAD_URL}/ctp7_modules/${tb}
            fi
        else
            ${DRYRUN} curl -LO ${GEMDAQ_DOWNLOAD_URL}/${tb%%.tgz*}/${tb}
        fi
        ${DRYRUN} tar xzf ${tb}
        ${DRYRUN} rm -rf ${tb}
    done

    ${DEBUG} ${DRYRUN} set +x

    ## Obsolete?
    ${DEBUG} ${DRYRUN} set -x
    mkdir -p ${tmpcard}/vfat3
    ${DRYRUN} curl -L https://raw.githubusercontent.com/cms-gem-daq-project/ctp7_modules/release/legacy-1.1/conf/conf.txt \
              -o ${tmpcard}/vfat3/conf.txt
    ${DRYRUN} rsync -ach --progress --partial --links mnt root@${ctp7host}:/
    ${DRYRUN} rsync -ach --progress --partial --links ${tmpcard}/{fw,oh_fw,scripts,xml,gemloader,vfat3} \
              root@${ctp7host}:${CARD_GEMDAQ_DIR}/
    ${DEBUG} ${DRYRUN} set +x
    popd

    echo "Upload rpc modules and restart rpcsvc"
    ${DRYRUN} ssh -tq root@${ctp7host} 'killall rpcsvc'

    if check_gemuser
    then
        ${DRYRUN} ssh -tq gemuser@${ctp7host} 'rpcsvc'
    else
        echo "CTP7 gemuser account does not exist on ${ctp7host}"
        usage
    fi

    return 0
}

usage() {
    cat <<EOF
Usage: $0 [options] <CTP7 hostname>
  Options:
    -o Update OptoHybrid FW to specified version (version 3.X.Y supported)
    -c Update CTP7 FW to specified version (version 3.X.Y supported)
    -g GE generation options are:
           1 for GE1/1 (default)
           2 (alias for 22
           21 for GE2/1 V1 OptoHybrid
           22 for GE2/1 V2 OptoHybrid
           0 for ME0.
    -l Number of OH links supported in the CTP7 FW (optional, if not specified defaults to 12)
    -a Create the gemuser CTP7 user account
    -u Update CTP7 libs/bins/fw images
    -k Keep downloaded artifacts
    -n Do a dry run (don't execute any commands)
    -d Increase debugging information
    -x XHAL SW release version (optional, if not specified, will select latest)
    -m CTP7 modules SW release version (optional, if not specified, will select latest)

Plese report bugs to
  https://github.com/cms-gem-daq-project/gemctp7user
EOF

    # kill -INT $$
    exit 1
}

setup_ctp7() {

    if ! ping -q -c 1 ${ctp7host}
    then
        echo "Unable to ping host ${ctp7host}"
        usage
    fi

    echo "Proceeding..."

    create_tmp_card

    if [ -n "${ohfw}" ]
    then
        update_oh_fw "${ohfw}"
    fi

    get_gem_generation

    if ! [ -n "${nlinks}" ]
    then
        echo "Assuming nlinks=12"
        nlinks=12
    fi

    if [ -n "${ctp7fw}" ]
    then
        update_ctp7_fw "${ctp7fw}"
    fi

    if [ -n "${gemuser}" ]
    then
        create_gemuser
    fi

    # Update CTP7 gemdaq paths
    if [ -n "${update}" ]
    then
        update_ctp7_sw
    fi

    return 0
}

## Option defaults
declare ctp7fw=
declare ge_gen=
declare nlinks=
declare ohfw=
declare gemuser=
declare update=
declare xhaltag=
declare ctp7modtag=
declare KEEP_ARTIFACTS=
declare DRYRUN=
declare DEBUG=:

while getopts "ac:g:l:o:x:ukdnh" opts
do
    case $opts in
        c)
            ctp7fw="$OPTARG";;
        g)
            ge_gen="$OPTARG";;
        l)
            nlinks="$OPTARG";;
        o)
            ohfw="$OPTARG";;
        a)
            gemuser="1";;
        u)
            update="1";;
        x)
            xhaltag="$OPTARG";;
        m)
            ctp7modtag="$OPTARG";;
        k)
            KEEP_ARTIFACTS="1";;
        d)
            DEBUG= ;;
        n)
            DRYRUN=echo;;
        h)
            usage;;
        \?)
            usage;;
        [?])
            usage;;
    esac
done

shift $((OPTIND-1))

declare ctp7host="$1"

(setup_ctp7)
