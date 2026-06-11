# SSX

`ssx` — a tiny bash CLI to manage [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev) client connections on macOS. Turn the proxy on/off with one command and switch between named server profiles.

`ssx` runs a local **SOCKS5 listener only** (via `ss-local`). It never touches macOS system proxy settings — you decide which apps use it.

## Requirements

- macOS with [Homebrew](https://brew.sh)
- Everything else (`shadowsocks-libev`, `jq`) is installed automatically by `make install`

## Install

```sh
# 1. Define your servers (required)
cp ss-configs.example.jsonc ss-configs.jsonc   # then edit it

# 2. Install deps + configs + CLI
make install
```

`make install` aborts with setup instructions if `ss-configs.jsonc` is missing or empty, and refuses to deploy one that doesn't parse or defines no profiles.

This installs:

| What     | Where                                       |
| -------- | ------------------------------------------- |
| Profiles | `~/.config/ssx/ss-configs.jsonc` (mode 600) |
| CLI      | `~/.local/bin/ssx`                          |

`make install` is idempotent — re-run it after editing `ss-configs.jsonc` to re-deploy profiles (the previous installed copy is backed up to `*.bak.<timestamp>` when it differs).

## Usage

```sh
ssx list            # list profiles (* = current)
ssx use tc-sh       # pick a profile (reconnects if already connected)
ssx on              # connect — starts ss-local, SOCKS5 on 127.0.0.1:1080
ssx status          # connection state (exit 0 connected / 1 disconnected)
ssx off             # disconnect
```

| Command           | Description                                                                             |
| ----------------- | --------------------------------------------------------------------------------------- |
| `on [profile]`    | Connect. Uses the current profile when omitted; switches if a different one is running. |
| `off`             | Disconnect.                                                                             |
| `use <profile>`   | Set the current profile; reconnects if currently connected. (alias: `switch`)           |
| `list`            | List profile names. (alias: `ls`)                                                       |
| `status`          | Show state, profile, pid, endpoint. (alias: `st`)                                       |
| `env`             | Print proxy env exports for shells.                                                     |
| `version`, `help` | The usual.                                                                              |

### Routing terminal tools through the proxy

```sh
eval "$(ssx env)"                  # sets ALL_PROXY / all_proxy
curl https://example.com           # now goes through the tunnel
```

`env` emits `socks5h://` URLs, which resolve DNS **through the proxy** (no local DNS leaks, works for locally-unresolvable domains). Use plain `socks5://` manually if you specifically want local DNS resolution.

Browsers: point your proxy extension (or per-app settings) at `127.0.0.1:1080` (SOCKS5).

## Config format

`ss-configs.jsonc` maps profile names to complete [`ss-local` config objects](https://github.com/shadowsocks/shadowsocks-libev#usage) — any key `ss-local` understands passes through (e.g. `plugin`, `fast_open`):

```jsonc
// Full-line // comments are allowed. No trailing commas, no inline comments.
{
  "config-name": {
    "server": "1.2.3.4",
    "server_port": 8388,
    "local_address": "127.0.0.1",
    "local_port": 1080,
    "password": "p_x_p_w_d",
    "timeout": 600,
    "method": "aes-256-gcm",
  },
}
```

Required per profile: `server`, `server_port`, `local_port`, `method`, and `password` (or `key`). `local_address` defaults to `127.0.0.1`.

The repo's `ss-configs.jsonc` is gitignored (it holds server passwords); `ss-configs.example.jsonc` is the committed template.

## Uninstall

```sh
make uninstall                 # disconnects, removes ~/.config/ssx and ~/.local/bin/ssx
make uninstall KEEP_CONFIG=1   # same, but keeps ~/.config/ssx
```

`shadowsocks-libev` itself is left installed (`brew uninstall shadowsocks-libev` to remove).

## Development

```sh
make help      # all targets
make test      # sandboxed offline smoke suite — never touches ~/.config/ssx
make format    # shfmt (brew-installed lazily)
make lint      # shellcheck (brew-installed lazily)
make tag       # tag HEAD with the version from VERSION and push it (main only)
make clean     # remove test sandboxes (.tmp/)
```

Layout: [bin/ssx](bin/ssx) is the single self-contained CLI (macOS system bash 3.2 compatible); [scripts/](scripts/) holds install/uninstall/deps/test; the [Makefile](Makefile) is the entry point for everything.

State lives in `~/.config/ssx/`: the deployed `ss-configs.jsonc`, the rendered `active.json` for `ss-local`, the `current` profile name, and `ss-local.pid`.
