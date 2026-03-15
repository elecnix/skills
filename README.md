# Skills

A collection of agent skills for various tools and services.

## Installation

Install any skill using the skills CLI:

```bash
npx skills add elecnix/skills
```

Or use individual skills by referencing them in your agent configuration.

## Available Skills

### [craft](skills/craft/)

Generate a standalone CLI for Craft.do document management using MCP. Create, search, and manage Craft documents from the command line.

**Requirements:** Craft.do account with MCP access, Node.js or Bun

```bash
npx mcporter generate-cli --name craft --compile --server <your-craft-mcp-url>
```

### [onetimesecret](skills/onetimesecret/)

Secure credential handoff via OneTimeSecret.com. Ask users for passwords, API keys, or other secrets **without the secret being visible to the agent**. Creates a one-time URL the user visits in their browser, then pipes the secret directly to a command or file.

**Requirements:** curl, python3

```bash
# Create link only
./onetimesecret.sh

# Wait for secret, pipe to command (agent never sees it)
./onetimesecret.sh --wait 120 --pipe "node inject-password.js"

# Wait for secret, save to file
./onetimesecret.sh --wait 60 --file /tmp/secret.txt

# With passphrase protection
./onetimesecret.sh --wait 120 --passphrase "Enter code: 4291" --file /tmp/secret.txt
```

## What are Skills?

Skills are reusable capabilities for AI agents. They provide procedural knowledge that helps agents accomplish specific tasks more effectively. Learn more at [agentskills.io](https://agentskills.io).

## Creating Your Own Skills

1. Create a new folder under `skills/` with your skill name
2. Add a `SKILL.md` file following the [Agent Skills specification](https://agentskills.io/specification)
3. The folder name must match the `name` field in SKILL.md frontmatter

### SKILL.md Format

```markdown
---
name: my-skill
description: A clear description of what this skill does and when to use it.
license: MIT
---

# My Skill

Instructions for the agent...
```

## License

Individual skills may have their own licenses. Check each skill's SKILL.md for details.

## Contributing

Contributions welcome! Please ensure your SKILL.md follows the [Agent Skills specification](https://agentskills.io/specification).
