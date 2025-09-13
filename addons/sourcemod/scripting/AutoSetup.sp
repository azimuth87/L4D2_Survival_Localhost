#include <weapons>

#define DEBUG	0

/* 
 * TODO:
 * * Fix bug with gun spawn counts being messed up if a player is given their setup standing next to a gun stack of the primary weapon
 * *   that they currently have equipped and is put back b/c it's not the one they want
 */

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))

#define L4D_TEAM_SPECTATE 1

/* 
	Version history

	1.1:
		Added more out-of-bounds zones

		only realized after mapping out several additional areas that !setup doesn't use health items (pills or kits).
		Still think it's useful to keep these for mapping out-of-bounds health items when we get around to updating !spechud to be TLS compatible.
		(on round start !spechud deletes out-of-bound items so it's only counting and displaying in-bound kits / throwables when it loops through everything)
			- dustin

	1.0:
		original plugin (updated for TLS update)

*/
#define PLUGIN_VERSION "1.1"
public Plugin:myinfo =
{
	name = "Auto Survival Setup Plugin",
	author = "khan",
	description = "Allow lazy players to avoid needing to pick up weapons...",
	version = PLUGIN_VERSION
};

new const WeaponAmmo[_:WeaponId] = 
{
	-1,				//WEPID_NONE,             
	-1,				//WEPID_PISTOL,           
	650,   			//"smg",              
	72,   			//"pump_shotgun",      
	90,   			//"auto_shotgun",      
	360,   			//"assault_rifle",            
	150,   			//"hunting_rifle",    
	650,   			//"silenced_smg",     
	72,   			//"chrome_shotgun",   
	360,   			//"desert_rifle",     
	180,  			//"military_sniper" 
	90,   			//"spas_shotgun",     
	-1,    
	-1,          
	-1,        
	-1,       
	-1,           
	-1,     
	-1, 			//WEPID_OXYGEN_TANK,      
	-1, 			//WEPID_MELEE,            
	-1, 			//WEPID_CHAINSAW,         
	30, 			//"grenade_launcher", 
	-1, 			//WEPID_AMMO_PACK,        
	-1,       
	-1,    
	-1,         
	360,			//"ak_47",       
	-1,				//WEPID_GNOME_CHOMPSKI,   
	-1,				//WEPID_COLA_BOTTLES,     
	-1,
	-1,  
	-1,       
	-1, 			//WEPID_PISTOL_MAGNUM,    
	650, 			//WEPID_SMG_MP5,          
	360, 			//WEPID_RIFLE_SG552,      
	180, 			//WEPID_SNIPER_AWP,       
	180, 			//WEPID_SNIPER_SCOUT,     
	-1, 			//"m60",     
	-1, 			//WEPID_TANK_CLAW,        
	-1, 			//WEPID_HUNTER_CLAW,      
	-1, 			//WEPID_CHARGER_CLAW,     
	-1, 			//WEPID_BOOMER_CLAW,      
	-1, 			//WEPID_SMOKER_CLAW,      
	-1, 			//WEPID_SPITTER_CLAW,     
	-1, 			//WEPID_JOCKEY_CLAW,      
	-1, 			//WEPID_MACHINEGUN,       
	-1, 			//WEPID_FATAL_VOMIT,      
	-1, 			//WEPID_EXPLODING_SPLAT,  
	-1, 			//WEPID_LUNGE_POUNCE,     
	-1, 			//WEPID_LOUNGE,           
	-1, 			//WEPID_FULLPULL,         
	-1, 			//WEPID_CHOKE,            
	-1, 			//WEPID_THROWING_ROCK,    
	-1, 			//WEPID_TURBO_PHYSICS,    
	-1, 			//WEPID_AMMO,             
	-1 				//WEPID_UPGRADE_ITEM
}

#define NUM_LASER_MAPS	15
new const String:sLaserMaps[NUM_LASER_MAPS][] = 
{
	"c1m2_streets", "c2m1_highway", "c2m5_concert", "c4m2_sugarmill_a", "c7m1_docks", 
	"c7m3_port", "c8m2_subway", "c9m2_lots", "c10m5_houseboat", 
	"c11m2_offices", "c11m3_garage", "c11m5_runway", "c12m5_cornfield", 
	"c13m4_cutthroatcreek", "c14m2_lighthouse"
}

// don't allow !setup command on these maps
#define NUM_RESTRICTED_MAPS	1
new const String:g_sRestrictedMaps[NUM_RESTRICTED_MAPS][] = 
{
	"c1m4_atrium"
}

enum
{
	Area_Min_X,
	Area_Min_Y,
	Area_Min_Z,
	Area_Max_X,
	Area_Max_Y,
	Area_Max_Z,
	Area_MaxStats
};

Handle g_hEntGiven = INVALID_HANDLE;
Handle g_hBlacklistAreas = INVALID_HANDLE;

char g_sKVSetupFile[PLATFORM_MAX_PATH];

Handle g_hEnabled;
bool g_bAutoSetupEnabled;
bool g_bAlreadyGiven[MAXPLAYERS];
bool g_bSurvivalStart;
int g_iRetryCount[MAXPLAYERS];

bool g_bSettingDefault[MAXPLAYERS];


public OnPluginStart()
{
	RegConsoleCmd("sm_setup", Cmd_Setup);
	//RegAdminCmd("sm_setuptest", Cmd_TestSetup, ADMFLAG_KICK, "test giving out setups");
	
	g_hEnabled = CreateConVar("autosetup_enabled", "1", "Auto pickup of weapons at beginning of round", 0, true, 0.0, true, 1.0);
	g_bAutoSetupEnabled = GetConVarBool(g_hEnabled);
	HookConVarChange(g_hEnabled, OnEnabledChange);
		
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	HookEvent("survival_round_start", Event_SurvivalRoundStart, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_PlayerBotReplace, EventHookMode_Post);
	
	g_bSurvivalStart = false;
	
	g_hEntGiven = CreateTrie();
	g_hBlacklistAreas = CreateArray(Area_MaxStats);
	
	ResetRetryCount();
}

public OnPluginEnd()
{
	ClearArray(g_hBlacklistAreas);
}

public OnMapStart()
{
	ClearArray(g_hBlacklistAreas);
	
	LoadBlacklistAreas();
}

//====================================
// Commands and ConVar Handles
//====================================

public Action:Cmd_Setup(client, args)
{
	if (IsCommandAccessible(client))
	{
		ShowAutoSetupMenu(client);
	}
	
	return Plugin_Handled;
}

public OnEnabledChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	CheckEnabled();
}

public CheckEnabled()
{
	g_bAutoSetupEnabled = GetConVarBool(g_hEnabled);
	if (g_bAutoSetupEnabled)
	{
		PrintToChatAll("\x04Auto setup enabled");
	}
	else
	{
		PrintToChatAll("\x04Auto setup disabled");
	}	
}

//public Action:Cmd_TestSetup(client, args)
//{
//	ResetAlreadyGiven();
//	
//	RunAutoSetup();
//}

//====================================
// Event/Timer stuff
//====================================

public Action:Event_RoundStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (!IsSurvival())
	{
		return Plugin_Continue;
	}
	
	ResetAlreadyGiven();
	
	SetKVPath();
	
	// Delay slightly before handing out weapons to let things load
	CreateTimer(0.3, Timer_RoundDelay);
	
	return Plugin_Continue;
}

public Action:Timer_RoundDelay(Handle:timer)
{
	RunAutoSetup();
}

public OnClientPostAdminCheck(client)
{
	if (!IsFakeClient(client) && GetClientCount(true) < MaxClients && IsSurvival())
	{
		if (g_bSurvivalStart)
		{
			#if DEBUG
			LogMessage("Survival start %N", client);
			#endif
			// Survival round already started. Don't give out weapons to this player.
			return
		}
		else
		{
			#if DEBUG
			LogMessage("Survival not started %N", client);
			#endif
		}
		
		if (g_bAutoSetupEnabled)
		{
			// Reset retry count. Plugin will retry giving player weapons up to 10 times in case they weren't fully connect when it runs at first.
			g_iRetryCount[client] = 0;
			
			// Delay checking for player setup to give them time to actually take control of survivor.
			CreateTimer(0.3, Timer_PlayerConnectDelay, client);
		}
	}
}

public Action:Timer_PlayerConnectDelay(Handle:timer, any:client)
{
	RunAutoSetupInd(client);
	return Plugin_Continue;
}

public Action:Event_RoundEnd(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_bSurvivalStart = false;
	return Plugin_Continue;
}

public Action:Event_SurvivalRoundStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_bSurvivalStart = true;
	return Plugin_Continue;
}

public Action:Event_PlayerBotReplace(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (!g_bSurvivalStart && IsSurvival())
	{
		new client = GetClientOfUserId( GetEventInt(hEvent, "player") );
		RunAutoSetupInd(client);
	}
	return Plugin_Continue;
}


//=====================================
// Helper functions
//=====================================

bool IsSurvival()
{
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	return StrContains(GameName, "survival", false) != -1;
}

bool IsRoundActive()
{
    return GameRules_GetPropFloat("m_flRoundStartTime") > 0.0 && GameRules_GetPropFloat("m_flRoundEndTime") == 0.0;
}

public bool:IsMapRestricted()
{
	new String:map[128];
	GetCurrentMap(map, sizeof(map));
	
	for (new i = 0; i < NUM_RESTRICTED_MAPS; i++)
	{
		if (StrEqual(g_sRestrictedMaps[i], map))
		{
			return true;
		}
	}
	return false;
}

bool IsCommandAccessible(int client)
{
	if (IsRoundActive())
	{
		PrintToChat(client, "[SM] Can't use while round's in progress.");
		return false;
	}
	else if (IsMapRestricted())
	{
		PrintToChat(client, "[SM] Can't use command on this map.");
		return false;
	}

	return true;
}

public ResetEntStatus()
{
	ClearTrie(g_hEntGiven);
}

public AddAssignedStatus(ent)
{
	char sEntId[32];
	IntToString(ent, sEntId, sizeof(sEntId));
	
	SetTrieValue(g_hEntGiven, sEntId, 1, false);
}

bool AlreadyAssigned(ent)
{
	char sEntId[32];
	IntToString(ent, sEntId, sizeof(sEntId));
	
	int iTemp;
	return GetTrieValue(g_hEntGiven, sEntId, iTemp);
}

