--
-- KDMAPI (Keppy's Direct MIDI API) wrapper for LuaJIT.
--
-- Lua port of https://github.com/python-midi/kdmapi
--

local ffi = require("ffi")
local bit = require("bit")
local bindings = require("kdmapi.bindings")

local KDMAPI = {
	_VERSION = "1.0.2",
	bindings = bindings,
	MMRESULT = bindings.MMRESULT,
	Settings = bindings.Settings,
}

local MIDIHDR = ffi.typeof("KDMAPI_MIDIHDR")
local MIDIHDR_SIZE = ffi.sizeof(MIDIHDR)
local DWORD1 = ffi.typeof("KDMAPI_DWORD[1]")
local chararr = ffi.typeof("char[?]")

local function lib()
	return bindings.lib()
end

-- Copy a byte string or an array of byte values into a fresh C buffer.
local function to_buffer(data)
	local t = type(data)
	if t == "string" then
		local buf = chararr(#data)
		ffi.copy(buf, data, #data)
		return buf, #data
	elseif t == "table" then
		local buf = chararr(#data)
		for i = 1, #data do
			buf[i - 1] = data[i]
		end
		return buf, #data
	end
	error("expected a string or a table of bytes, got " .. t, 3)
end

-- Encode a UTF-8 string as a NUL-terminated wchar_t string (UTF-16 on
-- Windows, UTF-32 elsewhere).
local function to_wide(s)
	local wide16 = ffi.sizeof("wchar_t") == 2
	local units = {}
	local i, n = 1, #s
	while i <= n do
		local c = s:byte(i)
		local cp, len
		if c < 0x80 then
			cp, len = c, 1
		elseif c >= 0xF0 then
			cp, len = bit.band(c, 0x07), 4
		elseif c >= 0xE0 then
			cp, len = bit.band(c, 0x0F), 3
		elseif c >= 0xC0 then
			cp, len = bit.band(c, 0x1F), 2
		else
			error("invalid UTF-8 in string", 3)
		end
		for j = i + 1, i + len - 1 do
			local cc = s:byte(j)
			if not cc or bit.band(cc, 0xC0) ~= 0x80 then
				error("invalid UTF-8 in string", 3)
			end
			cp = bit.bor(bit.lshift(cp, 6), bit.band(cc, 0x3F))
		end
		i = i + len
		if wide16 and cp >= 0x10000 then
			cp = cp - 0x10000
			units[#units + 1] = 0xD800 + bit.rshift(cp, 10)
			units[#units + 1] = 0xDC00 + bit.band(cp, 0x3FF)
		else
			units[#units + 1] = cp
		end
	end
	local buf = ffi.new("wchar_t[?]", #units + 1)
	for k = 1, #units do
		buf[k - 1] = units[k]
	end
	return buf
end

-- Pack up to 3 MIDI bytes into the 32-bit little-endian DWORD expected by
-- SendDirectData. Accepts either the bytes as arguments or a single table.
function KDMAPI.PackMessage(status, data1, data2)
	if type(status) == "table" then
		status, data1, data2 = status[1], status[2], status[3]
	end
	return bit.bor(
		bit.band(status or 0, 0xFF),
		bit.lshift(bit.band(data1 or 0, 0xFF), 8),
		bit.lshift(bit.band(data2 or 0, 0xFF), 16)
	)
end

-- Return the KDMAPI version from OmniMIDI as the following output:
-- Major.Minor.Build Rev. Revision (eg. 1.30.0 Rev. 51).
-- Returns major, minor, build, revision.
function KDMAPI.ReturnKDMAPIVer()
	local major, minor, build, rev = DWORD1(), DWORD1(), DWORD1(), DWORD1()
	if lib().ReturnKDMAPIVer(major, minor, build, rev) == 0 then
		error("ReturnKDMAPIVer failed", 2)
	end
	return tonumber(major[0]), tonumber(minor[0]), tonumber(build[0]), tonumber(rev[0])
end

-- Checks if KDMAPI is available. You can ignore the output if you want, but
-- you should give the user the choice between WinMM and KDMAPI.
-- Also returns false when the OmniMIDI library can't be loaded at all.
function KDMAPI.IsKDMAPIAvailable()
	if not bindings.is_loaded() and not bindings.try_load() then
		return false
	end
	return lib().IsKDMAPIAvailable() ~= 0
end

-- Initializes OmniMIDI through KDMAPI. (Like midiOutOpen)
function KDMAPI.InitializeKDMAPIStream()
	if lib().InitializeKDMAPIStream() == 0 then
		error("InitializeKDMAPIStream failed", 2)
	end
	return true
end

-- Closes OmniMIDI through KDMAPI. (Like midiOutClose)
function KDMAPI.TerminateKDMAPIStream()
	if lib().TerminateKDMAPIStream() == 0 then
		error("TerminateKDMAPIStream failed", 2)
	end
	return true
end

-- Resets OmniMIDI and all its MIDI channels through KDMAPI. (Like midiOutReset)
function KDMAPI.ResetKDMAPIStream()
	lib().ResetKDMAPIStream()
end

-- Send short messages through KDMAPI. (Like midiOutShortMsg)
function KDMAPI.SendCustomEvent(event_type, channel, param)
	return lib().SendCustomEvent(event_type, channel, param) ~= 0
end

-- Send short messages through KDMAPI. (Like midiOutShortMsg)
function KDMAPI.SendDirectData(message)
	lib().SendDirectData(message)
end

-- Send short messages through KDMAPI like SendDirectData, but bypasses the
-- buffer. (Like midiOutShortMsg)
function KDMAPI.SendDirectDataNoBuf(message)
	lib().SendDirectDataNoBuf(message)
end

-- MIDIHDR -> data buffer, so a buffer lives as long as its header
local anchors = setmetatable({}, { __mode = "k" })

-- Allocate a MIDIHDR describing `data` (a string or a table of bytes).
-- The returned header keeps its data buffer alive.
function KDMAPI.NewMIDIHDR(data)
	local buf, len = to_buffer(data)
	local hdr = MIDIHDR()
	hdr.lpData = buf
	hdr.dwBufferLength = len
	hdr.dwBytesRecorded = len
	anchors[hdr] = buf
	return hdr
end

-- Send long messages through KDMAPI. (Like midiOutLongMsg)
-- `data` is a KDMAPI_MIDIHDR, a string or a table of bytes.
-- Returns the MMRESULT of SendDirectLongData.
function KDMAPI.SendDirectLongData(data)
	local hdr = data
	if not ffi.istype(MIDIHDR, data) then
		hdr = KDMAPI.NewMIDIHDR(data)
	end
	local l = lib()
	local result = l.PrepareLongData(hdr, MIDIHDR_SIZE)
	if result ~= 0 then
		return result
	end
	result = l.SendDirectLongData(hdr, MIDIHDR_SIZE)
	l.UnprepareLongData(hdr, MIDIHDR_SIZE)
	return result
end

-- Send long messages through KDMAPI like SendDirectLongData, but bypasses the
-- buffer. (Like midiOutLongMsg)
-- `data` is a string or a table of bytes. Returns the MMRESULT.
function KDMAPI.SendDirectLongDataNoBuf(data)
	local buf, len = to_buffer(data)
	return lib().SendDirectLongDataNoBuf(buf, len)
end

-- Get or set the current settings for the driver.
-- `value` is a pointer (cdata) to cb_value bytes. Returns a boolean.
function KDMAPI.DriverSettings(setting, mode, value, cb_value)
	return lib().DriverSettings(setting, mode, value, cb_value) ~= 0
end

-- Read a DWORD setting. Returns the value, or nil if the driver refused.
-- (OmniMIDI needs OM_MANAGE to be sent first, see ManageSettings.)
function KDMAPI.GetSetting(setting)
	local value = DWORD1()
	if lib().DriverSettings(setting, bindings.Settings.OM_GET, value, 4) == 0 then
		return nil
	end
	return tonumber(value[0])
end

-- Write a DWORD setting (booleans are converted to 0/1). Returns a boolean.
function KDMAPI.SetSetting(setting, value)
	if type(value) == "boolean" then
		value = value and 1 or 0
	end
	local v = DWORD1(value)
	return lib().DriverSettings(setting, bindings.Settings.OM_SET, v, 4) ~= 0
end

-- Tell OmniMIDI that the settings are managed by this app (OM_MANAGE), or
-- give them back to the configurator (OM_LEAVE) when `manage` is false.
function KDMAPI.ManageSettings(manage)
	local setting = manage == false and bindings.Settings.OM_LEAVE or bindings.Settings.OM_MANAGE
	return lib().DriverSettings(setting, 0, nil, 0) ~= 0
end

-- Get the debug info of the driver (a KDMAPI_DebugInfo struct reference that
-- the driver keeps updating).
function KDMAPI.GetDriverDebugInfo()
	local info = lib().GetDriverDebugInfo()
	if info == nil then
		error("GetDriverDebugInfo failed", 2)
	end
	return info[0]
end

-- Load a custom sflist. (You can also load SF2 and SFZ files)
-- `path` is a UTF-8 string.
function KDMAPI.LoadCustomSoundFontsList(path)
	lib().LoadCustomSoundFontsList(to_wide(tostring(path)))
end

-- timeGetTime, but 64-bit. Returns milliseconds as a Lua number.
function KDMAPI.timeGetTime64()
	return tonumber(lib().timeGetTime64())
end

-- modMessage. Returns the MMRESULT.
function KDMAPI.modMessage(device_id, message, user, param1, param2)
	return lib().modMessage(device_id, message,
		ffi.cast("KDMAPI_DWORD_PTR", user or 0),
		ffi.cast("KDMAPI_DWORD_PTR", param1 or 0),
		ffi.cast("KDMAPI_DWORD_PTR", param2 or 0))
end

-- Load OmniMIDI from a specific path/name instead of the default "OmniMIDI".
KDMAPI.load = bindings.load

return KDMAPI
