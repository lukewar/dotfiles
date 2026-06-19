--- === TZExpand ===
---
--- Hotkey-driven multi-timezone expander for typed times.
--- Type "9pm" (or "9", "9:00", "9 pm PT", etc.) in any text input,
--- press the hotkey, and it expands to
---     9pm PT (12am ET / 5am GMT)
---
--- Usage:
---     hs.loadSpoon("TZExpand")
---     spoon.TZExpand:setHome("America/Los_Angeles")
---     spoon.TZExpand:setExtras({"America/New_York", "GMT"})
---     spoon.TZExpand:bindHotkey({"ctrl", "alt"}, "t")

local obj = {}
obj.__index = obj

obj.name = "TZExpand"
obj.version = "1.0.0"
obj.author = "Fernie <fernie@users.noreply.github.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.home = "America/Los_Angeles"
obj.extras = { "America/New_York", "GMT" }
obj.separator = " / "
obj.maxExtensions = 4

-- ----------------------------------------------------------------------------
-- Timezone abbreviations
-- ----------------------------------------------------------------------------

local TZ_LABEL = {
    ["America/Los_Angeles"] = "PT",
    ["America/Denver"]      = "MT",
    ["America/Chicago"]     = "CT",
    ["America/New_York"]    = "ET",
    ["America/Toronto"]     = "ET",
    ["Europe/London"]       = "UK",
    ["GMT"]                 = "GMT",
    ["UTC"]                 = "UTC",
    ["Europe/Berlin"]       = "CET",
    ["Europe/Paris"]        = "CET",
    ["Europe/Madrid"]       = "CET",
    ["Europe/Amsterdam"]    = "CET",
    ["Asia/Tokyo"]          = "JST",
    ["Asia/Shanghai"]       = "CST",
    ["Asia/Kolkata"]        = "IST",
    ["Asia/Jerusalem"]      = "IL",
    ["Australia/Sydney"]    = "AET",
}

-- Inverse map (abbrev → canonical IANA) used when the user types "9pm PT".
-- Note: "GMT"/"BST" both map to Europe/London so they respect DST.
local LABEL_TZ = {
    PT = "America/Los_Angeles", PST = "America/Los_Angeles", PDT = "America/Los_Angeles",
    MT = "America/Denver",      MST = "America/Denver",      MDT = "America/Denver",
    CT = "America/Chicago",     CST = "America/Chicago",     CDT = "America/Chicago",
    ET = "America/New_York",    EST = "America/New_York",    EDT = "America/New_York",
    UK = "Europe/London",       GMT = "Europe/London",       BST = "Europe/London",
    UTC = "UTC",
    CET = "Europe/Berlin",      CEST = "Europe/Berlin",
    JST = "Asia/Tokyo",
    IST = "Asia/Kolkata",
    IL  = "Asia/Jerusalem",    IDT = "Asia/Jerusalem",
}

local function labelFor(tz) return TZ_LABEL[tz] or tz end

local function formatTime(h, m)
    local ampm = (h < 12) and "am" or "pm"
    local h12 = h % 12
    if h12 == 0 then h12 = 12 end
    if m == 0 then
        return string.format("%d%s", h12, ampm)
    else
        return string.format("%d:%02d%s", h12, m, ampm)
    end
end

-- ----------------------------------------------------------------------------
-- Parser
-- ----------------------------------------------------------------------------

-- Accepts: "9", "9:00", "9pm", "9 pm", "9pm PT", "9:30 pm PT", "21:30",
-- with surrounding whitespace.
local function parse(input)
    if not input then return nil end
    local s = input:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    -- hour [:min] [am/pm] [tz]
    local h, m, ap, tz = s:match("^(%d%d?):?(%d?%d?)%s*([aApP]?[mM]?)%s*([%a/_%-]*)$")
    if not h then return nil end
    h = tonumber(h)
    if not h or h < 0 or h > 23 then return nil end
    m = tonumber(m) or 0
    if m < 0 or m > 59 then return nil end
    ap = (ap or ""):lower()
    if ap == "a" then ap = "am" elseif ap == "p" then ap = "pm" end

    -- Promote h to 24-hour when am/pm is provided.
    if ap == "pm" and h < 12 then h = h + 12
    elseif ap == "am" and h == 12 then h = 0 end

    if h > 23 then return nil end

    local sourceTZ = nil
    if tz and tz ~= "" then
        sourceTZ = LABEL_TZ[tz:upper()] or tz
    end
    return { hour = h, min = m, ampm = ap, sourceTZ = sourceTZ }