public ResetAlreadyGiven()
{
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		g_bAlreadyGiven[i] = false;
	}
}

public bool:HasPrimary(client)
{
	new weapon = GetPlayerWeaponSlot(client, 0);
	if (weapon != -1)
	{
		return true;
	}
	return false;
}

public bool:HasSecondary(client)
{
	new weapon = GetPlayerWeaponSlot(client, 1);
	if (weapon != -1)
	{
		return true;
	}
	return false;
}

public bool:HasThrowable(client)
{
	new weapon = GetPlayerWeaponSlot(client, 2);
	if (weapon != -1)
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
		if (StrEqual(sLaserMaps[i], map))
		{
			return true;
		}
	}
	return false;
}

public ResetRetryCount()
{
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		g_iRetryCount[i] = 0;
	}
}

bool IsEntLocation(float vLoc[3], float vEntLoc[3])
{
	if (GetVectorDistance(vLoc, vEntLoc) < 20.0)
	{
		return true;
	}
	
	return false;
}

bool HasLaser(client)
{
	new iWeaponEnt = GetPlayerWeaponSlot(client, 0);
	if (iWeaponEnt != -1)
	{
		new upgradeBit = GetEntProp(iWeaponEnt, Prop_Send, "m_upgradeBitVec");
		if ((upgradeBit & 4) == 4) return true;
	}
	return false;
}

#define UPGRADE_LASER           (1 << 2)
ToggleLaserOnWeapon(client, bool bEnable)
{
	int iWeaponEnt = GetPlayerWeaponSlot(client, 0);
	if (iWeaponEnt != -1)
	{
		new upgrades = GetEntProp(iWeaponEnt, Prop_Send, "m_upgradeBitVec");
		
		if (bEnable)
		{
			if (HasLaser(client))	 // Weapon already has lasersights
			{
				return;
			}
			upgrades |= UPGRADE_LASER;
		}
		else 
		{
			if (!HasLaser(client))	// Weapon doesn't have lasersights
			{
				return
			}
			upgrades &= ~UPGRADE_LASER;
		}
		
		SetEntProp(iWeaponEnt, Prop_Send, "m_upgradeBitVec", upgrades);
	}
}

GiveItem(client, String:sWeaponName[128]) 
{
	WeaponId wID = WeaponNameToId(sWeaponName);
	char sAmmo[16];
	IntToString(WeaponAmmo[wID], sAmmo, sizeof(sAmmo));
	
	int iWeaponEnt = CreateEntityByName(sWeaponName);
	DispatchSpawn(iWeaponEnt);
	
	if (WeaponAmmo[wID] > 0)
	{
		SetEntProp(iWeaponEnt, Prop_Send, "m_iExtraPrimaryAmmo", WeaponAmmo[wID], 4);
	}
	
	AcceptEntityInput(iWeaponEnt, "Use", client, client);
}


TryGetEntityMeleeName(int iMeleeEnt, char sMeleeName[32])
{
	char sModel[128];
	GetEntPropString(iMeleeEnt, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	if (StrContains(sModel, "cricket_bat", false) != -1)
	{
		sMeleeName = "cricket_bat";
	}
	else if (StrContains(sModel, "bat", false) != -1)
	{
		sMeleeName = "baseball_bat";
	}
	else if (StrContains(sModel, "crowbar", false) != -1)
	{
		char sEntName[128];
		GetEntPropString(iMeleeEnt, Prop_Data, "m_iName", sEntName, sizeof(sEntName));
		
		if (StrEqual(sEntName,"sneaky_crowbar", false))
		{
			sMeleeName = "golden_crowbar";
		}
		else
		{
			sMeleeName = "crowbar";
		}
	}
	else if (StrContains(sModel, "electric_guitar", false) != -1)
	{
		sMeleeName = "electric_guitar";
	}
	else if (StrContains(sModel, "fireaxe", false) != -1)
	{
		sMeleeName = "fireaxe";
	}
	else if (StrContains(sModel, "frying_pan", false) != -1)
	{
		sMeleeName = "frying_pan";
	}
	else if (StrContains(sModel, "golfclub", false) != -1)
	{
		sMeleeName = "golfclub";
	}
	else if (StrContains(sModel, "machete", false) != -1)
	{
		sMeleeName = "machete";
	}
	else if (StrContains(sModel, "tonfa", false) != -1)
	{
		sMeleeName = "tonfa";
	}
	else if (StrContains(sModel, "katana", false) != -1)
	{
		sMeleeName = "katana";
	}
	else if (StrContains(sModel, "hunting_knife", false) != -1)
	{
		sMeleeName = "hunting_knife";
	}
	else if (StrContains(sModel, "shovel", false) != -1)
	{
		sMeleeName = "shovel";
	}
	else if (StrContains(sModel, "pitchfork", false) != -1)
	{
		sMeleeName = "pitchfork";
	}
	else
	{
		return false;
	}
	
	return true;
}


//==================================
// Assign Player Setup Functions
//==================================

// Runs when player connects to server or if they take control of a bot...
RunAutoSetupInd(client)
{
	//LogMessage("Attempting to give player setup %N", client);
	if (g_bSurvivalStart)
	{
		#if DEBUG
		LogMessage("Survival start");
		#endif
		// Don't run setup if survival round already started
		return;
	}
	
	// Double check that the player is alive and not a bot
	if (!IS_SURVIVOR_ALIVE(client) && !IsFakeClient(client)) 
	{
		if(GetClientTeam(client) == L4D_TEAM_SPECTATE)
		{
			#if DEBUG
			LogMessage("Client joined as spectator - %N", client);
			#endif
			
			// Player joined as spectator
			return;
		}
		
		// Retry up to 10 times. Not sure how necessary this is because of the connect delay timer.
		if (g_iRetryCount[client] < 10)
		{
			#if DEBUG
			LogMessage("Client hasn't finished joining server. Retry attemp %i", g_iRetryCount[client]);
			#endif
			g_iRetryCount[client]++;
			
			CreateTimer(1.0, Timer_PlayerConnectDelay, client);
			return;
		}
		
		return;
	}
	
	if (!g_bAlreadyGiven[client])
	{
		g_bAlreadyGiven[client] = true;
		
		#if DEBUG
		LogMessage("Running auto setup for %N", client);
		#endif
		
		SetKVPath(); // Make sure path is defined		
		
		bool hasSetup = HasSetup(client);
		GiveDefaultWeapons(client, hasSetup);
	}
}

// Runs at the beginning of each round to setup for all current players
RunAutoSetup()
{
	if (g_bSurvivalStart)
	{
		return;
	}
	#if DEBUG
	LogMessage("Running auto setup for players");
	#endif
	
	// Reset list of entitites that have already been given out
	ResetEntStatus();
	
	// Make sure the KV path is defined
	SetKVPath(); 
	
	new order[4] = {-1, -1, -1, -1};
	// Find players to give setup to
	for (new i = 1; i < MaxClients; i++)
	{
		//if (IS_VALID_SURVIVOR(i) && !IsFakeClient(i))
		if (IS_VALID_SURVIVOR(i))
		{
			if (!g_bAlreadyGiven[i])
			{
				AddToArray(order, i);
			}
		}
	}
	
	// Reset order arrays - Used to give out setups in order of: admins with setup -> admins using default -> non-admin with setup -> non-admin using default
	new adminOrder[4] = {-1, -1, -1, -1};
	new adminOrderDefault[4] = {-1, -1, -1, -1};
	new nonAdminOrder[4] = {-1, -1, -1, -1};
	new nonAdminOrderDefault[4] = {-1, -1, -1, -1};
	
	new bool:isAdmin;
	new bool:hasSetup;
	// Add each player to matching order array
	for (new i = 0; i < 4; i++)
	{
		if (order[i] == -1)
		{
			continue;
		}
		
		isAdmin = false;
		if (GetUserAdmin(order[i]) != INVALID_ADMIN_ID)
		{
			isAdmin = true;
		}
		hasSetup = HasSetup(order[i]);
		
		if (isAdmin && hasSetup)
		{
			AddToArray(adminOrder, order[i]);
		}
		else if (isAdmin)
		{
			AddToArray(adminOrderDefault, order[i]);
		}
		else if (hasSetup)
		{
			AddToArray(nonAdminOrder, order[i]);
		}
		else
		{
			AddToArray(nonAdminOrderDefault, order[i]);
		}
	}
	
	
	// Randomize order
	RandomizeArray(adminOrder);
	RandomizeArray(adminOrderDefault);
	RandomizeArray(nonAdminOrder);
	RandomizeArray(nonAdminOrderDefault);
	
	// Run the setup for each player
	LoopOverOrderAndSetup(adminOrder, true);
	LoopOverOrderAndSetup(adminOrderDefault, false);
	LoopOverOrderAndSetup(nonAdminOrder, true);
	LoopOverOrderAndSetup(nonAdminOrderDefault, false);
}

bool HasSetup(client)
{
	new String:weapon[128];
	new String:weapon2[4][128];
	new bool:giveLasers;
	new Float:vec[3];
	new Float:vec2[4][3];
	new String:display[4][32];
	
	if (GetClientPrimarySetup(client, weapon, vec, giveLasers, false) ||
		GetClientSecondarySetup(client, weapon2, display, vec2, false) ||
		GetClientThrowableSetup(client, weapon2, vec2, false))
	{
		// Has setup for this map
		return true;
	 }
		
	return false;
}

AddToArray(arr[4], value)
{
	for (new i = 0; i < 4; i++)
	{
		if (arr[i] == -1)
		{
			arr[i] = value;
			return;
		}
	}
}

RandomizeArray(arr[4])
{
	new idx1,idx2,temp;
	for (new i = 0; i < 20; i++)
	{
		idx1 = GetRandomInt(0, 3);
		idx2 = GetRandomInt(0, 3);
		if (idx1 != idx2)
		{
			// swap the order
			temp = arr[idx1];
			arr[idx1] = arr[idx2];
			arr[idx2] = temp;
		}
	}
}

LoopOverOrderAndSetup(order[4], bool:hasSetup)
{
	for (new i = 0; i < 4; i++)
	{
		if (order[i] != -1)
		{
			g_bAlreadyGiven[order[i]] = true;
			
			GiveDefaultWeapons(order[i], hasSetup);
		}
	}
}

//==========================================
// Hand out weapons to players
//==========================================

GiveDefaultWeapons(client, bool bHasSetup)
{
	g_bSettingDefault[client] = false;
	bool bDefEnabled = IsDefaultEnabled();
	
	if (!bDefEnabled && !bHasSetup)
	{
		// No setup and not using default setup for this map
		return;
	}
	
	GivePrimaryWeapon(client, bHasSetup);
	
	GiveSecondaryWeapon(client, bHasSetup);
	
	// Don't bother giving a throwable to a player if they already have one
	if (!HasThrowable(client))
	{
		GiveThrowable(client, bHasSetup);
	}
}

bool PutBackPrimary(client)
{
	int iWeaponEnt = GetPlayerWeaponSlot(client, 0);
	
	char sClassname[64];
	if(!GetEdictClassname(iWeaponEnt, sClassname, sizeof(sClassname)))
	{
		return false;
	}
	
	char sSpawnClass[64];
	Format(sSpawnClass, sizeof(sSpawnClass), "%s_spawn", sClassname);
	
	int iEnt
	while ((iEnt = FindEntityByClassname(iEnt, sSpawnClass)) != -1) 
	{
		if (!IsValidEdict(iEnt) || !IsValidEntity(iEnt)) {
			continue;
		}
		
		// *TODO* The spawn count in the stack will be messed up if this happens while the player is standing next to the gun spawn. Killing the gun entity 
		// doesn't happen until after they are given the next weapon which means that the gun that's going to be killed is put back into the gun stack (+1 to 
		// item count) and this plugin adds one to item count. Maybe create a timer to wait a second and then correct the item count value.
		int iSpawnCount = GetEntData(iEnt, FindDataMapInfo(iEnt, "m_itemCount"), sizeof(iSpawnCount));
		if (iSpawnCount > 0 && iSpawnCount < 5)
		{
			SetEntData(iEnt, FindDataMapInfo(iEnt, "m_itemCount"), (iSpawnCount+1));
			
			AcceptEntityInput(iWeaponEnt, "kill");
			return true;
		}
	}
	
	return false;
}

bool GivePlayerWeapon(client, iWeaponSpawnEnt, String:sWeapon[128])
{
	// Verify that the spawn stack has available guns
	new iSpawnCount = GetEntData(iWeaponSpawnEnt, FindDataMapInfo(iWeaponSpawnEnt, "m_itemCount"), sizeof(iSpawnCount));
	if (iSpawnCount > 0)
	{
		// Decrement the spawn count in the gun spawn
		iSpawnCount--;
		SetEntData(iWeaponSpawnEnt, FindDataMapInfo(iWeaponSpawnEnt, "m_itemCount"), iSpawnCount);
		
		// Give player the weapon
		GiveItem(client, sWeapon);
		
		if (iSpawnCount == 0)
		{
			AddAssignedStatus(iWeaponSpawnEnt);
			
			// Make gun spawn not visible, so no one can grab more weapons from it but allow guns to be returned to the spawn.. 
			// This doesn't seem to always work (e.g. throwables on rooftop). *TODO* look into fixing this so that the guns can be returned to the spawn.
			SetEntProp(iWeaponSpawnEnt, Prop_Send, "m_fEffects", 48);
			
			// Just kill the spawn for now. Guns can't be returned to spawn but this would only happen if players are moving items so I don't care...
			//AcceptEntityInput(iWeaponSpawnEnt, "kill");
		}
		return true;
	}
	
	return false;
}

GivePrimaryWeapon(client, bool bHasSetup)
{
	char sWeapon[128];
	char sWeaponSpawn[128];
	bool bGiveLasers;
	float vLoc[3];
	
	if (bHasSetup)
	{
		if (!GetClientPrimarySetup(client, sWeapon, vLoc, bGiveLasers, false))
		{
			return;
		}
	}
	else
	{
		// Check for default
		if (!GetClientPrimarySetup(client, sWeapon, vLoc, bGiveLasers, true))
		{
			return;
		}
	}
	
	// Put back the primary weapon if player already picked one up. Would happen in the case of a player taking over a bot.
	if (HasPrimary(client))
	{
		new iCurWeaponEnt = GetPlayerWeaponSlot(client, 0);
		if (IdentifyWeapon(iCurWeaponEnt) != WeaponNameToId(sWeapon))
		{
			if (!PutBackPrimary(client))
			{
				// Failed to put back the primary weapon.
				return;
			}
		}
		else
		{
			// Already have the correct primary
			return; 
		}
	}
	
	//
	// Look for weapon spawn for the primary that they want equiped and give one of the guns from the stack to
	// the player.
	//
	
	Format(sWeaponSpawn, sizeof(sWeaponSpawn), "%s_spawn", sWeapon);
	
	float vEntLoc[3];
	new entity;
	while ((entity = FindEntityByClassname(entity, sWeaponSpawn)) != -1) 
	{
		if (!IsValidEdict(entity) || !IsValidEntity(entity)) {
			continue;
		}
		
		// Found weapon spawn for the primary weapon...
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEntLoc);
		if (IsEntLocation(vLoc, vEntLoc))
		{
			// Found gun spawn at the location that they want to pick up the gun from...
			if (AlreadyAssigned(entity))
			{
				// All guns from this stack have been used up...
				continue;
			}
			
			if (GivePlayerWeapon(client, entity, sWeapon))
			{
				// Give lasers to player if they have it in the setup and the map actually has laser sights
				if (bGiveLasers && MapHasLasers())
				{
					ToggleLaserOnWeapon(client, true);
				}
			}
			break;
		}
	}	
}

