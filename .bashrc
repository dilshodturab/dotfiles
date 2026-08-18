# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return
source ~/.local/share/omarchy/default/bash/rc
pokemon-colorscripts -r

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'
alias gs='git status'
alias gco="git checkout"
alias gaa="git add ."
alias gdiff="git diff"
alias gl="git pull"
alias gsh="git show"
alias gfo="git fetch origin"
alias gf="git fetch"
alias gb="git branch"
alias gm="git merge"
alias gc="git checkout"
alias gp="git push"
alias gcm="git commit -m"
alias glog="git log --graph --oneline --decorate --format='%C(yellow)%h%Creset %C(magenta)%cd%Creset %s%C(auto)%d%Creset' --date=format:'%Y-%m-%d %H:%M'"
alias e="exit"
alias t="tmux"
alias vi="nvim"
alias cl="clear"
alias clock="clock-rs"
alias fetch='pokemon-colorscripts -r | fastfetch'
weather() {
  curl "wttr.in/$1"
}

set -h
# NVM lazy load
nvm() {
  unset -f nvm node npm npx
  source /usr/share/nvm/init-nvm.sh
  nvm "$@"
}
node() {
  unset -f nvm node npm npx
  source /usr/share/nvm/init-nvm.sh
  node "$@"
}
npm() {
  unset -f nvm node npm npx
  source /usr/share/nvm/init-nvm.sh
  npm "$@"
}
npx() {
  unset -f nvm node npm npx
  source /usr/share/nvm/init-nvm.sh
  npx "$@"
}

rdp-connect() {
  echo -n "Server IP: "
  read target
  echo -n "Domain [Leave blank for none]: "
  read domain
  echo -n "Username: "
  read user

  # Logic: If domain is provided, use the flag. If not, omit it.
  local domain_flag=""
  [[ -n "$domain" ]] && domain_flag="/d:$domain"

  # We omit /p so xfreerdp prompts us securely in the terminal
  xfreerdp3 /v:$target $domain_flag /u:$user /dynamic-resolution /clipboard /cert:ignore
}
. "$HOME/.cargo/env"


# Added by Antigravity CLI installer
export PATH="/home/av/.local/bin:$PATH"
