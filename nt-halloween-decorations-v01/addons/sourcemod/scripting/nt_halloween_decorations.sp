#pragma semicolon 1

/* TODO FOR FUTURE:
	- Replay bot doesn't see decorations being cleared on new round start;
	should only spawn the pre-placed decorations for the replay, and not client spawned ones,
	otherwise replays playback for those demos can become very heavy.
	
	- Fix pumpkin UVs such that it self illuminates (black.vmt or similar, see assets).
	
	- Refactor location data out of code and into a config file for easier location updates.
	Same with decoration types and other extendable things that are currently hardcoded constant.
	
	- TE lights actually do not persist (lasts 25 secs or so?), so can remove the cvar time calculations.
	And just rely on the Cmd_ReLightDecorations repeat timer.
*/

#include <sourcemod>
#include <sdktools>
#include <sdktools_tempents>
#include <neotokyo>

#define PLUGIN_VERSION "0.3"

// How many maps are locations defined for
#define NUM_MAPS 10

// How many different models to randomly choose from
#define NUM_MODELS 1

// How many locations are there for each map
#define NUM_LOCATIONS 6

// Array enum accessors
#define LOCATION_POS 0
#define LOCATION_ANG 1
#define LOCATION_SIZE 2

#define INVALID_MAP_INDEX -1

#define MAX_TE_LIGHT_DURATION 25.0
#define TIMER_INACCURACY 0.1

#define NEO_MAX_PLAYERS 32

static float _vec3_zero[3] = { 0.0, 0.0, 0.0 };

static char _maps[NUM_MAPS][] = {
	"nt_ballistrade_ctg",
	"nt_dawn_ctg",
	"nt_disengage_ctg",
	"nt_dusk_ctg",
	"nt_ghost_ctg",
	"nt_marketa_ctg",
	"nt_redlight_ctg",
	"nt_rise_ctg",
	"nt_turmuk_ctg_beta3",
	"nt_shrine_ctg",
};

static char _models[NUM_MODELS][] = {
	"models/pumpkin/pumpkin",
};
static int _model_indices[NUM_MODELS];

