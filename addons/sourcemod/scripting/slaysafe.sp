#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0

#define KEYVALUE_TITLE	"slaysafe"
#define CFG_PATH		"data/SlaySafeCoordinates.cfg"

ArrayList g_hArray_ConfigIDs;
char g_sConfigPath[PLATFORM_MAX_PATH];

enum struct enum_Config {
	char sName[64];
	float slay[3]; 
	float cam_pos[3];
	float cam_ang[3];

	void clearSettings()
	{
		this.sName = "";
		for (int i = 0; i < 3; i++)
		{
			this.slay[i] = this.cam_pos[i] = this.cam_ang[i] = 0.0;
		}
	}
}

enum_Config g_Config;

public Plugin myinfo = {
	name		= "slaysafe",
	author		= "dustin",
	description = "slay bots in specified areas",
	version		= "1.0",
	url			= ""
};

/* TODO
	
	make sure global enum struct won't get reset if multiple people using menu
		for some reason.
*/

public void OnPluginStart()
{
	g_hArray_ConfigIDs = new ArrayList(ByteCountToCells(8));
	BuildPath(Path_SM, g_sConfigPath, sizeof(g_sConfigPath), CFG_PATH);

	RegConsoleCmd("sm_slaysafe", Command_Slaysafe);
}

public Action Command_Slaysafe(int client, int args)
{
	if (IsCommandAllowed(client))
	{
		drawmainmenu(client);
	}
	return Plugin_Handled;
}

bool IsCommandAllowed(int client)
{
	if (IsSurvival() == false)
	{
		PrintToChat(client, "[SM] Command only available in survival mode.");
		return false;
	}

	if (SurvivalRoundInProgress())
	{
		PrintToChat(client, "[SM] Cannot use while round is in progress.");
		return false;
	}

	if (AtLeastOneSurvivorBot() == false)
	{
		PrintToChat(client, "[SM] No survivor bots alive to teleport and slay.");
		return false;
	}

	return true;
}

bool IsSurvival()
{
	char GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	return StrContains(GameName, "survival", false) != -1;
}

bool SurvivalRoundInProgress()
{
	return GameRules_GetPropFloat("m_flRoundStartTime") > 0.0 && GameRules_GetPropFloat("m_flRoundEndTime") == 0.0;
}

bool AtLeastOneSurvivorBot()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			return true;
		}
	}
	return false;
}

public void OnConfigsExecuted()
{
	PopulateMenuIDs(0, "", true);
}

/**************************************************
 * Menu items
***************************************************/

void drawmainmenu(int client)
{
	Menu hmenu = new Menu(MainMenuHandler);
	hmenu.SetTitle("Choose slay location");

	char sMap[16];
	GetCurrentMap(sMap, sizeof(sMap));

	char sConfig[8];
	for (int i = 0; i < g_hArray_ConfigIDs.Length; i++)
	{
		g_hArray_ConfigIDs.GetString(i, sConfig, sizeof(sConfig));
		if (PopulateMenuIDs(client, sConfig) != -1)
		{
			hmenu.AddItem(sConfig, g_Config.sName);
		}
		else
		{
			delete hmenu;
			return;
		}
	}

	hmenu.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			// in case they left menu open when survival round started.
			if (IsCommandAllowed(param1))
			{
				char sMenuItem[32];
				menu.GetItem(param2, sMenuItem, sizeof(sMenuItem));

				SlaySurvivorBots(param1, sMenuItem);
			}

		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				drawmainmenu(param1);
			}
		}
		
		case MenuAction_End:
			delete menu;
	}
}

/**************************************************
 * Key Value Helpers
***************************************************/

void kv_goToTop(KeyValues kv)
{
	while (kv.NodesInStack() != 0)
		kv.GoBack();
}

