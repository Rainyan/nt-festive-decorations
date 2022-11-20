#pragma semicolon 1

/* TODO FOR FUTURE:
	- TE lights actually do not persist (lasts 25 secs or so?), so can remove the cvar time calculations.
	And just rely on the Cmd_ReLightDecorations repeat timer.
*/

#include <sourcemod>
#include <sdktools>
#include <sdktools_tempents>
#include <neotokyo>

#define PLUGIN_VERSION "0.5.0"

// How many different models to randomly choose from
#define NUM_MODELS 1

#define MAX_TE_LIGHT_DURATION 25.0
#define TIMER_INACCURACY 0.1

#define NEO_MAX_PLAYERS 32

#define CHRISTMAS_CFG_VERSION 1

#define DEBUG false

static float _vec3_zero[3] = { 0.0, 0.0, 0.0 };

static DataPack _dp_decoration_positions = null;
static int _num_decoration_positions;

static char _models[NUM_MODELS][] = {
	"models/holiday_decorations/xmas/holidaybox",
};
static int _model_indices[NUM_MODELS];

ConVar g_hCvar_Timelimit = null, g_hCvar_Scorelimit = null, g_hCvar_Chattime = null,
	g_hCvar_MaxDecorations = null, g_hCvar_SpecsCanSpawnDecorations,
	g_hCvar_LightSwitchSpeed = null;

static int _numPerPlayer[NEO_MAX_PLAYERS + 1];

Handle _timer_relight = INVALID_HANDLE;

public Plugin myinfo = {
	name = "NT Christmas Decorations",
	description = "Spawn client-side festive objects in the maps.",
	author = "code: Rain, 3D models & textures: John Kaz",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rainyan/nt-festive-decorations"
};

public void OnPluginStart()
{
	if(!HookEventEx("game_round_start", Event_RoundStart)) {
		SetFailState("Failed to hook event");
	}

	RegConsoleCmd("sm_gift", Cmd_SpawnGiftbox);
	RegConsoleCmd("sm_present", Cmd_SpawnGiftbox);

	CreateConVar("sm_festive_decorations_christmas_version", PLUGIN_VERSION, "Plugin version.",
		FCVAR_DONTRECORD);

	g_hCvar_LightSwitchSpeed = CreateConVar("sm_festive_decorations_christmas_lightswitch_secs", "5", "How many seconds to wait between changing the randomly chosen christmas light effect colors.",
		_, true, 1.0, true, 180.0);
	g_hCvar_LightSwitchSpeed.AddChangeHook(LightSwitchSpeedChanged);

	g_hCvar_MaxDecorations = CreateConVar("sm_festive_decorations_christmas_limit", "20",
		"How many !gifts per person per round max.", _, true, 0.0, true, 1000.0);

	g_hCvar_SpecsCanSpawnDecorations = CreateConVar("sm_festive_decorations_christmas_specs_may_spawn", "2",
		"Whether spectators are allowed to !gift. 0: spectators can never spawn !gifts, 1: spectators can always spawn !gifts visible to all players, 2: spectator !gifts are only visible to other spectating players.", _, true, 0.0, true, 2.0);
}

public void LightSwitchSpeedChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	float speed = StringToFloat(newValue);
	float min;
	if (g_hCvar_LightSwitchSpeed.GetBounds(ConVarBound_Lower, min) && speed >= min) {
		SetLightSwitchSpeed(speed);
	}
}

