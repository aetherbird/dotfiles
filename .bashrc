# ~/.bashrc: executed by bash(1) for non-login shells.

[ -z "$PS1" ] && return

HISTCONTROL=$HISTCONTROL${HISTCONTROL+:}ignoredups
HISTCONTROL=ignoreboth

shopt -s histappend

shopt -s checkwinsize

if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

#echo $PATH | grep -Eq "(^|:)/opt/nvim/bin(:|)" || PATH="$PATH:/opt/nvim/bin"
export PATH
#export VISUAL=/opt/nvim/bin/nvim
export EDITOR="$VISUAL"

force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	color_prompt=yes
    else
	color_prompt=
    fi
fi

# red='\[\e[0;31m\]'
# RED='\[\e[1;31m\]'
# blue='\[\e[0;34m\]'
# BLUE='\[\e[1;34m\]'
# cyan='\[\e[0;36m\]'
# CYAN='\[\e[1;36m\]'
# green='\[\e[0;32m\]'
# GREEN='\[\e[1;32m\]'
# yellow='\[\e[0;33m\]'
# YELLOW='\[\e[1;33m\]'
# PURPLE='\[\e[1;35m\]'
# purple='\[\e[0;35m\]'
# nc='\[\e[0m\]'

# PS1 Prompt
# Simple Cyan
# PS1="\[\e[36m\]\u@\h:\W\\$\[\e[m\] "
# Standard Multi
PS1="\[\e[36m\]\u\[\e[m\]@\[\e[36m\]\h\[\e[m\]:\[\e[33m\]\w\[\e[m\]\[\e[33m\] > \[\e[m\]"
export PS1

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.bash_local ]; then
    . ~/.bash_local
fi

LESS="-R -i"

if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

echo $PATH | grep -Eq "(^|:)/sbin(:|)"     || PATH=$PATH:/sbin
echo $PATH | grep -Eq "(^|:)/usr/sbin(:|)" || PATH=$PATH:/usr/sbin
#echo $PATH | grep -Eq "(^|:)/home/toby/.local(:|)" || PATH=$PATH:/home/toby/.local/bin


# Created by `pipx` on 2024-03-20 00:50:29
# export PATH="$PATH:~/.local/bin"

# colorscript -r inly if installed
if command -v colorscript >/dev/null 2>&1; then
    colorscript -r
fi

export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
