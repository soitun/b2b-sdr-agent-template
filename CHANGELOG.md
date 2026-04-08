# Changelog

All notable changes to the B2B SDR Agent Template are documented here.

Changes sourced from upstream (openclaw/openclaw) are labeled with the originating commit SHA.

---

## [Unreleased]

## 2026-04-08 — OpenClaw v2026.4.8 upstream sync

### Security (Critical — Upgrade Recommended)

- **Cross-origin redirect secret leakage fixed**
  307/308 redirects now drop request bodies and headers by default. Previously, auth tokens and API keys could leak to redirect targets via SSRF-guarded fetches. No config change required — protection is automatic after upgrade.
  Upstream: v2026.4.8

- **`/allowlist` commands require owner on channel resolution**
  In v2026.4.7 the owner check was enforced before channel resolution; now it's enforced before *and* during. Closes a narrow window where allowlist mutations could bypass the guard during fast concurrent requests.
  Upstream: v2026.4.8

- **Base64 byte limits before decode**
  Teams, Signal, QQ, and image-tool payloads now enforce byte-size caps before base64 decoding, preventing memory exhaustion from oversized payloads.
  Upstream: v2026.4.8

- **Untrusted event marking**
  Background summaries, ACP relay payloads, and wake-hook events are now tagged as untrusted system events and excluded from elevated execution contexts.
  Upstream: v2026.4.8

- **Windows cmd.exe approval gating strengthened**
  Env-assignment carriers inside cmd.exe wrappers are now caught by the approval gate even when ambient execution defaults are elevated.
  Upstream: v2026.4.8

### Fixed

#### Channels
- **Telegram/Setup**: Module import failures on packaged installs resolved — setup contracts load from bundled sidecars instead of missing dist files. Multi-account setups no longer break after `npm install -g`.
- **Slack**: WebSocket Socket Mode connections now respect HTTP(S) proxy settings and `NO_PROXY` exclusions — required for corporate proxy deployments.
- **Slack/Actions**: Bot token resolution fixed for `SecretRef`-backed tokens after config re-reads (e.g., `openclaw gateway restart`).
- **Discord/Events**: Cover image accepts URLs or local PNG/JPG/GIF paths with proper validation.
- **Matrix**: Multi-paragraph and loose-list rendering repaired — content no longer detaches from list items in formatted messages.
- **Telegram/Doctor**: Access-control fallback during multi-account normalization restored; inherited allowlists are no longer lost after `openclaw doctor`.
- **BlueBubbles**: Explicit private-network opt-out now respected for loopback and private server URLs.

#### Agent Runtime
- **Claude thinking blocks preserved** for Opus 4.5+, Sonnet 4.5+, and Claude 4-family models. Interleaved thinking was being stripped before forwarding — this caused reasoning regressions on complex SDR tasks with those models.
- **Context overflow recovery** now combines oversized and aggregate tool-result recovery in a single pass with a total-context backstop (prevents runaway token accumulation on long SDR conversation threads).
- **Claude CLI**: Nested API errors from structured output now surface properly instead of showing opaque CLI failure messages.

#### Infrastructure & Gateway
- **Gateway sessions — compaction checkpoints**: Pre-compaction state is now checkpointed with UI branch/restore — you can revert to the conversation state before compaction if a summary loses context.
- **Compaction provider**: Pluggable via `agents.defaults.compaction.provider` — swap in a different model for compaction without changing your main session model.
- **HTTP clients**: In-flight chat-completions aborted when client disconnects (prevents orphaned API calls on mobile reconnects).
- **Model selection**: Explicitly selected session models now resolve separately from runtime fallback chains — no more unexpected model switching mid-session.
- **Cron jobs**: `jobId` now loaded from on-disk store when missing, fixing "unknown cron job id" errors on gateway restart.

#### Providers
- **xAI/Grok**: `api.grok.x.ai` recognized as native endpoint; legacy `x_search` auth path maintained.
- **Mistral**: `reasoning_effort` sent for Mistral Small 4 with thinking-level mapping.
- **Ollama**: Vision capability auto-detected from API responses; streaming routed to correct endpoint (was defaulting to first configured instance).
- **Google Gemma**: Explicit thinking-off semantics preserved while reasoning support enabled in compatibility wrappers.
- **OpenAI TTS / Groq**: Groq endpoints now receive `wav` format; explicit `responseFormat` overrides honored.

