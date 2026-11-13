# Caffeine

A minimal macOS menu bar app that prevents your Mac from going to sleep.

## The Philosophy

This project demonstrates how **personal software** can be created in the age of AI. Instead of downloading yet another utility from the internet, you describe what you need, and it's built for you—tailored to your exact requirements.

- No bloat
- No subscription
- No tracking
- Just the functionality you asked for

## What It Does

- Lives in your menu bar (no dock icon)
- Click to toggle sleep prevention on/off
- Prevents both display sleep and system idle sleep while active
- Shows a coffee cup (☕) when active, Zzz when inactive
- Clean, minimal code that's easy to understand and modify

## Build & Run

Install the latest published release with Homebrew:

```bash
brew install --cask vnglst/tap/caffeine
```

Requires macOS 12 Monterey or later. Requires an Apple Silicon Mac.

```bash
# Build
./build.sh

# Run
open build/Caffeine.app

# Or install to Applications
cp -r build/Caffeine.app /Applications/
```

## How It Was Made

This entire app was created through conversation. The user described what they wanted, and the AI assistant (powered by Kimi K2.5 via opencode) wrote the code, debugged it, and refined it based on feedback.

**Key technologies used:**
- Swift
- Cocoa framework
- IOKit power management APIs

## Why This Matters

In an era of bloated software, app stores, and endless subscriptions, this represents a return to **personal computing**. Software created exactly to your specifications, owned by you, modifiable by you.

## License

This is personal software. Use it, modify it, make it yours.

## Publishing releases

Push a `vMAJOR.MINOR.PATCH` tag from `main` to build and publish a release.
Configure the `HOMEBREW_TAP_TOKEN` Actions secret with Contents write access to
`vnglst/homebrew-tap` so the workflow can update the Homebrew cask.
