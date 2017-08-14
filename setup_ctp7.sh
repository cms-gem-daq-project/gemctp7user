#!/bin/sh

helpstring="Usage: $0 [-o OptoHybrid fw version] [-c CTP7 fw version] [-a CTP7 user account to create] [-u Update CTP7 libs/bins/fw images] CTP7 hostname"

while getopts "a:c:o:uh" opts
do
    case $opts in
        c)
            ctp7fw="$OPTARG";;
        o)
            ohfw="$OPTARG";;
        a)
            newuser="$OPTARG";;
        u)
            update="1";;
        h)
            echo >&2 ${helpstring}
            exit 1;;
        \?)
            echo >&2 ${helpstring}
            exit 1;;
        [?])
            echo >&2 ${helpstring}
            exit 1;;
    esac
done

shift $((OPTIND-1))

ctp7host=${1}

ping -q -c 1 ${ctp7host} >& /dev/null
ctp7up=$?
if [ $ctp7up != 0 ]
then
    echo "Unable to ping host ${ctp7host}"
    exit
fi

# create local links if requested
if [ -n "${ohfw}" ]
then
    # echo "creating links for OH firmware version: ${ohfw}"
    if [ ! -f "oh_fw/optohybrid_${ohfw}.bit" ]
    then
        echo "OH firmware oh_fw/optohybrid_${ohfw}.bit downloading"
        echo "wget https://github.com/thomaslenzi/OptoHybridv2/releases/download/${ohfw}/OH_${ohfw//./_}_GBT.bit -O oh_fw/optohybrid_${ohfw}.bit"
        wget https://github.com/thomaslenzi/OptoHybridv2/releases/download/${ohfw}/OH_${ohfw//./_}_GBT.bit -O oh_fw/optohybrid_${ohfw}.bit
    fi
    echo "ln -sf optohybrid_${ohfw}.bit oh_fw/optohybrid_top.bit"
    ln -sf optohybrid_${ohfw}.bit oh_fw/optohybrid_top.bit

    if [ ! -f "oh_fw/optohybrid_${ohfw}.mcs" ]
    then
        echo "OH firmware oh_fw/optohybrid_${ohfw}.mcs missing, downloading"
        echo "wget https://github.com/thomaslenzi/OptoHybridv2/releases/download/${ohfw}/OH_${ohfw//./_}_GBT.mcs -O oh_fw/optohybrid_${ohfw}.mcs"
        wget https://github.com/thomaslenzi/OptoHybridv2/releases/download/${ohfw}/OH_${ohfw//./_}_GBT.mcs -O oh_fw/optohybrid_${ohfw}.mcs
    fi

    echo "ln -sf optohybrid_${ohfw}.mcs oh_fw/optohybrid_top.mcs"
    ln -sf optohybrid_${ohfw}.mcs oh_fw/optohybrid_top.mcs
fi

