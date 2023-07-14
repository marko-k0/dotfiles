if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_vi_key_bindings
    #fish_ssh_agent
    refresh_tmux_vars
    user_key_bindings

    alias g='git'
    alias k='kubectl'
    alias vim='nvim'
    set -gx EDITOR /usr/bin/vim
    set -gx VISUAL /usr/bin/vim
end

set -x GOPATH $HOME/go
set -x PATH $PATH $GOPATH/bin
