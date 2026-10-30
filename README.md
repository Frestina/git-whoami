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

## Quick start (new to git?)

This tool warns you before you save (commit) or upload (push) work as the wrong
GitHub account. You only need it if you have two or more GitHub accounts.

**Before you start**, you need:

- a Mac or Linux computer (on Windows, use WSL)
- git installed
- an SSH key for each GitHub account, added to that account on GitHub
  ([GitHub's guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh))
- on a Mac only: run `brew install bash` once

**1. Install it.** Open the Terminal and paste:

```bash
git clone https://github.com/Frestina/git-whoami.git ~/.local/share/git-whoami
~/.local/share/git-whoami/install.sh
```

**2. Tell it about your accounts.** Open the hidden file `~/.gitconfig` in your
home folder and add one block per account. Replace the name, email and key path
with your own:

```ini
[identity]
	active = alice

[identity "alice"]
	email = alice@example.com
	sshkey = ~/.ssh/alice-github.pub
```

**3. Say which folder belongs to which account**, for example "everything in
`~/work` uses my work account". Copy the files in [`examples/`](examples/) and
change them to match your setup. [Set up your identities](#set-up-your-identities)
explains each file.

**4. Check it.** Go into one of your project folders and run:

```bash
git whoami
```

It shows which account the project uses, and anything that doesn't match.

That's it. From now on, git stops you if you commit or push with the wrong
account, and tells you what to fix.

## Requirements

- git 2.13 or newer (for `includeIf`), or 2.31 for `git leakguard`
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

1. links `~/.local/bin/git-whoami` and `git-leakguard` to `bin/`. Set `BIN_DIR`
   to choose another directory, which must be on your `PATH`.
2. links `~/.config/git/hooks` to `hooks/`
3. sets `git config --global core.hooksPath ~/.config/git/hooks`, unless you
   already have a hooks path. In that case it tells you how to switch.

Nothing is checked until you add identities or leak terms, so installing it is
harmless.

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

## Leak guard

`git leakguard` is the second check on every push. It blocks a push that would
publish something you listed as private, such as a machine name, a home address
or a second account you keep separate.

The list goes in `~/.gitconfig`, next to your identities, so it is never in a
repo that could be pushed. Keep your dotfiles private if they hold this file.

```ini
[leak]
	term = my-laptop                     # literal, any case, anywhere in a line
	term = /home/alice/
	regex = "ghp_[a-z0-9]{36}"           # awk regex, in lowercase: lines are lowercased first
	private = alice/notes                # owner/repo, pushes to it aren't checked

[leak "alice-work"]
	term = alice-personal                # only while alice-work is the active identity
```

Quote a value that holds `#`, `;` or a backslash.

A push is checked for added lines, the names of new files, author and committer
names and emails, commit and tag messages, and ref names. Terms also search
binary files. Regexes don't, because a short one matches random bytes.

Commits already on a public remote aren't checked again, so pushing a fork
doesn't re-check its upstream's history. A commit that is only on a private
remote or a local one still counts when you push it somewhere public.

Only pushes to github.com are checked, and every repo counts as public unless
`leak.private` names it. A private repo you forgot to list gets blocked rather
than skipped.

```
git leakguard                    check the whole history of this repo
git leakguard --pre-push REMOTE URL
                                 check the commits being pushed
                                 (what the pre-push hook runs; reads git's stdin)
```

Run `git leakguard` before you make a private repo public. Changing a repo's
visibility involves no push, so no hook sees it. This scan also covers repos
listed in `leak.private`.

What it can't catch:

- **Commits made on github.com.** A merge in the web UI or an edit there never
  passes through your hooks. It can carry your email if you haven't turned on
  GitHub's email privacy setting.
- **Text inside images,** and anything compressed or encoded.
- **Anything not on your list.** It finds your terms, not secrets in general.

## How it works

Every file in `hooks/` except `dispatch` is a symlink to `hooks/dispatch`.
Because `core.hooksPath` points at this directory, git runs `dispatch` for every
hook. It:

- runs `git whoami --check` for `pre-commit`
- runs `git whoami --pre-push` for `pre-push`. This checks the remote, plus the
  author and committer of every commit that isn't on any remote yet.
- runs `git leakguard --pre-push` for `pre-push`
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
