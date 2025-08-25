#define MAX_QUERY_LENGTH	4096

Database g_hDatabase;

ConVar convar_Database;
ConVar convar_Table_l4d2stats;

new g_iTopCooldown[MAXPLAYERS+1];

new bool:g_bAnnounceActive[MAXPLAYERS+1];

public void Initialize_databaseConnection()
{
   if (g_hDatabase == null)
	{
		char sDatabase[256];
		convar_Database.GetString(sDatabase, sizeof(sDatabase));
		
		Database.Connect(OnSQLConnect, strlen(sDatabase) > 0 ? sDatabase : "default");
	} 
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		ThrowError("Error connecting to database: %s", error);

	//Double check that we don't already have a connection.
	if (g_hDatabase != null)
	{
		delete db;
		return;
	}

	g_hDatabase = db;
	
	char sQuery[MAX_QUERY_LENGTH];
	char sTable[64];
	convar_Table_l4d2stats.GetString(sTable, sizeof(sTable));
	
	FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` (`id` int(11) NOT NULL AUTO_INCREMENT, `steam_id` varchar(24) NOT NULL DEFAULT '', enabled BOOLEAN NOT NULL DEFAULT '0', PRIMARY KEY(id));", sTable);
	g_hDatabase.Query(DB_tableCreated, sQuery);
}

void DB_tableCreated(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Error creating DB table: %s", error);
	}
}

public Action Command_ToggleTankAnnouncements(int client, int args)
{
	int time = GetTime();
	
	if (g_iTopCooldown[client] != -1 && g_iTopCooldown[client] > time)
	{
		ReplyToCommand(client, "[SM] Please wait to use this command.");
		return Plugin_Handled;
	}
	
	g_iTopCooldown[client] = time + 3;
	
	if (!client || client > MaxClients)
	{
		ReplyToCommand(client, "[SM] for in-game use only.");
		return Plugin_Handled;
	}
	
	char sSteamID[24], sTable[64], sQuery[MAX_QUERY_LENGTH];
	convar_Table_l4d2stats.GetString(sTable, sizeof(sTable));
	
	if (!GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID)))
	{
		ReplyToCommand(client, "[SM] Steam Servers down - can't retrieve your steam ID. Try again later.");
		return Plugin_Handled;
	}
	
	FormatEx(sQuery, sizeof(sQuery), "UPDATE `%s` SET `enabled` = NOT `enabled` WHERE steam_id = '%s';", sTable, sSteamID);
	g_hDatabase.Query(DBQuery_Change_Status, sQuery, GetClientUserId(client));

	return Plugin_Handled;
}

public void DBQuery_Change_Status(Database db, DBResultSet results, const char[] error, any data)
{
	// results will equal null because we're simply updating the client's status and not retrieving any data
	
	int client = GetClientOfUserId(data);
	
	if (!client || !IsClientInGame(client))
	{
		return;
	}
	
	// rather not send another DB query so do it this way instead
	OnClientPutInServer(client);
	CreateTimer(0.5, Timer_RankPrintoutMsg, GetClientUserId(client));
}

public Action Timer_RankPrintoutMsg(Handle timer, any data)
{
	int client = GetClientOfUserId(data);
	
	if (client && IsClientInGame(client))
	{
		PrintToChat(client, "\x01[SM] Tank damage report toggled \x04%s", g_bAnnounceActive[client] ? "on" : "off");
		PrintToChat(client, "[SM] This change only affects you and will stay in affect after reconnecting.");
	}
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;
	
	g_iTopCooldown[client] = -1;

	// query if steam ID found
	char sSteamID[64], sTableRank[64], sQuery[MAX_QUERY_LENGTH];
	convar_Table_l4d2stats.GetString(sTableRank, sizeof(sTableRank));
	
	if (!GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID)))
	{
		// Steam DB down
		g_bAnnounceActive[client] = false;
		return;
	}
	
	FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM `%s` WHERE steam_id = '%s';", sTableRank, sSteamID);
	g_hDatabase.Query(DBQuery_Status, sQuery, GetClientUserId(client));
}

public void DBQuery_Status(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (results == null)
		ThrowError("Error getting client's l4dstats status results: %s", error);
	
	if (results.FetchRow())
	{	
		int field = -1;
		int istatus;
		
		if (SQL_FieldNameToNum(results, "enabled", field) && field != -1)
		{
			istatus = results.FetchInt(field);
			g_bAnnounceActive[client] = view_as<bool>(istatus);
		}
	}
	else
	{
		Initialize_Status(client);
	}
}

void Initialize_Status(int client)
{
	if (!client)
		return;
	
	if (!IsClientInGame(client))
		return;
	
	g_bAnnounceActive[client] = true;
	
	char sSteamID[56], sTableRank[64], sQuery[MAX_QUERY_LENGTH];
	if (!GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID)))
	{
		return;
	}
	
	convar_Table_l4d2stats.GetString(sTableRank, sizeof(sTableRank));
	
	Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (steam_id, enabled) VALUES ('%s', '%i');", sTableRank, sSteamID, 1);
	
	g_hDatabase.Query(DBQuery_OnInitialize_Status, sQuery);
}

public void DBQuery_OnInitialize_Status(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error initializing client's status: %s", error);
}