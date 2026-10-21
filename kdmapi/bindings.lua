--
-- OmniMIDI (KDMAPI) C bindings for LuaJIT.
--
-- Source: https://github.com/KeppySoftware/OmniMIDI/blob/master/OmniMIDI/OmniMIDI.h
--
-- The shared library is loaded lazily, on the first access to a function,
-- so this module can be required on machines without OmniMIDI installed.
--

local ffi = require("ffi")

local M = {}

-- Windows types are spelled out with fixed-width types: DWORD is 32-bit on
-- Windows, while C `unsigned long` is 64-bit on Linux/macOS.
ffi.cdef[[
typedef int32_t  KDMAPI_BOOL;
typedef uint32_t KDMAPI_DWORD;
typedef uint32_t KDMAPI_UINT;
typedef uint64_t KDMAPI_DWORD64;
typedef uintptr_t KDMAPI_DWORD_PTR;
typedef uint32_t KDMAPI_MMRESULT;

#pragma pack(push, 1)
/* mmsystem.h is byte-packed */
typedef struct KDMAPI_MIDIHDR {
	char *lpData;
	KDMAPI_DWORD dwBufferLength;
	KDMAPI_DWORD dwBytesRecorded;
	KDMAPI_DWORD_PTR dwUser;
	KDMAPI_DWORD dwFlags;
	struct KDMAPI_MIDIHDR *lpNext;
	KDMAPI_DWORD_PTR reserved;
	KDMAPI_DWORD dwOffset;
	KDMAPI_DWORD_PTR dwReserved[8];
} KDMAPI_MIDIHDR;
#pragma pack(pop)

/* OmniMIDI.h uses the default packing for this one */
typedef struct KDMAPI_DebugInfo {
	float RenderingTime;
	KDMAPI_DWORD ActiveVoices[16];
	double ASIOInputLatency;
	double ASIOOutputLatency;
	double HealthThreadTime;
	double ATThreadTime;
	double EPThreadTime;
	double CookedThreadTime;
	KDMAPI_DWORD CurrentSFList;
	double AudioLatency;
	KDMAPI_DWORD AudioBufferSize;
} KDMAPI_DebugInfo;
]]

-- All exports are WINAPI (__stdcall); LuaJIT ignores that outside 32-bit x86.
ffi.cdef[[
// Return the KDMAPI version from OmniMIDI as the following output: Major.Minor.Build Rev. Revision (eg. 1.30.0 Rev. 51).
KDMAPI_BOOL __stdcall ReturnKDMAPIVer(KDMAPI_DWORD *Major, KDMAPI_DWORD *Minor, KDMAPI_DWORD *Build, KDMAPI_DWORD *Revision);

// Checks if KDMAPI is available. You can ignore the output if you want, but you should give the user the choice between WinMM and KDMAPI.
KDMAPI_BOOL __stdcall IsKDMAPIAvailable(void);

// Initializes OmniMIDI through KDMAPI. (Like midiOutOpen)
KDMAPI_BOOL __stdcall InitializeKDMAPIStream(void);

// Closes OmniMIDI through KDMAPI. (Like midiOutClose)
KDMAPI_BOOL __stdcall TerminateKDMAPIStream(void);

// Resets OmniMIDI and all its MIDI channels through KDMAPI. (Like midiOutReset)
void __stdcall ResetKDMAPIStream(void);

// Send short messages through KDMAPI. (Like midiOutShortMsg)
KDMAPI_BOOL __stdcall SendCustomEvent(KDMAPI_DWORD eventtype, KDMAPI_DWORD chan, KDMAPI_DWORD param);

// Send short messages through KDMAPI. (Like midiOutShortMsg)
void __stdcall SendDirectData(KDMAPI_DWORD dwMsg);

// Send short messages through KDMAPI like SendDirectData, but bypasses the buffer. (Like midiOutShortMsg)
void __stdcall SendDirectDataNoBuf(KDMAPI_DWORD dwMsg);

// Send long messages through KDMAPI. (Like midiOutLongMsg)
KDMAPI_UINT __stdcall SendDirectLongData(KDMAPI_MIDIHDR *IIMidiHdr, KDMAPI_UINT IIMidiHdrSize);

// Send long messages through KDMAPI like SendDirectLongData, but bypasses the buffer. (Like midiOutLongMsg)
KDMAPI_UINT __stdcall SendDirectLongDataNoBuf(char *MidiHdrData, KDMAPI_DWORD MidiHdrDataLen);

// Prepares the long data, and locks its memory to prevent apps from writing to it.
KDMAPI_UINT __stdcall PrepareLongData(KDMAPI_MIDIHDR *IIMidiHdr, KDMAPI_UINT IIMidiHdrSize);

// Unlocks the memory, and unprepares the long data.
KDMAPI_UINT __stdcall UnprepareLongData(KDMAPI_MIDIHDR *IIMidiHdr, KDMAPI_UINT IIMidiHdrSize);

// Get or set the current settings for the driver.
KDMAPI_BOOL __stdcall DriverSettings(KDMAPI_DWORD Setting, KDMAPI_DWORD Mode, void *Value, KDMAPI_UINT cbValue);

// Get a pointer to the debug info of the driver.
KDMAPI_DebugInfo * __stdcall GetDriverDebugInfo(void);

// Load a custom sflist. (You can also load SF2 and SFZ files)
void __stdcall LoadCustomSoundFontsList(wchar_t *Directory);

// timeGetTime, but 64-bit
KDMAPI_DWORD64 __stdcall timeGetTime64(void);

// modMessage
KDMAPI_MMRESULT __stdcall modMessage(KDMAPI_UINT uDeviceID, KDMAPI_UINT uMsg, KDMAPI_DWORD_PTR dwUser, KDMAPI_DWORD_PTR dwParam1, KDMAPI_DWORD_PTR dwParam2);
]]