GiveSecondaryWeapon(client, bool bHasSetup)
{
	char sWeaponArray[4][128];
	char sWeaponSpawn[128];
	char sDisplayArray[4][32];
	float vLocArray[4][3];
	float vEntLoc[3];
	
	if (bHasSetup)
	{
		if(!GetClientSecondarySetup(client, sWeaponArray, sDisplayArray, vLocArray, false))
		{
			// Player doesn't have any secondary weapon setup defined for this map
			return;
		}
	}
	else
	{	
		if (!GetClientSecondarySetup(client, sWeaponArray, sDisplayArray, vLocArray, true))
		{
			return;
		}
	}
	
	for (new i = 0; i < 4; i++)
	{
		bool bIsMelee = false;
		if (StrEqual(sWeaponArray[i], "weapon_melee"))
		{
			bIsMelee = true;
		}
		
		new entity = -1;
		Format(sWeaponSpawn, sizeof(sWeaponSpawn), "%s_spawn", sWeaponArray[i]);
		
		// Search for weapon_melee_spawn or weapon_pistol_magnum_spawn
		while ((entity = FindEntityByClassname(entity, sWeaponSpawn)) != -1) 
		{
			if (!IsValidEdict(entity) || !IsValidEntity(entity)) {
				continue;
			}
			
			if (bIsMelee)
			{
				// Verify that this is the correct melee weapon. Don't worry about where it found it on the map.
				if (IsCorrectMelee(entity, sDisplayArray[i]) && !AlreadyAssigned(entity))
				{
					GiveMeleeWeapons(client, entity, sDisplayArray[i]);
					return;
				}
			}
			else
			{
				// Magnum - verify that this magnum spawn is at the location that they specified in the setup.
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEntLoc);
				if (IsEntLocation(vLocArray[i], vEntLoc) && !AlreadyAssigned(entity))
				{
					GivePlayerWeapon(client, entity, sWeaponArray[i]);
					return;
				}
			}
		}
		
		// Search for weapon_melee objects in case players moved melee weapons around on map.
		if (bIsMelee)
		{
			entity = -1; //reset entity just in case...
			while ((entity = FindEntityByClassname(entity, sWeaponArray[i])) != -1) 
			{
				if (!IsValidEdict(entity) || !IsValidEntity(entity)) {
					continue;
				}
				
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEntLoc);
				if (IsCorrectMelee(entity, sDisplayArray[i]))
				{
					if (AlreadyAssigned(entity))
					{
						continue;
					}
					
					GiveMeleeWeapons(client, entity, sDisplayArray[i]);
					return;
				}
			}
		}
	}
}

bool IsCorrectMelee(entity, String:melee[32])
{
	char sMeleeName[32];
	if (!TryGetEntityMeleeName(entity, sMeleeName))
	{
		return false;
	}
	
	if (StrEqual(sMeleeName, melee))
	{
		return true;
	}
	
	return false;
}

GiveMeleeWeapons(client, entity, char sMeleeName[32])
{
	// Keep track of the fact that this weapon was assigned to a player since killing the spawn apparently doesn't run quick enough 
	// and still exists during next player setup...
	AddAssignedStatus(entity);
	
	bool isGoldenCrowbar = StrEqual(sMeleeName, "golden_crowbar", false);
	if (isGoldenCrowbar)
	{
		sMeleeName = "crowbar";
	}
	
	// Create weapon and give to player
	new newMeleeEnt = CreateEntityByName("weapon_melee");
	DispatchKeyValue(newMeleeEnt, "melee_script_name", sMeleeName);
	DispatchSpawn(newMeleeEnt);
	EquipPlayerWeapon(client, newMeleeEnt);
	AddAssignedStatus(newMeleeEnt);
	
	if (isGoldenCrowbar)
	{
		SetEntProp(newMeleeEnt, Prop_Send, "m_nSkin", 1);
	}
	
	// Kill the existing spawn
	AcceptEntityInput(entity, "kill");
}

public GiveThrowable(client, bool:hasSetup)
{
	new String:weapon[4][128];
	new Float:vec[4][3];
	new Float:entLoc[3];
	
	if (hasSetup)
	{
		if (!GetClientThrowableSetup(client, weapon, vec, false))
		{
			return;
		}
	}
	else
	{
		if (!GetClientThrowableSetup(client, weapon, vec, true))
		{
			return;
		}
	}
	
	for (new i = 0; i < 4; i++)
	{
		new String:weaponSpawn[128];
		Format(weaponSpawn, sizeof(weaponSpawn), "%s_spawn", weapon[i]);
		
		new entity;
		while ((entity = FindEntityByClassname(entity, weaponSpawn)) != -1) 
		{
			if (!IsValidEdict(entity) || !IsValidEntity(entity)) {
				continue;
			}
			
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entLoc);
			if (IsEntLocation(vec[i], entLoc))	// verify that the throwable is from the correct location
			{
				if (AlreadyAssigned(entity))
				{
					continue;
				}
				AddAssignedStatus(entity);
			
				GivePlayerWeapon(client, entity, weapon[i]);
				return;
			}
		}
	}
}

