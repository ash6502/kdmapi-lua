-- Test suite run against test/mock_omnimidi.c. See test/run.sh.
package.path = "./?.lua;./?/init.lua;" .. package.path

local ffi = require("ffi")
local bindings = require("kdmapi.bindings")
local mock = bindings.load(assert(arg[1], "usage: luajit test/test.lua <path to mock lib>"))

local KDMAPI = require("kdmapi")
local output = require("kdmapi.output")

ffi.cdef[[
extern uint32_t last_short, last_short_nobuf, prepared, unprepared, long_len, last_size;
extern uint8_t long_buf[256];
extern wchar_t last_sflist[256];
extern uint32_t custom[3];
extern uintptr_t mod_args[5];
extern int reset_count;
size_t mock_sizeof_midihdr(void);
size_t mock_sizeof_debuginfo(void);
]]

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function long_bytes()
	return ffi.string(mock.long_buf, mock.long_len)
end

test("struct layouts match C", function()
	assert(ffi.sizeof("KDMAPI_MIDIHDR") == tonumber(mock.mock_sizeof_midihdr()))
	assert(ffi.sizeof("KDMAPI_DebugInfo") == tonumber(mock.mock_sizeof_debuginfo()))
end)

test("ReturnKDMAPIVer", function()
	local a, b, c, d = KDMAPI.ReturnKDMAPIVer()
	assert(a == 4 and b == 1 and c == 0 and d == 5)
end)

test("IsKDMAPIAvailable", function()
	assert(KDMAPI.IsKDMAPIAvailable() == true)
end)

test("Initialize/Terminate", function()
	assert(KDMAPI.InitializeKDMAPIStream() == true)
	assert(not pcall(KDMAPI.InitializeKDMAPIStream), "double init should raise")
	assert(KDMAPI.TerminateKDMAPIStream() == true)
	assert(not pcall(KDMAPI.TerminateKDMAPIStream), "double terminate should raise")
end)

test("ResetKDMAPIStream", function()
	local before = mock.reset_count
	KDMAPI.ResetKDMAPIStream()
	assert(mock.reset_count == before + 1)
end)

test("SendCustomEvent", function()
	assert(KDMAPI.SendCustomEvent(0x90, 3, 0xFFFFFFFF) == true)
	assert(mock.custom[0] == 0x90 and mock.custom[1] == 3 and mock.custom[2] == 0xFFFFFFFF)
end)

test("SendDirectData / NoBuf / PackMessage", function()
	KDMAPI.SendDirectData(KDMAPI.PackMessage(0x90, 60, 100))
	assert(mock.last_short == 0x643C90)
	KDMAPI.SendDirectDataNoBuf(KDMAPI.PackMessage({ 0xC1, 5 }))
	assert(mock.last_short_nobuf == 0x05C1)
end)

test("SendDirectLongData", function()
	assert(KDMAPI.SendDirectLongData({ 0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7 }) == 0)
	assert(long_bytes() == "\240\126\127\9\1\247")
	assert(mock.last_size == ffi.sizeof("KDMAPI_MIDIHDR"))
	assert(mock.prepared == mock.unprepared and mock.prepared > 0)
	local hdr = KDMAPI.NewMIDIHDR("\240\1\247")
	collectgarbage()
	assert(KDMAPI.SendDirectLongData(hdr) == 0)
	assert(long_bytes() == "\240\1\247")
end)

test("SendDirectLongDataNoBuf", function()
	assert(KDMAPI.SendDirectLongDataNoBuf("\240\67\16\247") == 0)
	assert(long_bytes() == "\240\67\16\247")
end)

test("DriverSettings", function()
	local S = KDMAPI.Settings
	assert(KDMAPI.GetSetting(S.OM_MAXVOICES) == nil, "unmanaged get should fail")
	assert(KDMAPI.ManageSettings() == true)
	assert(KDMAPI.SetSetting(S.OM_MAXVOICES, 1000) == true)
	assert(KDMAPI.GetSetting(S.OM_MAXVOICES) == 1000)
	assert(KDMAPI.SetSetting(S.OM_ENABLESFX, true) and KDMAPI.GetSetting(S.OM_ENABLESFX) == 1)
	local v = ffi.new("uint32_t[1]")
	assert(KDMAPI.DriverSettings(S.OM_MAXVOICES, S.OM_GET, v, 4) == true and v[0] == 1)
	assert(KDMAPI.ManageSettings(false) == true)
	assert(KDMAPI.GetSetting(S.OM_MAXVOICES) == nil)
end)

test("GetDriverDebugInfo", function()
	local info = KDMAPI.GetDriverDebugInfo()
	assert(info.RenderingTime == 1.5)
	assert(info.ActiveVoices[3] == 7)
	assert(info.CurrentSFList == 2)
	assert(info.AudioLatency == 9.25)
	assert(info.AudioBufferSize == 512)
end)

test("LoadCustomSoundFontsList (UTF-8 -> wchar_t)", function()
	local path = "C:\\sf\\piaño 🎹.sf2"
	KDMAPI.LoadCustomSoundFontsList(path)
	local expect = { 0x43, 0x3A, 0x5C, 0x73, 0x66, 0x5C, 0x70, 0x69, 0x61, 0xF1, 0x6F, 0x20 }
	for i, cp in ipairs(expect) do
		assert(mock.last_sflist[i - 1] == cp, "mismatch at " .. i)
	end
	if ffi.sizeof("wchar_t") == 4 then
		assert(mock.last_sflist[12] == 0x1F3B9)
	else
		assert(mock.last_sflist[12] == 0xD83C and mock.last_sflist[13] == 0xDFB9)
	end
	assert(not pcall(KDMAPI.LoadCustomSoundFontsList, "\255bad"))
end)

test("timeGetTime64", function()
	assert(KDMAPI.timeGetTime64() == 5000000000)
end)

test("modMessage", function()
	assert(KDMAPI.modMessage(0, 7, 1, 2, 3) == 0)
	for i = 0, 4 do
		assert(tonumber(mock.mod_args[i]) == ({ 0, 7, 1, 2, 3 })[i + 1])
	end
end)

test("output port", function()
	local devices = output.get_devices()
	assert(#devices == 1 and devices[1].name == "OmniMIDI 4.1.0 Rev. 5" and devices[1].is_output)
	local out = output.open()
	out:send({ 0x80, 60, 0 })
	assert(mock.last_short == 0x3C80)
	out:send("\176\7\100")
	assert(mock.last_short == 0x6407B0)
	out:send({ bytes = function() return { 0xE0, 0, 64 } end })
	assert(mock.last_short == 0x4000E0)
	out:send({ 0xF0, 0x41, 0xF7 })
	assert(long_bytes() == "\240\65\247")
	out:reset()
	out:close()
	out:close()
	assert(not pcall(out.send, out, { 0x90, 1, 1 }))
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
