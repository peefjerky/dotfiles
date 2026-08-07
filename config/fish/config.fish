# --- Environment ---
set -gx XDG_CURRENT_DESKTOP Hyprland
set -gx EDITOR nvim
set -gx XCURSOR_SIZE 24
set -gx JAVA_HOME /usr/lib/jvm/java-11-openjdk
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
set -gx NVM_DIR "$HOME/.nvm"
fish_add_path ~/.local/bin
fish_add_path ~/.cargo/bin
fish_add_path /opt/zen-browser-bin

# --- Homebrew ---
eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv fish)

if status is-interactive
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end

    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end

    # --- dots-hyprland terminal colors ---
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # --- fzf: use fzf.fish plugin if installed, else built-in bindings ---
    # fzf.fish adds: Ctrl+R history, Ctrl+Alt+F files, Ctrl+Alt+L git log,
    #                Ctrl+Alt+S git status, Ctrl+Alt+P processes
    if not functions -q _fzf_search_history
        fzf --fish | source
    end

    # --- Zoxide (z dirname, zi for interactive) ---
    zoxide init fish | source

    # --- Aliases ---
    alias ls 'eza --color=always --tree -x --icons=always --level=1 --git --long --no-filesize --no-time --no-user'
    alias nosleep 'systemd-inhibit --what=idle sleep infinity'
    alias clearcache 'sudo paccache -rk1 && sudo pacman -Rns (pacman -Qdtq) && yay -Sc && yay -Yc'
    alias pamcan pacman
    alias q 'qs -c ii'

    # Kitty-specific
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    if test "$TERM" = xterm-kitty
        alias ssh 'kitten ssh'
    end
end
