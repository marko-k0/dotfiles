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

test -f ~/.config/fish/secrets.fish; and source ~/.config/fish/secrets.fish

### --- Environment Paths ---
# Add your local binaries to the path
fish_add_path $HOME/.local/bin

### --- Node.js / NVM Setup ---
# Tell nvm.fish to use your existing .nvm folder if you want to keep it,
# or leave this out to use the default ~/.config/nvm (cleaner for Fish).
set -gx nvm_data $HOME/.nvm

# Automatically use the LTS version if available
if type -q nvm
    # This ensures your shell starts with a valid node version
    nvm use lts > /dev/null 2>&1
end

# Generated for envman. Do not edit.
test -s ~/.config/envman/load.fish; and source ~/.config/envman/load.fish
