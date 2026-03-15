---
name: craft
description: Generate a standalone CLI for Craft document management using MCP. Use when working with Craft.do documents, pages, blocks, or collections from the command line. Requires a Craft MCP URL from the user's Craft docs settings.
license: MIT
metadata:
  author: elecnix
  version: "1.0"
  mcporter: "https://github.com/steipete/mcporter"
---

# Craft CLI Generator

Create a standalone CLI binary for interacting with Craft.do documents via MCP (Model Context Protocol).

## Prerequisites

- [Bun](https://bun.sh) installed (for binary compilation)
- The user's personal Craft MCP URL

## Step 1: Get the Craft MCP URL

Instruct the user to obtain their Craft MCP URL:

1. Open Craft and navigate to: **Settings → Documents → MCP**
   - Or visit directly: https://www.craft.do/settings/documents/mcp
2. Find the MCP server URL (it looks like: `https://mcp.craft.do/links/XXXXX/mcp`)
3. Copy this URL — it contains a unique token for authentication

> **Note:** Each user has their own personal MCP URL. Do not share or commit this URL.

## Step 2: Generate the CLI Binary

Use [MCPorter](https://github.com/steipete/mcporter) to compile a standalone binary:

```bash
npx mcporter generate-cli \
  --name craft \
  --compile \
  --server <CRAFT_MCP_URL>
```

Replace `<CRAFT_MCP_URL>` with the user's actual Craft MCP URL.

This produces a native `craft` binary — no runtime dependencies, no Node.js needed. The binary starts instantly.

### Fallback: TypeScript (if Bun unavailable)

If Bun is not installed, generate TypeScript instead:

```bash
npx mcporter generate-cli \
  --name craft \
  --server <CRAFT_MCP_URL>
```

Then run with:
```bash
# Install deps once
npm init -y && npm install commander mcporter

# Run
npx tsx craft.ts --help
```

## Step 3: Use the Generated CLI

The CLI provides subcommands for all Craft MCP tools:

```bash
# List all available commands
./craft --help

# List all folders
./craft folders-list

# List documents in a folder
./craft documents-list --folder-ids <FOLDER_ID>

# Get content of a document/block
./craft blocks-get --id <BLOCK_ID>

# Create a new document
./craft documents-create --documents "My New Page"

# Add markdown content to a document
./craft markdown-add \
  --markdown "# Hello World\nThis is my content" \
  --position end \
  --page-id <PAGE_ID>

# Delete documents
./craft documents-delete --document-ids <DOC_ID>
```

### Output formats

Add `--raw json` for machine-readable output:
```bash
./craft folders-list --raw json
```

> **Tip:** Run `./craft --help` to see all available subcommands with their parameters.

## Step 4: Install Globally (Optional)

```bash
# Move to a directory in PATH
sudo mv craft /usr/local/bin/

# Or create a symlink
ln -s $(pwd)/craft ~/.local/bin/craft
```

Now use `craft` from anywhere:
```bash
craft folders-list
craft documents-list --location unsorted
```

## Troubleshooting

### Bun not found
Install Bun first:
```bash
curl -fsSL https://bun.sh/install | bash
```
Then retry the `--compile` command.

### Authentication errors
- Ensure the MCP URL is current and not expired
- Regenerate the URL in Craft settings if needed

## References

- [MCPorter](https://github.com/steipete/mcporter) — MCP CLI generator
- [Craft MCP Documentation](https://www.craft.do/fr/imagine/guide/mcp/mcp) — Official Craft MCP guide
