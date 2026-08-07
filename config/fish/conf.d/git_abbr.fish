# Context-aware git abbreviations (Fish 4.x) — expand inline before Enter
abbr --command git st  status
abbr --command git co  checkout
abbr --command git cb  'checkout -b'
abbr --command git br  branch
abbr --command git df  diff
abbr --command git dc  'diff --cached'
abbr --command git lg  'log --oneline --graph --decorate'
abbr --command git lo  'log --oneline -20'
abbr --command git aa  'add -A'
abbr --command git ca  'commit --amend --no-edit'
abbr --command git rh  'reset --hard HEAD'
abbr --command git pu  'push -u origin HEAD'
abbr --command git puf 'push --force-with-lease'
