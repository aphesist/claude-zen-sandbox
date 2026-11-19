// Claude's own Zen profile (claude-zen-sandbox). Read by Zen at every start;
// install.sh copies it to ~/.config/zen/claude/user.js.

// Claudezilla is placed in extensions/ by install.sh: load it without the
// "a program added an add-on" prompt (sideloaded add-ons are off by default).
user_pref("extensions.autoDisableScopes", 0);

// No password manager here: nothing Claude could ever have autofilled for it.
// Log in by hand to the sites you want Claude to use while signed in.
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// A quiet agent browser: blank start, no nagging, no session restore prompts.
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("zen.welcome-screen.seen", true);
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);

// Our patched Claudezilla (orange look, kept tabs, the pixel Claude's mood signal) is
// unsigned: Zen builds don't enforce signing, so allow it here, in this profile only.
// Your own Zen profile keeps requiring signed add-ons. No add-on updates either, so
// addons.mozilla.org never swaps it back for the stock one.
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.update.enabled", false);
user_pref("extensions.update.autoUpdateDefault", false);

// chrome/userChrome.css: the orange tabs and the pixel Claude above them
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// The house accent, so its windows are recognisable at a glance.
user_pref("zen.theme.accent-color", "#d71921");
