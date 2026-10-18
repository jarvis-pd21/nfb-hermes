# NFB layer for Hermes Agent

Each NFB (an AI agent that lives in a token) runs this fork of Hermes Agent on its own E2B computer.
Everything NFB-specific lives in this `nfb/` folder, so weekly upstream merges stay clean.

| Piece | File | What it does |
|---|---|---|
| Boot | `boot.sh` | Reads `~/.nfb/agent.env` (written by the NFB Worker), renders `~/.hermes/.env` + `config.yaml`, installs the plugin and skills, starts the gateway in a keep-alive loop. Brain stays off until the owner has prepaid. |
| Config | `config.yaml` | API server (the Worker talks to it on port 8642 with `X-Hermes-Session-Key: nfb-<aid>-e<incarnation>`: one master chat per owner), NFB MCP tools (wallet, ClankTok, site) with this NFB's own key, memory on, quiet tool progress. |
| Brain | `boot.sh` | `NFB_BRAIN_PROVIDER` = `openrouter` (default; this NFB's own sub-key, limit = its prepaid balance) / `anthropic` (owner's own key) / `workers-ai` (owner's own Cloudflare). Model is config only: `NFB_BRAIN_MODEL` + `NFB_BRAIN_FALLBACK_MODELS` (OpenRouter model IDs). |
| Guard | `plugins/nfb-guard` | Last step before a reply leaves: swaps the words NFB never uses and hides anything shaped like a secret. |
| Deep work | `bin/deep-work`, `skills/nfb/deep-work` | Pluggable delegate (`NFB_DELEGATE=claude-code` default). Claude Code runs on the NFB's own OpenRouter key. |
| Evergreen | `.github/workflows/nfb-upstream-sync.yml`, `tests/` | Weekly upstream merge + tests; pushes only if green. |

Sovereign and prepaid (Phil): no shared model key, no phone or payment secrets on the computer. The only credentials here are
this NFB's own and revocable: its model sub-key, its MCP key and its API server key. All three are rotated at every handover,
and the old owner's chats are wiped (fresh session key per incarnation, sessions deleted).

Memory is plain markdown (`~/.hermes/SOUL.md`, `~/.hermes/memories/*.md`), mirrored to the NFB's vault so it moves with the token.
