#include <sdktools>
#include <sourcemod>
#include <adminmenu>

#define PLUGIN_VERSION "1.0"

new Handle:hAdminMenu = INVALID_HANDLE

public Plugin:myinfo = 
{
	name = "SI spawner",
	author = "khan",
	description = "Spawns infected",
	version = PLUGIN_VERSION
}

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
	RegAdminCmd("sm_spawnsi", Command_SpawnSI, ADMFLAG_CHEATS, "sm_spawnsi <special infected>")
	RegAdminCmd("sm_autospawn", Command_AutoSpawn, ADMFLAG_CHEATS, "sm_autospawn <special infected>");
	
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		/* If so, manually fire the callback */
		OnAdminMenuReady(topmenu);
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	/* Block from being called twice */
	if (topmenu == hAdminMenu)
	{
		return;
	}
	hAdminMenu = topmenu;
	
	AttachAdminMenu();
}


AttachAdminMenu()
{
	new TopMenuObject:obj_server_options = AddToTopMenu(hAdminMenu, "Spawn SI", TopMenuObject_Category, CatHandler, INVALID_TOPMENUOBJECT);
	
	if (obj_server_options == INVALID_TOPMENUOBJECT)
	{
		/* Error! */
		return;
	}

	AddToTopMenu(hAdminMenu, "sm_spawnboomer", TopMenuObject_Item, AdminMenu_SpawnBoomer, obj_server_options, "sm_spawnboomer", ADMFLAG_SLAY);
	AddToTopMenu(hAdminMenu, "sm_spawncharger", TopMenuObject_Item, AdminMenu_SpawnCharger, obj_server_options, "sm_spawncharger", ADMFLAG_SLAY);
	AddToTopMenu(hAdminMenu, "sm_spawnhunter", TopMenuObject_Item, AdminMenu_SpawnHunter, obj_server_options, "sm_spawnhunter", ADMFLAG_SLAY);
	AddToTopMenu(hAdminMenu, "sm_spawnspitter", TopMenuObject_Item, AdminMenu_SpawnSpitter, obj_server_options, "sm_spawnspitter", ADMFLAG_SLAY);
	AddToTopMenu(hAdminMenu, "sm_spawnjockey", TopMenuObject_Item, AdminMenu_SpawnJockey, obj_server_options, "sm_spawnjockey", ADMFLAG_SLAY);
	AddToTopMenu(hAdminMenu, "sm_spawnsmoker", TopMenuObject_Item, AdminMenu_SpawnSmoker, obj_server_options, "sm_spawnsmoker", ADMFLAG_SLAY);
	AddToTopMenu(hAdminMenu, "sm_spawntank", TopMenuObject_Item, AdminMenu_SpawnTank, obj_server_options, "sm_spawntank", ADMFLAG_SLAY);
	AddToTopMenu(hAdminMenu, "sm_spawnwitch", TopMenuObject_Item, AdminMenu_SpawnWitch, obj_server_options, "sm_spawnwitch", ADMFLAG_SLAY);
	//AddToTopMenu(hAdminMenu, "sm_spawncommon", TopMenuObject_Item, AdminMenu_SpawnCommon, obj_server_options, "sm_spawncommon", ADMFLAG_SLAY);
}

public CatHandler(Handle:topmenu,TopMenuAction:action,TopMenuObject:object_id,param,String:buffer[],maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "Spawn SI");
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Spawn SI");
	}
}

public AdminMenu_SpawnCommon(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Common");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Common");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a common infected.", param);
		
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}

public AdminMenu_SpawnWitch(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Witch");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Witch");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a witch.", param);
		
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}

public AdminMenu_SpawnSpitter(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Spitter");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Spitter");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a spitter.", param);
		
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}

public AdminMenu_SpawnJockey(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Jockey");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Jockey");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a jockey.", param);
		
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}
public AdminMenu_SpawnSmoker(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Smoker");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Smoker");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a smoker.", param);
		
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}
public AdminMenu_SpawnTank(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Tank");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Tank");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a tank.", param);
		
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}
public AdminMenu_SpawnBoomer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Boomer");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Boomer");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a boomer.", param);
	
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}

public AdminMenu_SpawnCharger(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Charger");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Charger");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a charger.", param);
		
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}

public AdminMenu_SpawnHunter(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Hunter");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpawnSI(param, "Hunter");
		
		// Log Action, used by survival recorder
		LogAction(param, -1, "%L spawned a hunter.", param);
		
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}



//======================
// Commands
//======================
public Action:Command_AutoSpawn(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_autospawn <special infected>");
		return Plugin_Handled;
	}
	
	decl String:infected[64]
	GetCmdArg(1, infected, sizeof(infected));
	new bot = CreateFakeClient("Infected Bot");
	if (bot != 0)
	{
		ChangeClientTeam(bot,3);
		CreateTimer(0.1,kickbot,bot);
	}
	
	CheatCommand2(client, "z_spawn_old", infected);
	
	// Log Action, used by survival recorder
	char sCmdArg[24], sArgs[80];
	GetCmdArg(0, sCmdArg, sizeof(sCmdArg));
	GetCmdArgString(sArgs, sizeof(sArgs));
	Format(sArgs, sizeof(sArgs), "%s %s", sCmdArg, sArgs);
	LogAction(client, -1, sArgs);
	
	return Plugin_Handled;
}

public Action:Command_SpawnSI(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_spawnsi <special infected>");
		return Plugin_Handled;
	}
	
	decl String:infected[64];
	
	GetCmdArg(1, infected, sizeof(infected));
	
	SpawnSI(client, infected);
	
	// Log Action, used by survival recorder
	char sCmdArg[24], sArgs[80];
	GetCmdArg(0, sCmdArg, sizeof(sCmdArg));
	GetCmdArgString(sArgs, sizeof(sArgs));
	Format(sArgs, sizeof(sArgs), "%s %s", sCmdArg, sArgs);
	LogAction(client, -1, sArgs);
	
	return Plugin_Handled;
}

public SpawnSI(client, String:infected[64])
{
	new bot = CreateFakeClient("Infected Bot");
	if (bot != 0)
	{
		ChangeClientTeam(bot,3);
		CreateTimer(0.1,kickbot,bot);
	}
	
	CheatCommand(client, "z_spawn_old", infected);
}

stock GetAnyValidClient() 
{ 
    for (new target = 1; target <= MaxClients; target++) 
    { 
        if (IsClientInGame(target)) return target; 
    } 
    return -1; 
} 



public Action:kickbot(Handle:timer, any:client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client)) KickClient(client);
	}
}


stock CheatCommand(client, String:command[], String:argument1[])
{
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, argument1);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

stock CheatCommand2(client, String:command[], String:argument1[])
{
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s auto", command, argument1);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}