//=====================================
// Define Setup Methods
//=====================================

public DefinePrimaryWeapon(client)
{
	// Look up entity that the player is aiming at
	new entity = GetClientAimTarget(client, false)
	
	new WeaponId:wID = IdentifyWeapon(entity);
	if (wID != WeaponId:WEPID_NONE)
	{
		if (WeaponSlots[wID] == 0)	// verify that this is a primary weapon
		{
			new String:class[64];
			if(!GetEdictClassname(entity, class, sizeof(class)))
			{
				PrintToChat(client, "\x04Not a valid entity");
			}
			else
			{
				new len = strlen(class);
				if(len-6 > 0 && StrEqual(class[len-6], "_spawn"))
				{	
					SavePrimaryWeapon(entity, client);
				}
				else
				{
					PrintToChat(client, "\x04Need to use a weapon spawn");
				}
			}
		}
		else
		{
			PrintToChat(client, "\x04Not a valid primary weapon");
		}
	}
	else
	{
		PrintToChat(client, "\x04Not pointing at a weapon");
	}
	
	ShowPrimaryWeaponMenu(client);
}

public DefineLaserSights(client, bool:lasersOn)
{
	if (MapHasLasers())
	{
		SaveLaserSights(client, lasersOn);
	}
	
	ShowPrimaryWeaponMenu(client);
}


public DefineSecondaryWeapon(client, setupPosition)
{
	new entity = GetClientAimTarget(client, false)
	
	new WeaponId:wID = IdentifyWeapon(entity);
	if (wID != WeaponId:WEPID_NONE)
	{
		if (WeaponSlots[wID] == 1)	//secondary weapon
		{
			new String:class[64];
			if(!GetEdictClassname(entity, class, sizeof(class)))
			{
				PrintToChat(client, "\x04Not a valid entity");
			}
			else
			{
				new len = strlen(class);
				if(len-6 > 0 && StrEqual(class[len-6], "_spawn"))
				{
					SaveSecondaryWeapon(entity, client, setupPosition);
				}
				else if (StrEqual(class, "weapon_melee")) // allow players to specify melee weapons that were moved since the setup plugin doesn't care where it grabs melee weapons from
				{
					SaveSecondaryWeapon(entity, client, setupPosition);
				}
				else
				{
					PrintToChat(client, "\x04Need to use a weapon spawn");
				}
			}
		}
		else
		{
			PrintToChat(client, "\x04Not a valid secondary weapon");
		}
	}
	else
	{
		PrintToChat(client, "\x04Not pointing at a weapon");
	}
	
	ShowSecondaryWeaponMenu(client);
}

public DefineThrowableWeapon(client, setupPosition)
{
	new entity = GetClientAimTarget(client, false)
	
	new WeaponId:wID = IdentifyWeapon(entity);
	if (wID != WeaponId:WEPID_NONE)
	{
		if (WeaponSlots[wID] == 2)	//throwable weapon
		{
			new String:class[128];
			if(!GetEdictClassname(entity, class, sizeof(class)))
			{
				PrintToChat(client, "\x04Not a valid entity");
			}
			else
			{
				new len = strlen(class);
				if(len-6 > 0 && StrEqual(class[len-6], "_spawn"))
				{
					SaveThrowableWeapon(entity, client, setupPosition);
				}
				else
				{
					PrintToChat(client, "\x04Need to use a weapon spawn");
				}
			}
		}
		else
		{
			PrintToChat(client, "\x04Not a valid secondary weapon");
		}
	}
	else
	{
		PrintToChat(client, "\x04Not pointing at a weapon");
	}
	
	ShowThrowableMenu(client);
}



//=====================================
// KeyValue Save Setup Methods
//=====================================

SetKVPath()
{
	new String:path[PLATFORM_MAX_PATH];
	new String:mapName[32];
	GetCurrentMap(mapName, sizeof(mapName));
	
	//Verify that the directory exist - **TODO** put this somewhere that executes when the map loads rather than constantly calling
	BuildPath(Path_SM, path, sizeof(path), "data/AutoSetup");
	if (!DirExists(path))
	{
		CreateDirectory(path, 3);
	}
	BuildPath(Path_SM, path, sizeof(path), "data/AutoSetup/%s", mapName);
	if (!DirExists(path))
	{
		CreateDirectory(path, 3);
	}
	
	// Look up path name to setup file
	BuildPath(Path_SM, g_sKVSetupFile, sizeof(g_sKVSetupFile), "data/AutoSetup/%s/SetupDefinitions.cfg", mapName)
}


SavePrimaryWeapon(iEnt, client)
{
	new String:SteamID[64];
	if (g_bSettingDefault[client])
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[SavePrimaryWeapon] Couldn't process file");
			#endif
			CloseHandle(kv);
			return;
		}
	}
	
	// Save data to players steam ID
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[SavePrimaryWeapon] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return;
	}
	
	float vEntLoc[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vEntLoc);
	
	if (IsInBlacklistArea(vEntLoc))
	{
		// log action for GM server logs
		char sMap[16];
		GetCurrentMap(sMap, sizeof(sMap));
		LogAction(client, -1, "[AutoSetup] %L tried to save primary weapon from out-of-bounds location. Map: %s | location: %f %f %f", client, sMap, vEntLoc[0], vEntLoc[1], vEntLoc[2]);

		PrintToChat(client, "\x04Invalid item. Items much be reachable before the round starts.");
		return;
	}
	
	new wID = GetEntProp(iEnt, Prop_Send, "m_weaponID");
	
	KvSetNum(kv, "Primary WeaponId", wID);
	KvSetVector(kv, "Primary Weapon Location", vEntLoc);
	
	KvRewind(kv);
	KeyValuesToFile(kv, g_sKVSetupFile);
	CloseHandle(kv);
}

SaveLaserSights(client, bool:laserOn)
{
	new String:SteamID[64];
	if (g_bSettingDefault[client])
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[SaveLaserSights] Couldn't process file");
			#endif
			CloseHandle(kv);
			return;
		}
	}
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[SaveLaserSights] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return;
	}	
	
	if (laserOn)
	{
		KvSetNum(kv, "Laser Sights", 1);
	}
	else
	{
		KvSetNum(kv, "Laser Sights", 0);
	}
	
	KvRewind(kv);
	KeyValuesToFile(kv, g_sKVSetupFile);
	CloseHandle(kv);
}

SaveSecondaryWeapon(iEnt, client, iSetupPosition)
{
	char SteamID[64];
	if (g_bSettingDefault[client])
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[SaveSecondaryWeapon] Couldn't process file");
			#endif
			CloseHandle(kv);
			return;
		}
	}
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[SaveSecondaryWeapon] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return;
	}
	
	char sWeaponName[32];
	float vEntLoc[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vEntLoc);
	
	if (IsInBlacklistArea(vEntLoc))
	{
		// log action for GM server logs
		char sMap[16];
		GetCurrentMap(sMap, sizeof(sMap));
		LogAction(client, -1, "[AutoSetup] %L tried to save secondary weapon from out-of-bounds location. Map: %s | location: %f %f %f", client, sMap, vEntLoc[0], vEntLoc[1], vEntLoc[2]);

		PrintToChat(client, "\x04Invalid item. Items much be reachable before the round starts.");
		return;
	}
	
	new WeaponId:wID = IdentifyWeapon(iEnt);
	if (wID == WeaponId:WEPID_MELEE)	//melee weapon
	{
		char sMeleeName[32];
		if (TryGetEntityMeleeName(iEnt, sMeleeName))
		{
			sWeaponName = sMeleeName;
		}
		else
		{
			PrintToChat(client, "Save failed. Melee weapon not found.");
			CloseHandle(kv);
			return;
		}
	}
	else if (wID == WeaponId:WEPID_CHAINSAW)
	{
		sWeaponName = "chainsaw"
	}
	else	//magnum
	{
		sWeaponName = "magnum";
	}
	
	new String:keyName[64];
	new String:keyDispName[64];
	new String:keyLocName[64];
	Format(keyName, sizeof(keyName), "Secondary WeaponID %i", iSetupPosition);
	Format(keyDispName, sizeof(keyDispName), "Secondary Display %i", iSetupPosition);
	Format(keyLocName, sizeof(keyLocName), "Secondary Weapon Location %i", iSetupPosition);
	
	KvSetNum(kv, keyName, _:wID);
	KvSetString(kv, keyDispName, sWeaponName);
	KvSetVector(kv, keyLocName, vEntLoc);
	
	KvRewind(kv);
	KeyValuesToFile(kv, g_sKVSetupFile);
	CloseHandle(kv);
}

SaveThrowableWeapon(iEnt, client, iSetupPosition)
{
	char SteamID[64];
	if (g_bSettingDefault[client])
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[SaveThrowableWeapon] Couldn't process file");
			#endif
			CloseHandle(kv);
			return;
		}
	}
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[SaveThrowableWeapon] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return;
	}
	
	float vEntLoc[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vEntLoc);
	
	if (IsInBlacklistArea(vEntLoc))
	{
		// log action for GM server logs
		char sMap[16];
		GetCurrentMap(sMap, sizeof(sMap));
		LogAction(client, -1, "[AutoSetup] %L tried to save throwable from out-of-bounds location. Map: %s | location: %f %f %f", client, sMap, vEntLoc[0], vEntLoc[1], vEntLoc[2]);
		
		PrintToChat(client, "\x04Invalid item. Items much be reachable before the round starts.");
		return;
	}
	
	new wID = GetEntProp(iEnt, Prop_Send, "m_weaponID");
	
	// Verify that this throwable isn't already on the setup list. Remove it from the previous setup order if necessary so that it only shows up once on the list.
	char sLocationKey[128];
	char sWeaponKey[128];
	float vPos[3];
	for (new i = 0; i < 4; i++)
	{
		Format(sLocationKey, sizeof(sLocationKey), "Throwable Location %i", i);
		KvGetVector(kv, sLocationKey, vPos);
		
		float fDist = GetVectorDistance(vPos, vEntLoc)
		if (fDist < 0.005) // for some reason the actual location isn't exactly the same as the value saved to the file, so just verify that it's within a very very close distance...
		{
			if (i == iSetupPosition)
			{
				// throwable is already assigned to this spot. Don't need to do anything.
				CloseHandle(kv);
				return;
			}
			else
			{
				// Found weapon already in setup. Delete the previous version to avoid repeats.
				Format(sWeaponKey, sizeof(sWeaponKey), "Throwable WeaponID %i", i);
				KvDeleteKey(kv, sWeaponKey);
				KvDeleteKey(kv, sLocationKey);
				break;
			}
		}
	}
	
	char sKeyName[64];
	char sKeyLocName[64];
	Format(sKeyName, sizeof(sKeyName), "Throwable WeaponID %i", iSetupPosition);
	Format(sKeyLocName, sizeof(sKeyLocName), "Throwable Location %i", iSetupPosition);
	
	KvSetNum(kv, sKeyName, wID);
	KvSetVector(kv, sKeyLocName, vEntLoc);
	
	KvRewind(kv);
	KeyValuesToFile(kv, g_sKVSetupFile);
	CloseHandle(kv);
}

