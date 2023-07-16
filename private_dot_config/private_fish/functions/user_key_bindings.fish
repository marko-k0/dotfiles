#function user_key_bindings --on-event="fish_preexec"
function user_key_bindings
  #bind \ck accept-autosuggestion execute
    bind -M insert \cf accept-autosuggestion
end
