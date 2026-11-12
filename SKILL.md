---
name: long-form-breakdown
description: Turn long-form footage into an editor-ready brief, for a human editor or for Claude Code to edit from. Two routes chosen from the footage, one brief shape. Interview route; one long recording (interview, podcast, call, testimonial) becomes a full timestamped transcript plus a fix-notes editor brief PDF with hook references, keep/cut transcript, top-5 clip picks and a capture list. Editor-brief route; a folder of scripted takes (one file per script section, many takes per line) becomes the same PDF with every take marked keep or cut and graphics direction inline. Trigger on "brief this footage", "build the editor brief", "break down this interview", "transcribe and break down", "clips doc for the editor", "trim the repeated takes", "mark the keepers", or /long-form-breakdown. Not for cutting short clips and not for single reels.
metadata:
  requires:
    bins: [ffmpeg, ffprobe, whisper-cli, yt-dlp]
    optional: [google-chrome]
---

# Long-form breakdown

## Purpose

Turn raw long-form footage into one editor brief PDF and one verbatim transcript, so an editor who has never spoken to you can cut the piece without a call. The brief is in the fix-notes convention: black text is kept, red struck text is cut, green boxes are the graphics to add. The same brief works as the spec for an AI edit: hand Claude Code the footage and the brief and say "edit this footage to the brief".

Helper scripts named below live in this skill's own `scripts/` folder, next to this file, not in the workspace `scripts/` folder that holds written scripts.

## Inputs

- Footage: either ONE long recording (interview route) or a FOLDER of scripted takes (editor-brief route). A path to a file or folder. Nested folders are fine.
- The script the footage was filmed from, if there was one (editor-brief route). Paste it or give the path.
- Optional brand context, if the user has it: a note on their voice and tone (so profanity and register are judged correctly), the reference videos they study, and which numbers are confirmed and safe to leave on camera. If none of it exists, ask three quick questions before Step 4: who the video is for, which three videos it should feel like, and which numbers in it are real.
- Target length and platform for the finished piece. Ask if not given.
- Optional: the NLE project file, when the user edits in an NLE and wants the sequence table (Steps, section 4).

## Preflight

1. Brand context: read the user's brand files if the workspace has them (a `brand/` or `00-brand/` folder, a voice note, a references list). If not, carry on and ask the three questions from Inputs when you reach them.
2. `ffmpeg`, `ffprobe`, `whisper-cli` are on PATH. `yt-dlp` is needed only for reference screenshots.
3. A Chrome or Chromium binary for the PDF render. `scripts/render-pdf.sh` looks for `CHROME` in the environment or `.env`, then the standard macOS app paths, then `google-chrome`, `chromium` and `chromium-browser` on PATH. If none is found, the brief ships as HTML and the QA list says so.
4. Transcription engine. Default is local `whisper-cli` (whisper.cpp) with the `ggml-small.en` model in `~/.cache/whisper-cpp/` (README has the one-line download). For a recording over about two hours, or when the local pass is too slow, use Gemini: `GEMINI_API_KEY` must be in `.env`; if it is not, say which variable to add and where a key comes from (Google AI Studio), then continue with the local engine.
5. Pick the route from the footage, not from the phrasing of the request. One long file of a conversation is the interview route. A folder of short files with repeated lines is the editor-brief route. Say which route you picked and why before starting.
6. Do not run transcription on a file you have not probed. Step 1 comes first.

## Steps

### 1. Probe every file, including subfolders

Run `ffprobe` on every media file: duration, resolution, frame rate, audio channel layout. Recording tools often ship several files beside the composed export: a cleaned microphone track (`.m4a`), a video-only camera track, a raw and a trimmed export. Their durations tell you which export is trimmed and which audio is cleanest. Record every file in the file map (Steps, section 4) with the probed resolution and fps, not the nominal one. Sources are often not 16:9; the crop decision must be called out for the editor.

Extract one frame from each file (`ffmpeg -ss <t> -i file -frames:v 1 frame.jpg`) and look at it. You need to know what each file shows: a talking head, a composed screen capture, a face-cam channel. Do not guess from the filename.

