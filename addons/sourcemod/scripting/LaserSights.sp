#define PLUGIN_VERSION    "1.1"
#define PLUGIN_NAME       "L4D2 Laser Sights"

#include <sourcemod>
#include <sdktools>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)          (GetClientTeam(%1) == 2)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))

static Handle:cvarAllowAdmin				= INVALID_HANDLE;
static Handle:cvarAllowAfterRoundStart	= INVALID_HANDLE;

new bool:bLaserAll = true;
new bool:g_bRoundInProgress;

#define NUM_LASER_MAPS	15
new const String:LaserMaps[NUM_LASER_MAPS][] = 
{
	"c2m1_highway", // Motel
	"c2m5_concert", // Concert
	"c4m2_sugarmill_a", // Sugar Mill
	"c7m1_docks", // Traincar
	"c7m3_port", // Port Sacrifice
	"c8m2_subway", // Generator Room
	"c1m2_streets", // Gun Shop
	"c9m2_lots", // Truck Depot
	"c10m5_houseboat", // Boathouse
	"c11m3_garage", // Construction Site
	// "c10m2_drainage", // Drains, available after round starts, some players didn't like that
	"c11m2_offices", // Crane
	"c11m5_runway", // Runway
	"c12m5_cornfield", // Farmhouse
	"c13m4_cutthroatcreek", // Waterworks
	"c14m2_lighthouse" // Lighthouse
};

/*
	Changelog

1.1 (Aug 11, 2024) - removed ability to toggle off lasers mid-round.
	Lleage: there was a round where manga (non admin) grabbed a laser on accident mid round and got rid of it using the /l command 
		so he could put the gun back on the pile


 */

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "khan",
	description = "L4D2 Laser Sights",
	version = PLUGIN_VERSION
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	// This plugin will only work on L4D2
	decl String:GameName[64]
	GetGameFolderName(GameName, sizeof(GameName))
	if (!StrEqual(GameName, "left4dead2", false))
		return APLRes_Failure
	else
	return APLRes_Success
}

public OnPluginStart()
{
	// Console commands for turning on or off laser sights
	RegConsoleCmd("sm_laser", CmdLaserToggle);
	RegConsoleCmd("sm_l", CmdLaserToggle);
	RegConsoleCmd("sm_laseron", CmdLaserOn);
	RegConsoleCmd("sm_laseroff", CmdLaserOff);
	
	// Admin commands for turning on or off laser sights for everyone
	RegAdminCmd("sm_laserall", CmdLaserAll, ADMFLAG_KICK, "Toggle lasers for all survivors");
	RegAdminCmd("sm_laserallon", CmdLaserAllOn, ADMFLAG_KICK, "Turn on lasers for all survivors");
	RegAdminCmd("sm_laseralloff", CmdLaserAllOff, ADMFLAG_KICK, "Turn off lasers for all survivors");
	
	// Create cvar for setting whether or not admins are always allowed to turn on laser sights
	cvarAllowAdmin = CreateConVar("l4d2_lasersight_allow_admin", "0", "Whether or not to allow admins to always be able to turn on laser sights", 0);
	
	cvarAllowAfterRoundStart = CreateConVar("l4d2_lasersight_allow_afterRoundStart", "0", "Whether or not to allow toggling of laser sights after survival round has started", 0);
	
	// Hook start of round to reset bLaserAll
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	
	HookEvent("survival_round_start", Event_OnSurvivalStart);
	HookEvent("round_end", Event_OnRoundEnd);
}

public Action:Event_RoundStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	bLaserAll = true;
}

public Action:Event_OnSurvivalStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_bRoundInProgress = true;
}

public Action:Event_OnRoundEnd(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_bRoundInProgress = false;
}

public OnMapStart()
{
	g_bRoundInProgress = false;
}

public Action:CmdLaserToggle(client, args)
{	
	if (AllowLaser(client)) // Only allow turning on laser sights if the survival map has lasers
	{
		if (HasLaser(client))
		{
			CheatCommand(client, "upgrade_remove", "LASER_SIGHT");
		}
		else
		{
			CheatCommand(client, "upgrade_add", "LASER_SIGHT");
		}
		
		if (g_bRoundInProgress || !MapHasLasers())
		{
			// Log Action, used by survival recorder
			char sCmdArg[24];
			GetCmdArg(0, sCmdArg, sizeof(sCmdArg));
			LogAction(client, -1, sCmdArg);
		}
	}
	
	return Plugin_Handled;
}

