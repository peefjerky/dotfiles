#!/usr/bin/env sh
# ==============================================================================
# Shared fzf preview helpers for yt-x -- local replacement for the generated one
# ==============================================================================
# yt-x writes this file itself (__preview_fzf_create_shared_script, yt-x:1508),
# but only when it is missing:
#
#     if ! [ -s "$CLI_PREVIEW_FZF_SCRIPT" ]; then ... fi
#
# so a file that already exists wins. ~/.cache/yt-x/previews/text/fzf-preview.sh
# is a symlink to this one: `[ -s ]` follows symlinks, so yt-x leaves it alone,
# and the cache sweep (`find "$CLI_PREVIEW_DIR" -type f -mtime +N -exec rm {} +`,
# yt-x:4382) matches -type f, which a symlink is not. It survives both.
#
# Why replace it: upstream renders with `kitten icat`, or a bare `chafa`, and
# BOTH round-trip the terminal. icat asks for the screen size in pixels and hard
# errors without an answer; chafa probes with OSC 10/11, CSI 18t/14t/16t and DA1.
# Inside an fzf preview that is a race -- fzf owns the tty reader, so the replies
# land in fzf's input instead, and get echoed as literal text: the
# "?2026;2$y?2027;1$y?1u" in the Select Media bar and the "^[[?1u" after
# "Loading...".
#
# `--probe off` asks nothing, and `-f kitty` names the protocol outright rather
# than detecting it, so there is nothing to wait for. That pair emits the kitty
# graphics escape and no queries at all. `--polite on` additionally suppresses
# sequences that would confuse a program sharing the terminal, which fzf is.
# ==============================================================================

# Rows kept clear below the thumbnail. chafa emits real rows, unlike icat's
# absolute placement, so an unbounded image pushes the text out of the pane and
# fzf will not scroll a preview to get it back. yt-x prints, in order: title, up
# to six key/value lines, three dividers, then the description (yt-x:1702-1748),
# so this is roughly "title + metadata + eight lines of description".
#
# Only a bound, not a target: chafa fits the image inside cols x rows preserving
# aspect, and for a 16:9 thumbnail in a pane this shape the width is what binds.
YTX_PREVIEW_TEXT_ROWS=14

# ---------------------------------------------------------------------------
# Descriptions
# ---------------------------------------------------------------------------
# Set to 0 to switch this section off entirely, background fetch included.
YTX_DESCRIPTIONS=1
YTX_DESC_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yt-x/descriptions"

# yt-x fetches every listing with --flat-playlist (__fetch_yt_dlp), and for a
# subscriptions or channel tab YouTube returns no description at all -- the
# generated preview ends up carrying a literal `if ! [ null = "null" ]`, which
# is why that block silently prints nothing. Search listings DO carry a snippet
# and yt-x prints it itself, so this only fills the gap, and only when the page
# actually lacks descriptions -- otherwise it would print them twice.
#
# The join is the picture. yt-x names each cached thumbnail
# sha256(thumbnails[-1].url) (yt-x:1797; _util_generate_hash is plain sha256),
# and a YouTube thumbnail url carries the video id in its /vi/<id>/ segment. So
# the image path handed to fzf_preview identifies the video, with no need to
# match on titles.
_ytx_sync_page() {
    _ytx_state=$(ls -t "${XDG_CACHE_HOME:-$HOME/.cache}"/yt-x/state/*/*/state.env 2>/dev/null | head -1)
    [ -n "$_ytx_state" ] || return 1

    # -f, not -s: a search page legitimately maps to nothing (yt-x prints its own
    # snippets there), and an empty map is what records that so the jq below is
    # not re-run on every keystroke for the life of the page.
    _ytx_map="$YTX_DESC_DIR/idmap"
    [ -f "$_ytx_map" ] && [ ! "$_ytx_state" -nt "$_ytx_map" ] && return 0

    mkdir -p "$YTX_DESC_DIR" 2>/dev/null || return 1

    # state.env is shell assignments wrapping the raw json, so source it and let
    # jq read the url exactly as yt-x hashed it. Grepping the json text would
    # trip over \u0026 escapes that jq -r resolves.
    _ytx_rows=$(
        . "$_ytx_state" 2>/dev/null
        printf '%s' "$STATE_CURRENT_PLAYLIST_RESULTS" | jq -r '
            if ([.entries[]? | select(.description != null)] | length) > 0 then empty
            else .entries[]? | select(.thumbnails and .id) | (.thumbnails[-1].url) + " " + .id
            end' 2>/dev/null
    )
    if [ -z "$_ytx_rows" ]; then
        : >"$_ytx_map"
        return 0
    fi

    printf '%s\n' "$_ytx_rows" | while read -r _ytx_url _ytx_id; do
        case "$_ytx_url" in //*) _ytx_url="https:$_ytx_url" ;; esac
        printf '%s %s\n' "$(printf '%s' "$_ytx_url" | sha256sum | cut -d' ' -f1)" "$_ytx_id"
    done >"$_ytx_map.$$" 2>/dev/null

    mv "$_ytx_map.$$" "$_ytx_map" 2>/dev/null || { rm -f "$_ytx_map.$$"; return 1; }
    _ytx_fetch_page "$_ytx_map"
}

