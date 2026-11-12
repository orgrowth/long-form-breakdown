# Transcription prompts

Use these when the engine accepts a prompt (Gemini). With the local engine (`whisper-cli`), the "spell these" list goes in as the initial prompt and the rest is applied in post-processing as described in each section.

## Interview route

```
Transcribe this audio verbatim. There are two speakers: {SPEAKER_A} and {SPEAKER_B}. Name each turn with the speaker in capitals. One paragraph per turn. Start every turn with the timestamp of its first word in the form [MM:SS] SPEAKER: text. Keep filler words, repetitions and false starts. Do not summarise. Do not add commentary before or after the transcript. Spell these names exactly: {PROPER_NOUNS}.
```

Post-processing, both engines: rebase each chunk's timestamps to absolute time (`offset = chunk_index * 600` seconds), strip any line that is not a transcript turn, join the chunks in order.

## Scripted shoot route

```
Transcribe this audio verbatim. One speaker: {SPEAKER}. Include every false start, restart, self-talk between takes and spoken slate such as "okay, this one is the intro". Write [PAUSE] on its own line for any silence longer than three seconds. One line per utterance, each starting with its timestamp in the form [M:SS]. Start a new line on every restart, even a restart of the same sentence. Do not merge takes. Do not clean up grammar. Do not summarise. Do not add commentary. Spell these names exactly: {PROPER_NOUNS}.
```

Post-processing with the local engine, which does not take instructions:

1. Run `whisper-cli` with `-ml 60 -sow -osrt` for utterance-level output with a timestamp on every segment and no merging.
2. Insert `[PAUSE]` on its own line wherever the gap between one segment's end and the next segment's start exceeds three seconds.
3. Keep every segment as its own line. Never join two segments, even when they read as one sentence; a restart is only visible as two lines.
4. Apply the proper-noun spellings as a find-and-replace list the user has confirmed.
5. Read the result against the audio for the first two files before trusting it for the rest; local models drop some false starts, and a dropped false start hides a take boundary.

## Gemini fallback loop, requirements

- `GEMINI_API_KEY` from `.env`, never from chat.
- `GEMINI_MODELS` from `.env`, a comma-separated list, newest flash model first.
- Chunks of ten minutes of 16 kHz mono audio, sent inline as base64 (about 3.5 MB per chunk at 48 kbps).
- On HTTP 503, 429 or 404, sleep 15 to 30 seconds and try the next model in the list; wrap to the first model after the last.
- On an empty response, retry the same model up to three times.
- Skip any chunk whose transcript file already exists, so a rerun only fills gaps.
- Strip preamble lines that are not transcript before saving.
