
-- TZExpand: hotkey-driven timezone expander
-- Configure via the 🕘 menu bar item (settings persist across reloads).
hs.loadSpoon("TZExpand")
spoon.TZExpand:start({
    home = "America/Los_Angeles",              -- your home tz (first run only; menubar overrides)
    extras = { "America/New_York", "Europe/London" }, -- defaults
    hotkey = { mods = {"ctrl", "alt"}, key = "t" },
})
