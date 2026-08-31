# ==============================================================================
# Hide gum from yt-x
# ==============================================================================
# gum 2.0 is a Bubble Tea program, and Bubble Tea asks the terminal what it
# supports before it draws anything: DECRQM 2026 (synchronized output), DECRQM
# 2027 (grapheme clustering) and CSI ? u (kitty keyboard protocol). It does not
# drain the answers before exiting, so kitty's replies arrive after gum is gone
# and land in whatever reads the tty next. That is the stray text:
#
#   ^[[?1u                        echoed by the shell, right after gum spin's
#                                 own default --title, which is "Loading..."
#   ?2026;2$y?2027;1$y?1u         taken as typed input by the fzf that yt-x
#                                 opens a moment later, in the Select Media bar
#
# Confirmed by capturing `gum spin` on a pty: it emits exactly ?2026$p, ?2027$p
# and ?u, which is that trio in that order. Nothing else installed here sends
# all three -- fzf only asks CSI 6n and ?2004$p, and chafa is called with
# --probe off.
#
# yt-x reaches for gum in four places -- prompt (yt-x:1315), confirm (:1378),
# pager (:1442) and the loader (:1476) -- each gated on the same one-line
# helper, so overriding the helper is one edit rather than four. yt-x already
# ships read-based fallbacks for all of them, and bat already shadowed the gum
# pager. gum itself stays installed and works everywhere else; this only blinds
# yt-x to it.
#
# Loaded through CONFIG_AUTOLOADED_EXTENSIONS. __post_config_load sources
# extensions after the script's own definitions, so this redefinition wins.
# ==============================================================================

_dep_ch() {
  [ "$1" = "gum" ] && return 1
  command -v "$1" >/dev/null 2>&1
}
