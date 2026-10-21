# MacPacker Lab: a preview to try

This branch is my personal test build of MacPacker. It brings my eight open pull requests together, with some further ideas I tried on top of them.

It's here so you can try the changes in the app instead of reading through them first. It isn't meant to replace anything, and nothing in it needs an answer. Each change is yours to take, leave, or ask for as a small pull request of its own, whenever it suits you.

## Trying it

```bash
git clone --branch preview https://github.com/hertza-haeon/MacPacker.git MacPacker-preview
cd MacPacker-preview
git submodule update --init --recursive
open MacPacker.xcodeproj
```

Then run the MacPacker scheme. It builds as your usual Debug app and shares that app's settings. A few labels say "MacPacker Lab", the name of my personal build.

## What's in it

### The open pull requests

- sarensw/MacPacker#339: nothing is left behind when an extraction is cancelled or fails.
- sarensw/MacPacker#351: an archive window shows its own extractions.
- sarensw/MacPacker#352: archives open in tabs, with a New Tab button.
- sarensw/MacPacker#353: extract next to the archive, and select what was extracted.
- sarensw/MacPacker#354: move the archive to the Trash once it is extracted.
- sarensw/MacPacker#355: choose what happens when a name is already taken.
- sarensw/MacPacker#356: what an extraction left when MacPacker stopped is removed at the next start.
- sarensw/MacPacker#357: Finder's actions use the selection's folder, not the window's.

### Further ideas, not proposed yet

**New features**

- **Default app in one click:** a button in Settings ▸ Formats makes MacPacker the default app for archive formats. Unticking a format gives it back to the app that had it before.
- **Test archive** (File menu): checks every file without extracting anything, and names any damaged ones.
- **File name encoding** (View menu): fixes garbled names in archives made with an older encoding.
- **tar.gz, tar.xz and tar.bz2:** created alongside 7z and zip, split into volumes if needed, and edited like a zip or a 7z.
- **Notifications** when a long extraction, compression or test ends while MacPacker is in the background. Settings ▸ General can turn them off or change the minimum length (15 seconds, 30 seconds or 1 minute).

**Settings**

- **A redesigned Settings window:** a sidebar with coloured icons, and panes of grouped switches.
- **It opens in about a third of a second:** the pane on screen is built first, the others just after.

**Speed**

- **7z and xz archives unpack in about a quarter less time on Apple silicon**. MacPacker now uses 7-Zip’s own ARM64 decoder, as 7-Zip’s official builds do. A 900 MB test went from 28.4 s to 21.1 s, the same as the 7zz command-line tool. The bundled 7-Zip code is unchanged, and Intel Macs keep the standard decoder.
- **Large archives**, measured with 100,000 entries:
  - Select All in a big folder no longer freezes the window for minutes when the list reloads.
  - Sorting a folder of 100,000 items takes 0.16 s instead of 0.8 s (~5x faster).
  - Above 5,000 entries, search runs in the background so typing stays smooth.
  - Archives read by XAD open in 1.5 s instead of 5.2 s.
  - The list reuses its rows and its size and date formatters instead of rebuilding them for every cell.

**Fixes**

- A damaged .lz4 file now reports an error, instead of a successful extraction with nothing written.
- Save and Save As are greyed out on archives that can't be saved, instead of doing nothing.
- VoiceOver names the buttons that show only an icon, and the menus in Settings.

## Notes

- Everything works in the App Store version's sandbox, with no new entitlements.
- Each change is a commit of its own, and the logic behind it is covered by tests. Commits starting with `local:` are the further ideas; those marked `wip` only join the pull requests together for this build.

Thank you for MacPacker. I've enjoyed working in its code, and I'm happy to adapt any of this to where you want the app to go.
