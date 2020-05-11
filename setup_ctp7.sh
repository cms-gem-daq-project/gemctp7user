#!/bin/sh

## @file setup_ctp7.sh
## @author CMS GEM DAQ Project <gemdaq@cern.ch>
## @copyright MIT
## @version 1.0
## @brief Script to facilitate the setup of new CTP7s, or update SW/FW on a CTP7
## @details
## @par Usage
## See setup_ctp7.sh -h

set -o pipefail

### Globals
## @var CARD_GEMDAQ_DIR
## @brief location of @c gemdaq directory on CTP7
declare -r CARD_GEMDAQ_DIR=/mnt/persistent/gemdaq

## @var GEM_FW_DIR
## @brief location of FW files on PC
## @details If not set in the calling shell, use the default
##   Path to local storage of bitfiles and xml files for each FW version
##   Useful?
export GEM_FW_DIR=${GEM_FW_DIR:=/opt/gemdaq/fw}

## @var GEM_ADDRESS_TABLE_PATH
## @brief location of XML address table files on PC
## @details If not set in the calling shell, use the default
export GEM_ADDRESS_TABLE_PATH=${GEM_ADDRESS_TABLE_PATH:=/opt/cmsgemos/etc/maps}

## @var XHAL_ROOT
## @brief location of XHAL package on PC
## @details If not set in the calling shell, use the default
export XHAL_ROOT=${XHAL_ROOT:=/opt/xhal}

## @var tmpdir
## @brief location of temporary files
## @details variable is set in @ref create_tmp_card
declare tmpdir=

## @var tmpcard
## @brief location of @ref CARD_GEMDAQ_DIR inside the local @ref tmpdir
## @details variable is set in @ref create_tmp_card
declare tmpcard=

## @var gesuf
## @brief GEM station specific suffix for downloaded artifacts
declare gesuf=

## @fn create_tmp_card()
## @brief Creates a temporary directory to emulate CTP7 filesystem
## @details All artifacts to be pushed to a CTP7 are copied into this directory,
##   which has the same structure as the CTP7 filesystem
##   Upon completion or error, this temporary directory is removed in @ref cleanup_ctp7
##   unless the @c KEEP_ARTIFACTS flag is set
create_tmp_card() {

    if ! [ -n "${tmpcard}" ] || ! [ -d  "${tmpcard}" ]
    then
        echo "Downloading artifacts to ${tmpdir}"
        # Create a local temp structure for the artifacts
        tmpdir=$(mktemp -d /tmp/tmp.XXXXXX)

        # Create a local tree to mimic the card tree structure
        tmpcard=${tmpdir}${CARD_GEMDAQ_DIR}
        mkdir -p ${tmpcard}/{fw,oh_fw,scripts,xml,gemloader,vfat3}
    else
        echo "Temp area already exists at ${tmpdir}"
    fi

    return 0
}

## @fn cleanup_ctp7()
## @brief Remove all temporary artifacts created during execution
## @details Called in @c trap on
##
## @li @c EXIT
## @li @c SIGQUIT
## @li @c SIGINT
## @li @c SIGTERM
## @li @c SIGSEGV
cleanup_ctp7() {

    if ! [ -n "${KEEP_ARTIFACTS}" ] && [ -n "${tmpdir}" ]
    then
        echo "Cleaning up ${tmpdir}"
        rm -rf ${tmpdir}
    else
        echo "Not removing ${tmpdir}, make sure to clean up after yourself!"
    fi

}

trap cleanup_ctp7 EXIT SIGQUIT SIGINT SIGTERM SIGSEGV