end

-- ----------------------------------------------------------------------------
-- Expansion
-- ----------------------------------------------------------------------------

-- Returns the wall-clock time-of-day (hour, min) in `tzTarget` of the
-- moment that is `parsed.hour:parsed.min` wall-clock today in `tzSource`.
local function convertWallclock(parsed, tzSource, tzTarget)
    if tzSource == tzTarget then return parsed.hour, parsed.min end
    -- Find a UTC unix timestamp that, when formatted in tzSource, reads
    -- as parsed.hour:parsed.min today.
    local nowUtc = os.time(os.date("!*t"))
    local todayUtc = os.date("!*t", nowUtc)
    -- Compose a candidate UTC moment using today's UTC date but the
    -- requested hour:min, then nudge by the source-tz offset.
    todayUtc.hour = parsed.hour; todayUtc.min = parsed.min; todayUtc.sec = 0
    -- os.time(table) interprets table as local time; convert via
    -- os.date "!" round-trip to treat it as UTC.
    local candidate = os.time(todayUtc)
    -- Compensate: candidate is "today H:M local"; we want "today H:M UTC".
    local localEpoch = os.time()
    local localUtcDiff = os.difftime(localEpoch, os.time(os.date("!*t", localEpoch)))
    candidate = candidate + localUtcDiff -- now candidate = today H:M UTC

    -- Subtract source-tz offset to get the absolute UTC moment.
    local function offsetOf(tz, atUtc)
        local p = io.popen(string.format("TZ=%q date -r %d '+%%z'", tz, atUtc))
        if not p then return 0 end
        local out = p:read("*l") or "+0000"; p:close()
        local sign, hh, mm = out:match("([%+%-])(%d%d)(%d%d)")
        if not sign then return 0 end
        local secs = tonumber(hh) * 3600 + tonumber(mm) * 60
        return sign == "-" and -secs or secs
    end
    local sourceOff = offsetOf(tzSource, candidate)
    local absUtc = candidate - sourceOff

    -- Format that absolute UTC moment in tzTarget.
    local p = io.popen(string.format("TZ=%q date -r %d '+%%H %%M'", tzTarget, absUtc))
    if not p then return parsed.hour, parsed.min end
    local out = p:read("*l") or ""; p:close()
    local hh, mm = out:match("(%d+)%s+(%d+)")
    return tonumber(hh) or parsed.hour, tonumber(mm) or parsed.min
end

local function expand(self, parsed)
    local sourceTZ = parsed.sourceTZ or self.home
    local home = formatTime(parsed.hour, parsed.min) .. " " .. labelFor(sourceTZ)

    local parts = {}
    -- If user explicitly named a source TZ different from home, include home first.
    if parsed.sourceTZ and parsed.sourceTZ ~= self.home then
        local h, m = convertWallclock(parsed, sourceTZ, self.home)
        table.insert(parts, formatTime(h, m) .. " " .. labelFor(self.home))
    end
    for _, tz in ipairs(self.extras) do
        if tz ~= sourceTZ then
            local h, m = convertWallclock(parsed, sourceTZ, tz)
            table.insert(parts, formatTime(h, m) .. " " .. labelFor(tz))
        end
    end

    if #parts == 0 then return home end
    return home .. " (" .. table.concat(parts, self.separator) .. ")"
end

-- ----------------------------------------------------------------------------
-- Selection capture + paste
-- ----------------------------------------------------------------------------

