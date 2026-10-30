#!/usr/bin/env bash
# Install git-whoami and its global hooks by symlinking them from this checkout:
#   $BIN_DIR/git-whoami        -> bin/git-whoami   (BIN_DIR defaults to ~/.local/bin)
#   $BIN_DIR/git-leakguard     -> bin/git-leakguard
#   ~/.config/git/hooks        -> hooks/           (honours $XDG_CONFIG_HOME)
# and pointing the global core.hooksPath at that hooks directory, if it is unset.
#
#   ./install.sh               install, or re-link after moving the checkout
#   ./install.sh --uninstall   remove the links and core.hooksPath again
set -eu
here=$(cd "$(dirname "$0")" && pwd)
bin_dir=${BIN_DIR:-$HOME/.local/bin}
hooks_dir=${XDG_CONFIG_HOME:-$HOME/.config}/git/hooks

expand() { printf '%s' "${1/#\~/$HOME}"; }
current_hooks_path=$(git config --global core.hooksPath || true)

link() {
	local src=$1 dst=$2
	if [ -e "$dst" ] && [ ! -L "$dst" ]; then
		echo "install: $dst exists and is not a symlink; move it aside first" >&2
		exit 1
	fi
	mkdir -p "$(dirname "$dst")"
	ln -sfn "$src" "$dst"
	echo "linked  $dst -> $src"
}

unlink_ours() {
	local dst=$1
	if [ -L "$dst" ] && [[ $(readlink "$dst") == "$here"/* ]]; then
		rm "$dst"
		echo "removed $dst"
	fi
}

if [ "${1-}" = --uninstall ]; then
	unlink_ours "$bin_dir/git-whoami"
	unlink_ours "$bin_dir/git-leakguard"
	unlink_ours "$hooks_dir"
	if [ -n "$current_hooks_path" ] && [ "$(expand "$current_hooks_path")" = "$hooks_dir" ]; then
		git config --global --unset-all core.hooksPath
		echo "unset   core.hooksPath"
	fi
	echo "Your [identity] and [leak] sections in ~/.gitconfig were left in place."
	exit 0
fi
[ $# -eq 0 ] || { echo "usage: $0 [--uninstall]" >&2; exit 2; }

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
	echo "install: warning: git-whoami needs bash 4+, but this shell is $BASH_VERSION." >&2
	echo "         On macOS: brew install bash (it must come first on your PATH)." >&2
fi

link "$here/bin/git-whoami" "$bin_dir/git-whoami"
link "$here/bin/git-leakguard" "$bin_dir/git-leakguard"
link "$here/hooks" "$hooks_dir"

if [ -z "$current_hooks_path" ]; then
	git config --global core.hooksPath "$hooks_dir"
	echo "set     core.hooksPath = $hooks_dir"
elif [ "$(expand "$current_hooks_path")" != "$hooks_dir" ]; then
	echo >&2
	echo "install: core.hooksPath is already set to $current_hooks_path, so the hooks" >&2
	echo "         are NOT active. To use them instead:" >&2
	echo "           git config --global core.hooksPath $hooks_dir" >&2
fi

case ":$PATH:" in
	*":$bin_dir:"*) ;;
	*) echo >&2; echo "install: $bin_dir is not on your PATH; add it so 'git whoami' works." >&2 ;;
esac

echo
echo "Next: describe your identities in ~/.gitconfig (see examples/), then run"
echo "'git whoami' inside a repo."