SetDefaultForMap(bool bEnable)
{
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[SetDefaultForMap] Couldn't process file");
			#endif
			CloseHandle(kv);
			return;
		}
	}
	
	if (!KvJumpToKey(kv, "DEFAULT", true))
	{
		#if DEBUG
		PrintToChat(client, "[SetDefaultForMap] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return;
	}
	
	if (bEnable)
	{
		KvSetNum(kv, "Enabled", 1);
	}
	else
	{
		KvSetNum(kv, "Enabled", 0);
	}
	
	KvRewind(kv);
	KeyValuesToFile(kv, g_sKVSetupFile);
	CloseHandle(kv);
}

//==========================
// Retrieve Setup Methods
//==========================

bool GetClientPrimarySetup(client, String:sWeapon[128], Float:vLoc[3], &bLasers, bool:bUseDefault)
{
	char SteamID[64];
	if (g_bSettingDefault[client] || bUseDefault) //"Admin is defining the default for the map" || "giving out the default setup to a player"
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[GetClientPrimarySetup] Couldn't process file");
			#endif
			CloseHandle(kv);
			return false;
		}
	}
	else
	{
		// Couldn't find setup file. Must not be any setup for this map.
		Format(sWeapon, sizeof(sWeapon), "[NOT DEFINED]");
		CloseHandle(kv);
		return false;
	}
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[GetClientPrimarySetup] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return false;
	}
	
	int wID = KvGetNum(kv, "Primary WeaponId", 0);	
	KvGetVector(kv, "Primary Weapon Location", vLoc);
	bLasers = KvGetNum(kv, "Laser Sights", 0);
	
	bool bHasSetup = false;
	if (wID == 0)	// no weapon defined
	{
		Format(sWeapon, sizeof(sWeapon), "[NOT DEFINED]");
	}
	else
	{
		bHasSetup = true;
		Format(sWeapon, sizeof(sWeapon), "%s", WeaponNames[wID]);
	}
	
	CloseHandle(kv);
	return bHasSetup;
}

bool GetClientSecondarySetup(client, String:sWeaponArray[4][128], String:sDisplayArray[4][32], Float:vLocArray[4][3], bool:bUseDefault)
{
	char SteamID[64];
	if (g_bSettingDefault[client] || bUseDefault)
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[GetClientPrimarySetup] Couldn't process file");
			#endif
			CloseHandle(kv);
			return false;
		}
	}
	else
	{
		sWeaponArray[0] = "[NOT DEFINED]";
		sWeaponArray[1] = "[NOT DEFINED]";
		sWeaponArray[2] = "[NOT DEFINED]";
		sWeaponArray[3] = "[NOT DEFINED]";
		
		sDisplayArray[0] = "[NOT DEFINED]";
		sDisplayArray[1] = "[NOT DEFINED]";
		sDisplayArray[2] = "[NOT DEFINED]";
		sDisplayArray[3] = "[NOT DEFINED]";
		CloseHandle(kv);
		return false;
	}
		
	// This will get overwritten with the correct values if they exist
	sWeaponArray[0] = "[NOT DEFINED]";
	sWeaponArray[1] = "[NOT DEFINED]";
	sWeaponArray[2] = "[NOT DEFINED]";
	sWeaponArray[3] = "[NOT DEFINED]";
	
	sDisplayArray[0] = "[NOT DEFINED]";
	sDisplayArray[1] = "[NOT DEFINED]";
	sDisplayArray[2] = "[NOT DEFINED]";
	sDisplayArray[3] = "[NOT DEFINED]";
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[GetClientSecondarySetup] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return false;
	}
	
	bool bHasSetup = false;
	for (int i = 0; i < 4; i++)
	{
		char sKeyName[128];
		char sKeyDisplay[128];
		char sKeyVector[128];
		
		Format(sKeyName, sizeof(sKeyName), "Secondary WeaponID %i", i);
		Format(sKeyDisplay, sizeof(sKeyDisplay), "Secondary Display %i", i);
		Format(sKeyVector, sizeof(sKeyVector), "Secondary Weapon Location %i", i);
		
		int wID = KvGetNum(kv, sKeyName, 0);
		KvGetVector(kv, sKeyVector, vLocArray[i]);
		
		if (wID != 0)
		{
			bHasSetup = true;
			char sDisplayVal[32];
			KvGetString(kv, sKeyDisplay, sDisplayVal, sizeof(sDisplayVal), "[NOT DEFINED]");
			sDisplayArray[i] = sDisplayVal;
			
			char sTemp[128];
			Format(sTemp, sizeof(sTemp), "%s", WeaponNames[wID]);
			sWeaponArray[i] = sTemp;
		}
	}
	
	CloseHandle(kv);
	return bHasSetup;
}

bool GetClientThrowableSetup(client, String:weapon[4][128], Float:loc[4][3], bool:useDefault)
{
	new String:SteamID[64];
	if (g_bSettingDefault[client] || useDefault)
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[GetClientPrimarySetup] Couldn't process file");
			#endif
			CloseHandle(kv);
			return false;
		}
	}
	else
	{
		weapon[0] = "[NOT DEFINED]";
		weapon[1] = "[NOT DEFINED]";
		weapon[2] = "[NOT DEFINED]";
		weapon[3] = "[NOT DEFINED]";
		CloseHandle(kv);
		return false;
	}
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[GetClientThrowableSetup] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return false;
	}
	
	new bool:hasSetup = false;
	new String:name[128];
	new String:weaponKey[128];
	new String:locationKey[128];
	for (new i = 0; i < 4; i++)
	{
		Format(weaponKey, sizeof(weaponKey), "Throwable WeaponID %i", i);
		Format(locationKey, sizeof(locationKey), "Throwable Location %i", i);
		
		new wID = KvGetNum(kv, weaponKey, -1);
		KvGetVector(kv, locationKey, loc[i]);
		if (wID == -1)
		{
			Format(name, sizeof(name), "[NOT DEFINED]");
		}
		else
		{
			hasSetup = true;
			Format(name, sizeof(name), "%s", WeaponNames[wID]);
		}
		weapon[i] = name;
	}
	
	CloseHandle(kv);
	return hasSetup;
}

public bool:IsDefaultEnabled()
{
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[SetDefaultForMap] Couldn't process file");
			#endif
			CloseHandle(kv);
			return false;
		}
	}
	
	if (!KvJumpToKey(kv, "DEFAULT", true))
	{
		#if DEBUG
		PrintToChat(client, "[SetDefaultForMap] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return false;
	}
	
	new enabled = KvGetNum(kv, "Enabled", 0)
	CloseHandle(kv);
	
	if (enabled == 1)
	{
		return true;
	}
	return false;
}

//=======================
// Remove Setup Methods
//=======================

public RemovePrimaryWeapon(client)
{
	new String:SteamID[64];
	if (g_bSettingDefault[client])
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[RemovePrimaryWeapon] Couldn't process file");
			#endif
			CloseHandle(kv);
			return;
		}
	}
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[RemovePrimaryWeapon] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return;
	}
	
	KvDeleteKey(kv, "Primary WeaponId")
	KvDeleteKey(kv, "Primary Weapon Location")
	
	KvRewind(kv);
	KeyValuesToFile(kv, g_sKVSetupFile);
	CloseHandle(kv);
	
	ShowPrimaryRemoveMenu(client);
}

public RemoveSecondaryWeapon(client, setupPosition)
{
	new String:SteamID[64];
	if (g_bSettingDefault[client])
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[RemoveSecondaryWeapon] Couldn't process file");
			#endif
			CloseHandle(kv);
			return;
		}
	}
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[RemoveSecondaryWeapon] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return;
	}
	
	new String:keyName[128];
	new String:keyDispName[128];
	new String:keyLocName[128];
	Format(keyName, sizeof(keyName), "Secondary WeaponID %i", setupPosition);
	Format(keyDispName, sizeof(keyDispName), "Secondary Display %i", setupPosition);
	Format(keyLocName, sizeof(keyLocName), "Secondary Weapon Location %i", setupPosition);
	
	KvDeleteKey(kv, keyName);
	KvDeleteKey(kv, keyDispName);
	KvDeleteKey(kv, keyLocName);
	
	KvRewind(kv);
	KeyValuesToFile(kv, g_sKVSetupFile);
	CloseHandle(kv);
	
	ShowSecondaryRemoveMenu(client);
}

public RemoveThrowableWeapon(client, setupPosition)
{
	new String:SteamID[64];
	if (g_bSettingDefault[client])
	{
		SteamID = "DEFAULT";
	}
	else
	{
		new ID = GetSteamAccountID(client);
		Format(SteamID, sizeof(SteamID), "%i", ID);
	}
	
	new Handle:kv = CreateKeyValues("WeaponSetup");
	
	// Verify that we can read in the file
	if (FileExists(g_sKVSetupFile))
	{
		if (!FileToKeyValues(kv, g_sKVSetupFile))
		{
			#if DEBUG
			PrintToChat(client, "[SaveSecondaryWeapon] Couldn't process file");
			#endif
			CloseHandle(kv);
			return;
		}
	}
	
	if (!KvJumpToKey(kv, SteamID, true))
	{
		#if DEBUG
		PrintToChat(client, "[SaveSecondaryWeapon] Failed to create SteamID key");
		#endif
		CloseHandle(kv);
		return;
	}
	
	new String:keyName[128];
	new String:keyLocName[128];
	Format(keyName, sizeof(keyName), "Throwable WeaponID %i", setupPosition);
	Format(keyLocName, sizeof(keyLocName), "Throwable Location %i", setupPosition);
	
	KvDeleteKey(kv, keyName);
	KvDeleteKey(kv, keyLocName);
	
	KvRewind(kv);
	KeyValuesToFile(kv, g_sKVSetupFile);
	CloseHandle(kv);
	
	ShowThrowableRemoveMenu(client);
}

