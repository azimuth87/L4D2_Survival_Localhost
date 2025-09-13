#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

ConVar g_cvAutoBreak;

public Plugin myinfo = {
    name        = "Remove Gravestones Command",
    author      = "dustin",
    description = "",
    version     = "1.0",
    url         = ""
};

#define GRAVEMODELS     6
char g_sGraveModels[GRAVEMODELS][] = {
    "models/props_cemetery/grave_01.mdl",
    "models/props_cemetery/grave_02.mdl",
    "models/props_cemetery/grave_03.mdl",
    "models/props_cemetery/grave_04.mdl",
    "models/props_cemetery/grave_06.mdl",
    "models/props_cemetery/grave_07.mdl"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_breakgrave", Command_removeGravestones);
    RegConsoleCmd("sm_breakgraves", Command_removeGravestones);
    RegConsoleCmd("sm_breakables", Command_removeGravestones); // for now only breaking graves but if we include other maps then we'd probably rename the plugin and handle things different

    g_cvAutoBreak = CreateConVar("sm_breakgraves_auto", "1", "automatically break graves on round start", 0, true, 0.0, true, 1.0);

    HookEvent("round_start", Event_roundstart);
}

public Action Event_roundstart(Event event, const char[] name, bool dontBroadcast)
{
    if (g_cvAutoBreak.IntValue > 0 && isMapChurch())
    {
        breakallgraves();
    }
}

public Action Command_removeGravestones(int client, int args)
{
    if (client < 1)
    {
        ReplyToCommand(client, "[SM] Command only available to in-game clients.");
        return Plugin_Handled;
    }

    if (!isMapChurch())
    {
        ReplyToCommand(client, "[SM] Command only available on church (c10m3_ranchhouse).");
        return Plugin_Handled;
    }

    if (SurvivalRoundInProgress())
    {
        ReplyToCommand(client, "[SM] Cannot use this during a round.");
        return Plugin_Handled;
    }
    
    

    if (breakallgraves() > 0) PrintToChatAll("[SM] Break all gravestones command invoked.");
    else PrintToChat(client, "[SM] There are no gravestones to break.");
    
    return Plugin_Handled;
}

int breakallgraves()
{
    int ent = -1;
    int iCount;
    char sModelName[PLATFORM_MAX_PATH];
    while ((ent = FindEntityByClassname(ent, "prop_physics")) != -1)
	{
        if (IsValidEntity(ent))
        {
            GetEntPropString(ent, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
            for (int i = 0; i < GRAVEMODELS; i++)
            {
                if (StrEqual(sModelName, g_sGraveModels[i]))
                {
                    AcceptEntityInput(ent, "Break");
                    iCount++;
                }
            }
        }
    }
    return iCount;
}

bool isMapChurch()
{
    char sMap[32];
    GetCurrentMap(sMap, sizeof(sMap));
    return (StrEqual(sMap, "c10m3_ranchhouse"));
}

bool SurvivalRoundInProgress()
{
    return GameRules_GetPropFloat("m_flRoundStartTime") > 0.0 && GameRules_GetPropFloat("m_flRoundEndTime") == 0.0;
}