public Action Cmd_SpawnGiftbox(int client, int argc)
{
	if (client == 0) {
		ReplyToCommand(client, "This command cannot be executed by the server.");
		return Plugin_Handled;
	}

	int team = GetClientTeam(client);
	bool is_speccing = g_hCvar_SpecsCanSpawnDecorations.IntValue == 1 ? false : (team <= TEAM_SPECTATOR || !IsPlayerAlive(client));

	if (g_hCvar_SpecsCanSpawnDecorations.IntValue == 0 && is_speccing) {
		PrintToChat(client, "[SM] Spectating players may not spawn decorations!");
		return Plugin_Handled;
	}

	if (_numPerPlayer[client] >= g_hCvar_MaxDecorations.IntValue) {
		PrintToChat(client, "[SM] You can only spawn %d decorations per round!",
			g_hCvar_MaxDecorations.IntValue);
		return Plugin_Handled;
	}

	float eye_pos[3], eye_ang[3], trace_end_pos[3];

	GetClientEyePosition(client, eye_pos);
	GetClientEyeAngles(client, eye_ang);

	TR_TraceRayFilter(eye_pos, eye_ang, ALL_VISIBLE_CONTENTS,
		RayType_Infinite, NotHitSelf, client);
	TR_GetEndPosition(trace_end_pos, INVALID_HANDLE);

	SpawnDecoration(trace_end_pos, eye_ang, is_speccing);

	++_numPerPlayer[client];

	return Plugin_Handled;
}

bool NotHitSelf(int hitEntity, int contentsMask, int selfEntity)
{
	return hitEntity != selfEntity;
}

int GetDecorationPositions(const char[] map_name, DataPack out_dp = null)
{
#if DEBUG
	PrintToServer("GetDecorationPositions: %s", map_name);
#endif

	char path[PLATFORM_MAX_PATH];
	if (BuildPath(Path_SM, path, sizeof(path), "configs/festive_christmas.cfg") < 0)
	{
		ThrowError("Failed to build path");
	}
	if (!FileExists(path))
	{
		ThrowError("Config path doesn't exist: \"%s\"", path);
	}

	KeyValues kv = new KeyValues("cfg_festive_christmas");
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		ThrowError("Failed to import cfg to keyvalues: \"%s\"", path);
	}

	int version = kv.GetNum("version");
	if (version == 0)
	{
		delete kv;
		ThrowError("Invalid config version or no version found");
	}
	else if (version != CHRISTMAS_CFG_VERSION)
	{
		delete kv;
		ThrowError("Unsupported config version %d (expected version %d)",
			version, CHRISTMAS_CFG_VERSION);
	}

	int num_positions = 0;
	if (kv.JumpToKey(map_name) && kv.JumpToKey("pos"))
	{
		float rot[3];
		float xyz[3];
		kv.GetVector("rot", rot, _vec3_zero);
		kv.GetVector("xyz", xyz, _vec3_zero);
		if (!VectorsEqual(xyz, _vec3_zero))
		{
			++num_positions;
			if (out_dp != null)
			{
				Dp_WriteFloatArray(out_dp, rot, sizeof(rot));
				Dp_WriteFloatArray(out_dp, xyz, sizeof(xyz));
#if DEBUG
				PrintToServer("Wrote rot: %f %f %f", rot[0], rot[1], rot[2]);
				PrintToServer("Wrote xyz: %f %f %f", xyz[0], xyz[1], xyz[2]);
#endif
			}
			while (kv.GotoNextKey())
			{
				kv.GetVector("rot", rot, _vec3_zero);
				kv.GetVector("xyz", xyz, _vec3_zero);
				if (VectorsEqual(xyz, _vec3_zero))
				{
					break;
				}
				++num_positions;
				if (out_dp != null)
				{
					Dp_WriteFloatArray(out_dp, rot, sizeof(rot));
					Dp_WriteFloatArray(out_dp, xyz, sizeof(xyz));
#if DEBUG
					PrintToServer("Wrote rot: %f %f %f", rot[0], rot[1], rot[2]);
					PrintToServer("Wrote xyz: %f %f %f", xyz[0], xyz[1], xyz[2]);
#endif
				}
			}
		}
	}

	delete kv;
	return num_positions;
}

