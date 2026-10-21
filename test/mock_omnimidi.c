/* Minimal stand-in for OmniMIDI used by the test suite. Records the last calls. */
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <wchar.h>

#pragma pack(push, 1)
typedef struct MIDIHDR {
	char *lpData;
	uint32_t dwBufferLength, dwBytesRecorded;
	uintptr_t dwUser;
	uint32_t dwFlags;
	struct MIDIHDR *lpNext;
	uintptr_t reserved;
	uint32_t dwOffset;
	uintptr_t dwReserved[8];
} MIDIHDR;
#pragma pack(pop)

typedef struct {
	float RenderingTime;
	uint32_t ActiveVoices[16];
	double ASIOInputLatency, ASIOOutputLatency, HealthThreadTime, ATThreadTime, EPThreadTime, CookedThreadTime;
	uint32_t CurrentSFList;
	double AudioLatency;
	uint32_t AudioBufferSize;
} DebugInfo;

static DebugInfo dbg = { .RenderingTime = 1.5f, .ActiveVoices = { [3] = 7 }, .CurrentSFList = 2, .AudioLatency = 9.25, .AudioBufferSize = 512 };
static int stream_open = 0;
static uint32_t setting_value = 0;
static int managed = 0;

uint32_t last_short, last_short_nobuf, prepared, unprepared, long_len, last_size;
uint8_t long_buf[256];
wchar_t last_sflist[256];
uint32_t custom[3];
uintptr_t mod_args[5];
int reset_count;

int ReturnKDMAPIVer(uint32_t *a, uint32_t *b, uint32_t *c, uint32_t *d) { *a = 4; *b = 1; *c = 0; *d = 5; return 1; }
int IsKDMAPIAvailable(void) { return 1; }
int InitializeKDMAPIStream(void) { if (stream_open) return 0; stream_open = 1; return 1; }
int TerminateKDMAPIStream(void) { if (!stream_open) return 0; stream_open = 0; return 1; }
void ResetKDMAPIStream(void) { reset_count++; }
int SendCustomEvent(uint32_t t, uint32_t c, uint32_t p) { custom[0] = t; custom[1] = c; custom[2] = p; return 1; }
void SendDirectData(uint32_t m) { last_short = m; }
void SendDirectDataNoBuf(uint32_t m) { last_short_nobuf = m; }
unsigned PrepareLongData(MIDIHDR *h, unsigned s) { if (s != sizeof(MIDIHDR)) return 11; prepared++; return 0; }
unsigned UnprepareLongData(MIDIHDR *h, unsigned s) { if (s != sizeof(MIDIHDR)) return 11; unprepared++; return 0; }
unsigned SendDirectLongData(MIDIHDR *h, unsigned s) {
	last_size = s;
	if (s != sizeof(MIDIHDR)) return 11;
	long_len = h->dwBytesRecorded; memcpy(long_buf, h->lpData, long_len); return 0;
}
unsigned SendDirectLongDataNoBuf(char *d, uint32_t n) { long_len = n; memcpy(long_buf, d, n); return 0; }
int DriverSettings(uint32_t setting, uint32_t mode, void *v, unsigned cb) {
	if (setting == 2) { managed = 1; return 1; }
	if (setting == 3) { managed = 0; return 1; }
	if (!managed || cb != 4) return 0;
	if (mode == 0) setting_value = *(uint32_t *)v; else *(uint32_t *)v = setting_value;
	return 1;
}
DebugInfo *GetDriverDebugInfo(void) { return &dbg; }
void LoadCustomSoundFontsList(wchar_t *p) { wcsncpy(last_sflist, p, 255); }
uint64_t timeGetTime64(void) { return 5000000000ULL; }
unsigned modMessage(unsigned id, unsigned msg, uintptr_t u, uintptr_t p1, uintptr_t p2) {
	mod_args[0] = id; mod_args[1] = msg; mod_args[2] = u; mod_args[3] = p1; mod_args[4] = p2; return 0;
}
size_t mock_sizeof_midihdr(void) { return sizeof(MIDIHDR); }
size_t mock_sizeof_debuginfo(void) { return sizeof(DebugInfo); }