int PopulateMenuIDs(int client = 0, const char[] sConfig = "1", bool bPopulateConfigIDs = false)
{
	if (bPopulateConfigIDs)
	{
		g_hArray_ConfigIDs.Clear();
	}

	KeyValues kv = new KeyValues(KEYVALUE_TITLE);
	if (kv.ImportFromFile(g_sConfigPath) == false)
	{
		delete kv;
		if (client) PrintToChat(client, "[SM] Error config file not found. Contact an admin.");
		LogError("Config file not found: %s", g_sConfigPath);
		return -1;
	}

	kv_goToTop(kv);
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));
	if (!kv.JumpToKey(sMap, false))
	{
		// could be custom map so don't log error
		LogMessage("No config found for current map (%s).", sMap);
		if (client) PrintToChat(client, "[SM] No configs exist for current map.");
		delete kv;
		return -1;
	}

	// populating menu IDs
	if (bPopulateConfigIDs)
	{
		if (!kv.GotoFirstSubKey())
		{
			delete kv;
			LogError("No sub keys found for map %s", sMap);
			if (client) PrintToChat(client, "[SM] Error No sub keys found for map '%s'. Contact an admin.", sMap);
			return -1;
		}

		char sSection[8];
		kv.GetSectionName(sSection, sizeof(sSection));
		g_hArray_ConfigIDs.PushString(sSection);

		while (kv.GotoNextKey(false))
		{
			kv.GetSectionName(sSection, sizeof(sSection));
			g_hArray_ConfigIDs.PushString(sSection);
		}
	}
	// looking up info on a specific config
	else
	{
		if (!kv.JumpToKey(sConfig, false))
		{
			delete kv;
			if (client) PrintToChat(client, "[SM] Error couldn't find config specified.");
			return -1;
		}

		g_Config.clearSettings();
		kv.GetString("name", g_Config.sName, sizeof(g_Config.sName));
		kv.GetVector("slay", g_Config.slay);
		kv.GetVector("cam_pos", g_Config.cam_pos);
		kv.GetVector("cam_ang", g_Config.cam_ang);
	}

	delete kv;
	return g_hArray_ConfigIDs.Length;
}

void SlaySurvivorBots(int client, const char[] sConfig)
{
	if (PopulateMenuIDs(client, sConfig))
	{
		char sAuthID[36];
		GetClientAuthId(client, AuthId_Steam3, sAuthID, sizeof(sAuthID));

		CreateCameraEntity(g_Config.cam_pos, g_Config.cam_ang);
		slaySurvivorBots(g_Config.slay);
		PrintToChatAll("\x01[SM] %N \x03%s\x01 loaded !slaysafe location: \x04%s", client, sAuthID, g_Config.sName);
	}
}

void slaySurvivorBots(float fLocation[3])
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;
		
		TeleportEntity(i, fLocation, NULL_VECTOR, NULL_VECTOR);
		#if !DEBUG
		CreateTimer(0.5, timer_forcesuicide, GetClientUserId(i));
		#endif
	}
}

public Action timer_forcesuicide(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client) ForcePlayerSuicide(client);
}

void CreateCameraEntity( float position[3], float angles[3])
{
	int iEntity = CreateEntityByName("point_viewcontrol_multiplayer");
	
	if( IsValidEdict(iEntity) && IsValidEntity(iEntity) )
    {
		position[2] += 30.0;	// Get the camera of ground a bit increase z pos
		
		// Again doing this instead of TeleportEntity, becus better.
		char sOrigin[64], sAngle[64];
		
		Format(sOrigin, sizeof(sOrigin), "%f %f %f", position[0], position[1], position[2]);
		Format(sAngle, sizeof(sAngle), "%f %f %f", angles[0], angles[1], angles[2]);
		
		DispatchKeyValue(iEntity, "origin", sOrigin);
		DispatchKeyValue(iEntity, "angles", sAngle);
		
		DispatchSpawn(iEntity);
		
		AcceptEntityInput(iEntity, "enable");

		// disable camera after a few seconds
		CreateTimer(3.5, Timer_DisableCamera, iEntity);
		
    }
}

public Action Timer_DisableCamera(Handle timer, int cameraEntity)
{
	AcceptEntityInput(cameraEntity, "disable");
	AcceptEntityInput(cameraEntity, "kill");
}