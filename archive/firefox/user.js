// Chezmoi-managed Firefox startup preferences.
// Source of truth: <chezmoi source>/archive/firefox/user.js
// Installed into the active default profile by
// run_onchange_after_40-firefox-profile.sh.tmpl — edit the SOURCE, never the
// profile copy (the profile copy is overwritten whenever this file changes).
//
// Firefox re-reads user.js at every startup and overlays it onto prefs.js, so
// the prefs below are re-asserted on each launch.

// Enable the declarative chrome/ layer (chrome/userChrome.css,
// chrome/userContent.css). Inert until a chrome/ directory exists in the
// profile; the browser UI itself is themed by the Catppuccin add-on.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