#### Tools
- **Web Fetch**: HTTP/2 disabled for undici 8.0 compatibility (`allowH2: false`) — fixes connection errors on servers running Node 22+ with updated undici.
- **Exa Search**: Now shown in onboarding and provider pickers — was hidden from setup UI despite being a supported provider.
- **Memory Vector Recall**: Explicit warning when `sqlite-vec` is unavailable or writes are degraded (instead of silent fallback).
- **Memory Dreaming**: Config reads/writes now target the selected memory slot plugin instead of always targeting `memory-core`.

#### UI
- **Control UI light mode**: Scrollbar thumbs now visible in WebKit on light backgrounds.
- **iOS/Apple Watch**: Approval recovery works while iPhone is locked/backgrounded.
- **DNS pinning**: Skipped when trusted env-proxy mode is active — allows proxy-only sandboxes to resolve hosts through trusted proxies.

## 2026-04-08 — v3.6.0

### Added
- **Graphify Knowledge Graph** — Sales intelligence powered by [graphify](https://github.com/safishamsi/graphify)
  Build queryable knowledge graphs from product catalogs, customer conversations, and
  market research. Cherry-picked and adapted for B2B SDR context:
  - Product catalog graph → cross-sell paths, product families, spec relationships
  - Customer intelligence graph → buying patterns, referral paths, stalled lead recovery
  - Market research graph → competitive landscape, expansion opportunities
  - Runtime query via `python3 -m graphify query "topic"` (BFS/DFS traversal)
  - Interactive HTML visualization for owner dashboard
  - New skill: `skills/graphify/SKILL.md`
  - Deploy: auto-installs Python + graphifyy, auto-uploads all local skills
  - Added to `SKILLS_RESEARCH` in skill profiles (`full` profile)

### Changed
- **Operator Bilingual Mode now opt-in** — disabled by default, enable via
  `operator_bilingual: true` in IDENTITY.md. Prevents unexpected self-chat messages
  for operators who don't need Chinese translation.

### Deployment
- `deploy.sh` now auto-uploads all local skills from `skills/` directory
- `deploy.sh` Step 3b: auto-installs Python3 + graphify on target server

---

## 2026-04-08 — OpenClaw v2026.4.7 upstream sync

### Breaking Changes

- **`/allowlist` commands now require owner authorization**
  `/allowlist add` and `/allowlist remove` previously could be issued by any user. They now require owner-level access. Update your admin flows if you delegated allowlist management to non-owner accounts.
  Upstream: v2026.4.7

- **Dangerous environment overrides now blocked at model layer**
  Model-facing tool calls can no longer override Java, Rust, Cargo, Git, Kubernetes, or cloud credential environment variables. If your workflows inject env vars through model instructions, migrate to explicit workspace config or deploy scripts.
  Upstream: v2026.4.7

- **`gateway config.apply` / `config.patch` writes blocked from model**
  AI cannot modify gateway config at runtime via these calls. This prevents prompt-injection-based config changes. Existing automation that patches config via the model layer must migrate to direct API calls with human approval.
  Upstream: v2026.4.7

### Added

- **Webhook Ingress Plugin** — inbound automation drives TaskFlows via shared-secret endpoints
  External systems (CRMs, zapier, n8n, custom webhooks) can now POST to OpenClaw and trigger or advance TaskFlows directly. This is the cleanest way to implement inbound-lead-to-SDR-flow automation: new lead in CRM → webhook → SDR agent starts outreach sequence.

  ```yaml
  # workspace config
  plugins:
    webhook-ingress:
      enabled: true
      secret: "{{WEBHOOK_SECRET}}"    # shared secret for HMAC validation
      endpoint: "/webhooks/crm"       # path exposed by the gateway
  ```

  Sample payload to start a TaskFlow:
  ```json
  {
    "event": "lead.created",
    "flow": "outreach-sequence",
    "data": { "name": "Li Wei", "company": "Shenzhen MFG Co", "phone": "+86..." }
  }
  ```
  Upstream: v2026.4.7

- **`openclaw infer` CLI Hub** — first-class provider-backed inference
  New top-level command for running inference tasks outside of conversation context: model completions, media generation, web lookups, and embeddings. Useful for batch processing leads or generating personalized outreach copy at scale.

  ```bash
  openclaw infer model --prompt "Draft a cold outreach message for Li Wei at Shenzhen MFG" \
    --provider anthropic --model claude-sonnet-4-6
  openclaw infer media image --prompt "Product catalog cover" --provider gemini
  ```
  Upstream: v2026.4.7

- **Memory/Wiki stack restored** — structured claims, evidence fields, freshness-weighted search
  The bundled memory-wiki stack is back with meaningful upgrades: claim/evidence structure, contradiction clustering, and freshness weighting. For SDR use: store verified facts about leads (budget signals, authority contacts, pain points) with evidence links. Freshness weighting ensures recent intel ranks higher than stale data.
  Upstream: v2026.4.7

- **New AI providers: Gemma 4 (Google), Arcee AI**
  Two new bundled providers. Gemma 4 supports `thinkingOff` semantics for faster, non-reasoning responses — good for high-volume first-touch outreach. Arcee AI includes the Trinity catalog, a curated set of task-specialized models. Added to `workspace/TOOLS.md` provider table.
  Upstream: v2026.4.7

- **Session compaction checkpoints + branch/restore UI**
  Sessions UI now shows compaction checkpoints. You can branch from any checkpoint (useful when a long sales conversation goes off-track) or restore pre-compaction state for audit/review. No config needed — automatic.
  Upstream: v2026.4.7

- **Pluggable compaction provider registry**
  Plugins can now replace the built-in context summarization pipeline. Enables custom summarization strategies (e.g., preserve all price quotes verbatim while compacting small talk).
  Upstream: v2026.4.7

### Fixed

- **HTTP requests aborted on client disconnect** — zombie sessions no longer hold resources when a channel disconnects mid-conversation. Improves stability on mobile channels (WhatsApp, Telegram) where connections drop frequently.
  Upstream: v2026.4.7

- **Docker/Podman auto-binding to `0.0.0.0`** — gateway now auto-binds to all interfaces inside containers. No manual `--bind` flag needed. Simplifies `docker run` and Compose deployments.
  Upstream: v2026.4.7

- **Prompt-cache runtime context exposure** — prompt cache statistics now surfaced to context engines. Helps diagnose unexpected API costs or latency spikes by showing cache hit/miss at runtime.
  Upstream: v2026.4.7

- **Ollama vision capability auto-detected** — no longer need to manually declare `vision: true` for Ollama vision models; capability is detected from API responses.
  Upstream: v2026.4.7

### Security

- Media byte limits enforced before base64 decode on Teams, Signal, and QQ Bot channels — prevents memory exhaustion via crafted media payloads.
- File upload URLs validated against HTTPS + Microsoft/SharePoint host allowlists — prevents SSRF via document upload.
- Cross-origin redirect body stripping for POST payloads — prevents credential leakage on redirects.
- Private-network blocking for main-frame document redirects — closes redirect-based SSRF vector.
- Workspace-only filesystem constraint enforced for document uploads.
  Upstream: v2026.4.7

### Documentation
- Updated `workspace/TOOLS.md`: Webhook Ingress Plugin section, expanded AI provider table (Gemma 4, Arcee AI)
- Updated `deploy/UPGRADE.md`: v2026.4.7 security breaking changes and migration notes

---

## 2026-04-06 — OpenClaw v2026.4.5 upstream sync

### Breaking Changes (run `openclaw doctor --fix`)
- **Legacy config aliases removed** — The following keys are no longer recognized at load time:
  - `talk.voiceId` / `talk.apiKey` → use canonical `voice.*` paths
  - `agents.*.sandbox.perSession` → use `sandbox.*` canonical paths
  - `browser.ssrfPolicy.allowPrivateNetwork`
  - `hooks.internal.handlers`
  - Channel/group/room `allow` toggles
  
  Run `openclaw doctor --fix` to auto-migrate. Backward compat shims remain active during the transition period.

### Fixed
- **WhatsApp: `blockStreaming` config option restored**
  The `blockStreaming` option (disables streaming responses on WhatsApp) was inadvertently removed in a prior release. Now restored. No config change needed — existing `blockStreaming: true` configs will work again.
  Upstream: v2026.4.5

- **Telegram: model picker checks and HTML formatting restored**
  Non-default model confirmations now correctly show the model name in HTML-formatted messages. DM voice-note transcription restored. Reaction persistence fixed across gateway restarts.
  Upstream: v2026.4.5

- **Security: plugin allowlists and `/allowlist` access controls hardened**
  Plugin-only tool allowlists are now properly preserved between restarts. `/allowlist add` and `/allowlist remove` now require owner access. Canvas bridge actions require exact normalized URL matches.
  Upstream: v2026.4.5

### Added
- **Multilingual Control UI (12 languages)**
  The OpenClaw control dashboard and mobile UI are now localized for Simplified Chinese, Traditional Chinese, Brazilian Portuguese, German, Spanish, Japanese, Korean, French, Turkish, Indonesian, Polish, and Ukrainian. Operators in China, Japan, Korea, and LATAM can now manage the SDR agent in their native language.
  Upstream: v2026.4.5

- **New AI providers: Qwen, Fireworks AI, StepFun, MiniMax**
  Four new bundled providers are now available as drop-in LLM backends. Qwen and MiniMax are particularly relevant for China-based deployments. Add to `workspace/TOOLS.md` provider table.
  Upstream: v2026.4.5

- **`openclaw status --verbose`** — New diagnostic flag showing prompt cache reuse statistics. Useful for debugging latency or unexpected API costs.
  Upstream: v2026.4.5

- **`openclaw plugins install --force`** — Allows replacing an existing installed plugin without manual removal. Useful for development workflows.
  Upstream: v2026.4.5

### Documentation
- Updated `workspace/TOOLS.md`: WhatsApp `blockStreaming` note, expanded AI provider table (Qwen, Fireworks, StepFun, MiniMax)
- Updated `deploy/UPGRADE.md`: v2026.4.5 breaking changes and migration steps

## 2026-04-05 — v3.4.0

### Added
- **Operator Bilingual Mode** — English for customers, Chinese self-chat sync for operators
  Non-English-speaking operators can now run a global English-facing SDR without needing
  to read English. The agent replies to customers in English and immediately sends a
  Chinese translation to itself via WhatsApp self-chat. Operators read Chinese in their
  "Message to myself" channel; customers only ever see English.

  How it works:
  - Customer sends any language → Agent always replies in English
  - After each English reply → Agent silently sends Chinese translation via self-chat
  - Owner reports (Pipeline daily, quote approvals, notifications) → always Chinese
  - No hardcoded numbers, no extra config — works with `selfChatMode: true` (default)

  Updated files: `workspace/AGENTS.md`, `skills/sdr-humanizer/SKILL.md`

## 2026-04-03

### Fixed
- **Telegram: per-account action configuration now correctly applied during discovery**
  If you run multiple Telegram bots (e.g., one per market), each account's `actions` block
  (reactions, polls, inline buttons) is now independently honored. Previously, only the
  top-level channel config was evaluated regardless of `accountId`.
  Upstream: `fb8048a188e5` — "fix: honor telegram action discovery account config"

- **Mistral AI provider: full transport compatibility**
  OpenClaw now correctly handles Mistral's API quirks when using Mistral as the LLM backend:
  - Uses `max_tokens` instead of `max_completion_tokens`
  - Suppresses unsupported OpenAI-specific params (`store`, `reasoning_effort`)
  - Applies automatically for `provider: mistral` and any custom provider whose `baseUrl`
    points to `api.mistral.ai`
  Upstream: `6ac5806a3957` — "fix(providers): honor mistral transport compat (#60405)"

### Documentation
- Added Multi-Account Telegram Setup guide to `workspace/TOOLS.md`
- Added AI Model Provider reference table (Claude, OpenAI, Mistral, Groq) to `workspace/TOOLS.md`