//=====================================
// Menu System
//=====================================

ShowAutoSetupMenu(client)
{
	// Reset some paths in case we switched maps..
	SetKVPath();
	
	new Handle:menu = CreateMenu(mh_AutoSetup, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "Auto Setup Menu");
	
	if (g_bAutoSetupEnabled)
	{
		AddMenuItem(menu, "Turn Off", "Turn Off");
	}
	else
	{
		AddMenuItem(menu, "Turn On", "Turn On");
	}
	AddMenuItem(menu, "Define Setup", "Define Setup")
	AddMenuItem(menu, "Remove Setup", "Remove Setup");
	
	if (GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		AddMenuItem(menu, "Defaults", "Default Player Setup");
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public mh_AutoSetup(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));

			if (StrEqual(item, "Turn Off"))
			{
				SetConVarBool(g_hEnabled, false);
				ShowAutoSetupMenu(param1);
			}
			else if (StrEqual(item, "Turn On"))
			{
				SetConVarBool(g_hEnabled, true);
				ShowAutoSetupMenu(param1);
			}
			else if (StrEqual(item, "Define Setup"))
			{
				g_bSettingDefault[param1] = false;
				ShowAddSetupMenu(param1);
			}
			else if (StrEqual(item, "Remove Setup"))
			{
				g_bSettingDefault[param1] = false;
				ShowRemoveSetupMenu(param1);
			}
			else if (StrEqual(item, "Defaults"))
			{
				ShowDefaultSetupMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}

	}
}

ShowAddSetupMenu(client)
{
	new Handle:menu = CreateMenu(mh_DefineSetupMenu, MENU_ACTIONS_DEFAULT);
	if (g_bSettingDefault[client])
	{
		SetMenuTitle(menu, "Define Default Setup");
	}
	else
	{
		SetMenuTitle(menu, "Define Setup");
	}
	SetMenuExitBackButton(menu, true);
	
	AddMenuItem(menu, "Primary Weapon", "Primary Weapon");
	AddMenuItem(menu, "Secondary Weapon", "Secondary Weapon");
	AddMenuItem(menu, "Throwable", "Throwable");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public mh_DefineSetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Primary Weapon"))
			{
				ShowPrimaryWeaponMenu(param1);
			}
			else if (StrEqual(item, "Secondary Weapon"))
			{
				ShowSecondaryWeaponMenu(param1);
			}
			else if (StrEqual(item, "Throwable"))
			{
				ShowThrowableMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				if (g_bSettingDefault[param1])
				{
					ShowDefaultSetupMenu(param1);
				}
				else
				{
					ShowAutoSetupMenu(param1);
				}
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}

	}
}


ShowPrimaryWeaponMenu(client)
{
	new Handle:menu = CreateMenu(mh_DefinePrimarySetupMenu, MENU_ACTIONS_DEFAULT);
	if (g_bSettingDefault[client])
	{
		SetMenuTitle(menu, "Define Default Primary");
	}
	else
	{
		SetMenuTitle(menu, "Define Primary Weapon");
	}
	SetMenuExitBackButton(menu, true);
	
	new String:weapon[128];
	new bool:laserOn;
	new Float:vec[3];
	GetClientPrimarySetup(client, weapon, vec, laserOn, false);
	
	AddMenuItem(menu, "Primary 1", weapon);
	if (MapHasLasers())
	{
		if (laserOn)
		{
			AddMenuItem(menu, "Laser", "Toggle Laser (Currently On)");
		}
		else
		{
			AddMenuItem(menu, "NoLaser", "Toggle Laser (Currently Off)");
		}
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public mh_DefinePrimarySetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Primary 1"))
			{
				DefinePrimaryWeapon(param1);
			}
			else if (StrEqual(item, "Laser"))
			{
				DefineLaserSights(param1, false); // Toggle laser off
			}
			else if (StrEqual(item, "NoLaser"))
			{
				DefineLaserSights(param1, true); // Toggle laser on
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowAddSetupMenu(param1);
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}

	}
}

ShowSecondaryWeaponMenu(client)
{
	new Handle:menu = CreateMenu(mh_DefineSecondarySetupMenu, MENU_ACTIONS_DEFAULT);
	if (g_bSettingDefault[client])
	{
		SetMenuTitle(menu, "Define Default Secondary");
	}
	else
	{
		SetMenuTitle(menu, "Define Secondary Weapon");
	}
	SetMenuExitBackButton(menu, true);
	
	new String:weapon[4][128];
	new String:display[4][32];
	new Float:vec[4][3];
	GetClientSecondarySetup(client, weapon, display, vec, false);
	
	for (new i = 0; i < 4; i++)
	{
		new String:menuItem[64];
		Format(menuItem, sizeof(menuItem), "Secondary %i", i);
		AddMenuItem(menu, menuItem, display[i]);
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public mh_DefineSecondarySetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Secondary 0"))
			{
				DefineSecondaryWeapon(param1, 0);
			}
			else if (StrEqual(item, "Secondary 1"))
			{
				DefineSecondaryWeapon(param1, 1);
			}
			else if (StrEqual(item, "Secondary 2"))
			{
				DefineSecondaryWeapon(param1, 2);
			}
			else if (StrEqual(item, "Secondary 3"))
			{
				DefineSecondaryWeapon(param1, 3);
			}

		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowAddSetupMenu(param1);
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}

	}
}

ShowThrowableMenu(client)
{
	new Handle:menu = CreateMenu(mh_DefineThrowableSetupMenu, MENU_ACTIONS_DEFAULT);
	if (g_bSettingDefault[client])
	{
		SetMenuTitle(menu, "Define Throwable Setup");
	}
	else
	{
		SetMenuTitle(menu, "Define Throwable Setup");
	}
	SetMenuExitBackButton(menu, true);
	
	new String:weapon[4][128];
	new Float:vec[4][3];
	GetClientThrowableSetup(client, weapon, vec, false);

	new String:menuItem[64];
	for (new i = 0; i < 4; i++)
	{
		Format(menuItem, sizeof(menuItem), "Throwable %i", i);
		AddMenuItem(menu, menuItem, weapon[i]);
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public mh_DefineThrowableSetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}
			
			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Throwable 0"))
			{
				DefineThrowableWeapon(param1, 0);
			}
			else if (StrEqual(item, "Throwable 1"))
			{
				DefineThrowableWeapon(param1, 1);
			}
			else if (StrEqual(item, "Throwable 2"))
			{
				DefineThrowableWeapon(param1, 2);
			}
			else if (StrEqual(item, "Throwable 3"))
			{
				DefineThrowableWeapon(param1, 3);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowAddSetupMenu(param1);
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}

	}
}

ShowRemoveSetupMenu(client)
{
	new Handle:menu = CreateMenu(mh_RemoveSetupMenu, MENU_ACTIONS_DEFAULT);
	if (g_bSettingDefault[client])
	{
		SetMenuTitle(menu, "Remove Default Setup");
	}
	else
	{
		SetMenuTitle(menu, "Remove Setup");
	}
	SetMenuExitBackButton(menu, true);
	
	AddMenuItem(menu, "Primary Weapon", "Primary Weapon");
	AddMenuItem(menu, "Secondary Weapon", "Secondary Weapon");
	AddMenuItem(menu, "Throwable", "Throwable");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public mh_RemoveSetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Primary Weapon"))
			{
				ShowPrimaryRemoveMenu(param1);
			}
			else if (StrEqual(item, "Secondary Weapon"))
			{
				ShowSecondaryRemoveMenu(param1);
			}
			else if (StrEqual(item, "Throwable"))
			{
				ShowThrowableRemoveMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				if (g_bSettingDefault[param1])
				{
					ShowDefaultSetupMenu(param1);
				}
				else
				{
					ShowAutoSetupMenu(param1);
				}
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}
	}
}

ShowPrimaryRemoveMenu(client)
{
	new Handle:menu = CreateMenu(mh_RemovePrimarySetupMenu, MENU_ACTIONS_DEFAULT);
	if (g_bSettingDefault[client])
	{
		SetMenuTitle(menu, "Remove Default Primary");
	}
	else
	{
		SetMenuTitle(menu, "Remove Primary Weapon");
	}
	SetMenuExitBackButton(menu, true);
	
	new String:weapon[128];
	new bool:laserOn;
	new Float:vec[3];
	GetClientPrimarySetup(client, weapon, vec, laserOn, false);
	
	AddMenuItem(menu, "Primary 1", weapon);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public mh_RemovePrimarySetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Primary 1"))
			{
				RemovePrimaryWeapon(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowRemoveSetupMenu(param1);
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}

	}
}

ShowSecondaryRemoveMenu(client)
{
	new Handle:menu = CreateMenu(mh_RemoveSecondarySetupMenu, MENU_ACTIONS_DEFAULT);
	if (g_bSettingDefault[client])
	{
		SetMenuTitle(menu, "Remove Default Secondary");
	}
	else
	{
		SetMenuTitle(menu, "Remove Secondary Weapon");
	}
	SetMenuExitBackButton(menu, true);
	
	new String:weapon[4][128];
	new String:display[4][32];
	new Float:vec[4][3];
	GetClientSecondarySetup(client, weapon, display, vec, false);
	
	for (new i = 0; i < 4; i++)
	{
		new String:menuItem[64];
		Format(menuItem, sizeof(menuItem), "Secondary %i", i);
		AddMenuItem(menu, menuItem, display[i]);
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public mh_RemoveSecondarySetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Secondary 0"))
			{
				RemoveSecondaryWeapon(param1, 0);
			}
			else if (StrEqual(item, "Secondary 1"))
			{
				RemoveSecondaryWeapon(param1, 1);
			}
			else if (StrEqual(item, "Secondary 2"))
			{
				RemoveSecondaryWeapon(param1, 2);
			}
			else if (StrEqual(item, "Secondary 3"))
			{
				RemoveSecondaryWeapon(param1, 3);
			}

		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowRemoveSetupMenu(param1);
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}

	}
}