M.MMRESULT = {
	MMSYSERR_NOERROR = 0,
	MMSYSERR_ERROR = 1,
	MMSYSERR_BADDEVICEID = 2,
	MMSYSERR_NOTENABLED = 3,
	MMSYSERR_ALLOCATED = 4,
	MMSYSERR_INVALHANDLE = 5,
	MMSYSERR_NODRIVER = 6,
	MMSYSERR_NOMEM = 7,
	MMSYSERR_NOTSUPPORTED = 8,
	MMSYSERR_BADERRNUM = 9,
	MMSYSERR_INVALFLAG = 10,
	MMSYSERR_INVALPARAM = 11,
	MMSYSERR_HANDLEBUSY = 12,
	MMSYSERR_INVALIDALIAS = 13,
	MMSYSERR_BADDB = 14,
	MMSYSERR_KEYNOTFOUND = 15,
	MMSYSERR_READERROR = 16,
	MMSYSERR_WRITEERROR = 17,
	MMSYSERR_DELETEERROR = 18,
	MMSYSERR_VALNOTFOUND = 19,
	MMSYSERR_NODRIVERCB = 20,
	WAVERR_BADFORMAT = 32,
	WAVERR_STILLPLAYING = 33,
	WAVERR_UNPREPARED = 34,
	MIDIERR_UNPREPARED = 64,
	MIDIERR_STILLPLAYING = 65,
	MIDIERR_NOMAP = 66,
	MIDIERR_NOTREADY = 67,
	MIDIERR_NODEVICE = 68,
	MIDIERR_INVALIDSETUP = 69,
	MIDIERR_BADOPENMODE = 70,
	MIDIERR_DONT_CONTINUE = 71,
}

-- DriverSettings modes and setting IDs (OmniMIDI.h)
M.Settings = {
	OM_SET = 0x0,
	OM_GET = 0x1,
	OM_MANAGE = 0x2,
	OM_LEAVE = 0x3,

	OM_CAPFRAMERATE = 0x10000,
	OM_DEBUGMMODE = 0x10001,
	OM_DISABLEFADEOUT = 0x10002,
	OM_DONTMISSNOTES = 0x10003,
	OM_ENABLESFX = 0x10004,
	OM_FULLVELOCITY = 0x10005,
	OM_IGNOREVELOCITYRANGE = 0x10006,
	OM_IGNOREALLEVENTS = 0x10007,
	OM_IGNORESYSEX = 0x10008,
	OM_IGNORESYSRESET = 0x10009,
	OM_LIMITRANGETO88 = 0x10010,
	OM_MT32MODE = 0x10011,
	OM_MONORENDERING = 0x10012,
	OM_NOTEOFF1 = 0x10013,
	OM_EVENTPROCWITHAUDIO = 0x10014,
	OM_SINCINTER = 0x10015,
	OM_SLEEPSTATES = 0x10016,
	OM_AUDIOBITDEPTH = 0x10017,
	OM_AUDIOFREQ = 0x10018,
	OM_CURRENTENGINE = 0x10019,
	OM_BUFFERLENGTH = 0x10020,
	OM_MAXRENDERINGTIME = 0x10021,
	OM_MINIGNOREVELRANGE = 0x10022,
	OM_MAXIGNOREVELRANGE = 0x10023,
	OM_OUTPUTVOLUME = 0x10024,
	OM_TRANSPOSE = 0x10025,
	OM_MAXVOICES = 0x10026,
	OM_SINCINTERCONV = 0x10027,
	OM_OVERRIDENOTELENGTH = 0x10028,
	OM_NOTELENGTH = 0x10029,
	OM_ENABLEDELAYNOTEOFF = 0x10030,
	OM_DELAYNOTEOFFVAL = 0x10031,
	OM_CHANUPDLENGTH = 0x10032,
	OM_UNLOCKCHANS = 0x10033,
}

M.default_lib_name = "OmniMIDI"

local lib

-- Load the OmniMIDI shared library. `name` may be a bare name ("OmniMIDI",
-- resolved as OmniMIDI.dll / libOmniMIDI.so) or a full path. Calling it again
-- replaces the previously loaded library.
function M.load(name)
	lib = ffi.load(name or os.getenv("KDMAPI_LIB") or M.default_lib_name)
	return lib
end

-- Like load(), but returns nil plus an error message instead of raising.
function M.try_load(name)
	local ok, res = pcall(M.load, name)
	if ok then
		return res
	end
	return nil, res
end

function M.is_loaded()
	return lib ~= nil
end

-- Return the loaded library namespace, loading the default one if needed.
function M.lib()
	return lib or M.load()
end

return M
