#include <sourcemod>
#include <nativevotes>
#include <sourcetvmanager>

int g_iVoteFor;

// For resetting sv_maxplayers across map changes
int g_iSlotsValue;
Handle g_hMaxPlayers;

bool g_bFirstCheck = true;
int g_iMaxPlayers_Original;

// seperate plugin I didn't want to make a native for
#include "slots/AdminSlotsControl.sp"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "slots",
	author = "unknown",
	description = "Changes the slots",
	url = ""
}

/*
	TODO

	if an admin joins, opens up a slot, then leaves, reset slots to original value
		that was before he joined
*/

/* Store original value so we can reset later. */
public void OnConfigsExecuted()
{
	if (g_bFirstCheck)
	{
		g_bFirstCheck = false;
		int iMaxPlayers = FindConVar("sv_maxplayers").IntValue;
		
		// if sv_maxplayers wasn't set in server.cfg, it'll return "-1"
		if (iMaxPlayers <= 0)
		{
			g_iMaxPlayers_Original = 4;
		}
		else if (iMaxPlayers > 30)
		{
			LogMessage("sv_maxplayers shouldn't be set higher than 30 (current value is set at '%i'). Setting to 30.", iMaxPlayers);
			SetConVarInt(FindConVar("sv_maxplayers"), 30);
			g_iMaxPlayers_Original = 30;
		}
		else
		{
			g_iMaxPlayers_Original = iMaxPlayers;
		}
	}

	// AdminSlotsControl.sp - little delay, wait for the file to be generated first
	CreateTimer(0.5, Timer_LoadAdmins);
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_slots", Slots_Vote, "Changes the slots");
	RegConsoleCmd("sm_slot", Slots_Vote, "Changes the slots");
	
	g_hMaxPlayers = FindConVar("sv_maxplayers");
	HookConVarChange(g_hMaxPlayers, MaxPlayers_Changed);
	
	HookEvent("player_disconnect", PlayerDisconnect_Event, EventHookMode_Pre);

	// AdminSlotsControl.sp
	g_hAdminSlotRejectionMsg = CreateConVar("admin_slots_reject_msg", "Human player limit reached.", "Default rejection message to use when a non-admin tries to connect to the hidden slot.");
	g_Array_SteamIDs = new ArrayList(ByteCountToCells(16));
}

public void MaxPlayers_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	// if !slots hasn't been voted on yet (which means this variable didn't get set), don't do anything
	if (g_iSlotsValue == 0) return;
	
	int iNewValue = StringToInt(newValue);
	if (iNewValue != g_iSlotsValue)
	{
		LogMessage("Reinforcing sv_maxplayers to %i (from %i)", g_iSlotsValue, iNewValue);
		SetConVarInt(g_hMaxPlayers, g_iSlotsValue);
	}
}

public Action PlayerDisconnect_Event(Event event, const char[] name, bool dontBroadcast)
{
	char strNetworkId[8];
	event.GetString("networkid", strNetworkId, sizeof(strNetworkId));
	
	if (!StrEqual(strNetworkId, "BOT"))
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		if (GetRealHumanCount(client) == 0)
		{
			g_iSlotsValue = 0;
			SetConVarInt(g_hMaxPlayers, g_iMaxPlayers_Original);
			LogMessage("Last player left. Sv_maxplayers value reset to %i", g_iMaxPlayers_Original);
		}
	}
	return Plugin_Continue;
}

public Action Slots_Vote(int client, int args)
{	
	if (NativeVotes_IsVoteInProgress())
	{
		ReplyToCommand(client, "\x04A vote is already in progress.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == 1 && !IsGenericAdmin(client))
	{
		ReplyToCommand(client, "\x04You must be on the survivor or infected team to use this command.");
		return Plugin_Handled;
	}
	
	if (args != 1)
	{
		ReplyToCommand(client, "\x04[SM] Invalid Usage: !slots <#>");
		return Plugin_Handled;
	}
	
	char sArgs[32];
	GetCmdArg(1, sArgs, sizeof(sArgs));
	int voteval = StringToInt(sArgs);
	
	if (voteval < 1 || voteval > 30)
	{
		ReplyToCommand(client, "\x04[SM] Invalid Usage: value cannot be less than 1 or exceed 30.");
		return Plugin_Handled;
	}
	
	if (voteval == FindConVar("sv_maxplayers").IntValue) 
	{
		ReplyToCommand(client, "\x04Slots are already set to %i", voteval);
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "\x04[SM] You cannot start a vote while one is currently going.");
		return Plugin_Handled;
	}

	// game mode check
	char sGamemode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGamemode, sizeof(sGamemode));
	
	if ((StrContains(sGamemode, "versus") != -1 || StrContains(sGamemode, "scavenge") != -1 || StrContains(sGamemode, "mutation12") != -1 || StrContains(sGamemode, "mutation15") != -1 || StrContains(sGamemode, "mutation18") != -1) && voteval < 8)
	{
		ReplyToCommand(client, "\x04[SM] Cannot vote for less than 8 slots in %s mode", sGamemode);
		return Plugin_Handled;
	}
	
	g_iVoteFor = voteval;

	Handle vote = NativeVotes_Create(MenuHandler_VoteCallback, NativeVotesType_Custom_YesNo);
	NativeVotes_SetInitiator(vote, client);
	
	char sDetails[256];
	FormatEx(sDetails, sizeof(sDetails), "Change slot limit to %i?", g_iVoteFor);
	NativeVotes_SetDetails(vote, sDetails);
	NativeVotes_SetResultCallback(vote, VoteResultHandler);
	NativeVotes_DisplayToAll(vote, 20);
	
	return Plugin_Handled;
}

public int MenuHandler_VoteCallback(NativeVote menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(menu, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(menu, NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_End:
		{
			NativeVotes_Close(menu);
		}
	}
}

public int VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[] client_indexes, const int[] client_votes, int num_items, const int[] item_indexes, const int[] item_votes)
{
	for (int i=0; i<num_items; i++)
	{
		if (item_indexes[i] == NATIVEVOTES_VOTE_YES && item_votes[i] > (num_clients / 2))
		{
			char sDetails[256];
			FormatEx(sDetails, sizeof(sDetails), "Changing slots to %i...", g_iVoteFor);
			NativeVotes_DisplayPass(vote, sDetails);
			
			g_iSlotsValue = g_iVoteFor; // assign before setting the convar int, because of the hooked convar change function.
			SetConVarInt(FindConVar("sv_maxplayers"), g_iVoteFor);
			return;
		}
	}
	
	NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
}

bool IsGenericAdmin(int client) {
    return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false); 
}

int GetRealHumanCount(int Disconnector = 0)
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