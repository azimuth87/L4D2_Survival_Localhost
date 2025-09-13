#include <sdktools>

#pragma semicolon	1
#pragma newdecls required

#define TEAM_SURVIVOR	2

bool g_bRoundInProgress;

public Plugin myinfo =
{
    name = "SlayBots",
    author = "khan",
    description = "Slays all the bots.",
    version = "1.0"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_nobots", TeleportBots);
	RegConsoleCmd("sm_nobot", TeleportBots);
	RegConsoleCmd("sm_nb", TeleportBots);
	RegConsoleCmd("sm_slaybots", Cmd_SlayBots);
	
	// update for GM group - only allow command when round not in progress
	HookEvent("survival_round_start", Event_OnSurvivalStart);
	HookEvent("round_end", Event_OnRoundEnd);
}

public Action Cmd_SlayBots(int client, int args)
{	
	if (!client || GetClientTeam(client) != TEAM_SURVIVOR) { return Plugin_Handled; }
		
	if (g_bRoundInProgress)
	{
		PrintToChat(client, "[SM] Can't use this while a round is in progress");
		return Plugin_Handled;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR) continue;
		
		if (IsPlayerAlive(i) && IsFakeClient(i))
			ForcePlayerSuicide(i);
	}

	return Plugin_Handled;
}

public Action TeleportBots(int client, int args)
{
	if (!client || GetClientTeam(client) != TEAM_SURVIVOR) { return Plugin_Handled; }
		
	if (g_bRoundInProgress)
	{
		PrintToChat(client, "[SM] Can't use this while a round is in progress");
		return Plugin_Handled;
	}
	
	bool OnGround = false;
	if (GetEntityFlags(client) & FL_ONGROUND)
		OnGround = true;
	
	if (!OnGround)
	{
		PrintToChat(client, "[SM] You must be on the ground.");
		return Plugin_Handled;
	}
	
	float vec[3];
	GetClientAbsOrigin(client, vec);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))continue;
		
		// Check if this is a bot survivor		
		if (IsPlayerAlive(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
			TeleportEntity(i, vec, NULL_VECTOR, NULL_VECTOR);
		
		// Give the bots a chance to spread out a bit
		CreateTimer(1.5, Timer_SlayTeleBots, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Handled;
}

public Action Timer_SlayTeleBots(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))continue;
		
		// Check if this is a bot survivor		
		if (IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsFakeClient(i))
			ForcePlayerSuicide(i);
	}
}

public Action Event_OnSurvivalStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundInProgress = true;
}

public Action Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundInProgress = false;
}

public void OnMapStart()
{
	g_bRoundInProgress = false;
}