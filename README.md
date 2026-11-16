# Reachedge

Your market advisor with twenty years of Wall Street experience, as a chat on your own computer.
Connect your own AI (ChatGPT sign-in, an API key or a local model) and, if you like, your investment
accounts. Everything stays on your computer, encrypted.

This repository only holds the installers and the releases.

## Download the app

**https://reachedge.vercel.app** — Mac (Apple Silicon and Intel), Windows and Linux.

## Or install with one command

**Mac or Linux**: open Terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/tbvisser/reachedge-releases/main/install.sh | bash
```

**Windows**: open PowerShell and paste:

```powershell
irm https://raw.githubusercontent.com/tbvisser/reachedge-releases/main/install.ps1 | iex
```

After a few seconds Reachedge opens in your browser at `http://127.0.0.1:3737`.
No admin rights needed; everything goes into `~/.reachedge` (Windows: `%USERPROFILE%\.reachedge`).

| Command | What it does |
|---|---|
| `reachedge` | Start and open in your browser |
| `reachedge stop` | Stop |
| `reachedge update` | Install the latest version (your chats and connections stay) |
| `reachedge uninstall` | Remove |

On a Mac you also find Reachedge in Spotlight and Launchpad; on Windows in the Start menu.

## What you can connect

- **AI**: ChatGPT (sign in with your Go, Plus, Pro or Business plan), Claude, OpenAI, Gemini, OpenRouter, Groq,
  Mistral, xAI, DeepSeek (API key), or Ollama, LM Studio and Hermes on your own computer.
  Claude needs an API key: Anthropic does not allow signing in with a Claude subscription in other apps.
- **Accounts (read-only)**: Trading 212, Interactive Brokers, Alpaca, Bitvavo, Kraken, DEGIRO (CSV export).
- **Data**: prices (Yahoo Finance) and macro figures (FRED) are built in; Finnhub for news and fundamentals.

Analysis and education, not personal financial advice.
