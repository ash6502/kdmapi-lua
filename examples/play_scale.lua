-- Play a C major scale through OmniMIDI.
-- Run from the repository root: luajit examples/play_scale.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local ffi = require("ffi")
local output = require("kdmapi.output")

local sleep
if ffi.os == "Windows" then
	ffi.cdef("void __stdcall Sleep(uint32_t ms);")
	sleep = function(ms) ffi.C.Sleep(ms) end
else
	ffi.cdef("int usleep(uint32_t usec);")
	sleep = function(ms) ffi.C.usleep(ms * 1000) end
end

local devices = output.get_devices()
if #devices == 0 then
	error("KDMAPI is not available, is OmniMIDI installed?")
end
print("Using " .. devices[1].name)

local out = output.open()
out:send({ 0xC0, 0 }) -- program change: acoustic grand piano
for _, note in ipairs({ 60, 62, 64, 65, 67, 69, 71, 72 }) do
	out:send({ 0x90, note, 100 })
	sleep(250)
	out:send({ 0x80, note, 0 })
end
out:close()
