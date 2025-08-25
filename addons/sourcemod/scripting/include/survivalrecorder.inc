#if defined _survivalrecorder_included
 #endinput
#endif
#define _survivalrecorder_included


/**
 * Logs a miscellaneous event (if a round's in progress) to the demo archive
 *
 * @param str      Event text
 * @noreturn
 */
native void survRecorder_LogMiscEvent(char[] str);

/**
 * Returns the category as an integer (solo = 1, duo = 2, etc..)
 *
 *
 * @return game category as integer
 */
native int survRecorder_GetCategory();

// credit: autorecorder.sp
stock void InitDirectory(const char[] sDir)
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
			LogMessage("Directory Created: %s", sPath);
		}
	}
}

// credit: drixevel
/*
	Formats seconds as it would appear in-game (e.g. 226:48.67)
		* precision bool should always be passed as true
		* const char[] format should be passed in as "%M:%S" (FORMATTED_TIME define)
*/
stock void FormatSeconds(float seconds, char[] buffer, int maxlength, const char[] format, bool precision = false)
{
	int t = RoundToFloor(seconds);

	int mins; char sMinute[32];
	if (t >= 60)
	{
		mins = RoundToFloor(t / 60.0);
		t %= 60;

		Format(sMinute, sizeof(sMinute), "%02d", mins);
	}

	char sSeconds[32];
	switch (precision)
	{
		case true: Format(sSeconds, sizeof(sSeconds), "%05.2f", float(t) + seconds - RoundToFloor(seconds));
		case false: Format(sSeconds, sizeof(sSeconds), "%02d", t);
	}

	strcopy(buffer, maxlength, format);

	ReplaceString(buffer, maxlength, "%M", strlen(sMinute) > 0 ? sMinute : "00");
	ReplaceString(buffer, maxlength, "%S", strlen(sSeconds) > 0 ? sSeconds : "00");
}

// stock function from drixevel's sourcemod-misc.inc
stock void GetServerIP(char[] sIP, int size, bool show_port = false)
{
	int ip = FindConVar("hostip").IntValue;

	int ips[4];
	ips[0] = (ip >> 24) & 0x000000FF;
	ips[1] = (ip >> 16) & 0x000000FF;
	ips[2] = (ip >> 8) & 0x000000FF;
	ips[3] = ip & 0x000000FF;

	Format(sIP, size, "%d.%d.%d.%d", ips[0], ips[1], ips[2], ips[3]);

	if (show_port)
	{
		Format(sIP, size, "%s:%d", sIP, FindConVar("hostport").IntValue);
	}
}

/*
	Returns human players
*/
stock int GetRealHumanCount(int Disconnector = 0)
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (!IsFakeClient(i) && i != Disconnector)
		{
			count++;
		}
	}
	return count;
}

stock void GetModelName(int client, char[] buffer, int size)
{
    char sModel[64];
    GetClientModel(client, sModel, sizeof(sModel));

    if (StrEqual(sModel, "models/survivors/survivor_coach.mdl")) strcopy(buffer, size, "Coach");
    else if (StrEqual(sModel, "models/survivors/survivor_gambler.mdl")) strcopy(buffer, size, "Nick");
    else if (StrEqual(sModel, "models/survivors/survivor_producer.mdl")) strcopy(buffer, size, "Rochelle");
    else if (StrEqual(sModel, "models/survivors/survivor_mechanic.mdl")) strcopy(buffer, size, "Ellis");
    else if (StrEqual(sModel, "models/survivors/survivor_manager.mdl")) strcopy(buffer, size, "Louis");
    else if (StrEqual(sModel, "models/survivors/survivor_teenangst.mdl")) strcopy(buffer, size, "Zoey");
    else if (StrEqual(sModel, "models/survivors/survivor_namvet.mdl")) strcopy(buffer, size, "Bill");
    else if (StrEqual(sModel, "models/survivors/survivor_biker.mdl")) strcopy(buffer, size, "Francis");
	// custom model being used
	else strcopy(buffer, size, "unknown");
}

stock void survinc_PrintToSourceTVBot(char[] text, any ...)
{
	char sBuffer[4096];
	VFormat(sBuffer, sizeof(sBuffer), text, 2);
	
	if (g_iSourceTVBot < 1 || IsClientInGame(g_iSourceTVBot) == false)
	{
		g_iSourceTVBot = FindSourceTVClient();
	}

	if (g_iSourceTVBot > 0)
	{
		PrintToChat(g_iSourceTVBot, "%s %s", SOURCETV_HEADER, sBuffer);
	}
	else
	{
		LogError("SourceTV bot not in-game.");
	}
}

stock void LogDebugEvent(char[] text, any ...)
{
	char sLog[256];
	VFormat(sLog, sizeof(sLog), text, 2);
	
	// TODO don't think i need this anymore
	#if DEBUG
	survinc_PrintToSourceTVBot("\x04Debug\x01: %s", sLog);
	#endif
	
	LogToFile(g_sDebugLog, "%s", sLog);
}

/*
	TODO get actual game mode if we end up adding that feature..
*/
stock void GetGameMode(char[] sbuffer, int len)
{
	strcopy(sbuffer, len, "vanilla");
}

stock bool IsSurvival()
{
	char sGamemode[16];
	FindConVar("mp_gamemode").GetString(sGamemode, sizeof(sGamemode));
	return StrEqual(sGamemode, "survival");
}

stock float GetCurrentSurvivalTime()
{
	float fTime;
	if (GameRules_GetPropFloat("m_flRoundStartTime") > 0.0) 
	{
		fTime = GetGameTime() - GameRules_GetPropFloat("m_flRoundStartTime");
	}
	else
	{
		fTime = 0.0;
	}
	return fTime;
}

stock void FormatTeam(int team, char[] sBuffer, int size)
{
	switch (team) {
	
	case 1:
		Format(sBuffer, size, "spectate");
	case 2:
		Format(sBuffer, size, "survivors");
	case 3:
		Format(sBuffer, size, "infected");
	default:
		Format(sBuffer, size, "unknown (team %i)", team);
	}
}

// detecting idle survivors.
// credits: https://gitlab.phangos.fr/sourcemod/zombie-4-ever/blob/71af8911f12509da68db2d23bb4030d4f2ad0039/scripting/include/l4d_stocks.inc
stock int L4D_GetBotOfIdlePlayer(int client)
{
	int idleClient;
	int offset;
	char netclass[128];

	// maybe rewrite this so it's not looping through all clients
	for (int bot = 1; bot <= MaxClients; bot++)
	{
		if (!IsClientInGame(bot) || 
		!IsFakeClient(bot) ||
		GetClientTeam(bot) != TEAM_SURVIVORS ||
		!IsPlayerAlive(bot) ||
		GetClientHealth(bot) < 1)
		{
			continue;
		}

		GetEntityNetClass(bot, netclass, sizeof(netclass));
		offset = FindSendPropInfo(netclass, "m_humanSpectatorUserID");

		if (offset < 1)
		{
			continue;
		}

		idleClient = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));

		if (idleClient == client)
		{
			return bot;
		}
	}

	return -1;
}

/*
	Returns client index of the sourceTV bot (-1 if not found)
*/
int FindSourceTVClient()
{
	char sName[32], sTmp[32];
	GetConVarString(g_hSourceTVName, sName, sizeof(sName));
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsFakeClient(i))
			continue;
		
		GetClientName(i, sTmp, sizeof(sTmp));
		if (StrEqual(sTmp, sName, true))
		{
			return i;
		}
	}
	return -1;
}