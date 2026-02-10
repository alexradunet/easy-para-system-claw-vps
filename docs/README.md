# Second Brain — AI-Assisted Personal Knowledge Management

A personal knowledge management system built on Obsidian, powered by an AI agent (Nazar) running OpenClaw, synchronized across devices via Syncthing, and hosted on a hardened Debian VPS behind Tailscale.

## Clone and Run

```bash
git clone https://github.com/YOUR_USER/second-brain.git
cd second-brain
```

1. Open `vault/` in Obsidian — the PARA folder structure is ready to use
2. Customize the agent personality in `vault/99-system/openclaw/workspace/SOUL.md`
3. Fill in your details in `vault/99-system/openclaw/workspace/USER.md`
4. Deploy to a VPS when ready (see [Deployment Guide](deployment.md))

## What Is This?

Three things working together:

1. **An Obsidian vault** (`vault/`) — organized with the PARA method (Projects, Areas, Resources, Archive) plus Inbox and Daily Journey
2. **An AI agent** (Nazar) — lives inside the vault, processes voice messages, manages your daily journal, and answers questions about your life
3. **A deployment stack** (`deploy/`) — Docker containers that run the agent and sync the vault across all your devices

```
second-brain/
├── vault/                ← Obsidian vault (PARA structure + agent config)
│   ├── 00-inbox/         ← Quick capture
│   ├── 01-daily-journey/ ← Daily notes
│   ├── 02-projects/      ← Active projects (goals + deadlines)
│   ├── 03-areas/         ← Life areas (ongoing)
│   ├── 04-resources/     ← Reference material
│   ├── 05-arhive/        ← Completed / inactive
│   └── 99-system/        ← Agent workspace, skills, templates
├── deploy/               ← Docker stack (push to VPS)
│   ├── docker-compose.yml
│   ├── Dockerfile.nazar
│   └── ...
└── docs/                 ← This documentation
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](architecture.md) | System design, components, data flow |
| [Vault Structure](vault-structure.md) | PARA vault layout and conventions |
| [Agent System](agent.md) | Nazar agent — workspace, personality, memory |
| [Skills Reference](skills.md) | Available skills (obsidian, voice, vps-setup) |
| [Deployment Guide](deployment.md) | VPS provisioning and Docker deployment |
| [Security Model](security.md) | Hardening, Tailscale, secrets management |
| [Syncthing Setup](syncthing.md) | Multi-device vault synchronization |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |

## Quick Start

### Local only (no VPS)

1. Clone this repo
2. Open `vault/` in Obsidian
3. Start writing notes — the PARA folder structure is ready
4. Templates are in `99-system/templates/`

### With VPS deployment

1. Copy `.env.example` to `.env` and fill in your API keys
2. Spin up a Debian 13 VPS
3. SSH in as root, install Claude Code
4. Point Claude Code at the `vps-setup` skill:
   ```
   Read vault/99-system/openclaw/skills/vps-setup/SKILL.md and help me set up this VPS
   ```
5. Or run the one-liner:
   ```bash
   sudo bash provision-vps.sh --deploy-repo /srv/nazar/deploy
   ```

See [Deployment Guide](deployment.md) for the full walkthrough.