static void Dp_ReadFloatArray(DataPack source, float[] buffer, int count)
{
// Because DataPack.ReadFloatArray is not available in SourceMod < 1.11
#if SOURCEMOD_V_MAJOR <= 1 && SOURCEMOD_V_MINOR <= 10
	for (int i = 0; i < count; ++i)
	{
		buffer[i] = source.ReadFloat();
	}
#else
	source.ReadFloatArray(buffer, count);
#endif
}

// Declared stock for backwards compatibility; potentially unused parameters
static stock void Dp_WriteFloatArray(DataPack target, const float[] arr, int count, bool insert = false)
{
// Because DataPack.WriteFloatArray is not available in SourceMod < 1.11
#if SOURCEMOD_V_MAJOR <= 1 && SOURCEMOD_V_MINOR <= 10
	for (int i = 0; i < count; ++i)
	{
// Because the insert parameter is not available in SourceMod < 1.10
#if SOURCEMOD_V_MINOR <= 9
		target.WriteFloat(arr[i]);
#else
		target.WriteFloat(arr[i], insert);
#endif
	}
#else
	target.WriteFloatArray(arr, count, insert);
#endif
}

void SpawnDecoration(const float pos[3], const float ang[3], const bool for_spectators_only = false)
{
	TE_Start("physicsprop");
	TE_WriteVector("m_vecOrigin", pos);
	TE_WriteFloat("m_angRotation[0]", ang[0]);
	TE_WriteFloat("m_angRotation[1]", ang[1]);
	TE_WriteFloat("m_angRotation[2]", ang[2]);
	TE_WriteVector("m_vecVelocity", _vec3_zero);
	TE_WriteNum("m_nModelIndex", _model_indices[GetRandomInt(0, sizeof(_model_indices) - 1)]);
	TE_WriteNum("m_nFlags", 0);
	if (!for_spectators_only) {
		int recipients[NEO_MAX_PLAYERS];
		int num_recipients;
		for (int client = 1; client <= MaxClients; ++client) {
			if (IsClientInGame(client) && !IsClientSourceTV(client) && !IsClientReplay(client)) {
				recipients[num_recipients++] = client;
			}
		}
		if (num_recipients != 0) {
			TE_Send(recipients, num_recipients, 0.0);
		}
	} else {
		int spectators[NEO_MAX_PLAYERS];
		int num_spectators;
		for (int client = 1; client <= MaxClients; ++client) {
			if (IsClientInGame(client) && (!IsPlayerAlive(client) || GetClientTeam(client) <= TEAM_SPECTATOR) && !IsClientSourceTV(client) && !IsClientReplay(client)) {
				spectators[num_spectators++] = client;
			}
		}
		if (num_spectators != 0) {
			TE_Send(spectators, num_spectators, 0.0);
		}
	}
}

public void OnConfigsExecuted()
{
	if (g_hCvar_Timelimit == null) {
		g_hCvar_Timelimit = FindConVar("neo_round_timelimit");
	}
	if (g_hCvar_Scorelimit == null) {
		g_hCvar_Scorelimit = FindConVar("neo_score_limit");
	}
	if (g_hCvar_Chattime == null) {
		g_hCvar_Chattime = FindConVar("mp_chattime");
	}
	if (g_hCvar_Timelimit == null || g_hCvar_Scorelimit == null || g_hCvar_Chattime == null) {
		SetFailState("Failed to find cvar(s)");
	}

	SetLightSwitchSpeed(g_hCvar_LightSwitchSpeed.FloatValue);
}

