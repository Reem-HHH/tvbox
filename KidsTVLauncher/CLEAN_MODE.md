# Clean TV Mode testing checklist

1. Launch the app and confirm only video is visible (or a clear error if offline).
2. Move an air mouse or touch the screen: nothing should respond.
3. Press OK: it should start playback if autoplay was blocked; it should not pause a playing video.
4. Press Right/Left: next/previous video should play.
5. Press 1–4: the playlist changes without an app banner.
6. Trigger parent access (see `TESTING.md`). Video should hide before the PIN / parent UI.
7. Create or enter the parent PIN; confirm the parent menu opens only after a correct PIN.
8. Return from the parent menu and confirm playback resumes.
9. Force a bad playlist (optional) and confirm the player skips, then moves channels, rather than looping forever.

YouTube-controlled title, avatar, branding, ads, error messages, or pre-play/end-state UI may still appear. The app does not cover or crop those elements.
