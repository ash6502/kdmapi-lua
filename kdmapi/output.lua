--
-- A simple MIDI output port on top of KDMAPI.
--
-- Lua counterpart of kdmapi.mido_backend from the Python package.
--

local KDMAPI = require("kdmapi")

local M = {}

-- List the available output devices, in the same shape as the mido backend.
function M.get_devices()
	local devices = {}

	if KDMAPI.IsKDMAPIAvailable() then
		local maj, min, build, rev = KDMAPI.ReturnKDMAPIVer()
		devices[#devices + 1] = {
			name = string.format("OmniMIDI %d.%d.%d Rev. %d", maj, min, build, rev),
			is_input = false,
			is_output = true,
		}
	end

	return devices
end

local Output = {}
Output.__index = Output
M.Output = Output

-- Open the KDMAPI stream and return an output port.
function M.open()
	KDMAPI.InitializeKDMAPIStream()
	return setmetatable({ closed = false }, Output)
end

-- Normalize a message to a table of bytes. Accepts a table of bytes, a byte
-- string, or an object with a bytes() method (e.g. a mido-style message).
local function message_bytes(message)
	local t = type(message)
	if t == "string" then
		return { message:byte(1, -1) }
	elseif t == "table" then
		if type(message.bytes) == "function" then
			return message:bytes()
		end
		return message
	end
	error("expected a MIDI message (table, string or object with bytes()), got " .. t, 3)
end

-- Send one MIDI message. SysEx messages (starting with 0xF0) go through
-- SendDirectLongDataNoBuf, everything else is packed into a 32-bit DWORD.
function Output:send(message)
	assert(not self.closed, "port is closed")
	local bytes = message_bytes(message)
	if bytes[1] == 0xF0 then
		-- Sysex messages are written as a string.
		KDMAPI.SendDirectLongDataNoBuf(bytes)
	else
		-- The bytes of a message as packed into a 32 bit integer.
		KDMAPI.SendDirectData(KDMAPI.PackMessage(bytes))
	end
end

-- Reset all channels (like midiOutReset).
function Output:reset()
	assert(not self.closed, "port is closed")
	KDMAPI.ResetKDMAPIStream()
end

-- Close the port. Safe to call more than once.
function Output:close()
	if not self.closed then
		self.closed = true
		KDMAPI.TerminateKDMAPIStream()
	end
end

return M
