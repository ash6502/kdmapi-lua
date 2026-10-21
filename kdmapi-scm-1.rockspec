rockspec_format = "3.0"
package = "kdmapi"
version = "scm-1"
source = {
	url = "git+https://github.com/ash6502/kdmapi-lua.git",
}
description = {
	summary = "KDMAPI (Keppy's Direct MIDI API) wrapper for LuaJIT",
	detailed = "LuaJIT FFI bindings for OmniMIDI's KDMAPI and a simple MIDI output port. Port of the kdmapi Python package.",
	homepage = "https://github.com/ash6502/kdmapi-lua",
	license = "MIT",
}
dependencies = {
	"lua == 5.1",
}
build = {
	type = "builtin",
	modules = {
		["kdmapi"] = "kdmapi/init.lua",
		["kdmapi.bindings"] = "kdmapi/bindings.lua",
		["kdmapi.output"] = "kdmapi/output.lua",
	},
}
