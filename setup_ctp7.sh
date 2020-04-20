#!/bin/sh

usage() {

    echo "Usage: $0 [options] <CTP7 hostname>"
    echo "  Options:"
    echo "    -o OptoHybrid fw version (version 3.X.Y supported)"
    echo "    -c CTP7 fw version (version 3.X.Y supported"
    echo "    -g GE generation, defaults to GE1/1"
    echo "         options are:"
    echo "           1 for GE1/1"
    echo "           2 (alias for 22"
    echo "           21 for GE2/1 V1 OptoHybrid"
    echo "           22 for GE2/1 V2 OptoHybrid"
    echo "           0 for ME0. "
    echo "    -l Number of OH links supported in the CTP7 fw"
    echo "    -x XHAL SW release version (optional, if not specified, will select latest)"
    echo "    -m CTP7 modules SW release version (optional, if not specified, will select latest)"
    echo "    -a Create the gemuser CTP7 user account"
    echo "    -u Update CTP7 libs/bins/fw images"
    echo ""
    echo "Plese report bugs to"
    echo "https://github.com/cms-gem-daq-project/gemctp7user"

    kill -INT $$
}

while getopts "ac:g:l:o:x:uh" opts
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
        h)
            usage;;
        \?)
            usage;;
        [?])
            usage;;
    esac
done

shift $((OPTIND-1))

ctp7host=${1}

ping -q -c 1 ${ctp7host} >& /dev/null

if [ "$?" != "0" ]
then
    echo "Unable to ping host ${ctp7host}"
    usage
fi

GEM_FW_DIR=/opt/gemdaq/fw
GEM_ADDRESS_TABLE_ROOT=/opt/cmsgemos/etc/maps
XHAL_ROOT=/opt/xhal

