#!/usr/bin/env python3
"""PreToolUse(Bash) hook: block `git worktree add` targets outside the repo's working tree."""
import json
import os
import shlex
import subprocess
import sys

SEPARATORS = {";", "&&", "||", "|", "&", "\n"}
ADD_OPTS_WITH_VALUE = {"-b", "-B", "--reason"}


def segments(cmd):
    lexer = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    seg = []
    for tok in lexer:
        if tok in SEPARATORS:
            yield seg
            seg = []
        else:
            seg.append(tok)
    yield seg


def worktree_add_target(seg):
    """Return (git -C dir or None, path) for a `git ... worktree add` segment, else None."""
    if "git" not in seg:
        return None
    args = seg[seg.index("git") + 1:]
    git_dir = None
    while args and args[0].startswith("-"):
        if args[0] == "-C" and len(args) > 1:
            git_dir = args[1]
            args = args[2:]
        else:
            args = args[1:]
    if args[:2] != ["worktree", "add"]:
        return None
    args = args[2:]
    while args:
        arg = args.pop(0)
        if arg in ADD_OPTS_WITH_VALUE:
            args = args[1:]
        elif not arg.startswith("-"):
            return git_dir, arg
    return None


def violations(cmd, cwd):
    for seg in segments(cmd):
        if seg[:1] == ["cd"] and len(seg) > 1:
            cwd = os.path.join(cwd, os.path.expanduser(seg[1]))
            continue
        target = worktree_add_target(seg)
        if not target:
            continue
        git_dir, path = target
        base = os.path.join(cwd, os.path.expanduser(git_dir or "."))
        top = subprocess.run(["git", "-C", base, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True).stdout.strip()
        if not top:
            continue
        dest = os.path.realpath(os.path.join(base, os.path.expanduser(path)))
        if not dest.startswith(os.path.realpath(top) + os.sep):
            yield dest, top


def main():
    data = json.load(sys.stdin)
    cmd = data.get("tool_input", {}).get("command", "")
    if "worktree" not in cmd:
        return 0
    try:
        bad = list(violations(cmd, data.get("cwd") or os.getcwd()))
    except ValueError:  # unparseable quoting; don't block on our own parse failure
        return 0
    for dest, top in bad:
        print(f"Blocked: worktree {dest} is outside repo {top}. Use EnterWorktree, or "
              f"`git -C {top} worktree add .claude/worktrees/<name> ...`.", file=sys.stderr)
    return 2 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
