# CardAssist

CardAssist is a voice-first iOS app that helps you decide which credit card to use based on the cards in your wallet, the benefits attached to them, and whether you have already used trackable credits.

The app is built for a hackathon prototype and is meant to be run locally with your own API keys.

## What It Does

- Scans multiple card fronts from a single photo using OpenRouter.
- Lets you confirm detected cards before saving them.
- Uses Firecrawl to research each saved card and split perks into:
  - `benefits`: lounge access, rental coverage, hotel programs, protections, and other ongoing perks
  - `coupons`: trackable credits or discounts like hotel credits, travel credits, DoorDash, Uber, lululemon, and entertainment credits
- Lets you mark coupons as used so the app can reason with that state later.
- Connects to an ElevenLabs agent for real-time voice chat.
- Exposes client tools to Eleven so the agent can:
  - read the user wallet
  - look up relevant benefits for the current question

## Tech Stack

- `SwiftUI` for the iOS app
- `OpenRouter` for multimodal card detection
- `Firecrawl` for live card-benefit research
- `ElevenLabs` for streaming voice chat

## Requirements

- Xcode 16 or newer
- iOS 18.0 deployment target
- An iPhone is recommended for the best camera and microphone experience

## Required Environment Variables

Set these in Xcode, not in source control.

Open Xcode, select the `CardAssist` scheme, then go to:

`Product` -> `Scheme` -> `Edit Scheme...` -> `Run` -> `Arguments` -> `Environment Variables`

Add:

- `OPENROUTER_API_KEY`
- `FIRECRAWL_API_KEY`
- `ELEVEN_AGENT_ID`

Optional:

- `OPENROUTER_MODEL`
  - defaults to `openai/gpt-5-mini`
- `ELEVENLABS_API_KEY`
  - required if your Eleven agent is private

## Eleven Agent Setup

Create an Eleven agent and add these two client tools with these exact names:

- `get_wallet_cards`
- `lookup_wallet_benefits`

`lookup_wallet_benefits` should accept a required string parameter named `question`.

The app already handles those tool calls on the client side. If the names do not match exactly, the tool integration will not work.

Recommended system prompt shape:

- recommend only from the cards in the saved wallet
- use `lookup_wallet_benefits` for merchant, hotel, travel, dining, shopping, wellness, perk, and benefit questions
- use `get_wallet_cards` if the agent needs to confirm what cards are available
- do not invent benefits or credits
- be concise and conversational

## How To Run

1. Open `CardAssist.xcodeproj` in Xcode.
2. Add the environment variables listed above to the `CardAssist` run scheme.
3. Build and run the app on a simulator or physical device.
4. Add cards from the `cards` tab using the `+` button.
5. Review the detected cards and confirm the ones you want to save.
6. Wait for Firecrawl enrichment to populate benefits and coupons.
7. Open the `chat` tab and tap the mic to start talking to the Eleven agent.

## Notes

- API keys are intentionally not stored in the repo.
- The app uses camera and microphone permissions for onboarding and voice chat.
- Most of the app currently lives in `CardAssist/ContentView.swift`.
- The launch video files are intentionally excluded from this repo setup.

## Project Structure

- `CardAssist/`: SwiftUI app source
- `CardAssist.xcodeproj`: Xcode project
- `.gitignore`: local ignore rules