static float _mapPropPositions[NUM_MAPS][NUM_LOCATIONS][LOCATION_SIZE][3] = {
	// Mark XYZ as all zeroes to skip a location.
	{ // nt_ballistrade_ctg
		{ // location 1
			{ 1388.0,	-693.0,	-25.0 },
			{ 0.0,		-88.0,		0.0 }		// angles
		},
		{ // location 2
			{ 1681.0,	-895.0,	117.0 },
			{ 0.0,		145.0,		0.0 }
		},
		{ // location 3
			{ 1220.0,	-1929.0,	72.0 },
			{ 0.0,		92.0,		0.0 }
		},
		{ // location 4 setpos 643.154480 -471.237976 108.688347;setang -7.626810 -179.171005 0.000000
			{ 643.0,		-471.0,		114.0 },
			{ 0.0,		-179.0,		0.0 }
		},
		{ // location 5
			{ 0.0,		0.0,		0.0 },
			{ 0.0,		0.0,		0.0 }
		},
		{ // location 6
			{ 0.0,		0.0,		0.0 },
			{ 0.0,		0.0,		0.0 }
		},
	},
	{ // nt_dawn_ctg
		{ // location 1
			{ -372.0,	828.0,		-139.0 },	// XYZ pos
			{ 0.0,		315.0,		0.0 }		// angles
		},
		{ // location 2
			{ 1122.0,	4440.0,	-150.0 },
			{ 0.0,		7.0,		0.0 }
		},
		{ // location 3
			{ -8.0,	4618.0,	-175.0 },
			{ 0.0,		322.0,		0.0 }
		},
		{ // location 4
			{ -880.0,	2052.0,	-143.0 },
			{ 0.0,		322.0,		0.0 }
		},
		{ // location 5
			{ -1070.0,	3354.0,	-191.0 },
			{ 0.0,		112.0,		0.0 }
		},
		{ // location 6
			{ -2168.0,	3620.0,	-149.0 },
			{ 0.0,		247.0,		0.0 }
		},
	},
	{ // nt_disengage_ctg
		{ // location 1
			{ -504.0,	-1019.0,		-205.0 },	// XYZ pos
			{ 0.0,		-140.0,		0.0 }		// angles
		},
		{ // location 2

			{ 754.0,	2689.0,	-231.0 },
			{ 0.0,	28.0,	0.0 },
		},
		{ // location 3
			{ 0.0,	0.0,	0.0 },
			{ 0.0,	0.0,	0.0 },
		},
		{ // location 4
			{ 0.0,	0.0,	0.0 },
			{ 0.0,	0.0,	0.0 },
		},
		{ // location 5
			{ 0.0,	0.0,	0.0 },
			{ 0.0,	0.0,	0.0 },
		},
		{ // location 6
			{ 0.0,	0.0,	0.0 },
			{ 0.0,	0.0,	0.0 },
		},
	},
	{ // nt_dusk_ctg
		{ // location 1
			{ 2036.0,	4354.0,	-185.0 },	// XYZ pos
			{ 0.0,		202.0,		0.0 }		// angles
		},
		{ // location 2
			{ 539.0,	2825.0,	-241.0 },
			{ 0.0,		277.0,		0.0 }
		},
		{ // location 3
			{ 576.0,	664.0,		-105.0 },
			{ 0.0,		172.0,		0.0 }
		},
		{ // location 4
			{ -474.0,	-158.0,	-163.0 },
			{ 0.0,		60.0,		0.0 }
		},
		{ // location 5
			{ -1070.0,	3354.0,	-191.0 },
			{ 0.0,		112.0,		0.0 }
		},
		{ // location 6
			{ 0.0,		0.0,		0.0 }, // Zeroed; skipping this location.
			{ 0.0,		0.0,		0.0 }
		},
	},
	{ // nt_ghost_ctg
		{ // location 1
			{ -1363.0,	-181.0,	37.0 },
			{ 0.0,		0.0,		0.0 }		// angles
		},
		{ // location 2
			{ -1340.0,	914.0,	273.0 },
			{ 0.0,		0.0,		0.0 }
		},
		{ // location 3
			{ -2167.0,	3829.0,	102.0 },
			{ 0.0,		-133.0,		0.0 }
		},
		{ // location 4
			{ -277.0,		5121.0,		80.0 },
			{ 0.0,		74.0,		0.0 }
		},
		{ // location 5
			{ -86.0,		2533.0,		220.0 },
			{ 0.0,		-89.0,		0.0 }
		},
		{ // location 6
			{ 751.0,		414.0,		45.0 },
			{ 0.0,		-177.0,		0.0 }
		},
	},
	{ // nt_marketa_ctg
		{ // location 1
			{ 444.0,	-1680.0,	75.0 },
			{ 0.0,		-125.0,		0.0 }		// angles
		},
		{ // location 2
			{ 934.0,	171.0,	48.0 },
			{ 0.0,		132.0,		0.0 }
		},
		{ // location 3
			{ 530.0,	347.0,	270.0 },
			{ 0.0,		47.0,		0.0 }
		},
		{ // location 4
			{ 375.0,		1113.0,	250.0 },
			{ 0.0,		-147.0,		0.0 }
		},
		{ // location 5
			{ 0.0,		0.0,	0.0 },
			{ 0.0,		-89.0,		0.0 }
		},
		{ // location 6
			{ 0.0,		0.0,	0.0 },
			{ 0.0,		-177.0,		0.0 }
		},
	},
	{ // nt_redlight_ctg
		{ // location 1
			{ 501.0,	-415.0,	156.0 },
			{ 0.0,	-134.0,	0.0 },
		},
		{ // location 2
			{ -2815.0,	336.0,	52.0 },
			{ 0.0,	1.0,	0.0 },
		},
		{ // location 3
			{ -2504.0,	1325.0,	31.0 },
			{ 0.0,	-14.0,	0.0 },
		},
		{ // location 4
			{ -74.0,	1251.0,	44.0 },
			{ 0.0,	-45.0,	0.0 },
		},
		{ // location 5
			{ 1294.0,	597.0,	52.0 },
			{ 0.0,	-136.0,	0.0 },
		},
		{ // location 6
			{ 2223.0,	-1815.0,	51.0 },
			{ 0.0,	-165.0,	0.0 },
		},
	},
	{ // nt_rise_ctg
		{ // location 1
			{ -820.0, 481.0, -847.0 },
			{ 0.0, -149.0, 0.0 },
		},
		{ // location 2
			{ 115.0, 268.0, -689.0 },
			{ 0.0, -153.0, 0.0 },
		},
		{ // location 3
			{ -18.0, -845.0, -461.0 },
			{ 0.0, 33.0, 0.0 },
		},
		{ // location 4
			{ 1404.0, 73.0, -52.0 },
			{ 0.0, -167.0, 0.0 },
		},
		{ // location 5
			{ 2039.0, -4.0, -535.0 },
			{ 0.0, 160.0, 0.0 },
		},
		{ // location 6
			{ -60.0, -29.0, -346.0 },
			{ 0.0, -36.0, 0.0 },
		},
	},
	{ // nt_turmuk_ctg_beta3
		{ // location 1 setpos -1881.784912 757.893982 -45.369083;setang 8.506684 -32.468887 0.000000
			{ -1881.0, 757.0, -45.0 },
			{ 0.0, -32.0, 0.0 },
		},
		{ // location 2 setpos -250.468811 550.445435 -460.287109;setang 0.440007 -49.202435 0.000000
			{ -269.0, 550.0, -460.0 },
			{ 0.0, -49.0, 0.0 },
		},
		{ // location 3 setpos 1473.129639 1200.338989 -511.937500;setang -3.886664 99.530777 0.000000
			{ 1473.0, 1200.0, -511.0 },
			{ 0.0, 99.0, 0.0 },
		},
		{ // location 4
			{ 0.0, 0.0, 0.0 },
			{ 0.0, 0.0, 0.0 },
		},
		{ // location 5
			{ 0.0, 0.0, 0.0 },
			{ 0.0, 0.0, 0.0 },
		},
		{ // location 6
			{ 0.0, 0.0, 0.0 },
			{ 0.0, 0.0, 0.0 },
		},
	},
	{ // nt_shrine_ctg
		{ // location 1 setpos -2706.750000 5510.031250 153.375000;setang -0.916733 -134.732758 0.000000
			{ -2706.0, 5510.0, 153.0 },
			{ 0.0, -134.0, 0.0 },
		},
		{ // location 2 setpos 365.717041 3024.625488 81.084778;setang -4.803417 -179.232849 0.000000
			{ 365.0, 3024.0, 81.0 },
			{ 0.0, -179.0, 0.0 },
		},
		{ // location 3
			{ 0.0, 0.0, 0.0 },
			{ 0.0, 0.0, 0.0 },
		},
		{ // location 4
			{ 0.0, 0.0, 0.0 },
			{ 0.0, 0.0, 0.0 },
		},
		{ // location 5
			{ 0.0, 0.0, 0.0 },
			{ 0.0, 0.0, 0.0 },
		},
		{ // location 6
			{ 0.0, 0.0, 0.0 },
			{ 0.0, 0.0, 0.0 },
		},
	},
};
static int _currentMapIndex;

