# Sourced by caelestia's ~/.config/fish/config.fish, last, inside the
# `status is-interactive` block. This file is NOT a caelestia dots target, so it
# survives `caelestia update` -- ~/.config/fish/ does not. Anything personal
# belongs here, never in config.fish.

# Wider `ls` columns than caelestia's default.
command -v eza &>/dev/null && alias ls='eza --across -w=40 --icons --group-directories-first -1'

# zoxide's `z` / `zi`. Caelestia's config.fish already runs
# `zoxide init fish --cmd cd`, which replaces `cd` -- but that flag defines
# `cd`/`cdi` INSTEAD of `z`/`zi`, not in addition to them. This second init adds
# the standard pair back. Not a duplicate: both are needed for both sets.
# Sourcing twice is safe -- the PWD hook is the same function name either way,
# so the later definition replaces the earlier one rather than stacking.
command -v zoxide &>/dev/null && zoxide init fish | source

# ~/.local/bin (extract-here, voxtype-submap). fish_add_path is idempotent and
# de-duplicates, unlike the three `export PATH=...` / `set -gx PATH ...` lines
# that used to sit at the bottom of config.fish -- those ran on every shell and
# compounded through nesting, leaving ~/.local/bin in PATH NINE times.
# The -U universal variable below is the real fix; this line only covers the
# case where fish_variables is lost.
fish_add_path -g ~/.local/bin