void SetLightSwitchSpeed(float speed)
{
	if (_timer_relight != INVALID_HANDLE) {
		delete _timer_relight;
	}
	_timer_relight = CreateTimer(speed, Cmd_ReLightDecorations, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	decl String:ext_path[PLATFORM_MAX_PATH];
	for (int i = 0; i < sizeof(_models); ++i) {
		char exts[][] = { "dx80.vtx", "dx90.vtx", "mdl", "phy", "sw.vtx", "vvd", "xbox.vtx" };
		for (int j = 0; j < sizeof(exts); ++j) {
			Format(ext_path, sizeof(ext_path), "%s.%s", _models[i], exts[j]);
			if (StrEqual(exts[j], "mdl")) {
				_model_indices[i] = PrecacheModel(ext_path);
				if (_model_indices[i] == 0) {
					SetFailState("Failed to precache: \"%s\"", _models[i]);
				}
			}
			AddFileToDownloadsTable(ext_path);
		}
	}
	AddFileToDownloadsTable("materials/models/holiday_decorations/xmas/holidaybox.vmt");
	AddFileToDownloadsTable("materials/models/holiday_decorations/xmas/holidaybox.vtf");
	AddFileToDownloadsTable("materials/models/holiday_decorations/xmas/holidaybox_d.vtf");

	decl String:map_name[PLATFORM_MAX_PATH];
	GetCurrentMap(map_name, sizeof(map_name));

	if (_dp_decoration_positions != null)
	{
		delete _dp_decoration_positions;
		_num_decoration_positions = 0;
	}
	_dp_decoration_positions = new DataPack();
	_num_decoration_positions = GetDecorationPositions(map_name, _dp_decoration_positions);

	for (int i = 0; i < sizeof(_numPerPlayer); ++i) {
		_numPerPlayer[i] = 0;
	}
}

public Action Cmd_ReLightDecorations(Handle timer)
{
	LightDecorationLocations();
	return Plugin_Continue;
}

bool VectorsEqual(const float v1[3], const float v2[3])
{
	return v1[0] == v2[0] && v1[1] == v2[1] && v1[2] == v2[2];
}

int RandomRGBComponent()
{
	// Using additional seed because this gets called thrice per tick (r+g+b)
	static int seed = 0;
	SetRandomSeed(GetGameTickCount() + seed);
	seed = (seed + 1) % 3;
	return GetRandomInt(0, 255);
}

void LightDecorationLocations()
{
	if (_dp_decoration_positions == null)
	{
		return;
	}

	float xyz[3];
	_dp_decoration_positions.Reset();

	// This timer will persist across newrounds, so setting to maximum map length for a standard CTG server setup.
	float time = (g_hCvar_Scorelimit.IntValue * 2 - 1) * (g_hCvar_Timelimit.FloatValue * 60 + g_hCvar_Chattime.FloatValue);
	for (int i = 0; i < _num_decoration_positions; ++i)
	{
		Dp_ReadFloatArray(_dp_decoration_positions, xyz, sizeof(xyz)); // twice because skip angles
		Dp_ReadFloatArray(_dp_decoration_positions, xyz, sizeof(xyz));

		TE_Start("Dynamic Light");
		TE_WriteVector("m_vecOrigin", xyz);
		TE_WriteFloat("m_fRadius", 180.0);
		TE_WriteNum("r", RandomRGBComponent());
		TE_WriteNum("g", RandomRGBComponent());
		TE_WriteNum("b", RandomRGBComponent());
		TE_WriteNum("exponent", 2);
		TE_WriteFloat("m_fTime", time);
		TE_WriteFloat("m_fDecay", 1.0);
		// Only one TE dynamic light allowed at a time, so we light the one that's in each client's PVS.
		// Should only have one light per PVS to avoid lights visibly turning off.
		TE_SendToAllInRange(xyz, RangeType_Visibility, 0.0);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < sizeof(_numPerPlayer); ++i) {
		_numPerPlayer[i] = 0;
	}

	if (_dp_decoration_positions != null) {
		float xyz[3];
		float rot[3];
		_dp_decoration_positions.Reset();
		for (int i = 0; i < _num_decoration_positions; ++i)
		{
			Dp_ReadFloatArray(_dp_decoration_positions, rot, sizeof(rot));
			Dp_ReadFloatArray(_dp_decoration_positions, xyz, sizeof(xyz));
			SpawnDecoration(xyz, rot);
		}
	}
}