ConVar g_hCvar_Timelimit = null, g_hCvar_Scorelimit = null, g_hCvar_Chattime = null,
	g_hCvar_MaxDecorations = null, g_hCvar_SpecsCanSpawnDecorations;

static int _numPerPlayer[NEO_MAX_PLAYERS + 1];

public Plugin myinfo = {
	name = "NT Halloween Decorations",
	description = "Spawn client-side festive objects in the maps.",
	author = "Rain",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rainyan/nt-festive-decorations"
};

public void OnPluginStart()
{
	if(!HookEventEx("game_round_start", Event_RoundStart)) {
		SetFailState("Failed to hook event");
	}
	
	RegConsoleCmd("sm_pumpkin", Cmd_SpawnPumpkin);
	
	CreateConVar("sm_festive_decorations_version", PLUGIN_VERSION, "Plugin version.",
		FCVAR_DONTRECORD);
	
	g_hCvar_MaxDecorations = CreateConVar("sm_festive_decorations_limit", "20",
		"How many !pumpkins per person per round max.", _, true, 0.0, true, 1000.0);
	
	g_hCvar_SpecsCanSpawnDecorations = CreateConVar("sm_festive_decorations_specs_may_spawn", "2",
		"Whether spectators are allowed to !pumpkin.", _, true, 0.0, true, 2.0);
}