ShowThrowableRemoveMenu(client)
{
	new Handle:menu = CreateMenu(mh_RemoveThrowableSetupMenu, MENU_ACTIONS_DEFAULT);
	if (g_bSettingDefault[client])
	{
		SetMenuTitle(menu, "Remove Default Throwable");
	}
	else
	{
		SetMenuTitle(menu, "Remove Throwable Setup");
	}
	
	SetMenuExitBackButton(menu, true);
	
	new String:weapon[4][128];
	new Float:vec[4][3];
	GetClientThrowableSetup(client, weapon, vec, false);

	new String:menuItem[64];
	for (new i = 0; i < 4; i++)
	{
		Format(menuItem, sizeof(menuItem), "Throwable %i", i);
		AddMenuItem(menu, menuItem, weapon[i]);
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public mh_RemoveThrowableSetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Throwable 0"))
			{
				RemoveThrowableWeapon(param1, 0);
			}
			else if (StrEqual(item, "Throwable 1"))
			{
				RemoveThrowableWeapon(param1, 1);
			}
			else if (StrEqual(item, "Throwable 2"))
			{
				RemoveThrowableWeapon(param1, 2);
			}
			else if (StrEqual(item, "Throwable 3"))
			{
				RemoveThrowableWeapon(param1, 3);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowRemoveSetupMenu(param1);
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}
	}
}

//===================
// Default Menu System
//===================

ShowDefaultSetupMenu(client)
{
	if (!IsCommandAccessible(client))
	{
		return;
	}

	new String:mapName[32];
	GetCurrentMap(mapName, sizeof(mapName));
	
	new Handle:menu = CreateMenu(mh_DefaultSetupMenu, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "%s Default Settings", mapName);
	SetMenuExitBackButton(menu, true);
	
	if (IsDefaultEnabled())
	{
		AddMenuItem(menu, "Turn Off Default", "Turn Off Default");
	}
	else
	{
		AddMenuItem(menu, "Turn On Default", "Turn On Default");
	}
	AddMenuItem(menu, "Define Default", "Define Default");
	AddMenuItem(menu, "Remove Default", "Remove Default");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public mh_DefaultSetupMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsCommandAccessible(param1))
			{
				return;
			}

			//param1 is client, param2 is item
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			if (StrEqual(item, "Turn Off Default"))
			{
				SetDefaultForMap(false);
				ShowDefaultSetupMenu(param1);
			}
			else if (StrEqual(item, "Turn On Default"))
			{
				SetDefaultForMap(true);
				ShowDefaultSetupMenu(param1);
			}
			else if (StrEqual(item, "Define Default"))
			{
				g_bSettingDefault[param1] = true;
				ShowAddSetupMenu(param1);
			}
			else if (StrEqual(item, "Remove Default"))
			{
				g_bSettingDefault[param1] = true;
				ShowRemoveSetupMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowAutoSetupMenu(param1);
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);
		}
	}
}

//=======================================
// Handle blacklisted areas. Survivors shouldn't be allowed to equip items that are out-of-reach before the round starts
//=======================================

bool IsInBlacklistArea(float vPos[3])
{
	if (g_hBlacklistAreas == INVALID_HANDLE) return false;
	
	for (int iIndex = 0, iSize = GetArraySize(g_hBlacklistAreas); iIndex < iSize; iIndex++)
	{
		float vMin[3], vMax[3];
		vMin[0] = GetArrayCell(g_hBlacklistAreas, iIndex, Area_Min_X);
		vMin[1] = GetArrayCell(g_hBlacklistAreas, iIndex, Area_Min_Y);
		vMin[2] = GetArrayCell(g_hBlacklistAreas, iIndex, Area_Min_Z);
		vMax[0] = GetArrayCell(g_hBlacklistAreas, iIndex, Area_Max_X);
		vMax[1] = GetArrayCell(g_hBlacklistAreas, iIndex, Area_Max_Y);
		vMax[2] = GetArrayCell(g_hBlacklistAreas, iIndex, Area_Max_Z);
		
		if (vPos[0] > vMin[0] && vPos[0] < vMax[0] 
			&& vPos[1] > vMin[1] && vPos[1] < vMax[1]
			&& vPos[2] > vMin[2] && vPos[2] < vMax[2])
		{
			return true;
		}
	}
	
	return false;
}

void LoadBlacklistAreas()
{
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	
	if (StrEqual(sMap, "c1m2_streets"))
	{
		LoadBlockedAreas_c1m2();
	}
	else if (StrEqual(sMap, "c6m1_riverbank"))
	{
		LoadBlockedAreas_c6m1();
	}
	else if (StrEqual(sMap, "c6m2_bedlam"))
	{
		LoadBlockedAreas_c6m2();
	}
	else if (StrEqual(sMap, "c2m1_highway"))
	{
		LoadBlockedAreas_c2m1();
	}
	else if (StrEqual(sMap, "c3m1_plankcountry"))
	{
		LoadBlockedAreas_c3m1();
	}
	else if (StrEqual(sMap, "c3m3_shantytown"))
	{
		LoadBlockedAreas_c3m3();
	}
	else if (StrEqual(sMap, "c3m4_plantation"))
	{
		LoadBlockedAreas_c3m4();
	}
	else if (StrEqual(sMap, "c4m1_milltown_a"))
	{
		LoadBlockedAreas_c4m1();
	}
	else if (StrEqual(sMap, "c4m2_sugarmill_a"))
	{
		LoadBlockedAreas_c4m2();
	}
	else if (StrEqual(sMap, "c4m3_sugarmill_b"))
	{
		LoadBlockedAreas_c4m3();
	}
	else if (StrEqual(sMap, "c5m1_waterfront"))
	{
		LoadBlockedAreas_c5m1();
	}
	else if (StrEqual(sMap, "c7m1_docks"))
	{
		LoadBlockedAreas_c7m1();
	}
	else if (StrEqual(sMap, "c7m2_barge"))
	{
		LoadBlockedAreas_c7m2();
	}
	else if (StrEqual(sMap, "c8m4_interior"))
	{
		LoadBlockedAreas_c8m4();
	}
	else if (StrEqual(sMap, "c8m5_rooftop"))
	{
		LoadBlockedAreas_c8m5();
	}
	else if (StrEqual(sMap, "c10m3_ranchhouse"))
	{
		LoadBlockedAreas_c10m3();
	}
	else if (StrEqual(sMap, "c11m3_garage"))
	{
		LoadBlockedAreas_c11m3();
	}
	else if (StrEqual(sMap, "c12m5_cornfield"))
	{
		LoadBlockedAreas_c12m5();
	}
	else if (StrEqual(sMap, "c13m3_memorialbridge"))
	{
		LoadBlockedAreas_c13m3();
	}
	else if (StrEqual(sMap, "c13m4_cutthroatcreek"))
	{
		LoadBlockedAreas_c13m4();
	}
	else if (StrEqual(sMap, "c14m2_lighthouse"))
	{
		LoadBlockedAreas_c14m2();
	}
	else if (StrEqual(sMap, "c5m4_quarter"))
	{
		LoadBlockedAreas_c5m4();
	}
	else if (StrEqual(sMap, "c8m2_subway"))
	{
		LoadBlockedAreas_c8m2();
	}
	else if (StrEqual(sMap, "c8m3_sewers"))
	{
		LoadBlockedAreas_c8m3();
	}
	else if (StrEqual(sMap, "c10m2_drainage"))
	{
		LoadBlockedAreas_c10m2();
	}
	else if (StrEqual(sMap, "c10m4_mainstreet"))
	{
		LoadBlockedAreas_c10m4();
	}
	else if (StrEqual(sMap, "c11m2_offices"))
	{
		LoadBlockedAreas_c11m2();
	}
	else if (StrEqual(sMap, "c11m4_terminal"))
	{
		LoadBlockedAreas_c11m4();
	}
	else if (StrEqual(sMap, "c12m2_traintunnel"))
	{
		LoadBlockedAreas_c12m2();
	}
	else if (StrEqual(sMap, "c12m3_bridge"))
	{
		LoadBlockedAreas_c12m3();
	}
}

// gun shop
void LoadBlockedAreas_c1m2()
{
	//
	// Add area inside Save 4 Less
	//
	AddAreaToList(g_hBlacklistAreas, -7576.344727, -2743.845459, 346.105072, -6650.789551, -2258.400635, 669.595947);
	AddAreaToList(g_hBlacklistAreas, -7576.344727, -2258.400635, 346.105072, -7056.095703, -1261.229492, 595.121765);
	
	// pill box in another building
	AddAreaToList(g_hBlacklistAreas, -3679.137939, 2231.701416, 241.934967, -3487.827392, 2329.941650, 380.620269);
}

// riverbank
void LoadBlockedAreas_c6m1()
{
	// saferoom (magnium)
	AddAreaToList(g_hBlacklistAreas, -4271.229492, 1346.223388, 636.005126, -3806.587646, 1514.820800, 773.530578);
	
	// pill area in bathroom
	AddAreaToList(g_hBlacklistAreas, 3174.341064, 1869.037109, -31.166597, 3338.614257, 2068.725585, 118.327247);
}

// bedlam
void LoadBlockedAreas_c6m2()
{
	// starting saferoom area
	AddAreaToList(g_hBlacklistAreas, 2864.499023, -1349.515380, -387.743255, 3367.571777, -1034.248413, -202.500701);
}

// motel
void LoadBlockedAreas_c2m1()
{
	// start saferoom area
	AddAreaToList(g_hBlacklistAreas, 10469.126953, 7712.908691, -660.242187, 10895.430664, 8008.562011, -519.391540);
	// end saferoom area
	AddAreaToList(g_hBlacklistAreas, -947.859130, -2805.304687, -1149.583496, -676.285522, -2251.935058, -975.095214);
}

// gator village
void LoadBlockedAreas_c3m1()
{
	// items in the float (not yet accessable until later)
	AddAreaToList(g_hBlacklistAreas, -4729.281738, 5838.100097, -101.421180, -4241.154785, 6266.133789, 163.100418);
}

// shanty town
void LoadBlockedAreas_c3m3()
{
	// hunting rifle, out of bounds area
	AddAreaToList(g_hBlacklistAreas, -810.480041, -2478.506835, -103.906677, -397.424224, -2323.076416, 103.698448);

}

// plantation
void LoadBlockedAreas_c3m4()
{
	// starting safe room
	//AddAreaToList(g_hBlacklistAreas, -5322.741699, -1791.452026, -227.368392, -4813.869628, -1501.057373, -49.157337);
	AddAreaToList(g_hBlacklistAreas, -5358.017089, -1818.508056, -164.872848, -4688.675292, -1461.419311, 78.787261);
}