echo "Proceeding..."
# create local links if requested
if [ -n "${ohfw}" ]
then
    OH_FW_DOWNLOAD_DIR=https://github.com/cms-gem-daq-project/OptoHybridv3/releases/download
    echo "Creating links for OH firmware version: ${ohfw}"
    ohfwre='^[3]\.[0-9]+\.[0-9]+\.(1C|C|2A)$'
    if [[ ${ohfw} =~ ${ohfwre} ]]
    then
        echo "Downloading V3 firmware with tag ${ohfw}"
        set -x
        curl -L -O ${OH_FW_DOWNLOAD_DIR}/${ohfw%.*}.X/OH_${ohfw}.tar.gz
        set +x
        echo "Untar and copy firmware files and xml address table to relevant locations"
        set -x
        tar xvf OH_${ohfw}.tar.gz
        cp -rfp OH_${ohfw}/OH_${ohfw//_/-}.bit oh_fw/optohybrid_${ohfw}.bit
        cp -rfp OH_${ohfw}/oh_registers_${ohfw}.xml xml/oh_registers_${ohfw}.xml
        ln -sf optohybrid_${ohfw}.bit oh_fw/optohybrid_top.bit
        ln -sf oh_registers_${ohfw}.xml xml/optohybrid_registers.xml
        rm -rf OH_${ohfw}*
        set +x
    else
        echo "Invalid OptoHybrid firmware version specified (${ohfw})"
        echo "Valid versions usually look like X.Y.Z.C (GE1/1 long)"
        echo " or X.Y.Z.1C (GE1/1 short)"
        echo " or X.Y.Z.2A (GE2/1)"
        usage
    fi
fi

set -x
if [ -n "${ge_gen}" ]
then
    genre='^([01]|(2[12]?))$'
    if ! [[ "${ge_gen}" =~ ${genre} ]]
    then
        echo "Invalid GEM generation specified ${ge_gen}"
        usage
    fi
    if [[ ${ge_gen} = "21" ]]
    then
        echo "Using GE2/1 OHv1"
        gesuf="ge21v1_"
    elif [[ ${ge_gen} =~ "2" ]]
    then
        echo "Using GE2/1 OHv2"
        gesuf="ge21v2_"
    elif [[ ${ge_gen} = "0" ]]
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
set +x

if ! [ -n "${nlinks}" ]
then
    echo "Assuming nlinks=12"
    nlinks=12
fi

if [ -n "${ctp7fw}" ]
then
    AMC_FW_DOWNLOAD_DIR=https://github.com/cms-gem-daq-project/GEM_AMC/releases/download
    AMC_FW_RAW_DIR=https://raw.githubusercontent.com/cms-gem-daq-project/GEM_AMC

    ctp7fwre='^[3]\.[0-9]+\.[0-9]+$'
    if ! [[ ${ctp7fw} =~ ${ctp7fwre} ]]
    then
        echo "Unsupported CTP7 FW version (${ctp7fw})"
        usage
    fi

    fwbase="v${ctp7fw//./_}_${gesuf}${nlinks}oh"
    fwfile="gem_ctp7_${fwbase}.bit"
    pushd fw
    if [ ! -f "${fwfile}" ]
    then
        echo "CTP7 firmware fw/${fwfile} missing, downloading"
        set -x
        curl -L -O ${AMC_FW_DOWNLOAD_DIR}/v${ctp7fw}/${fwfile}
        set +x
    fi
    set -x
    ln -sf ${fwfile} gem_ctp7.bit
    set +x
    popd

    pushd xml
    if [ ! -f "xml/gem_amc_top_${ctp7fw//./_}.xml" ]
    then
        echo "CTP7 firmware xml/gem_amc_top_${ctp7fw//./_}.xml missing, downloading"
        set -x
        curl -L -O ${AMC_FW_DOWNLOAD_DIR}/v${ctp7fw}/address_table_${fwbase}.zip
        unzip address_table_${fwbase}.zip
        rm address_table_${fwbase}.zip
        cp -rfp address_table_${fwbase}/gem_amc_top.xml gem_amc_v${ctp7fw//./_}.xml
        rm -rf address_table_${fwbase}
        set +x
    fi

    set -x
    ln -sf gem_amc_v${ctp7fw//./_}.xml gem_amc_top.xml
    set +x
    popd

    echo "Download gemloader"
    mkdir -p gemloader

    declare -a gemloaderArray=(
        "gemloader_clear_header.sh"
        "gemloader_configure.sh"
        "gemloader_load_test_data.sh"
        "gemloader_read.sh"
    )
    pushd gemloader
    for gemloaderFile in "${gemloaderArray[@]}"
    do
        set -x
        curl -L -O ${AMC_FW_RAW_DIR}/v${ctp7fw}/scripts/gemloader/${gemloaderFile}
        set +x
    done
    popd
fi

# create new CTP7 user if requested and gemuser doesn't exist
if [ -n "${gemuser}" ]
then
    ssh -t root@${ctp7host} cat /etc/passwd|egrep gemuser >/dev/null
    if ! [ "$?" = "0" ]
    then
        read -p "Create CTP7 user account: gemuser (y|n) : " create
        while true
        do
            case $create in
                [yY]* )
                    set -x
                    ssh root@${ctp7host} '/usr/sbin/adduser gemuser -h /mnt/persistent/gemuser && /bin/save_passwd'
                    ssh gemuser@${ctp7host} 'mkdir -p ~/logs'
                    rsync -aXch --progress --partial --links .profile .bashrc .vimrc .inputrc gemuser@${ctp7host}:~/
                    set +x
                    break;;
                [nN]* )
                    break;;
                * )
                    echo "Enter y or n (case insensitive)";;
            esac
        done
    else
        echo "CTP7 user gemuser already exists"
    fi
fi

