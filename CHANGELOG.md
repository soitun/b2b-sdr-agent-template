# Changelog

All notable changes to the B2B SDR Agent Template are documented here.

Changes sourced from upstream (openclaw/openclaw) are labeled with the originating commit SHA.

---

## [Unreleased]

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