## @fn update_lmdb()
## @brief Updates the LMDB on the CTP7 following update of FW
## @details Called if either @ref update_oh_fw or @ref update_ctp7_fw have been called
update_lmdb() {

    echo "Update LMDB address table on the CTP7, make a new .pickle file and resync xml folder"
    pushd ${tmpcard}/xml

    ${DEBUG} ${DRYRUN} set -x
    ${DRYRUN} rm -rf ${GEM_ADDRESS_TABLE_PATH}/amc_address_table_top.pickle
    ${DRYRUN} python ${XHAL_ROOT}/bin/gem_reg.py -n ${ctp7host} \
           -e update_lmdb ${CARD_GEMDAQ_DIR}/xml/gem_amc_top.xml
    ${DRYRUN} cp -rfp ${GEM_ADDRESS_TABLE_PATH}/amc_address_table_top.pickle gem_amc_top_v${ctp7fw//./_}.pickle
    ${DRYRUN} perl -pi -e 's|creg_utils.reg_interface.common.reg_xml_parser|crw_reg|g' gem_amc_top_v${ctp7fw//./_}.pickle
    ${DRYRUN} ln -sf gem_amc_v${ctp7fw//./_}.pickle gem_amc_top.pickle
    ${DEBUG} ${DRYRUN} set +x

    # Partially update card
    ${DRYRUN} rsync -ach --progress --partial --links ${tmpcard}/xml root@${ctp7host}:${CARD_GEMDAQ_DIR}/

    echo "New pickle file has been copied to the CTP7, make sure you modify it correctly"

    popd

    return 0
}

## @fn get_gem_generation()
## @brief Determines the appropriate suffix for downloading, depending on the GEM station
## @details Valid options are:
## @li @c 1 for GE1/1 (default)
## @li @c 2 (alias for @c 22
## @li @c 21 for GE2/1 V1 OptoHybrid
## @li @c 22 for GE2/1 V2 OptoHybrid
## @li @c 0 for ME0
get_gem_generation() {
    export ge_gen=${ge_gen:="$1"}
    ${DEBUG} echo ${ge_gen}

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

## @fn check_gemuser()
## @brief Checks if the @c gemuser account is present on the CTP7
## @details
check_gemuser() {
    ${DRYRUN} ssh -tq root@${ctp7host} cat /etc/passwd|egrep gemuser >/dev/null
}

## @fn create_gemuser()
## @brief Creates the @c gemuser account on the CTP7 and performs minimal user account setup
## @details
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

## @fn update_oh_fw()
## @brief Obtains the specified OptoHybrid firmware version and performs the update
## @details This function determines the artifact name and location
##
## @li unpacks the address table file and bitfile
## @li creates expected symlinks
## @li copies the files to the @ref tmpcard
## @li copies the address table file to the @c GEM_ADDRESS_TABLE_PATH on the PC
## @li pushes the files in @ref tmpcard to the CTP7
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

        # Update the card
        ${DRYRUN} rsync -ach --progress --partial --links ${tmpcard}/{oh_fw,xml} \
                  root@${ctp7host}:${CARD_GEMDAQ_DIR}/

        # Update the PC
        ${DRYRUN} cp -rfp ${tmpcard}/xml/{optohybrid_registers.xml,oh_registers_${ohfw}.xml} ${GEM_ADDRESS_TABLE_PATH}/
        ${DEBUG} ${DRYRUN} set +x

        popd
    else
        echo "Invalid OptoHybrid firmware version specified (${ohfw})"
        echo "Valid versions usually look like X.Y.Z.C (GE1/1 long)"
        echo " or X.Y.Z.1C (GE1/1 short)"
        echo " or X.Y.Z.2A (GE2/1)"
        usage
    fi

    return 0
}

## @fn update_ctp7_fw()
## @brief Obtains the specified CTP7 firmware version and performs the update
## @details This function determines the artifact name and location
##
## @li unpacks the address table file and bitfile
## @li creates expected symlinks
## @li copies the files to the @c tmpcard
## @li copies the address table file to the @c GEM_ADDRESS_TABLE_PATH on the PC
## @li pushes the files in @c tmpcard to the CTP7
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

    # Update the card
    ${DRYRUN} rsync -ach --progress --partial --links ${tmpcard}/{fw,gemloader,xml} \
              root@${ctp7host}:${CARD_GEMDAQ_DIR}/

    # Update the PC
    ${DRYRUN} cp -rfp ${tmpdir}/address_table_${fwbase}/uhal*.xml ${GEM_ADDRESS_TABLE_PATH}/
    ${DRYRUN} cp -rfp ${tmpcard}/xml/*.xml ${GEM_ADDRESS_TABLE_PATH}/

    return 0
}

## @fn update_ctp7_sw()
## @brief Obtains the latest (or specified) versions of all SW artfacts for the CTP7
## @details This function
##
## @li determines the artifact names and locations
## @li downloads the tarballs
## @li unpacks the shared library files
## @li copies the files to the @c tmpcard
## @li pushes the files in @c tmpcard to the CTP7
##
## The packages taken include:
##
## @li @c ctp7-base.tgz : including @c ipbus, @c liblmdb.so
## @li @c reedmuller.tgz : including @c libreedmuller.so, @c rmencode, @c rmdecode
## @li @c rwreg.tgz : including @c librwreg.so
## @li @c reg_interface.tgz : including @c reg_interface
## @li @c xhal.tgz : including @c libxhal.so, @c reg_interface_gem
## @li @c ctp7_modules-${gesuf\%\%_*}\.tgz : including all CTP7 modules libraries for the specified GEM generation
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

    # Take latest versions
    tarballs=(
        ctp7-base.tgz
        reedmuller.tgz
        rwreg.tgz
        reg_interface.tgz
        xhal.tgz
        ctp7_modules-${gesuf%%_*}.tgz
    )

    ${DEBUG} ${DRYRUN} set -x
    for tb in ${tarballs[@]}
    do
        if [[ "${tb}" =~ xhal ]]
        then
            # Override if a specific version is specified
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

    # Obsolete?
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
        ${DRYRUN} ssh -tq gemuser@${ctp7host} sh -lic 'rpcsvc'
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
    -g GEM station/generation options are:
           1 for GE1/1 (default)
           2 (alias for 22
           21 for GE2/1 V1 OptoHybrid
           22 for GE2/1 V2 OptoHybrid
           0 for ME0
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

## @fn setup_ctp7()
## @brief Main entrypoint
## @details The available flags are:
##
## @li @c -o Update OptoHybrid FW to specified version (version 3.X.Y supported)
## @li @c -c Update CTP7 FW to specified version (version 3.X.Y supported)
## @li @c -g GEM station/generation options are:
##          - @c 1 for GE1/1 (default)
##          - @c 2 (alias for @c 22
##          - @c 21 for GE2/1 V1 OptoHybrid
##          - @c 22 for GE2/1 V2 OptoHybrid
##          - @c 0 for ME0
## @li @c -l Number of OH links supported in the CTP7 FW (optional, if not specified defaults to 12)
## @li @c -a Create the gemuser CTP7 user account
## @li @c -u Update CTP7 libs/bins/fw images
## @li @c -k Keep downloaded artifacts
## @li @c -n Do a dry run (don't execute any commands)
## @li @c -d Increase debugging information
## @li @c -x XHAL SW release version (optional, if not specified, will select latest)
## @li @c -m CTP7 modules SW release version (optional, if not specified, will select latest)
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

    if [ -n "${ctp7fw}" ] ||  [ -n "${ohfw}" ]
    then
        update_lmdb
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

#### Option defaults
## @var ctp7fw
## @brief Update the CTP7 firmware to the specified version, script option @c -c
declare ctp7fw=

## @var ge_gen
## @brief GEM station/generation specifier, script option @c -g
declare ge_gen=

## @var nlinks
## @brief Number of OptoHybrid links to support, script option @c -n (default is 12)
declare nlinks=

## @var ohfw
## @brief Update the OptoHybrid firmware to the specified version, script option @c -o
declare ohfw=

## @var gemuser
## @brief create the @c gemuser account on the CTP7,script option @c -a
declare gemuser=

## @var update
## @brief Perform an update of the SW libraries on the CTP7, script option @c -u
declare update=

## @var xhaltag
## @brief Version number of @c xhal package, script option @c -x (default is latest)
declare xhaltag=

## @var ctp7modtag
## @brief Version number of CTP7 modules, script option @c -m (default is latest)
declare ctp7modtag=

## @var KEEP_ARTIFACTS
## @brief Keep downloaded artifacts and card temp directory after execution, script option @c -k
declare KEEP_ARTIFACTS=

## @var DRYRUN
## @brief Perform a dry run, i.e., don't execute any operations, script option @c -n
## @details If set, script will @c echo the corresponding commands
declare DRYRUN=

## @var DEBUG
## @brief Flag to increase debugging output, script option @c -d
declare DEBUG=:

# Parse the options
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

## @var ctp7host
## @brief hostname of the CTP7 to operate on, @c $1 after processing options
declare -r ctp7host="$1"

# Call the actual setup script
(setup_ctp7)
