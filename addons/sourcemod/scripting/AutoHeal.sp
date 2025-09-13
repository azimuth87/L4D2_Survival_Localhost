/*============================================================================
 * 10/07/2020 - Converted plugin source to transitional syntax. - Gravity
=============================================================================*/
#include <sourcemod>
#include <sdktools>

#pragma semicolon	1
#pragma newdecls required

#define TEAM_SURVIVOR	2

bool bRoundStarted;
bool bHangHelpEnabled;

public Plugin myinfo =
{
	name = "Survival Auto Heal",
	author = "khan",
	description = "Give players full health when survival rounds begin",
	version = "1.0"
};

public void OnPluginStart()
{
	// Some heal commands to support existing radial menu and command to add to admin menu
	RegAdminCmd("sm_heal", Give_Health,	ADMFLAG_KICK, "Heal player");
	RegAdminCmd("sm_gw", Give_Health,	ADMFLAG_KICK, "Heal player");
	
	// Hook events
	HookEvent("survival_round_start", Event_SurvivalStart, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_ledge_grab", Event_LedgeGrab, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	
	// Default round start to true in case someone reloads plugins after the round starts
	bRoundStarted = true;

	LoadTranslations("common.phrases");
}

public void Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
	bRoundStarted = false;
}

public void OnConfigsExecuted()
{
	GameModeCheck();
}

void GameModeCheck()
{
	// Only enable for survival games
	char GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	if (StrContains(GameName, "survival", false) != -1)
	{
		bHangHelpEnabled = true;
	}
	else
	{
		bHangHelpEnabled = false;
	}
}

public void Event_RoundEnd(Event hEvent, const char[] name, bool dontBroadcast)
{
	bRoundStarted = false;
}

public void Event_LedgeGrab(Handle hEvent, const char[] name, bool dontBroadcast)
{
	if (!bRoundStarted && bHangHelpEnabled)
	{
		// Delay pickup - player will just fall off the edge otherwise
		int userid = GetEventInt(hEvent, "userid");
		CreateTimer(0.1, Timer_PickupHelp, userid);
	}
}

public Action Timer_PickupHelp(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client != 0 && IsClientInGame(client))
		HealPlayer(client);
}

public void Event_SurvivalStart(Handle hEvent, const char[] name, bool dontBroadcast)
{
	bRoundStarted = true;
	
	// Find and heal all survivors when the rounds starts
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != TEAM_SURVIVOR)continue;
		HealPlayer(i);
	}
}

void HealPlayer(int client)
{
	// Heal player to 100 permanent health
	int iflags = GetCommandFlags("give");
	SetCommandFlags("give", iflags & ~FCVAR_CHEAT);
	FakeClientCommand(client,"give health");
	SetCommandFlags("give", iflags);
	
	// Remove temp health and reset revive count
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
}

public Action Give_Health(int client, int args)
{
	char sPlayer[64];
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_heal <#userid|name>");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, sPlayer, sizeof(sPlayer));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count; 
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(sPlayer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		int iflags = GetCommandFlags("give");
		SetCommandFlags("give", iflags & ~FCVAR_CHEAT);
		FakeClientCommand(target_list[i], "give health");
		SetCommandFlags("give", iflags);
		
		SetEntPropFloat(target_list[i], Prop_Send, "m_healthBuffer", 0.0);
		SetEntProp(target_list[i], Prop_Send, "m_currentReviveCount", 0);
	}
	
	// Log Action, used by survival recorder
	char sCmdArg[24], sArgs[80];
	GetCmdArg(0, sCmdArg, sizeof(sCmdArg));
	GetCmdArgString(sArgs, sizeof(sArgs));
	Format(sArgs, sizeof(sArgs), "%s %s", sCmdArg, sArgs);
	LogAction(client, -1, sArgs);
	
	return Plugin_Handled;
}
