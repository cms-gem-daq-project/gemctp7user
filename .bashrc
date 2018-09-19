# ~/.bashrc: executed by bash(1) for non-login shells.

# echo "Sourcing .bashrc"

alias reg="reg_interface.py"
alias sca="sca.py"

#export VIMRUNTIME=~/.vim/

# You may uncomment the following lines if you want `ls' to be colorized:
export GREP_OPTIONS='--color=auto'
export LS_OPTIONS='--color=auto'
#eval `dircolors`
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'

# Some more alias to avoid making mistakes:
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'

#export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export PYTHONPATH=/mnt/persistent/gemdaq/python/reg_interface:$PYTHONPATH

[ -z "$PS1" ] && return

export PS1='\h:\w\$ '
umask 022

if shopt -q login_shell
then
    # echo "Login shell"
    : # These are executed only when it is a login shell
else
    # echo "Non-login shell"
    : # Only when it is NOT a login shell
fi