-- Grab the currently selected text via ⌘C. If there's no selection,
-- extend it backwards by `extensions` words first (each ⌥⇧←).
local function captureSelection(extensions)
    local pb = hs.pasteboard
    local snapshot = pb.readAllData()
    local sentinel = "\1TZEXPAND\1" -- never matches real content
    pb.setContents(sentinel)
    local beforeCount = pb.changeCount()

    if extensions > 0 then
        for _ = 1, extensions do
            hs.eventtap.keyStroke({"alt", "shift"}, "left", 0)
        end
    end
    hs.eventtap.keyStroke({"cmd"}, "c", 0)

    -- Poll for pasteboard update (up to ~250ms).
    local got = nil
    for _ = 1, 25 do
        hs.timer.usleep(10000)
        if pb.changeCount() ~= beforeCount then
            local s = pb.getContents()
            if s and s ~= sentinel then got = s end
            break
        end
    end

    -- Restore snapshot.
    if snapshot then pb.writeAllData(snapshot) else pb.clearContents() end
    return got
end

local function pasteText(text)
    local pb = hs.pasteboard
    local snapshot = pb.readAllData()
    pb.setContents(text)
    hs.eventtap.keyStroke({"cmd"}, "v", 0)
    hs.timer.doAfter(0.4, function()
        if snapshot then pb.writeAllData(snapshot) else pb.clearContents() end
    end)
end

-- ----------------------------------------------------------------------------
-- Public API
-- ----------------------------------------------------------------------------

-- Exposed for testing/debugging.
obj.parse = parse
function obj:_expand(parsed) return expand(self, parsed) end

function obj:setHome(tz) self.home = tz; return self end
function obj:setExtras(tzs) self.extras = tzs; return self end
function obj:setSeparator(sep) self.separator = sep; return self end

-- Convenience: load settings, bind hotkey, start menubar in one call.
-- Settings persisted via the menubar override values from init.lua.
function obj:start(opts)
    opts = opts or {}
    if opts.home then self.home = opts.home end
    if opts.extras then self.extras = opts.extras end
    if opts.separator then self.separator = opts.separator end
    self:loadSettings()
    if opts.hotkey then self:bindHotkey(opts.hotkey.mods or {"ctrl","alt"}, opts.hotkey.key or "t") end
    self:startMenuBar()
    return self
end

function obj:trigger()
    -- Try existing selection first.
    local sel = captureSelection(0)
    if sel and sel ~= "" then
        local parsed = parse(sel)
        if parsed then pasteText(expand(self, parsed)); return end
    end
    -- Grow the selection until it parses, or give up.
    for i = 1, self.maxExtensions do
        sel = captureSelection(i)
        if sel and sel ~= "" then
            local parsed = parse(sel)
            if parsed then pasteText(expand(self, parsed)); return end
        end
    end
    hs.alert.show("TZExpand: couldn't parse a time near the cursor", 1)
end

function obj:bindHotkey(mods, key)
    if self._hk then self._hk:delete() end
    self._hk = hs.hotkey.bind(mods, key, function() self:trigger() end)
    return self
end

-- ----------------------------------------------------------------------------
-- Settings persistence + menubar UI
-- ----------------------------------------------------------------------------

local SETTINGS_KEY = "TZExpandSpoonSettings"

function obj:loadSettings()
    local s = hs.settings.get(SETTINGS_KEY)
    if type(s) ~= "table" then return self end
    if s.home   then self.home   = s.home end
    if s.extras then self.extras = s.extras end
    if s.separator then self.separator = s.separator end
    return self
end

function obj:saveSettings()
    hs.settings.set(SETTINGS_KEY, {
        home = self.home, extras = self.extras, separator = self.separator,
    })
    return self
end