public Action Cmd_SpawnPumpkin(int client, int argc)
{
	if (client == 0) {
		ReplyToCommand(client, "This command cannot be executed by the server.");
		return Plugin_Handled;
	}
	
	int team = GetClientTeam(client);
	bool is_speccing = g_hCvar_SpecsCanSpawnDecorations.IntValue == 1 ? false : (team <= TEAM_SPECTATOR || !IsPlayerAlive(client));
	
	if (g_hCvar_SpecsCanSpawnDecorations.IntValue == 0 && is_speccing) {
		PrintToChat(client, "[SM] Spectating players may not spawn pumpkins!");
		return Plugin_Handled;
	}
	
	if (_numPerPlayer[client] >= g_hCvar_MaxDecorations.IntValue) {
		PrintToChat(client, "[SM] You can only spawn %d pumpkins per round!",
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

void SpawnDecoration(const float[3] pos, const float[3] ang, const bool for_spectators_only = false)
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
		TE_SendToAll(0.0);
	} else {
		int spectators[NEO_MAX_PLAYERS];
		int num_spectators;
		for (int client = 1; client <= MaxClients; ++client) {
			if (IsClientInGame(client) && (!IsPlayerAlive(client) || GetClientTeam(client) <= TEAM_SPECTATOR)) {
				spectators[num_spectators++] = client;
			}
		}
		if (num_spectators != 0) {
			TE_Send(spectators, num_spectators, 0.0);
		}
	}
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
	AddFileToDownloadsTable("materials/models/pumpkin/black.vmt");
	AddFileToDownloadsTable("materials/models/pumpkin/green.vmt");
	AddFileToDownloadsTable("materials/models/pumpkin/pumpkin.vmt");
	AddFileToDownloadsTable("materials/models/pumpkin/pumpkin.vtf");
	AddFileToDownloadsTable("materials/models/pumpkin/pumpkin_illum.vtf");
	
	decl String:map_name[PLATFORM_MAX_PATH];
	GetCurrentMap(map_name, sizeof(map_name));
	
	_currentMapIndex = INVALID_MAP_INDEX;
	for (int i = 0; i < sizeof(_maps); ++i) {
		if (StrEqual(map_name, _maps[i])) {
			_currentMapIndex = i;
			break;
		}
	}
	
	if (_currentMapIndex != INVALID_MAP_INDEX) {
		g_hCvar_Timelimit = FindConVar("neo_round_timelimit");
		g_hCvar_Scorelimit = FindConVar("neo_score_limit");
		g_hCvar_Chattime = FindConVar("mp_chattime");
		if (g_hCvar_Timelimit == null) {
			SetFailState("Failed to find neo_round_timelimit");
		} else if (g_hCvar_Scorelimit == null) {
			SetFailState("Failed to find neo_score_limit");
		} else if (g_hCvar_Chattime == null) {
			SetFailState("Failed to find mp_chattime");
		}
		
		LightDecorationLocations();
		CreateTimer(1.0, Cmd_ReLightDecorations, _, TIMER_REPEAT);
	}
}

public Action Cmd_ReLightDecorations(Handle timer)
{
	if (_currentMapIndex != INVALID_MAP_INDEX) {
		LightDecorationLocations();
	}
	return Plugin_Continue;
}

bool VectorsEqual(const float[3] v1, const float[3] v2)
{
	return v1[0] == v2[0] && v1[1] == v2[1] && v1[2] == v2[2];
}

void LightDecorationLocations()
{
	// Light all the decoration locations.
	for (int location = 0; location < NUM_LOCATIONS; ++location) {
		if (VectorsEqual(_vec3_zero, _mapPropPositions[_currentMapIndex][location][LOCATION_POS])) {
			continue;
		}
		
		TE_Start("Dynamic Light");
		TE_WriteVector("m_vecOrigin", _mapPropPositions[_currentMapIndex][location][LOCATION_POS]);
		TE_WriteFloat("m_fRadius", 180.0);
		TE_WriteNum("r", 255);
		TE_WriteNum("g", 100);
		TE_WriteNum("b", 0);
		TE_WriteNum("exponent", 2);
		// This timer will persist across newrounds, so setting to maximum map length for a standard CTG server setup.
		TE_WriteFloat("m_fTime", (g_hCvar_Scorelimit.IntValue * 2 - 1) * (g_hCvar_Timelimit.FloatValue * 60 + g_hCvar_Chattime.FloatValue));
		TE_WriteFloat("m_fDecay", 1.0);
		// Only one TE dynamic light allowed at a time, so we light the one that's in each client's PVS.
		// Should only have one light per PVS to avoid lights visibly turning off.
		TE_SendToAllInRange(_mapPropPositions[_currentMapIndex][location][LOCATION_POS], RangeType_Visibility, 0.0);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < sizeof(_numPerPlayer); ++i) {
		_numPerPlayer[i] = 0;
	}
	
	if (_currentMapIndex == -1) {
		return;
	}
	
	for (int location = 0; location < NUM_LOCATIONS; ++location) {
		if (VectorsEqual(_vec3_zero, _mapPropPositions[_currentMapIndex][location][LOCATION_POS])) {
			continue;
		}
		
		SpawnDecoration(
			_mapPropPositions[_currentMapIndex][location][LOCATION_POS],
			_mapPropPositions[_currentMapIndex][location][LOCATION_ANG]);
	}
}
