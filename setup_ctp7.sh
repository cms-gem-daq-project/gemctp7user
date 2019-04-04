#!/bin/sh

helpstring="Usage: $0 [options] <CTP7 hostname>
  Options:
    -o OptoHybrid fw version
    -c CTP7 fw version
    -g GE generation (1 for Ge1/1, 2 for GE2/1, optional. Defaults to GE1/1)
    -l Number of OH links supported in the CTP7 fw
    -x XHAL release version
    -a CTP7 user account to create
    -u Update CTP7 libs/bins/fw images

Plese report bugs to
https://github.com/cms-gem-daq-project/gemctp7user"

if [ -z "$XHAL_ROOT" ]
then
    echo "XHAL_ROOT is not set, please get the correct tag of XHAL code and source the setup.sh there. Exiting..."
    exit
fi

if [ -z "$CTP7_MOD_ROOT" ]
then
    echo "CTP7_MOD_ROOT is not set, please get the correct tag of ctp7_modules code and source the setup.sh there. Exiting..."
    exit
fi

while getopts "a:c:g:l:o:x:uh" opts
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
            newuser="$OPTARG";;
        u)
            update="1";;
        x)
            xhaltag="$OPTARG";;
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
fi

echo "Proceeding..."
# create local links if requested
if [ -n "${ohfw}" ]
then
    echo "creating links for OH firmware version: ${ohfw}"
    if [[ ${ohfw} = *"3."* ]]
    then 
        echo "Downloading V3 firmware with tag ${ohfw}"
        echo "wget https://github.com/cms-gem-daq-project/OptoHybridv3/releases/download/${ohfw}/OH_${ohfw}.tar.gz"
        wget https://github.com/cms-gem-daq-project/OptoHybridv3/releases/download/${ohfw}/OH_${ohfw}.tar.gz 
        echo "Untar and copy firmware files and xml address table to relevant locations"
        echo "tar -xvf OH_${ohfw}.tar.gz"
        tar -xvf OH_${ohfw}.tar.gz
        echo "cp OH_${ohfw}/OH_${ohfw}.mcs oh_fw/optohybrid_${ohfw}.mcs"
        cp OH_${ohfw}/OH_${ohfw//_/-}.mcs oh_fw/optohybrid_${ohfw}.mcs
        echo "cp OH_${ohfw}/OH_${ohfw//_/-}.bit oh_fw/optohybrid_${ohfw}.bit"
        cp OH_${ohfw}/OH_${ohfw//_/-}.bit oh_fw/optohybrid_${ohfw}.bit
        echo "cp OH_${ohfw}/oh_registers.xml xml/optohybrid_registers_${ohfw}.xml"
        cp OH_${ohfw}/oh_registers_${ohfw}.xml xml/oh_registers_${ohfw}.xml
        echo "ln -sf optohybrid_${ohfw}.bit oh_fw/optohybrid_top.bit"
        ln -sf optohybrid_${ohfw}.bit oh_fw/optohybrid_top.bit
        echo "ln -sf optohybrid_${ohfw}.mcs oh_fw/optohybrid_top.mcs"
        ln -sf optohybrid_${ohfw}.mcs oh_fw/optohybrid_top.mcs
        echo "ln -sf xml/oh_registers_${ohfw}.mcs oh_fw/optohybrid_registers.xml"
        ln -sf oh_registers_${ohfw}.xml xml/optohybrid_registers.xml
        echo "rm -rf OH_${ohfw}/"
        rm -rf OH_${ohfw}/
        echo "rm -rf OH_${ohfw}.tar.gz"
        rm -rf OH_${ohfw}.tar.gz
    else
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
fi
if [ -n "${ge_gen}" ]
then
    if [[ ${ge_gen} = "2" ]]
    then
        ge21suf="ge21_"
    else 
        ge21suf=""
    fi
fi

if [ -n "${ctp7fw}" ]
then

    if [[ ${ctp7fw} = *"3."* ]]
    then
        ln -sf recover_v3.sh scripts/recover.sh
    else 
        ln -sf recover_v2.sh scripts/recover.sh
    fi
    # echo "creating links for CTP7 firmware version: ${ctpfw}"

    if [ ! -f "fw/gem_ctp7_gem_ctp7_v${ctp7fw//./_}.bit" ]
    then
        echo "CTP7 firmware fw/gem_ctp7_v${ctp7fw//./_}.bit missing, downloading"
        echo "wget https://github.com/evka85/GEM_AMC/releases/download/v${ctp7fw}/gem_ctp7_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.bit -O fw/gem_ctp7_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.bit"
        wget https://github.com/evka85/GEM_AMC/releases/download/v${ctp7fw}/gem_ctp7_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.bit -O fw/gem_ctp7_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.bit
    fi
    echo "ln -sf fw/gem_ctp7_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.bit fw/gem_ctp7.bit"
    ln -sf gem_ctp7_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.bit fw/gem_ctp7.bit
        
    if [ ! -f "xml/gem_amc_top_${ctp7fw//./_}.xml" ]
    then
        echo "CTP7 firmware xml/gem_amc_top_${ctp7fw//./_}.xml missing, downloading"
        echo "wget https://github.com/evka85/GEM_AMC/releases/download/v${ctp7fw}/address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.zip"
        wget https://github.com/evka85/GEM_AMC/releases/download/v${ctp7fw}/address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.zip
        echo "unzip address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.zip"
        unzip address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.zip
        echo "rm address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.zip"
        rm address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh.zip
        echo "cp address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh/gem_amc_top.xml xml/gem_amc_v${ctp7fw//./_}.xml"
        cp address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh/gem_amc_top.xml xml/gem_amc_v${ctp7fw//./_}.xml
        echo "rm -rf address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh"
        rm -rf address_table_v${ctp7fw//./_}_${ge21suf}${nlinks}oh
    fi

    echo "Download gemloader"
    if [ ! -d "gemloader/" ]
    then
        mkdir gemloader
    fi
    echo "wget https://raw.githubusercontent.com/evka85/GEM_AMC/v${ctp7fw//./_}/scripts/gemloader/gemloader_clear_header.sh -P gemloader/"
    wget https://raw.githubusercontent.com/evka85/GEM_AMC/v${ctp7fw//./_}/scripts/gemloader/gemloader_clear_header.sh -P gemloader/
    echo "wget https://raw.githubusercontent.com/evka85/GEM_AMC/v${ctp7fw//./_}/scripts/gemloader/gemloader_configure.sh -P gemloader/"
    wget https://raw.githubusercontent.com/evka85/GEM_AMC/v${ctp7fw//./_}/scripts/gemloader/gemloader_configure.sh -P gemloader/
    echo "wget https://raw.githubusercontent.com/evka85/GEM_AMC/v${ctp7fw//./_}/scripts/gemloader/gemloader_load_test_data.sh -P gemloader/"
    wget https://raw.githubusercontent.com/evka85/GEM_AMC/v${ctp7fw//./_}/scripts/gemloader/gemloader_load_test_data.sh -P gemloader/
    echo "wget https://raw.githubusercontent.com/evka85/GEM_AMC/v${ctp7fw//./_}/scripts/gemloader/gemloader_read.sh -P gemloader/"
    wget https://raw.githubusercontent.com/evka85/GEM_AMC/v${ctp7fw//./_}/scripts/gemloader/gemloader_read.sh -P gemloader/

    echo "ln -sf xml/gem_amc_top_v${ctp7fw//./_}.xml xml/gem_amc_top.xml"
    ln -sf gem_amc_v${ctp7fw//./_}.xml xml/gem_amc_top.xml
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
                ssh root@${ctp7host} /usr/sbin/adduser ${newuser} -h /mnt/persistent/${newuser} && /bin/save_passwd;
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

# Download xhal tag
if [ -n "${xhaltag}" ]
then
    echo "Fetching xhal binaries and libraries"
    res=$(curl -s --head https://github.com/cms-gem-daq-project/xhal/releases/tag/${xhaltag} | head -n 1 | grep "HTTP/1.[01] [23]..")
    if [ -n "${res}" ]
    then
        echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/ipbus -O bin/ipbus"
        wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/ipbus -O bin/ipbus

        echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/liblog4cplus.so  -O lib/liblog4cplus.so"
        wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/liblog4cplus.so  -O lib/liblog4cplus.so
        echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/libxhal_ctp7.so  -O lib/libxhal_ctp7.so"
        wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/libxhal_ctp7.so  -O lib/libxhal_ctp7.so
        echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/libxerces-c.so   -O lib/libxerces-c.so"
        wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/libxerces-c.so   -O lib/libxerces-c.so
        echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/librwreg_ctp7.so -O lib/librwreg_ctp7.so"
        wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/librwreg.so -O lib/librwreg.so
        echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/liblmdb.so       -O lib/liblmdb.so"
        wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/liblmdb.so       -O lib/liblmdb.so

        echo "ln -sf libxhal_ctp7.so lib/libxhal.so"
        ln -sf libxhal_ctp7.so lib/libxhal.so
        echo "ln -sf libxerces-c.so lib/libxerces-c-3.1.so"
        ln -sf libxerces-c.so lib/libxerces-c-3.1.so
        echo "ln -sf liblog4cplus.so lib/liblog4cplus-1.1.so.9"
        ln -sf liblog4cplus.so lib/liblog4cplus-1.1.so.9
    else
        echo "Unable to find specified tag ${xhaltag} in list of xhal releases (https://github.com/cms-gem-daq-project/xhal/releases)"
        echo "Please verify that the specified tag exists"
        exit
    fi

    echo "wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/reg_interface.zip && unzip reg_interface.zip && rm reg_interface.zip"
    wget https://github.com/cms-gem-daq-project/xhal/releases/download/${xhaltag}/reg_interface.zip
    unzip reg_interface.zip -d python/
    rm reg_interface.zip
fi

# Update CTP7 gemdaq paths
if [ -n "${update}" ]
then
    echo "Creating/updating CTP7 gemdaq directory structure"
    echo "ssh root@${ctp7host} mkdir -p /mnt/persistent/gemdaq"
    echo "ssh root@${ctp7host} mkdir -p /mnt/persistent/gemdaq/address_table.mdb"
    echo "ssh root@${ctp7host} touch /mnt/persistent/gemdaq/address_table.mdb/data.mdb"
    echo "ssh root@${ctp7host} touch /mnt/persistent/gemdaq/address_table.mdb/lock.mdb"
    echo "ssh root@${ctp7host} chmod -R 777 /mnt/persistent/gemdaq/address_table.mdb"
    ssh root@${ctp7host} mkdir -p /mnt/persistent/gemdaq && mkdir -p /mnt/persistent/gemdaq/address_table.mdb && touch /mnt/persistent/gemdaq/address_table.mdb/data.mdb && touch /mnt/persistent/gemdaq/address_table.mdb/lock.mdb && chmod -R 777 /mnt/persistent/gemdaq/address_table.mdb

    find . -type d -print0 | xargs -0 -n1 chmod a+rx
    find . -type f -print0 | xargs -0 -n1 chmod a+r
    find bin -type f -print0 | xargs -0 -n1 chmod a+rx
    find lib -type f -print0 | xargs -0 -n1 chmod a+rx

    echo "wget https://raw.githubusercontent.com/cms-gem-daq-project/ctp7_modules/develop/conf/conf.txt"
    wget https://raw.githubusercontent.com/cms-gem-daq-project/ctp7_modules/develop/conf/conf.txt
    echo "cp conf.txt vfat3/conf.txt"
    cp conf.txt vfat3/conf.txt
    echo "rm -rf conf.txt"

    echo "rsync -ach --progress --partial --links bin fw lib oh_fw scripts xml python vfat3 root@${ctp7host}:/mnt/persistent/gemdaq/"
    rsync -ach --progress --partial --links bin fw lib oh_fw scripts xml python gemloader vfat3 root@${ctp7host}:/mnt/persistent/gemdaq/
   
    echo "Update LMDB address table on the CTP7, make a new .pickle file and resync xml folder"
    echo "cp xml/* $XHAL_ROOT/etc/"
    cp xml/* $XHAL_ROOT/etc/
    echo "Upload rpc modules and restart rpcsvc"
    scp -r $CTP7_MOD_ROOT/lib/*.so root@${ctp7host}:/mnt/persistent/rpcmodules 
    ssh root@${ctp7host} killall rpcsvc
    if [ -n "${newuser}" ]
    then
        ssh -t ${newuser}@${ctp7host} 'sh -lic "rpcsvc"'
    else
        ssh -t texas@${ctp7host} 'sh -lic "rpcsvc"'
    fi
    echo "python python/reg_interface/reg_interface.py -n ${ctp7host} -e update_lmdb /mnt/persistent/gemdaq/xml/gem_amc_top.xml"
    python $XHAL_ROOT/python/reg_interface/reg_interface.py -n ${ctp7host} -e update_lmdb /mnt/persistent/gemdaq/xml/gem_amc_top.xml
    cp $XHAL_ROOT/etc/gem_amc_top.pickle xml/gem_amc_top.pickle
    rsync -ach --progress --partial --links xml root@${ctp7host}:/mnt/persistent/gemdaq/

    echo "Cleaning local temp folders"
    rm ./bin/*
    rm ./vfat3/*
    rm ./lib/*
    rm ./fw/*
    rm ./oh_fw/*
    rm -rf ./python/reg_interface
    rm ./xml/*
    rm -rf ./gemloader
fi