### 2. Transcribe

Extract mono audio first: `ffmpeg -i in.mp4 -vn -ac 1 -ar 16000 audio.wav`. For a single long file, cut ten-minute chunks (`-ss` and `-t 600`); per-section files under ten minutes go whole.

Local engine (default): run `whisper-cli -m ~/.cache/whisper-cpp/ggml-small.en.bin -f audio.wav -ml 60 -sow -osrt -of briefs/YYYY-MM-DD-<slug>/<file>` (one segment per utterance, a timestamp on every segment, no merging). Give it the proper nouns to spell with `--prompt "<names>"` (product names, tools, people the speaker names) as the initial prompt; automatic transcription mangles them against an accent.

Gemini engine (optional, multi-hour files): send each chunk inline as base64 to `generateContent` with the key from `.env`. A model fallback loop is mandatory, not optional. Keep a list of current flash models in `.env` as `GEMINI_MODELS`, newest first, and fall through the list on 503, 429 and 404 with a 15 to 30 second sleep between attempts. Re-run only missing outputs; skip any chunk whose transcript already exists. Retry three times on an empty response. Strip any preamble lines that are not transcript. Rebase chunk timestamps to absolute time in code (`offset = chunk_index * 600`). The exact prompts are in `references/transcription-prompts.md`.

Prompt rules by route:

- Interview: two speakers, named, verbatim, one paragraph per turn, `[MM:SS] SPEAKER:` at the start of every turn.
- Scripted shoot: one named speaker, verbatim INCLUDING false starts, self-talk between takes and spoken slates ("okay, this one is the intro"), `[PAUSE]` for any gap over three seconds, one line per utterance starting `[M:SS]`, a new line on every restart. With the local engine, derive `[PAUSE]` from timestamp gaps in post-processing and keep every segment as its own line.

Timestamp resolution check: a fast model sometimes returns uniform ten-second timestamps instead of utterance-level ones. Usable, but write "approximate, cut by ear" wherever that file's timestamps appear in the brief.

Hard rule: never write a take note for a transcript line you have not read. Every keep or cut claim traces to a line you actually looked at.

Save the full transcript as `briefs/YYYY-MM-DD-<slug>/transcript.md` (one section per file on the editor-brief route).

### 3. Read everything, then map

Interview route:

