# ~/.profile: executed by Bourne-compatible login shells.

# echo "Sourcing .profile

if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# path set by /etc/profile
export GEM_PATH=/mnt/persistent/gemdaq
export PATH=$PATH:$GEM_PATH/scripts:$GEM_PATH/bin
export PATH=$GEM_PATH/python/reg_interface:$PATH
export PYTHON_PATH=$GEM_PATH/python:$PYTHON_PATH
export PATH=$HOME/bin:$PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GEM_PATH/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/persistent/rpcmodules

mesg n