# Update CTP7 gemdaq paths
CARD_GEMDAQ_DIR=/mnt/persistent/gemdaq
GEMDAQ_DOWNLOAD_URL=https://cern.ch/cmsgemdaq/sw/gemos/repos/releases/legacy/base/tarballs
if [ -n "${update}" ]
then
    echo "Creating/updating CTP7 gemdaq directory structure"
    set -x
    ssh root@${ctp7host} "echo Setting up  ${CARD_GEMDAQ_DIR} && \
mkdir -p ${CARD_GEMDAQ_DIR} && \
mkdir -p ${CARD_GEMDAQ_DIR}/address_table.mdb && \
touch ${CARD_GEMDAQ_DIR}/address_table.mdb/data.mdb && \
touch ${CARD_GEMDAQ_DIR}/address_table.mdb/lock.mdb && \
chmod -R 777 ${CARD_GEMDAQ_DIR}/address_table.mdb"
    set +x

    mkdir -p ${ctp7host}
    pushd scripts
    gesuf=${gesuf%*_}
    gesuf=${gesuf%%v*}
    cp -rfp ${gesuf}/*.sh .
    popd

    cp -rfp -t ${ctp7host} bin lib fw oh_fw gemloader scripts xml

    pushd ${ctp7host}
    find . -type d -print0 -exec chmod a+rx {} \+
    find . -type f -print0 -exec chmod a+r  {} \+
    find bin -type f -print0 -exec chmod a+rx {} \+
    find lib -type f -print0 -exec chmod a+rx {} \+

    ## Take latest versions
    tarballs=(
        ctp7-base.tgz     ## ipbus, liblmdb.so
        reedmuller.tgz    ## libreedmuller.so, rmencode, rmdecode
        rwreg.tgz         ## librwreg.so
        reg_interface.tgz ## reg_interface
        xhal.tgz          ## libxhal.so, reg_interface_gem
        # ctp7_modules_${gesuf}.tgz  ## ctp7 RPC modules FIXME
        ctp7_modules.tgz  ## ctp7 RPC modules
    )
    set -x
    for tb in ${tarballs[@]}
    do
        curl -L -O ${GEMDAQ_DOWNLOAD_URL}/${tb}
        tar xzf ${tb}
        rm -rf ${tb}
    done

    ## Override if a specific version is specified
    if [ -n "${xhaltag}" ]
    then
        curl -L ${GEMDAQ_DOWNLOAD_URL}/xhal-${xhaltag}.tgz -o xhal.tgz
        tar xzf xhal.tgz
        rm -rf xhal.zip
    fi

    if [ -n "${ctp7modtag}" ]
    then
        # curl -L ${GEMDAQ_DOWNLOAD_URL}/ctp7_modules-${ctp7modtag}_${gesuf}.tgz -o ctp7_modules.tgz ## FIXME
        curl -L ${GEMDAQ_DOWNLOAD_URL}/ctp7_modules-${ctp7modtag}.tgz -o ctp7_modules.tgz
        tar xzf ctp7_modules.tgz
        rm -rf ctp7_modules.tgz
    fi
    set +x

    ## Obsolete?
    set -x
    mkdir -p vfat3
    curl -L https://raw.githubusercontent.com/cms-gem-daq-project/ctp7_modules/release/legacy-1.1/conf/conf.txt \
         -o vfat3/conf.txt
    rsync -ach --progress --partial --links mnt root@${ctp7host}:/
    rsync -ach --progress --partial --links fw oh_fw scripts xml gemloader vfat3 \
         root@${ctp7host}:${CARD_GEMDAQ_DIR}/
    set +x

    echo "Update LMDB address table on the CTP7, make a new .pickle file and resync xml folder"
    set -x
    echo cp -rfp xml/* ${GEM_ADDRESS_TABLE_ROOT}/
    set +x

    echo "Upload rpc modules and restart rpcsvc"
    ssh root@${ctp7host} 'killall rpcsvc'
    ssh -t root@${ctp7host} cat /etc/passwd|egrep gemuser >/dev/null
    if [ "$?" = "0" ]
    then
        ssh -t gemuser@${ctp7host} 'rpcsvc'
    else
        echo "CTP7 gemuser account does not exist on ${ctp7host}"
        usage
    fi

    pushd xml
    set -x
    python ${XHAL_ROOT}/bin/gem_reg.py -n ${ctp7host} \
           -e update_lmdb ${CARD_GEMDAQ_DIR}/xml/gem_amc_top.xml
    cp -rfp ${GEM_ADDRESS_TABLE_ROOT}/amc_address_table_top.pickle gem_amc_top_v${ctp7fw//./_}.pickle
    ln -sf gem_amc_v${ctp7fw//./_}.pickle gem_amc_top.pickle
    set +x
    popd
    rsync -ach --progress --partial --links xml root@${ctp7host}:${CARD_GEMDAQ_DIR}/

    echo "Cleaning local temp folders"
    popd
    echo rm ${ctp7host}
    echo rm ./bin/*
    echo rm ./vfat3/*
    echo rm ./lib/*
    echo rm ./fw/*
    echo rm ./oh_fw/*
    echo rm ./xml/*
    echo rm -rf ./mnt
    echo rm -rf ./gemloader
fi