# One yt-dlp for the whole page rather than one per hover: --print-to-file
# templates the output filename, so each video lands in its own file and a hover
# is a file read, never a network wait. Detached with setsid because fzf kills
# the preview process on every keystroke and would take a plain background job
# with it.
_ytx_fetch_page() {
    _ytx_urls=""
    while read -r _ _ytx_id; do
        [ -s "$YTX_DESC_DIR/$_ytx_id.txt" ] ||
            _ytx_urls="$_ytx_urls https://www.youtube.com/watch?v=$_ytx_id"
    done <"$1"
    [ -n "$_ytx_urls" ] || return 0

    setsid sh -c "yt-dlp --skip-download --no-warnings --ignore-errors \
        --print-to-file '%(description)s' '$YTX_DESC_DIR/%(id)s.txt' $_ytx_urls" \
        >/dev/null 2>&1 </dev/null &
}

# Runs on EXIT so it lands under everything yt-x printed. Prints only what is
# already cached -- the first pass over a new page shows nothing here while the
# background fetch runs, and it fills in from then on.
ytx_print_description() {
    [ "$YTX_DESCRIPTIONS" = 1 ] || return 0
    [ -n "$YTX_IMAGE_HASH" ] || return 0
    _ytx_id=$(awk -v h="$YTX_IMAGE_HASH" '$1==h{print $2; exit}' "$YTX_DESC_DIR/idmap" 2>/dev/null)
    [ -n "$_ytx_id" ] || return 0
    [ -s "$YTX_DESC_DIR/$_ytx_id.txt" ] || return 0
    draw_divider
    fold -s -w "${FZF_PREVIEW_COLUMNS:-80}" <"$YTX_DESC_DIR/$_ytx_id.txt"
}
trap ytx_print_description EXIT

draw_divider() {
  ll=1
  while [ $ll -le $FZF_PREVIEW_COLUMNS ];do printf "${THEME_FZF_PREVIEW_DIVIDER}─${THEME_RESET}" ;ll=$(( ll + 1 ));done;
  echo
}

fzf_preview() {
  file=$1

  if [ "$YTX_DESCRIPTIONS" = 1 ]; then
    YTX_IMAGE_HASH=${file##*/}
    YTX_IMAGE_HASH=${YTX_IMAGE_HASH%.jpg}
    _ytx_sync_page 2>/dev/null
  fi

  cols=$FZF_PREVIEW_COLUMNS
  lines=$FZF_PREVIEW_LINES
  if [ -z "$cols" ] || [ -z "$lines" ]; then
    # A TIOCGWINSZ ioctl, not an escape query -- safe while fzf holds the tty.
    set -- $(stty size </dev/tty)
    lines=$1
    cols=$2
  fi

  rows=$(( lines - YTX_PREVIEW_TEXT_ROWS ))
  [ "$rows" -lt 3 ] && rows=3

  if ! command -v chafa >/dev/null 2>&1; then
    printf "%s" "$TXT_PREVIEW_INSTALL_VIEWER"
    return
  fi

  # Only claim the kitty protocol where it certainly exists. Anywhere else fall
  # back to symbols, which needs no protocol and no probe either.
  fmt=symbols
  [ -n "$KITTY_WINDOW_ID" ] && fmt=kitty

  if [ "$fmt" = symbols ]; then
    chafa --probe off --polite on --animate off -f symbols -s "${cols}x${rows}" "$file"
    return
  fi

  # The kitty protocol needs the cursor moved past the image by hand. chafa sends
  # the whole picture as ONE placement that occupies the r= rows named in its own
  # header, then emits a single newline -- so without this everything yt-x prints
  # next (divider, title, channel, duration, views, description) lands on row 2,
  # inside the image's footprint. kitty draws graphics at z-index 0, which is
  # above text, so that output is not merely misplaced, it is invisible.
  #
  # r= is read back rather than assumed: chafa fits the image inside cols x rows
  # preserving aspect, so for a 16:9 thumbnail in a pane this shape the width
  # binds first and the real row count is well under $rows. Padding by $rows
  # instead would leave a gap the size of the error.
  # Held in a variable, not a temp file: fzf kills the preview process on every
  # keystroke while scrolling, and each of these payloads is a couple of hundred
  # KB of base64, so a file would leak one per abandoned preview. No NULs in it,
  # so a shell variable is safe.
  out=$(chafa --probe off --polite on --animate off -f kitty -s "${cols}x${rows}" "$file" 2>/dev/null) || return
  [ -n "$out" ] || return
  printf '%s' "$out"

  used=$(printf '%s' "$out" | head -c 200 | grep -oaE 'r=[0-9]+' | head -1 | cut -d= -f2)
  [ -n "$used" ] || used=1
  # Command substitution ate chafa's single trailing newline, so the cursor is
  # still on the image's first row: emit the full row count, not one less.
  i=$used
  while [ "$i" -gt 0 ]; do printf '\n'; i=$((i - 1)); done
}
