/*
[Yesterday, 10:27 PM]
Gr?vity:
	hi, think u could help with a fairly simple plugin, basically just printstochat to the client first kit used (roundtime). after that 2 kits used last one used: x ssecond or min ago3 kits used last one used x mins ago
	etc
	only kits you used on yourself lol

...........................................
Format:

1 kit used.
2 kits used (last one used 2 minutes 58 seconds ago)
3 kits used (last one used 1 hour 58 minutes ago)
...........................................

For tracking kit usage in survival.
*/

#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

// globals
StringMap g_hTrie_Medkits;
StringMap g_hTrie_Timestamp;
bool g_bRoundInProgress;

public Plugin myinfo = {
	name        = "Medkit Statistics",
	author      = "dustin",
	description = "keeps track of players medkit usage.",
	version     = "1.1",
	url         = ""
};

/*
	version
	
	1.1 - print out message to SourceTV client on successfull heal,
		since it's not always obvious if someone healed when watching a demo recording.
*/

public void OnPluginStart()
{
	HookEvent("survival_round_start", Event_OnSurvivalStart);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("heal_success", Event_OnHealSuccess);
	
	g_hTrie_Medkits = CreateTrie();
	g_hTrie_Timestamp = CreateTrie();
}

public void Event_OnHealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int SourceTV = FindSourceTVClient();
	
	int client = GetClientOfUserId(GetEventInt(event, "subject"));
	
	// game mode check not needed since g_bRoundInProgress only gets set when survival clock is active
	if (!IsPlayerIndex(client) || IsFakeClient(client) || !g_bRoundInProgress)
	{
		return;
	}
	
	char sSteamID[64];
	if (!GetClientAuthId(client, AuthId_Steam3, sSteamID, sizeof(sSteamID)))
	{
		LogError("[Medkit Stats] unable to retrieve client's steam ID. Steam database is probably down.");
		return;
	}
	
	int iMedkits;
	GetTrieValue(g_hTrie_Medkits, sSteamID, iMedkits);

	iMedkits++;
	
	SetTrieValue(g_hTrie_Medkits, sSteamID, iMedkits);
	
	if (iMedkits == 1)
	{
		PrintToChat(client, "\x04first\x01 medkit used.");
		
		if (SourceTV > 0) PrintToChat(SourceTV, "\x03%L\x01 : \x04first\x01 medkit used.", client);
		
		int iTime = GetTime();
		SetTrieValue(g_hTrie_Timestamp, sSteamID, iTime);
	}
	else
	{
		int iTime;
		GetTrieValue(g_hTrie_Timestamp, sSteamID, iTime);
		
		int iDifference = GetTime() - iTime;
		
		int Hours = RoundToFloor(float(iDifference)/60/60);
		int Minutes = (iDifference/60) % 60;
		int Seconds = iDifference % 60;
		
		char sTime[32], sSeconds[12], sMinutes[12], sHours[12];
		
		// less than 1 minute
		if (iDifference < 60)
		{
			Format(sTime, sizeof(sTime), "\x04%i\x01 seconds", iDifference);
		}
		
		// less than 1 hour
		else if (iDifference < 3600)
		{
			Format(sMinutes, sizeof(sMinutes), Minutes == 1? "minute" : "minutes");
			Format(sSeconds, sizeof(sSeconds), Seconds == 1? "second" : "seconds");
			
			Format(sTime, sizeof(sTime), "\x04%i\x01 %s \x04%i\x01 %s", Minutes, sMinutes, Seconds, sSeconds);
		}
		
		else
		{
			Format(sHours, sizeof(sHours), Hours == 1? "hour" : "hours");
			Format(sMinutes, sizeof(sMinutes), Minutes == 1? "minute" : "minutes");
			
			Format(sTime, sizeof(sTime), "\x04%i\x01 %s \x04%i\x01 %s", Hours, sHours, Minutes, sMinutes);
		}
			
		PrintToChat(client, "\x04%i\x01 kits used (last one used %s ago)", iMedkits, sTime);
		
		if (SourceTV > 0) PrintToChat(SourceTV, "\x03%L\x01 : \x04%i\x01 kits used (last one used %s ago)", client, iMedkits, sTime);
		
		iTime = GetTime();
		SetTrieValue(g_hTrie_Timestamp, sSteamID, iTime);
	}
}

public void Event_OnSurvivalStart(Event event, const char[] name, bool dontBroadcast)
{
	ClearTrie(g_hTrie_Medkits);
	ClearTrie(g_hTrie_Timestamp);
	
	g_bRoundInProgress = true;
}

public void OnMapStart()
{
	g_bRoundInProgress = false;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundInProgress = false;
}

bool IsPlayerIndex(int client)
{
	return 0 < client <= MaxClients;
}

int FindSourceTVClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsFakeClient(i)) continue;
		
		if (IsClientSourceTV(i)) return i;
	}
	return -1;
}