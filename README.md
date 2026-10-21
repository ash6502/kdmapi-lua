# kdmapi-lua

[KDMAPI (Keppy's Direct MIDI API)](https://github.com/KeppySoftware/OmniMIDI/blob/master/DeveloperContent/KDMAPI.md) wrapper for LuaJIT.

A Lua rewrite of [python-midi/kdmapi](https://github.com/python-midi/kdmapi). It provides LuaJIT FFI bindings for OmniMIDI and a Lua-friendly wrapper around them, plus a small output port (the equivalent of the Python package's Mido backend).

Requires LuaJIT 2.1 (or 2.0) and [OmniMIDI](https://github.com/KeppySoftware/OmniMIDI). No C compiler is needed.

## Installation

Copy the `kdmapi` directory somewhere on your `package.path`, or:

```sh
luarocks make kdmapi-scm-1.rockspec
```

OmniMIDI is loaded the first time a KDMAPI function is called. By default it looks for `OmniMIDI` (`OmniMIDI.dll` on Windows, `libOmniMIDI.so` elsewhere). To use another file, set the `KDMAPI_LIB` environment variable or call `KDMAPI.load(path)` before anything else.

## Instructions

```lua
local KDMAPI = require("kdmapi")

-- Initialize the device
KDMAPI.InitializeKDMAPIStream()

-- Send a short 32-bit MIDI message data (here: note on, middle C, velocity 100)
KDMAPI.SendDirectData(KDMAPI.PackMessage(0x90, 60, 100))

-- Close the device
KDMAPI.TerminateKDMAPIStream()
```

### API

| Function | Notes |
| --- | --- |
| `ReturnKDMAPIVer()` | Returns `major, minor, build, revision`; raises on failure |
| `IsKDMAPIAvailable()` | `true`/`false`; also `false` if OmniMIDI can't be loaded |
| `InitializeKDMAPIStream()` / `TerminateKDMAPIStream()` | Return `true`; raise on failure |
| `ResetKDMAPIStream()` | |
| `SendCustomEvent(event_type, channel, param)` | Returns a boolean |
| `SendDirectData(dword)` / `SendDirectDataNoBuf(dword)` | |
| `SendDirectLongData(data)` | `data` is a byte string, a table of bytes or a `KDMAPI_MIDIHDR`; prepares, sends and unprepares it; returns the MMRESULT |
| `SendDirectLongDataNoBuf(data)` | `data` is a byte string or a table of bytes; returns the MMRESULT |
| `DriverSettings(setting, mode, ptr, size)` | Raw call; returns a boolean |
| `GetSetting(setting)` / `SetSetting(setting, value)` / `ManageSettings([false])` | Helpers for DWORD/BOOL settings |
| `GetDriverDebugInfo()` | Returns the driver's live `KDMAPI_DebugInfo` struct |
| `LoadCustomSoundFontsList(path)` | `path` is a UTF-8 string (sflist, SF2 or SFZ) |
| `timeGetTime64()` | Milliseconds, as a Lua number |
| `modMessage(device_id, msg, user, param1, param2)` | Returns the MMRESULT |
| `PackMessage(status, data1, data2)` or `PackMessage({...})` | Packs up to 3 bytes into a DWORD |
| `NewMIDIHDR(data)` | Allocates a `KDMAPI_MIDIHDR` that keeps its buffer alive |

Constants are in `KDMAPI.MMRESULT` and `KDMAPI.Settings` (`OM_SET`, `OM_GET`, `OM_MAXVOICES`, ...). The raw FFI namespace is available via `require("kdmapi.bindings").lib()`.

## Output port

`kdmapi.output` is the counterpart of the Python package's Mido backend:

```lua
local output = require("kdmapi.output")

for _, device in ipairs(output.get_devices()) do
    print(device.name) -- e.g. "OmniMIDI 4.1.0 Rev. 5"
end

local out = output.open()
out:send({ 0x90, 60, 100 })       -- tables of bytes
out:send("\x80\x3c\x00")          -- byte strings
out:send({ 0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7 }) -- SysEx goes through SendDirectLongDataNoBuf
out:close()
```

`send` also accepts any object with a `bytes()` method that returns a table of bytes. See `examples/play_scale.lua`.

## Differences from the Python package

- `ReturnKDMAPIVer` returns four values instead of a list.
- Windows types are mapped to fixed-width types (`DWORD` is `uint32_t`, `BOOL` is `int32_t`), so the bindings are correct on 64-bit Linux too.
- `KDMAPI_MIDIHDR` has the full `dwReserved[8]` field, so its size matches what `PrepareLongData` checks for. `KDMAPI_DebugInfo` uses the default struct packing, like `OmniMIDI.h`.
- `modMessage` takes plain integers for the `DWORD_PTR` arguments.
- `timeGetTime64` is exposed, and settings helpers were added.

## Tests

The tests run against a mock OmniMIDI library, so they work on Linux without OmniMIDI:

```sh
test/run.sh
```

## License

MIT, see [LICENSE](LICENSE). The original Python package is by Sebastiano Barezzi and is licensed under LGPL-3.0-or-later.
