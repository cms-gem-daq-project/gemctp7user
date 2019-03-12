usage() { 

    echo './vX_switch.sh [vX]'
    echo ''
    echo '    vX = v2 or v3'
    echo ''
    echo 'Will change the symlinks on the ctp7 to point to the correct files for vX electronics. Ends with a call to recover.sh'
    kill -INT $$
}

VX=$1

if [ -z ${1+x} ]
then
    usage
fi

if [ $VX != "v2" ]  &&  [ $VX != "v3" ]
then
    usage
fi   

echo "Updating symlinks"
ln -snf /mnt/persistent/gemdaq_${VX} /mnt/persistent/gemuser/gemdaq_USER
ln -snf /mnt/persistent/rpcmodules_${VX} /mnt/persistent/gemuser/rpcmodules_USER
echo "Finished symlinks"

echo "Running recover.sh"
recover.sh
echo "Finished running recover.sh"