- Read the whole transcript. Map zones with exact boundaries: private chat before the interview, the interview itself, off-record debrief after. Internal zones are listed in the brief as never-publish ranges and are excluded from the cut section entirely.
- Chapter the publishable zone, ten to fifteen chapters per thirty minutes, each with IN, OUT and a one-line title.
- Pick the top five clips. Criteria, in order: hard numbers spoken on camera, emotional peaks, standalone value with zero context, short quotable answers, mechanism stories (how something actually works). Per clip: number, title, IN and OUT from the raw file, duration, pull quote, one editor note, two alternates in a small box.
- Build the hook block: the cold open that runs before the interview proper. Three to five moments pulled from later in the conversation (the hardest number, the boldest claim, the emotional peak, one line that names the guest's credential), each with IN and OUT from the raw file, ordered so the last one opens a loop the interview closes. Fifteen to forty seconds in total. Reference 1's opening sets the shape.

Editor-brief route:

- Read every file's transcript and mark every utterance keep or cut.
- The usual pattern: the speaker slates the section aloud, then restarts a line until happy. The last complete take is usually the keeper. Exceptions: an earlier take matches the script wording better, or is cleaner (no lip smack, no doubled word, better energy). Say which take and why in a small gray parenthetical the editor can read in plain words. Never shorthand like "first two lines"; the editor may not share your first language, and the verbatim text is the clarity.
- Intra-line trims (a doubled first word, an "um", a restart inside a kept line) are struck inside the kept line, not noted separately.

Sweep both routes for:

- Profanity, judged against the user's voice and register (ask if unsure). An isolated swear inside a cut range still gets a red MUST NOT SURVIVE flag, because editors sometimes rescue a cut take for its audio.
- Wrong facts spoken on camera (a wrong version number, a wrong price, a wrong name). Two independent transcription passes agreeing on a surprising phrase counts as confirmation; flag it in red and give the fix (re-record, or cover with a graphic that carries the correct fact).
- Script promises whose payoff got cut. An open loop must land somewhere. If the footage no longer pays it off, give the graphic the job and say so in a green box.
- Take-note details that help the editor: a clap that works as a sync marker, a moment the speaker looks off camera, a section filmed twice on two days with different light.

### 4. References (both routes)

The brief leans on references, so pick them before writing it. Three slots:

- Reference 1, the master: closest match on viewer, genre and length. The brief is built around it.
- Reference 2, the pacing benchmark: best-in-class editing for the format; the audience can differ.
- Reference 3, the tone: how it should feel for this exact viewer.

Interview route: these are hook references. Slot 1 is the hook reference the user names (ask for one if they have none). Slot 3 is the user's most recent published episode when they have one, for house continuity; otherwise a tone reference they name. Slot 2 is a pacing benchmark.

Editor-brief route: use the videos the user names first. To find more, use outlier research: if the vidIQ MCP is connected, run `vidiq_outliers` on the video's concept as one sentence (long form) and pick the highest breakout scores that match the viewer and length; otherwise search YouTube for the concept and rank by views divided by the channel's subscribers. If nothing fits, ask the user for three URLs.

Then take real screenshots; screenshots of the moves beat prose about them. Download the first two minutes of each reference with `scripts/fetch-reference.sh <url> <out-dir>`; it also writes a contact sheet of those two minutes, one frame every two seconds. (Building a sheet by hand: `-vf "fps=1/2,scale=320:-1,tile=8x8"`; check `ffmpeg -filters` for `drawtext` before labelling frames with it, many builds omit it.) Pull the frames that show the named moves (number stamp, floating annotated proof, mini diagram, artefact mockup, screen plus bubble framing, name and credential card, kinetic word pop) and caption each with its exact timestamp in the reference. Four small screenshots per reference in ONE nowrap flex row. Save them to `briefs/YYYY-MM-DD-<slug>/refs/`.

### 5. Build the brief

Write `brief.html` from `references/brief-template.html`. One PDF for both routes, this exact shape:

1. Section 1, the brief: two pages maximum. It IS the brief, one continuous section. Order: the watch-these-three box (clickable links, one line each on what to take), what we are making, THE ONE THING TO TAKE FROM REFERENCE 1 with its moves as a row of captioned screenshots, the same for reference 2, the same for reference 3, pacing and framing notes, technical notes, then the red warnings box. Technical MUST state the sequence and export spec explicitly (resolution, frame rate, and that clips under the sequence resolution get scaled to frame size), the crop decision, the audio channel to use, and caption spellings for every proper noun. Nothing else before the file map.
2. Section 2, the file map: file, what it is or which script section, raw runtime, format (real probed resolution and fps). Optional second table when the user works in an NLE with a project file: the project's relevant sequences, each one's role, THE DELIVERABLE sequence to edit in marked clearly, and any never-publish internal sequences.
3. Section 3, the cut, in the fix-notes convention. Legend box first: black text is keep exactly as filmed; red struck text is do not use (or, when the timeline is pre-assembled, already cut; the legend says which); green ADD box is a graphic or b-roll insert at the exact spot it sits in the transcript; gray parenthetical is a reason or a check-by-ear flag. Then the FULL verbatim transcript with timestamps. Editor-brief route: file by file. Interview route: hook block first, then the interview block, timestamped against the delivered timeline. Takes struck in red, keepers in black, intra-line strikes for partial trims, gray parentheticals for keeper-choice reasons, green boxes placed inline at the line they apply to. The graphics notes are the "adding in" layer; the transcript is what exists.
4. Section 4, notes for the owner, on its own page. The capture list: every screen recording and b-roll shot the on-camera claims need. Rule of thumb: every on-camera claim gets something on screen within two seconds, so every named tool, profile, dashboard, document or artefact in the transcript needs a capture on this list, with the timestamp of the claim. One list; if the user has a team, group it by who records what. Then open decisions: title wording, music, pending assets.

Layout rules, non-negotiable: no heading ever sits alone at the bottom of a page (the template carries `page-break-after: avoid` on h2 and h3 plus keep-together wrappers around a heading and its first content); each file block is glued as a unit; long file blocks start on a new page, except the first block after the legend, which flows so the legend page is not left empty; image rows are a single nowrap flex row of small thumbnails, never big stacked images. Page size: A4 by default, Letter for a US user; the `@page` rule at the top of the template is the one line to change. No em dashes, en dashes or double hyphens anywhere, including inside embedded transcript text (convert a spoken break to an ellipsis).

Show the Section 1 text in chat for approval before rendering.

### 6. Render and read back

`scripts/render-pdf.sh briefs/YYYY-MM-DD-<slug>/brief.html briefs/YYYY-MM-DD-<slug>/brief.pdf`. The script uses Chrome or Chromium headless and prints the page count. Read the rendered pages back (open the PDF with the Read tool) before calling it done. Check that Section 1 fits in two pages, that Section 4 starts on its own page, and that the page count matches what the HTML should produce.

### 7. Verify names and numbers

Published numbers and proper nouns come from a transcription model and can be wrong. Spot-check anything a clip or a claim hangs on against the audio or a frame before it ships. Mark the rest "check by ear at <timestamp>". Anything cited as a result must be a number the user has confirmed; if the speaker said a number nobody has confirmed, flag it, do not silently keep it.

## Output

`briefs/YYYY-MM-DD-<slug>/` containing:

- `transcript.md`, the full verbatim transcript with timestamps.
- `brief.html`, the source of the PDF.
- `brief.pdf`, the editor brief.
- `refs/`, the reference screenshots the HTML embeds.

Copy `brief.pdf` next to the raw footage wherever the editor pulls from, so it sits beside the files it describes. Report: what changed since the last version if this is a revision; the red flags that need a human decision (wrong spoken facts, profanity, missing links, open loops) listed separately from routine notes; then the paths.

## QA checklist

- Route stated and justified from the footage.
- Every media file, including subfolders, appears in the file map with probed resolution and fps.
- Every keep or cut note traces to a transcript line that was read.
- Every kept take is complete; no keeper starts mid-sentence.
- Every swear, wrong fact and open loop is flagged in red with a fix.
- Every named tool, profile, dashboard or artefact in the kept text has a capture on the Section 4 list with a timestamp.
- Three references with real screenshots and timestamps, links clickable.
- Technical notes state sequence spec, export spec, crop, audio channel, caption spellings.
- Section 1 is two pages or fewer; Section 4 starts on its own page; no heading alone at a page foot.
- No em dashes, en dashes or double hyphens in the HTML, PDF or transcript.
- Any `[your number]` style placeholder is listed here as unresolved.
- Say plainly what was not verified (timestamps approximate, a name unchecked, PDF not opened).

## Troubleshooting

- `whisper-cli` returns uniform ten-second timestamps or merges lines: rerun `whisper-cli` with a smaller `-ml` (max segment length); if it persists, mark that file "approximate, cut by ear".
- Gemini returns 503, 429 or 404: the fallback loop should move to the next model in `GEMINI_MODELS`; if every model fails, wait five minutes and rerun; only missing chunks are re-sent.
- Gemini returns an empty body: retry three times, then split the chunk in half.
- Contact sheet fails with "No such filter: drawtext": drop the drawtext label and caption the frames in HTML instead.
- Chrome renders a blank PDF: the HTML path must be absolute in the `file://` URL; check for an unclosed tag near the top of the file.
- `render-pdf.sh` exits 2 with "No Chrome or Chromium found": set `CHROME=<path to the binary>` in `.env`, or install Chrome; until then ship `brief.html` and say the PDF was not rendered.
- A heading lands alone at the foot of a page: wrap the heading and its first block in a `div.keep-together`.
- The footage folder has more takes than the transcript has lines: the transcription merged restarts; rerun that file with utterance-level output before writing any take note.
- `yt-dlp` refuses a reference with a bot-check error: retry once with the `youtube.com/watch?v=` form of the URL, then ask the user for a screenshot of the reference instead.
