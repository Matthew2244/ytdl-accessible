#!/bin/bash
# Verify everything before committing. Run this, not your memory.
#
# Written after a broken AppleScript was committed and pushed: the compile
# failed, the output scrolled past, and the "COMPILED OK" line came from the
# *next* command in the chain. The app was left missing from /Applications.
# Anything that can be checked automatically should be.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAIL=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; FAIL=1; }

echo "Checking ytdl-accessible."
echo

echo "Python syntax"
for f in ytdl ytdescribe; do
  if python3 -c "import ast,sys; ast.parse(open('$HERE/$f').read())" 2>/dev/null; then
    ok "$f"
  else
    bad "$f does not parse"
    python3 -c "import ast; ast.parse(open('$HERE/$f').read())" 2>&1 | tail -3
  fi
done

echo
echo "Every option documented in --help"
if ! python3 - "$HERE" <<'PY'
import re, sys, os
here = sys.argv[1]
for name in ("ytdl", "ytdescribe"):
    src = open(os.path.join(here, name)).read()
    missing = []
    for m in re.finditer(r"(?:ap|fmt|part|pl)\.add_argument\((.*?)\)\n", src, re.S):
        if "help=" not in m.group(1):
            n = re.search(r'"([^"]+)"', m.group(1))
            missing.append(n.group(1) if n else "?")
    print("  %s  %s" % ("ok   " if not missing else "FAIL ",
                        name if not missing else "%s: undocumented %s" % (name, missing)))
    if missing:
        bad_ = True
sys.exit(1 if "bad_" in dir() else 0)
PY
then FAIL=1; fi

echo
echo "AppleScript compiles"
TMPAPP="$(mktemp -d)/t.app"
if osacompile -o "$TMPAPP" "$HERE/MediaDownload.applescript" 2>/tmp/osa.err; then
  ok "MediaDownload.applescript"
  rm -rf "$TMPAPP"
else
  bad "MediaDownload.applescript does not compile"
  tail -3 /tmp/osa.err
fi

echo
echo "Dialog accessibility"
if ! python3 - "$HERE" <<'PY'
import re, sys, os
src = open(os.path.join(sys.argv[1], "MediaDownload.applescript")).read()
body = "\n".join(l for l in src.split("\n") if not l.strip().startswith("--"))

# A button that is both default and cancel makes Escape do nothing — measured,
# and it is the shape you write by accident.
blocks = re.findall(r"display dialog.*?(?=\n\s*(?:on error|end try|if |set |my ))", body, re.S)
dead = []
for b in blocks:
    d = re.search(r'default button "([^"]+)"', b)
    c = re.search(r'cancel button "([^"]+)"', b)
    if d and c and d.group(1) == c.group(1):
        dead.append(d.group(1))
print("  %s Escape works on every dialog%s"
      % ("ok   " if not dead else "FAIL ", "" if not dead else " — dead on: %s" % dead))

# A list you can enter and cannot leave by keyboard is a trap.
lists = re.findall(r"set \w+ to \{[^}]*\}", body)
pickers = [l for l in lists if "choose from list" in body[body.index(l):body.index(l) + 500]]
noback = [l[:40] for l in pickers if '"Back"}' not in l]
print("  %s every list offers a Back item%s"
      % ("ok   " if not noback else "FAIL ", "" if not noback else " — missing in %d" % len(noback)))
sys.exit(1 if (dead or noback) else 0)
PY
then FAIL=1; fi

echo
echo "Shell scripts"
for f in install.sh check.sh; do
  bash -n "$HERE/$f" 2>/dev/null && ok "$f" || bad "$f has a syntax error"
done

echo
if [ "$FAIL" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Something failed above. Do not commit."
fi
exit "$FAIL"
