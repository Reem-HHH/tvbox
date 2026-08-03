# No shrinking rules needed for the MVP.
# Keep the launcher entry point if R8 ever strips reflective lookups.
-keep class ae.kidstv.launcher.MainActivity { *; }
