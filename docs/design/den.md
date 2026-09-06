# den — the home-os shell

home-os's shell is **den**. The reference implementation lives at
`~/Code/Tools/den` and is written in Zig; the shell that runs on home-os is
`kernel/src/console/den.home`, written in Home. They are the same language,
and `scripts/den-conform.sh` is what makes that a claim rather than a name.

## Why a second implementation instead of the original

CLAUDE.md is unambiguous: **home-os source stays 100 % `.home`**, with the
single exception of unavoidable boot assembly. The reference den is ~100,000
lines of Zig across 237 files. Vendoring it would put the largest Zig program
in the tree at the centre of the operating system, which is precisely the rule's
subject. So den is *ported*, not hosted — and the original earns its keep as the
oracle the port is measured against.

## The split: who owns what

`serial_shell.home` owns the terminal. It reads COM1, echoes, handles backspace,
and assembles a line. It does not interpret one.

`den.home` owns the language. It gets every line that is shell — a builtin, an
alias, an assignment, or anything using shell syntax at all. What stays behind
in `serial_shell.home` is this kernel's own debug commands (`disk`, `ext2`,
`irq`, `hid`, `netc`, `nets`, `run`, `exec`, `ls`, `ps`, …), which are not part
of the den language and have no equivalent in the reference.

The routing decision lives in `den_should_handle()`, in den, so there is one
answer rather than two lists drifting apart. A line containing a quote, a `$`, a
redirect, a `;`, a `|`, a `#` or a `&&` is shell by construction — which matters
for a case like `disk > log`, where the command is the kernel's but the
redirection is the shell's, and the old dispatcher would have written to the
console and dropped the file on the floor without saying so.

## What the language does today

Lexing honours single quotes (everything literal), double quotes (expansion but
no word splitting, with `\"`, `\\`, `\$` and `` \` `` escaped), and backslash
outside quotes. Expansion covers `$NAME`, `${NAME}` and `$?`. A word of the form
`NAME=VALUE` is an assignment. Aliases substitute the command word — by splicing
the alias body's words in front of the arguments, never by rejoining and
re-lexing, which would strip the arguments' quoting a second time. Commands are
joined with `;`, `&&` and `||`. Output redirects with `>` and `>>` through the
VFS. `#` starts a comment.

Thirty-seven builtins: `.` `[` `alias` `basename` `builtin` `cat` `cd` `clear`
`command` `declare` `dirname` `dirs` `echo` `env` `eval` `exit` `export` `false`
`help` `history` `let` `local` `popd` `printf` `pushd` `pwd` `readonly`
`realpath` `set` `source` `test` `true` `type` `typeset` `umask` `uname`
`unalias` `unset` `which` `whoami`.

External programs are found in `/bin` (or by a path containing a separator) and
run through the ELF loader at ring 3.

## Pipelines, without fork

A pipeline runs in stages. Each stage runs with its output attached to a
holding file; the next runs with its input attached to that file. For finite
input — every pipeline in a script that terminates — the bytes and the exit
status are what a concurrent pipe gives.

Two processes running at once and passing bytes through a shared buffer needs
fork. What a pipeline *means* does not, and the difference is stated rather
than hidden: a stage runs to completion before the next starts, so an unbounded
producer never reaches its consumer, and the intermediate bytes live in a file
rather than a kernel buffer.

It is written for any number of stages. A two-stage version would have run
`a | b | c` as `a | b` and dropped `c` silently, which is the failure this tree
keeps turning up — output that looks like it worked.

`<` and `>` work the same way for a program as for a builtin: the kernel is
told where standard input and output point (`set_user_stdin`,
`set_user_stdout`) before the program is entered, and told to forget
afterwards. Standard error is never redirected, so a program's complaint about
a failure cannot vanish into the file the failure was about.

## What it still refuses

Job control — `&`, `jobs`, `fg`, `bg` — needs a process that keeps running
after the shell returns, which needs fork/exec. Refused with a message, not
faked, and registered as **S12** in MASTER_PLAN §7.

This is the distinction that matters. The file this replaced,
`kernel/src/lib/den_lib.home`, implemented these by returning `0`: its `pwd` and
`echo` printed nothing, its external execution reported success without
executing, and its pipes and all three redirection functions were bare
`return 0`. A caller could not tell that apart from working. It was reachable at
boot through `shell_syscall_init()`, whose only observable effect was a log line
saying it had initialised.

## The conformance gate

```bash
scripts/den-conform.sh              # check home-os against the goldens
scripts/den-conform.sh --record     # re-derive the goldens from the real den
```

`--record` runs each `tests/den/*.den` through the reference shell and writes
`tests/den/*.expected`. Nothing else writes those files: a golden edited by hand
is a test that asserts whatever the code already does.

Checking boots the kernel the boot gate builds, feeds the script over the serial
line, recovers each command's output from between the prompts, and requires the
result to match the golden byte for byte. CI runs the check — it has no den
binary, which is the reason the golden is committed rather than derived there.

The scripts run as one shell, not one per line: variables, aliases and the
working directory have to survive from one line to the next, and a fresh shell
per line would lose all three.

### Writing a test

Assert on output that is not a substring of the command that produced it. The
console echoes what it is sent, so a milestone that also appears in the input
passes without the command having run. `printf` reassembles its arguments, which
no echo of the input can produce:

```sh
printf "%s%s\n" and ran      # asserts "andran"; the input contains neither
```

## Where the port still differs

- `uname` prints the sysname alone; `uname -a` prints sysname, nodename and
  machine — matching the reference. The boot gate asserts the `-a` form, because
  a bare `home-os` would substring-match the first of the many lines containing
  it.
- An unquoted expansion of an unset variable produces an empty word here, where
  POSIX produces no word at all.
- `printf` does not reuse its format string when given more arguments than
  conversions.
- `env` lists the shell's variables, which are not a process environment.
