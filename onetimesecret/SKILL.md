# OneTimeSecret — Secure Credential Handoff

> Use this skill when you need to ask the user for a password, API key, or other secret **without the secret being visible to you (the agent)**.

## When to Use

| Scenario | Use this skill? |
|----------|----------------|
| Agent needs user's password to inject into a web form via CDP | ✅ Yes |
| Agent needs an API key to configure a service | ✅ Yes |
| Agent needs a secret but must not see/log it | ✅ Yes |
| User can type directly into the terminal | ❌ Use `read -s` instead |

## How It Works

1. **Agent runs the script** → Creates a one-time secret URL
2. **Agent shows URL to user** → "Please visit this link and enter your secret"
3. **User opens URL in browser** → Enters secret into the secure form
4. **Agent retrieves secret** → Via `--pipe` or `--file` (never visible to agent)

The secret **never passes through the agent's context** — it goes directly from the user's browser to the specified command or file.

## Usage

```bash
# Basic: Create link only (agent displays URL to user)
./onetimesecret.sh

# Wait for secret, pipe to a command
./onetimesecret.sh --wait 120 --pipe "python3 inject-password.py"

# Wait for secret, save to file
./onetimesecret.sh --wait 60 --file /tmp/secret.txt

# With passphrase protection (user must enter both)
./onetimesecret.sh --wait 120 --passphrase "Enter code: 4291" --file /tmp/secret.txt

# Quiet mode (only outputs URL, useful for automation)
./onetimesecret.sh --quiet
```

## Options

| Option | Description | Required |
|--------|-------------|----------|
| `--wait SECONDS` | Timeout in seconds to wait for secret | **Mandatory** with `--pipe`/`--file` |
| `--passphrase TEXT` | Require passphrase to unlock secret | No |
| `--ttl SECONDS` | Secret expiration time (default: 600) | No |
| `--pipe CMD` | Pipe secret to this command | No |
| `--file PATH` | Save secret to this file | No |
| `--quiet` | Only output the URL (no decoration) | No |

## Security Properties

- ✅ Secret is **never printed to stdout** (only stderr for UI)
- ✅ Secret goes directly to `--pipe` command or `--file`
- ✅ One-time use: secret is burned after retrieval
- ✅ Optional passphrase for two-factor protection
- ✅ Auto-expires after TTL
- ✅ File saved with `chmod 600` permissions

## Agent Integration Example

```bash
# Agent needs password for CDP injection
# 1. Create secret link
./onetimesecret.sh --wait 120 --pipe "node cdp-inject.js --password-stdin"

# 2. Tell user: "Please visit the URL above and enter your password"
# 3. Script waits up to 2 minutes
# 4. When user submits, secret pipes directly to cdp-inject.js
# 5. Agent never sees the password
```

## Notes

- Uses the **anonymous** OneTimeSecret API (no account required)
- For production use, consider self-hosting: https://github.com/onetimesecret/onetimesecret
- The `--wait` timeout is **mandatory** when using `--pipe` or `--file` to prevent infinite hangs
- Secrets are stored on onetimesecret.com servers only until viewed (then burned)
- For air-gapped/high-security environments, use the OS keychain or GUI prompt instead
