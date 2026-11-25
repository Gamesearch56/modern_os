# AI assistant

ModernOS has a built-in chat assistant. Ask it a question, get help with a text, or let it explain something, without opening a browser. You decide which AI answers: one that runs entirely on your own computer, or Google's Gemini or OpenAI's ChatGPT with your own account. The assistant is off until you set it up.

Labels are given in English with the German label in parentheses the first time. You can switch the language in Settings under **Language & Time** (Sprache & Zeit).

## Opening the assistant

- Press **SUPER + A**, or
- click **Assistant** (Assistent) in the bar. It is the robot icon on the left, next to the launcher button.

The chat panel opens on the screen you are working on. It also appears on top of fullscreen games and videos.

- Type into **Ask anything...** (Frag etwas...) and press **Enter** or **Send** (Senden).
- While a reply is being written, **Stop** (Stopp) cancels it. Your question goes back into the text field so you can change it and send it again.
- **Clear chat** (Chat leeren) deletes the conversation.
- The gear, **Assistant settings** (Assistent-Einstellungen), opens Settings > **AI** (KI).
- **Esc** closes the panel.

The assistant answers in the language you write in. A single message can be up to 2000 characters long.

If the assistant has not been set up yet, the panel says **The assistant has to be set up** (Der Assistent muss eingerichtet werden) and offers **Set up assistant** (Assistent einrichten).

## Choosing a provider

Open Settings with **SUPER + I** and go to **AI** (KI), in the **Apps** group. Under **Assistant** (Assistent), pick one of:

| Choice | Where the AI runs | What you need |
|---|---|---|
| Ollama | On your own computer | Nothing but disk space and a reasonably fast computer |
| Gemini | Google's servers | A Google AI Studio API key |
| ChatGPT | OpenAI's servers | An OpenAI platform API key |
| Off (Aus) | Nowhere; the assistant is turned off | |

The assistant starts as **Off**.

## Ollama: an assistant on your own computer

With Ollama, the AI model runs on this computer. Your conversation does not leave it.

### Setting it up

Choose **Ollama**. A short guide, **Set up Ollama** (Ollama einrichten), walks you through two steps:

1. **Install Ollama** (Ollama installieren) opens Ollama in the App Store. Install it there.
2. **Start the service** (Dienst starten): click **Start and download model** (Starten und Modell laden). This starts Ollama and downloads a small model for everyday chat. You are asked for an administrator password, and the download can take a few minutes.

If a step does not finish, simply click its button again.

### Models

- **AI model** (KI-Modell) chooses which installed model answers.
- **Download models** (Modelle laden) is a library of models. Use **Search models** (Modelle suchen), then **Install** (Installieren) or **Delete** (Löschen). Each model has a short note saying what it is good at, for example everyday chat, code, pictures or translation.
- ModernOS also tells you whether a model fits your computer. A model that fits in your graphics memory runs well; a larger one still works but is slower, and some are simply too big.
- The model you are using is marked **In use** (In Verwendung) and cannot be deleted.

Models can take a lot of disk space. Settings > **Storage** (Speicher) shows how much under "AI models".

### Web search with Brave

A model on your computer only knows what it learned when it was made. To let it look up current facts, give it a Brave Search key:

1. Under **Brave API key** (Brave-API-Schlüssel), click **Get API key** (API-Schlüssel holen). The Brave Search website opens, where you can create a key.
2. Paste the key into the field and click **Save** (Speichern). You now see **A key is saved.** (Ein Schlüssel ist gespeichert.)
3. To stop using it, click **Remove** (Entfernen).

From then on, the assistant searches the web on its own when an answer needs it. Web search is offered for Ollama only.

## Gemini and ChatGPT

Both work the same way. You connect your own account with an API key, and replies are charged to that account.

1. Choose **Gemini** or **ChatGPT** under **Assistant**.
2. Click **Get API key** (API-Schlüssel holen). For Gemini this opens Google AI Studio, for ChatGPT the OpenAI platform. Create a key there.
3. Paste the key into the **API key** (API-Schlüssel) field and click **Connect** (Verbinden). Settings then shows **Google AI is connected.** or **ChatGPT is connected.** and hides the key.
4. Pick a model from the list.

- **Sign out** (Abmelden) removes the key from this computer.
- **Add credits** (Guthaben hinzufügen) opens the billing page of your account.

An API key is not the same as a regular subscription. Even with a valid key, your account needs API quota or credits. If it runs out, the assistant tells you so, for example "This account has no API credits left", and Settings shows a matching hint. If the provider is busy, wait a moment and try again.

## Reply options

These options appear for every provider:

- **Thinking** (Nachdenken): the model thinks the question through before it answers. Replies take longer. Off by default.
- **Short replies** (Kurze Antworten): keeps answers to a few lines. Turn it off to allow longer replies. On by default.

## Where your keys are stored

Your API keys are **not** stored in your settings file. They are kept in a separate private file, `~/.config/modern/secrets.json`, that only your own account can read. ModernOS never shows the keys again after you save them.

- To change a key, sign out (or remove it) and paste a new one.
- Calendar logins from the clock widget are stored in the same private file.
- Do not share this file, and do not paste its contents anywhere.

## Privacy in plain words

What happens to your words depends on the provider you choose.

**Ollama**

- Everything happens on this computer. Your questions and the answers are not sent anywhere.
- The only exception is web search: if you saved a Brave key, the search words the assistant chooses are sent to Brave Search. Your Brave key itself is only used by the search helper on your computer and is never given to the AI model.

**Gemini and ChatGPT**

- Your question is sent to Google or OpenAI, together with the recent part of the conversation (up to the last 12 messages), so the AI knows what you were talking about.
- What those companies do with it is governed by their terms for your account.
- Do not send passwords, private documents or other information you would not want to share with that company.

**On your computer**

- The chat history is saved locally so it is still there next time. Only the latest 24 messages are kept.
- **Clear chat** (Chat leeren) deletes the saved history.
- Turning the assistant **Off** stops it from sending anything at all.

For more on how ModernOS handles your data, see [Privacy and security](13-privacy-and-security.md). If the assistant does not answer, see [Troubleshooting](14-troubleshooting.md).