if [ -n "${ctp7fw}" ]
then
    # echo "creating links for CTP7 firmware version: ${ctpfw}"
    if [ ! -f "fw/gem_ctp7_gem_ctp7_v${ctp7fw//./_}_GBT.bit" ]
    then
        echo "CTP7 firmware fw/gem_ctp7_v${ctp7fw//./_}_GBT.bit missing, downloading"
        echo "wget https://github.com/evka85/GEM_AMC/releases/download/v${ctp7fw}/gem_ctp7_v${ctp7fw//./_}_GBT.bit -O fw/gem_ctp7_v${ctp7fw//./_}_GBT.bit"
        wget https://github.com/evka85/GEM_AMC/releases/download/v${ctp7fw}/gem_ctp7_v${ctp7fw//./_}_GBT.bit -O fw/gem_ctp7_v${ctp7fw//./_}_GBT.bit
    fi

    echo "ln -sf gem_ctp7_v${ctp7fw//./_}_GBT.bit fw/gem_ctp7.bit"
    ln -sf gem_ctp7_v${ctp7fw//./_}_GBT.bit fw/gem_ctp7.bit

    if [ ! -f "xml/gem_amc_top_${ctp7fw//./_}.xml" ]
    then
        echo "CTP7 firmware xml/gem_amc_top_${ctp7fw//./_}.xml missing, downloading"
        echo "wget https://github.com/evka85/GEM_AMC/releases/download/v${ctp7fw}/address_table_v${ctp7fw//./_}_GBT.zip"
        wget https://github.com/evka85/GEM_AMC/releases/download/v${ctp7fw}/address_table_v${ctp7fw//./_}_GBT.zip
        echo "unzip address_table_v${ctp7fw//./_}_GBT.zip"
        unzip address_table_v${ctp7fw//./_}_GBT.zip
        echo "cp address_table_v${ctp7fw//./_}_GBT/gem_amc_top.xml xml/gem_amc_v${ctp7fw//./_}.xml"
        cp address_table_v${ctp7fw//./_}_GBT/gem_amc_top.xml xml/gem_amc_v${ctp7fw//./_}.xml
        echo "rm -rf address_table_v${ctp7fw//./_}_GBT"
        rm -rf address_table_v${ctp7fw//./_}_GBT
    fi

    echo "ln -sf gem_amc_top_${ctp7fw//./_}.xml xml/gem_amc_top.xml"
    ln -sf gem_amc_top_${ctp7fw//./_}.xml xml/gem_amc_top.xml
fi

# create new CTP7 user if requested
if [ -n "${newuser}" ]
then
    read -p "Create CTP7 user account: ${newuser} (y|n) : " create
    while true
    do
        case $create in
            [yY]* )
                echo "ssh root@${ctp7host} /usr/sbin/adduser ${newuser} -h /mnt/persistent/${newuser}";
                ssh root@${ctp7host} /usr/sbin/adduser ${newuser} -h /mnt/persistent/${newuser};
                echo "rsync -aXch --progress --partial --links .profile .bashrc .viminfo .vimrc .inputrc ${newuser}@${ctp7host}:~/";
                rsync -aXch --progress --partial --links .profile .bashrc .viminfo .vimrc .inputrc ${newuser}@${ctp7host}:~/;
                break;;
            [nN]* )
                break;;
            * )
                echo "Enter y or n (case insensitive)";;
        esac
    done
fi

# Update CTP7 gemdaq paths
if [ -n "${update}" ]
then
    echo "Creating/updating CTP7 gemdaq directory structure"
    echo "ssh root@${ctp7host} mkdir -p /mnt/persistent/gemdaq"
    ssh root@${ctp7host} mkdir -p /mnt/persistent/gemdaq

    echo "Fetching binaries and libraries"
    echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/ipbus -O bin/ipbus"
    wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/ipbus -O bin/ipbus

    echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/liblog4cplus.so  -O lib/liblog4cplus.so"
    wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/liblog4cplus.so  -O lib/liblog4cplus.so
    echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/libxhal_ctp7.so  -O lib/libxhal_ctp7.so"
    wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/libxhal_ctp7.so  -O lib/libxhal_ctp7.so
    echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/libxerces-c.so   -O lib/libxerces-c.so"
    wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/libxerces-c.so   -O lib/libxerces-c.so
    echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/librwreg_ctp7.so -O lib/librwreg_ctp7.so"
    wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/librwreg_ctp7.so -O lib/librwreg_ctp7.so
    echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/liblmdb.so       -O lib/liblmdb.so"
    wget https://github.com/cms-gem-daq-project/xhal/releases/download/v2.0.0/liblmdb.so       -O lib/liblmdb.so

    echo "ln -sf librwreg_ctp7.so lib/librwreg.so"
    ln -sf librwreg_ctp7.so lib/librwreg.so
    echo "ln -sf libxerces-c.so lib/libxerces-c-3.1.so"
    ln -sf libxerces-c.so lib/libxerces-c-3.1.so
    echo "ln -sf liblog4cplus.so lib/libxerces-c-3.1.so"
    ln -sf liblog4cplus.so lib/liblog4cplus-1.1.so.9

    echo "wget https://github.com/cms-gem-daq-project/xhal/files/1071017/reg_interface.zip && unzip reg_interface.zip && rm reg_interface.zip"
    wget https://github.com/cms-gem-daq-project/xhal/files/1071017/reg_interface.zip
    unzip reg_interface.zip -d python/
    rm reg_interface.zip

    echo "rsync -ach --progress --partial --links bin fw lib oh_fw scripts xml python root@${ctp7host}:/mnt/persistent/gemdaq/"
    rsync -ach --progress --partial --links bin fw lib oh_fw scripts xml python root@${ctp7host}:/mnt/persistent/gemdaq/
    echo "Clearing folders"
    rm ./bin/*
    rm ./lib/*
    rm ./fw/*
    rm ./oh_fw/*
    rm ./python/reg_interface/*
    rm ./xml/*
fi
