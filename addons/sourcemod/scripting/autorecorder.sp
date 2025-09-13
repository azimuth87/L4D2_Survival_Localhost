#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.3.0"

public Plugin myinfo =
{
	name = "Auto Recorder when survival started",
	author = "Stevo.TVR and me",
	description = "Automates SourceTV recording based on player count and time of day.",
	version = PLUGIN_VERSION,
	url = "http://www.theville.org"
}

ConVar g_hTvEnabled = null;
ConVar g_hDemoPath = null;
bool g_bIsRecording = false;

public void OnPluginStart()
{
	CreateConVar("sm_autorecord_version", PLUGIN_VERSION, "Auto Recorder plugin version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hDemoPath = CreateConVar("sm_autorecord_path", ".", "Path to store recorded demos");

	AutoExecConfig(true, "autorecorder");

	g_hTvEnabled = FindConVar("tv_enable");

	char sPath[PLATFORM_MAX_PATH];
	g_hDemoPath.GetString(sPath, sizeof(sPath));
	if(!DirExists(sPath))
	{
		InitDirectory(sPath);
	}

	HookEvent("survival_round_start", Event_survival_round_start_autorecorder);
	HookEvent("round_end", Event_round_end_autorecorder);

	StopRecord();
}

public void OnMapEnd()
{
	if(g_bIsRecording)
	{
		StopRecord();
	}
}

void StartRecord()
{
	if(g_hTvEnabled.BoolValue && !g_bIsRecording)
	{
		char sPath[PLATFORM_MAX_PATH];
		char sTime[16];
		char sMap[32];

		g_hDemoPath.GetString(sPath, sizeof(sPath));
		FormatTime(sTime, sizeof(sTime), "%Y%m%d-%H%M%S", GetTime());
		GetCurrentMap(sMap, sizeof(sMap));

		// replace slashes in map path name with dashes, to prevent fail on workshop maps
		ReplaceString(sMap, sizeof(sMap), "/", "-", false);

		ServerCommand("tv_record \"%s/auto-%s-%s\"", sPath, sTime, sMap);
		LogMessage("Recording to auto-%s-%s.dem", sTime, sMap);

		g_bIsRecording = true;
	}
}

void StopRecord()
{
	if(g_hTvEnabled.BoolValue)
	{
		ServerCommand("tv_stoprecord");
		g_bIsRecording = false;
	}
}

public void Event_survival_round_start_autorecorder(Event event, const char[] name, bool dontBroadcast)
{
	StartRecord();
}

public void Event_round_end_autorecorder(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(5.0, Timer_DelayStopRecordingSurvivalRoundEnd);
}

public Action Timer_DelayStopRecordingSurvivalRoundEnd(Handle hTimer, any ent)
{
	StopRecord();
	return Plugin_Continue;
}

void InitDirectory(const char[] sDir)
{
	char sPieces[32][PLATFORM_MAX_PATH];
	char sPath[PLATFORM_MAX_PATH];
	int iNumPieces = ExplodeString(sDir, "/", sPieces, sizeof(sPieces), sizeof(sPieces[]));

	for(int i = 0; i < iNumPieces; i++)
	{
		Format(sPath, sizeof(sPath), "%s/%s", sPath, sPieces[i]);
		if(!DirExists(sPath))
		{
			CreateDirectory(sPath, 509);
		}
	}
}