if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_vi_key_bindings
    #fish_ssh_agent
    refresh_tmux_vars
    user_key_bindings

    alias g='git'
    alias k='kubectl'
    alias kns='kubens'
    alias vim='nvim'

    set -gx EDITOR nvim
    set -gx VISUAL nvim
end

set -x GOPATH $HOME/go
fish_add_path $GOPATH/bin $HOME/.krew/bin $HOME/.cargo/bin