local POPULAR_TZS = {
    "America/Los_Angeles", "America/Denver", "America/Chicago", "America/New_York",
    "America/Toronto", "America/Mexico_City", "America/Sao_Paulo",
    "Europe/London", "Europe/Amsterdam", "Europe/Berlin", "Europe/Paris", "Europe/Madrid", "Europe/Athens",
    "UTC", "GMT",
    "Asia/Dubai", "Asia/Jerusalem", "Asia/Kolkata", "Asia/Singapore", "Asia/Shanghai", "Asia/Tokyo",
    "Australia/Sydney", "Pacific/Auckland", "Pacific/Honolulu",
}

local function tzChoices(exclude)
    local out, seen = {}, {}
    if exclude then for _, e in ipairs(exclude) do seen[e] = true end end
    for _, tz in ipairs(POPULAR_TZS) do
        if not seen[tz] then
            table.insert(out, { text = tz, subText = "label: " .. (TZ_LABEL[tz] or tz) })
        end
    end
    return out
end

local function pickTimezone(prompt, exclude, onPick)
    local chooser = hs.chooser.new(function(choice)
        if choice then onPick(choice.text) end
    end)
    chooser:placeholderText(prompt)
    chooser:choices(tzChoices(exclude))
    chooser:searchSubText(true)
    chooser:show()
end

local function buildMenu(self)
    local items = {}
    table.insert(items, { title = "Home: " .. self.home .. " (" .. (TZ_LABEL[self.home] or self.home) .. ")", disabled = true })
    table.insert(items, { title = "Change home timezone…", fn = function()
        pickTimezone("Home timezone", nil, function(tz)
            self.home = tz; self:saveSettings(); hs.alert.show("Home: " .. tz, 1)
        end)
    end })
    table.insert(items, { title = "-" })
    table.insert(items, { title = "Extra timezones:", disabled = true })
    for i, tz in ipairs(self.extras) do
        table.insert(items, {
            title = "  " .. tz .. " (" .. (TZ_LABEL[tz] or tz) .. ")",
            menu = {
                { title = "Remove", fn = function()
                    table.remove(self.extras, i); self:saveSettings()
                end },
                { title = "Move up", disabled = (i == 1), fn = function()
                    self.extras[i], self.extras[i-1] = self.extras[i-1], self.extras[i]
                    self:saveSettings()
                end },
                { title = "Move down", disabled = (i == #self.extras), fn = function()
                    self.extras[i], self.extras[i+1] = self.extras[i+1], self.extras[i]
                    self:saveSettings()
                end },
            },
        })
    end
    table.insert(items, { title = "Add extra timezone…", fn = function()
        local excl = { self.home }
        for _, t in ipairs(self.extras) do table.insert(excl, t) end
        pickTimezone("Add timezone", excl, function(tz)
            table.insert(self.extras, tz); self:saveSettings()
            hs.alert.show("Added " .. tz, 1)
        end)
    end })
    table.insert(items, { title = "-" })
    table.insert(items, { title = "Test expand…", fn = function()
        local btn, txt = hs.dialog.textPrompt("TZExpand test", "Enter a time (e.g., 9pm, 9:30 pm PT):", "9pm", "OK", "Cancel")
        if btn == "OK" and txt and txt ~= "" then
            local p = parse(txt)
            if p then hs.alert.show(expand(self, p), 3)
            else hs.alert.show("Couldn't parse: " .. txt, 2) end
        end
    end })
    table.insert(items, { title = "Edit ~/.hammerspoon/init.lua", fn = function()
        hs.execute("open -t ~/.hammerspoon/init.lua")
    end })
    table.insert(items, { title = "Reload Hammerspoon", fn = function() hs.reload() end })
    return items
end

function obj:startMenuBar()
    if self._menu then self._menu:delete() end
    self._menu = hs.menubar.new()
    if not self._menu then return self end
    self._menu:setTitle("🕘")
    self._menu:setTooltip("TZExpand")
    self._menu:setMenu(function() return buildMenu(self) end)
    return self
end

function obj:stopMenuBar()
    if self._menu then self._menu:delete(); self._menu = nil end
    return self
end

return obj