// burger tank
void LoadBlockedAreas_c4m1()
{
	// hunting rifle on tree fort
	AddAreaToList(g_hBlacklistAreas, 1555.372802, 2998.499755, 60.508419, 1963.749145, 3435.201171, 317.534820);

	// end saferoom kits
	AddAreaToList(g_hBlacklistAreas, 3469.734863, -2246.503173, -17.760292, 4361.120605, -1158.528808, 407.166137);
}

// Sugar Mill
void LoadBlockedAreas_c4m2()
{
	// starting saferoom kits
	AddAreaToList(g_hBlacklistAreas, 3355.866943, -2623.249267, 57.055404, 4098.074218, -1414.946899, 456.794555);

	// end safe room weapons
	AddAreaToList(g_hBlacklistAreas, -2025.225341, -13915.416992, 13.456125, -1284.982543, -13299.242187, 293.647003);
}

// cane field
void LoadBlockedAreas_c4m3()
{
	// end safe room kits
	AddAreaToList(g_hBlacklistAreas, 3393.736328, -2535.682128, 66.974220, 3991.838134, -1430.828369, 374.900482);
}

// parish waterfront
void LoadBlockedAreas_c5m1()
{
	// end saferoom weapons
	AddAreaToList(g_hBlacklistAreas, -4632.578125, -1373.925903, -437.470886, -3610.110107, -1124.286865, -245.784347);
}

void LoadBlockedAreas_c5m4()
{
	// Areas in rooms/balcony across the float
	AddAreaToList(g_hBlacklistAreas, -1793.453247, 191.115723, 229.245056, -1689.789063, 591.268982, 479.840057);
	AddAreaToList(g_hBlacklistAreas, -2289.793213, 131.571915, 73.851830, -1788.491333, 1032.876587, 424.160889);

	// pill box
	AddAreaToList(g_hBlacklistAreas, -2497.031494, -271.314788, -11.824886, -2129.890136, 12.183491, 181.086853);
}

// traincar
void LoadBlockedAreas_c7m1()
{
	// melee on fire escape stairs
	AddAreaToList(g_hBlacklistAreas, 8799.041992, 564.427612, 135.753555, 9074.479492, 898.390869, 424.639953);

	// end saferoom weapons
	AddAreaToList(g_hBlacklistAreas, 1726.839965, 2176.499511, 95.706954, 2248.316894, 2564.572998, 290.771514);
}

void LoadBlockedAreas_c8m2()
{
	//
	// Add areas up top and in stairwell as unreachable
	//
	AddAreaToList(g_hBlacklistAreas, 7085.201172, 2617.625000, 240.356216, 8209.518555, 2815.277832, 481.208923);
	AddAreaToList(g_hBlacklistAreas, 7026.030273, 2549.625000, -81.811378, 7288.632813, 3931.267822, 464.663727);
	AddAreaToList(g_hBlacklistAreas, 7273.192871, 3661.757324, 242.969955, 8193.793945, 3861.601807, 392.825165);

	// m60 outside of playable area
	AddAreaToList(g_hBlacklistAreas, 6861.795898, 2268.218017, -409.534149, 7162.350097, 2457.201171, -263.689971);
}

void LoadBlockedAreas_c7m2()
{
	// end saferoom weapons
	AddAreaToList(g_hBlacklistAreas, -11334.833007, 3049.908691, 79.339378, -10826.981445, 3371.023437, 241.312927);

	// unreachable melee
	AddAreaToList(g_hBlacklistAreas, -1738.557250, 1287.222656, 195.427520, -1389.650024, 1554.576049, 382.572235);
}

// hospital
void LoadBlockedAreas_c8m4()
{
	// medkits - starting saferoom
	AddAreaToList(g_hBlacklistAreas, 12233.188476, 12109.212890, -61.676677, 12436.131835, 12459.040039, 115.934188);

	// medkits - end saferoon
	AddAreaToList(g_hBlacklistAreas, 11061.137695, 14778.188476, 5445.031250, 11558.057617, 15189.452148, 5831.415527);
}

void LoadBlockedAreas_c8m3()
{
	// Roof + room
	AddAreaToList(g_hBlacklistAreas, 11000.456055, 7347.729492, 235.876389, 12723.143555, 7691.017090, 589.924805);
	AddAreaToList(g_hBlacklistAreas, 10488.334961, 6724.119141, 124.552948, 11027.801758, 7572.779297, 582.261841);

	// kits inside end saferoom + just outside that building
	AddAreaToList(g_hBlacklistAreas, 11915.160156, 11993.903320, -134.623443, 13998.278320, 12769.000976, 158.598159);
}

// rooftop
void LoadBlockedAreas_c8m5()
{
	// saferoom kits
	AddAreaToList(g_hBlacklistAreas, 5104.493164, 8288.185546, 5455.128906, 5581.569335, 8594.787109, 5714.267578);
}

// drains
void LoadBlockedAreas_c10m2()
{
	// Area on other side of bridge
	AddAreaToList(g_hBlacklistAreas, -8169.432129, -8796.593750, -421.713226, -7353.578125, -6800.836426, -8.223939);
	// melee in same area
	AddAreaToList(g_hBlacklistAreas, -8046.458007, -8220.458984, -509.351898, -7845.781250, -7937.913085, -388.354278);
}

// church
LoadBlockedAreas_c10m3()
{
	// pill box
	AddAreaToList(g_hBlacklistAreas, -9453.528320, -2868.578613, -93.541221, -9110.448242, -2573.608398, 97.469932);
}

// street
void LoadBlockedAreas_c10m4()
{
	// Other side of map
	AddAreaToList(g_hBlacklistAreas, -2208.013916, -4939.761230, -90.486542, 796.972412, -3267.179443, 365.474121);
	AddAreaToList(g_hBlacklistAreas, -50.827919, -3528.903564, -240.134399, 295.024291, -2825.246826, 137.580093);
}

void LoadBlockedAreas_c11m2()
{
	// Non-starting roofs
	AddAreaToList(g_hBlacklistAreas, 6458.442383, 3951.522461, 556.869995, 7184.311035, 5063.395508, 1154.021118);
	AddAreaToList(g_hBlacklistAreas, 7134.628906, 3011.010742, 440.812439, 8450.346680, 5006.796875, 1210.047363);

	// weapons in starting saferoom
	AddAreaToList(g_hBlacklistAreas, 5016.564941, 2443.708251, -106.451721, 5549.770019, 2934.032714, 232.710067);

	// pill box
	AddAreaToList(g_hBlacklistAreas, 8711.392578, 4083.024414, 545.278625, 9056.588867, 4338.243164, 741.586914);

	// end saferoom weapons
	AddAreaToList(g_hBlacklistAreas, 7673.226562, 5981.941406, -78.034240, 8231.482421, 6303.549804, 117.574394);
}

void LoadBlockedAreas_c11m3()
{
	// starting saferoom weapons
	AddAreaToList(g_hBlacklistAreas, -5593.356933, -3413.461181, -52.754135, -5231.236328, -2861.046630, 186.361297);

	// pill box
	AddAreaToList(g_hBlacklistAreas, -3364.351318, 2369.169677, -41.757263, -2993.304687, 2729.996337, 146.276473);
	
}

void LoadBlockedAreas_c11m4()
{
	// Room that opens up from van + side room which sticks slightly farther forward so it had to be separate
	AddAreaToList(g_hBlacklistAreas, -836.165649, 1289.687988, -101.787933, 440.997467, 3525.813477, 210.684464);
	AddAreaToList(g_hBlacklistAreas, -562.389771, 3144.859863, -19.110537, -341.717255, 3600.990723, 189.226593);
}

void LoadBlockedAreas_c12m2()
{
	// Other section after door opens
	AddAreaToList(g_hBlacklistAreas, -8951.464843, -8074.367187, -94.088745, -6441.115234, -7569.615234, 301.165161);
	AddAreaToList(g_hBlacklistAreas, -8491.200195, -7644.803222, -166.831253, -8349.777343, -7274.067382, 80.504318);
}

void LoadBlockedAreas_c12m3()
{
	// Top of fallen bridge
	AddAreaToList(g_hBlacklistAreas, 5447.685059, -12453.073242, 172.862701, 8355.444336, -11147.437500, 1305.585449);
}

// corn field
void LoadBlockedAreas_c12m5()
{
	// saferoom weapon
	AddAreaToList(g_hBlacklistAreas, 10285.306640, -781.754455, -122.010490, 10702.290039, -396.501373, 88.542160);
}

void LoadBlockedAreas_c13m3()
{
	// start saferoom weapons
	AddAreaToList(g_hBlacklistAreas, -4538.776855, -5473.265625, 20.614854, -4084.789062, -4891.583007, 270.549011);
	// end saferoom weapons
	AddAreaToList(g_hBlacklistAreas, 5732.519042, -6610.867675, 264.028228, 6380.418457, -5897.431640, 550.003784);
}

void LoadBlockedAreas_c13m4()
{
	// area near beginning of map
	AddAreaToList(g_hBlacklistAreas, -4374.199218, -9523.884765, 196.711730, -3008.174316, -7645.036132, 597.714904);
}

// lighthouse
void LoadBlockedAreas_c14m2()
{
	// saferoom weapons
	AddAreaToList(g_hBlacklistAreas, 1690.861450, -1384.909179, 333.540466, 2569.923339, -591.354614, 631.351135);

	// pickup truck bed
	AddAreaToList(g_hBlacklistAreas, -794.880554, 1007.551269, 3.115380, -218.352249, 1320.591186, 399.208862);
}

AddAreaToList(Handle:hAreaList, float fMinX, float fMinY, float fMinZ, float fMaxX, float fMaxY, float fMaxZ)
{
	int iIndex = PushArrayCell(hAreaList, fMinX);
	SetArrayCell(hAreaList, iIndex, fMinY, Area_Min_Y);
	SetArrayCell(hAreaList, iIndex, fMinZ, Area_Min_Z);
	SetArrayCell(hAreaList, iIndex, fMaxX, Area_Max_X);
	SetArrayCell(hAreaList, iIndex, fMaxY, Area_Max_Y);
	SetArrayCell(hAreaList, iIndex, fMaxZ, Area_Max_Z);
}
