# git-whoami

If you have more than one GitHub account (personal and work, or a main account
and a bot), it's easy to commit with the wrong email or push with the wrong SSH
key. `git-whoami` stops that from happening.

You describe each account once in your git config. `git whoami` then tells you
which account a repo uses and checks that everything agrees with it:

- the **commit author and committer email**
- the **SSH key** each GitHub remote pushes with
- the **owner** of each GitHub remote, when the owner is one of your own accounts

Global git hooks run the same check on every `git commit` and `git push`, and
block the commit or push when something doesn't match.

```
$ git whoami
identity   alice-work  (from ~/.gitconfig-work)
author     Alice Example <alice@work.example>
origin     git@github.com:acme/api.git  key alice ✗, owner acme

Identity mismatch: this repo is set up as alice-work, but
  - origin: pushes with alice's SSH key (via host 'github.com')
```

## Requirements

- git 2.13 or newer (for `includeIf`)
- bash 4 or newer. Linux already has it. macOS ships bash 3.2, so run
  `brew install bash` and make sure Homebrew's `bin` comes first on your `PATH`.
- OpenSSH, if you push over SSH

## Install

```bash
git clone https://github.com/Frestina/git-whoami.git ~/.local/share/git-whoami
~/.local/share/git-whoami/install.sh
```

The installer symlinks files from the clone, so keep the clone where it is.
Running `git pull` in it updates the tool. It:

1. links `~/.local/bin/git-whoami` to `bin/git-whoami`. Set `BIN_DIR` to
   choose another directory, which must be on your `PATH`.
2. links `~/.config/git/hooks` to `hooks/`
3. sets `git config --global core.hooksPath ~/.config/git/hooks`, unless you
   already have a hooks path. In that case it tells you how to switch.

Nothing is checked until you add identities, so installing it is harmless.

## Set up your identities

The examples use two accounts, `alice` (personal) and `alice-work`. Complete
copies of every file are in [`examples/`](examples/).

### 1. Describe each account in `~/.gitconfig`

Every identity is an `[identity "<github-username>"]` section. `identity.active`
names the default one.

```ini
[identity]
	active = alice

[identity "alice"]
	email = alice@example.com                     # every email you use as alice
	email = 1234+alice@users.noreply.github.com
	sshkey = ~/.ssh/alice-github.pub              # the key alice pushes with

[identity "alice-work"]
	email = alice@work.example
	sshkey = ~/.ssh/alice-work-github.pub
```

`git-whoami` only knows an identity if it has an `sshkey` line. If you only
push over HTTPS, point `sshkey` at any path.

### 2. Switch identity by directory

Use `includeIf` to load a second config file for repos under a directory. Put
it **after** the defaults above, so the included values win:

```ini
# ~/.gitconfig
[includeIf "gitdir:~/work/"]
	path = ~/.gitconfig-work
```

```ini
# ~/.gitconfig-work
[identity]
	active = alice-work
[user]
	email = alice@work.example
```

To set the identity for one repo only, run this inside the repo:

```bash
git config identity.active alice-work
git config user.email alice@work.example
```

### 3. Give each account its own SSH host alias

GitHub decides which account you are from the SSH key, so each account needs
its own key and its own host alias in `~/.ssh/config`:

```
Host github.com
	IdentityFile ~/.ssh/alice-github
	IdentitiesOnly yes

Host github-work
	HostName github.com
	IdentityFile ~/.ssh/alice-work-github
	IdentitiesOnly yes
```

Clone work repos with the alias, for example `git@github-work:acme/api.git`.
`git-whoami` resolves the alias with `ssh -G` and checks that the key matches
the active identity's `sshkey`.

### 4. Check it

```bash
cd ~/work/some-repo
git whoami
```

## Usage

```
git whoami                       show the identity, where it comes from, and any problems
git whoami --check [--quiet]     exit 1 on a mismatch (what the pre-commit hook runs)
git whoami --pre-push REMOTE URL check a remote and the commits being pushed
                                 (what the pre-push hook runs; reads git's stdin)
git whoami -h                    show this usage
```

To skip the hooks for one commit or push, use `git commit --no-verify` or
`git push --no-verify`.

## How it works

Every file in `hooks/` except `dispatch` is a symlink to `hooks/dispatch`.
Because `core.hooksPath` points at this directory, git runs `dispatch` for every
hook. It:

- runs `git whoami --check` for `pre-commit`
- runs `git whoami --pre-push` for `pre-push`. This checks the remote, plus the
  author and committer of every commit that isn't on any remote yet.
- then runs the repo's own `.git/hooks/<name>` if there is one. A global
  `core.hooksPath` would otherwise stop those hooks from running.

Repos that set their own `core.hooksPath`, such as husky or lefthook, don't run
the global hooks, so they aren't checked.

## Limitations

- **Emails you haven't listed.** An email that isn't listed under any identity
  only produces a note. An email listed under a *different* identity blocks the
  commit. So add every email you use for an account as an `email =` line.
- **HTTPS remotes.** For an HTTPS remote, your credential helper picks the
  account, not an SSH key. These remotes get the owner check but not the key
  check.
- **`core.sshCommand` and `GIT_SSH_COMMAND`.** A key chosen with these isn't
  seen. Only the `IdentityFile` from `~/.ssh/config` is checked.
- **Other hosts.** Only github.com remotes are checked.

## Uninstall

```bash
~/.local/share/git-whoami/install.sh --uninstall
```

This removes the two symlinks, and also `core.hooksPath` if the installer set
it. Your `[identity]` sections stay in your git config, and git ignores them.

## License

[MIT](LICENSE)
