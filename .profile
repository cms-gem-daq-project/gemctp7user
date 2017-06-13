# ~/.profile: executed by Bourne-compatible login shells.

if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# path set by /etc/profile
# export PATH

#export PATH=$PATH:$HOME/scripts:$HOME/scripts/generated:$HOME/apps/python/bin
export PATH=$PATH:$HOME/scripts:$HOME/scripts/generated:$HOME/bin
export PATH=$HOME/apps/misc:$HOME/apps/reg_interface:$PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/lib

mesg n
