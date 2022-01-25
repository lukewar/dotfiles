alias code="open -a 'Visual Studio Code'"
alias cdw="cd ~/Workspace"

alias raudio="sudo kextunload /System/Library/Extensions/AppleHDA.kext;sudo kextload /System/Library/Extensions/AppleHDA.kext;sudo kill -9 `ps ax|grep 'coreaudio[a-z]' | awk '{print $1}'`"

# git

git_branch() {
  GIT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) || return
  [ -n "$GIT_BRANCH" ] && echo "($GIT_BRANCH) "
}

alias gga='git add'
alias ggm='git merge'
alias ggr='git rebase'
alias ggpull='git pull origin "$(git_branch)"'
alias ggpush='git push origin "$(git_branch)"'
alias ggpf='git push origin "$(git_branch)" --force-with-lease'
alias ggc='git commit'
alias ggch='git checkout'

# workspaces
alias cdw="cd ~/Workspace"
alias cdwg="cd ~/Workspace/github"
alias cdwgg="cd ~/Workspace/github/github"

# more macOS/Bash-like word jumps
export WORDCHARS=""

# bundler
alias be="bundle exec"
alias bef="bundle exec fastlane"

# direnv https://direnv.net
eval "$(direnv hook zsh)"

# rbenv https://github.com/rbenv/rbenv
export RBENV_ROOT=/usr/local/var/rbenv
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

# zsh git prompt
setopt prompt_subst
autoload -Uz vcs_info
zstyle ':vcs_info:*' formats '%F{5}[%F{2}%b%F{5}] %F{2}%c%F{3}%u%f'

precmd () { vcs_info }
PROMPT='%F{5}[%F{2}%n%F{5}] %F{3}%3~ ${vcs_info_msg_0_}%f%# '

# Golang
export GOPATH=$HOME/go

# Locale
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