public Action:CmdLaserOn(client, args)
{
	// Only allow turning on laser sights if the survival map has lasers
	if (AllowLaser(client))
	{
		if (!HasLaser(client))
		{
			CheatCommand(client, "upgrade_add", "LASER_SIGHT");
			
			if (g_bRoundInProgress || !MapHasLasers())
			{
				// Log Action, used by survival recorder
				char sCmdArg[24];
				GetCmdArg(0, sCmdArg, sizeof(sCmdArg));
				LogAction(client, -1, sCmdArg);
			}
		}
	}
	return Plugin_Handled;
}

public Action:CmdLaserOff(client, args)
{
	// Always allow turning off laser sights
	if (HasLaser(client))
	{
		CheatCommand(client, "upgrade_remove", "LASER_SIGHT");
	}
	return Plugin_Handled;
}

public Action:CmdLaserAll(client, args)
{
	if (AllowLaser(client))
	{
		// Give or remove laser sights
		ToggleLasers(bLaserAll);
		
		// Toggle bool
		bLaserAll = !bLaserAll;
		
		if (g_bRoundInProgress || !MapHasLasers())
		{
			// Log Action, used by survival recorder
			char sCmdArg[24];
			GetCmdArg(0, sCmdArg, sizeof(sCmdArg));
			LogAction(client, -1, sCmdArg);
		}
	}
}

public Action:CmdLaserAllOn(client, args)
{
	// Allow admins to turn on laser sights for everyone if cvar is set
	if (AllowLaser(client))
	{
		ToggleLasers(true);
		
		if (g_bRoundInProgress || !MapHasLasers())
		{
			// Log Action, used by survival recorder
			char sCmdArg[24];
			GetCmdArg(0, sCmdArg, sizeof(sCmdArg));
			LogAction(client, -1, sCmdArg);
		}
	}
}

public Action:CmdLaserAllOff(client, args)
{
	ToggleLasers(false);
}

public ToggleLasers(bool:give)
{
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		if (IS_SURVIVOR_ALIVE(i))
		{
			if (give)
			{
				CheatCommand(i, "upgrade_add", "LASER_SIGHT");
			}
			else
			{
				CheatCommand(i, "upgrade_remove", "LASER_SIGHT");
			}
		}
	}
}

public bool:AllowLaserBeforeStart()
{
	new String:sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));
	
	// Don't allow before start
	if (StrEqual(sMap, "c11m2_offices") || StrEqual(sMap, "c10m2_drainage"))
		return false;
		
	// Allow
	return true;
}

public bool:HasLaser(client)
{
	new weapon = GetPlayerWeaponSlot(client, 0);
	if (weapon != -1)
	{
		new upgradeBit = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
		if ((upgradeBit & 4) == 4) return true;
	}
	return false;
}

bool:AllowLaser(client)
{
	if (client == 0)
	{
		ReplyToCommand(client, "Command available in-game only.");
		return false;
	}
	
	if (!IsSurvival())
	{
		PrintToChat(client, "\x05Command only available in survival mode.");
		return false;
	}
	
	if (GetConVarBool(cvarAllowAdmin) && (GetUserAdmin(client) != INVALID_ADMIN_ID))
	{
		// Allow admins to turn on lasers whenever they want
		return true;
	}
	
	if (MapHasLasers())
	{
		if (g_bRoundInProgress && GetConVarBool(cvarAllowAfterRoundStart) == false)
		{
			PrintToChat(client, "\x05Not allowed to use this command while a round is in progress.");
			return false;
		}
		return true;
	}
	else
	{
		PrintToChat(client, "\x05Not allowed to use this command on this map.");
		return false;
	}
}

bool:IsSurvival()
{
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	if (StrContains(GameName, "survival", false) != -1)
	{
		return true;
	}
	return false;
}

public bool:MapHasLasers()
{
	new String:map[128];
	GetCurrentMap(map, sizeof(map));
	
	for (new i = 0; i < NUM_LASER_MAPS; i++)
	{
		if (StrEqual(LaserMaps[i], map))
		{
			return true;
		}
	}
	return false;
}

stock CheatCommand(client, const String:command[], const String:arguments[])
{
    if (!client) return;
    new admindata = GetUserFlagBits(client);
    SetUserFlagBits(client, ADMFLAG_ROOT);
    new flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
    SetUserFlagBits(client, admindata);
}