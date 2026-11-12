# long-form-breakdown

A Claude Code skill that turns raw long-form footage into a detailed editor brief: the full transcript with every take marked keep or cut, the reference videos to match with real screenshots, and the graphics to add at each line. Hand the brief to a human editor, or hand it back to Claude Code with the footage and say "edit this footage to the brief".

## Why a brief

The more direction an editor gets, the fewer revisions you go through. A good brief gives them three reference videos to study, the script to cut the raw footage down to, and notes on graphics, sound, fonts and brand rules. This skill writes that brief for you, and the same brief is what makes an AI edit come out right instead of generic: the references become the benchmark Claude checks its own work against.

## What it does

1. Probes every file in your footage folder (duration, resolution, frame rate, audio) and looks at a frame from each.
2. Transcribes everything locally with Whisper, one line per utterance with timestamps, keeping every false start so the takes are visible.
3. Reads the transcript like an editor reads a script: picks the best take of each line, marks restarts, trailing-off lines and dead pauses as cuts, and flags swearing, wrong facts and promises the cut no longer pays off.
4. Finds three reference videos (the master, the pacing benchmark, the tone), using vidIQ outliers if you have the vidIQ MCP connected, downloads the first two minutes of each and pulls screenshots of the moves worth copying.
5. Suggests the graphics to add at each key line as green boxes in the transcript.
6. Renders one PDF in the fix-notes convention: black text is kept, red struck text is cut, green boxes are graphics to add.

It works on two kinds of footage: one long recording (an interview, podcast or call) or a folder of scripted takes with many attempts per line.

## Requirements

- [Claude Code](https://claude.com/product/claude-code)
- `ffmpeg`, `whisper-cli` (whisper.cpp) and `yt-dlp`: `brew install ffmpeg whisper-cpp yt-dlp` on a Mac
- The Whisper model, once:

```bash
mkdir -p ~/.cache/whisper-cpp && curl -L -o ~/.cache/whisper-cpp/ggml-small.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
```

- Google Chrome or Chromium, for the PDF (without it you get the brief as HTML)
- Optional: the vidIQ MCP connected to Claude Code, for outlier reference research

## Install

```bash
git clone https://github.com/orgrowth/long-form-breakdown ~/.claude/skills/long-form-breakdown
```

## Use

In Claude Code, put your raw video, mic recordings, screen recordings and b-roll in one folder, then say "build the editor brief for this footage" and give it the folder, or type `/long-form-breakdown`. Paste the script you filmed from if there was one. Everything runs on your machine except the reference downloads.

Then, if Claude is editing: drop the brief into the same session with the footage and say "edit this footage to the brief". Lock the base cut before any graphics are made, and every time you fix the same thing twice, add it to your rules so the next brief carries it.

## What's in here

| Path | What it is |
|---|---|
| `SKILL.md` | The skill: routes, steps, the brief layout and the QA checklist |
| `references/brief-template.html` | The HTML template the PDF is rendered from |
| `references/transcription-prompts.md` | Transcription prompts and post-processing rules |
| `scripts/fetch-reference.sh` | Downloads the first two minutes of a reference video and builds a contact sheet |
| `scripts/render-pdf.sh` | Renders the brief to PDF with headless Chrome |

## Licence

MIT. Made by [Orgrowth](https://orgrowth.ai).
