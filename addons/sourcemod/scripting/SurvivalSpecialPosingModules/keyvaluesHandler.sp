/***************************************
	Saving methods & KV stuff
***************************************/

void kv_goToTop(KeyValues kv)
{
	while (kv.NodesInStack() != 0)
		kv.GoBack();
}

int kv_countSubDirectories(KeyValues kv)
{
	if (!kv.GotoFirstSubKey())
	{
		return 0;
	}
	
	int count = 1; // starting at first sub key
	while (kv.GotoNextKey(false))
	{
		count++;
	}
	
	kv.GoBack();
	return count;
}

bool kv_IsCameraCreated(int client, int iconfig)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_PATH);
	KeyValues kv = new KeyValues("SImodel_Spawns");
	
	// Import file
	kv.ImportFromFile(sPath);
	kv_goToTop(kv);
	
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));
	
	if (!kv.JumpToKey(sMap, false)) {
		PrintToChat(client, "[SM] Error - couldn't find map key '%s' in config file", sMap);
		delete kv;
		return false;
	}

	char sConfigName[8];
	IntToString(iconfig, sConfigName, sizeof(sConfigName));
	
	if (!kv.JumpToKey(sConfigName)) {
		PrintToChat(client, "[SM] Error - couldn't find config '%s' -> '%s'", sMap, sConfigName);
		delete kv;
		return false;
	}
	
	if (!kv.JumpToKey("camera", false)) {
		delete kv;
		return false;
	}
	delete kv;
	return true;
}

/*void kv_pickRandomSectionName(KeyValues kv, char[] buffer, int size)
{
	int iSubSectionCount = kv_countSubDirectories(kv);
	int rndpick = GetRandomInt(1, iSubSectionCount);
	
	char sSection[12];
	IntToString(rndpick, sSection, sizeof(sSection));
	strcopy(buffer, size, sSection);
}*/

bool bDeleteSavedConfig(int client, int iConfig)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_PATH);
	
	KeyValues kv = new KeyValues("SImodel_Spawns");
	
	// Import file
	kv.ImportFromFile(sPath);
	kv_goToTop(kv);
	
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));
	
	if(!kv.JumpToKey(sMap, false))
	{
		PrintToChat(client, "[SM] Unable to delete config: map %s key not found.", sMap);

		delete kv;
		return false;
	}
	
	char sConfigName[8];
	IntToString(iConfig, sConfigName, sizeof(sConfigName));

	if(!kv.JumpToKey(sConfigName, false))
	{
		PrintToChat(client, "[SM] Unable to delete config: '%s' -> '%s' key not found.", sMap, sConfigName);

		delete kv;
		return false;
	}

	kv.DeleteThis();
	
	kv_goToTop(kv);
	kv.ExportToFile(sPath);
	
	delete kv;
	
	return true;
}

bool bSaveCamera(int client, float pos[3], float ang[3])
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_PATH);
	
	KeyValues kv = new KeyValues("SImodel_Spawns");
	
	// Import file
	kv.ImportFromFile(sPath);
	kv_goToTop(kv);
	
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));

	if (!kv.JumpToKey(sMap, false))
	{
		PrintToChat(client, "[SM] Error: to find config map key '%s'", sMap);
		delete kv;
		return false;
	}
	
	// jump to current config
	if (g_iConfigID == 0)
	{
		PrintToChat(client, "[SM] No config currently selected. Load a config or create a new one.");
		delete kv;
		return false;
	}

	char sConfigName[8];
	IntToString(g_iConfigID, sConfigName, sizeof(sConfigName));

	if (!kv.JumpToKey(sConfigName, true))
	{
		PrintToChat(client, "[SM] Error trying to create config '%s' -> '%s'", sMap, sConfigName);
		delete kv;
		return false;
	}
	
	kv.JumpToKey("camera", true);
	
	kv.SetVector("position", pos);
	kv.SetVector("angles", ang);
	
	kv_goToTop(kv);
	kv.ExportToFile(sPath);
	
	delete kv;
	
	return true;
}

bool bSaveToCfgFile(const char[] sModelName, float pos[3], float ang[3])
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_PATH);
	
	KeyValues kv = new KeyValues("SImodel_Spawns");
	
	// Import file
	kv.ImportFromFile(sPath);
	kv_goToTop(kv);
	
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));
	
	// Create map section
	kv.JumpToKey(sMap, true);
	
	// 'c1m4_atrium' -> '2'
	char sTmp[8];
	IntToString(g_iConfigID, sTmp, sizeof(sTmp));
	kv.JumpToKey(sTmp, true);
	
	int iProp;
	char key[16];
	Format(key, sizeof(key), "prop%i", iProp);

	// find latest prop name ('prop3', 'prop4', etc. ) that doesn't exist yet.
	while (kv.JumpToKey(key))
	{
		kv.GoBack();
		iProp++;
		Format(key, sizeof(key), "prop%i", iProp);
	}
	kv.JumpToKey(key, true);
	
	kv.SetString("model", sModelName);
	kv.SetVector("position", pos);
	kv.SetVector("angles", ang);
	
	kv_goToTop(kv);
	kv.ExportToFile(sPath);
	
	delete kv;
	
	return true;
}

int GetNumOfPoseConfigs()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_PATH);

	KeyValues kv = new KeyValues("SImodel_Spawns");
	
	// Import file
	if (!kv.ImportFromFile(sPath))
	{
		delete kv;
		return -1;
	}

	kv_goToTop(kv);
	
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));

	if(!kv.JumpToKey(sMap, false))
	{
		delete kv;
		return -1;
	}

	int iSubSectionCount = kv_countSubDirectories(kv);
	delete kv;
	return iSubSectionCount;
}

bool bLoadCfgFile(int iConfig, bool bEndRoundPose = false, bool bSlaySurvivorsEditMode = false)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_PATH);
	
	KeyValues kv = new KeyValues("SImodel_Spawns");
	
	// Import file
	kv.ImportFromFile(sPath);
	kv_goToTop(kv);
	
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));
	
	if(!kv.JumpToKey(sMap, false))
	{
		delete kv;
		return false;
	}

	char sSectionName[8];
	
	// if end round pose - select a config for the map at random.
	// TODO test this
	if (bEndRoundPose)
	{
		/*
			scenerio: config names are '15', '16', '17'
				(previous config names got deleted during editing)
		 */
		int iSubSectionCount = PopulateMenuIDs(); // populate g_hArray_ConfigIDs
		int rndpick = GetRandomInt(0, iSubSectionCount -1);
		g_hArray_ConfigIDs.GetString(rndpick, sSectionName, sizeof(sSectionName));
		g_hArray_ConfigIDs.Clear();
	}
	else
	{
		IntToString(iConfig, sSectionName, sizeof(sSectionName));
	}
	
	if (!kv.JumpToKey(sSectionName, false))
	{
		delete kv;
		return false;
	}
	
	char sModel[48];
	float pos[3], ang[3];
	char sName[42];
	float campos[3], camangle[3];

	if(kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(sName, sizeof(sName));
			
			if(StrEqual(sName, "camera")) {

				kv.GetVector("position", campos);
				kv.GetVector("angles", camangle);

				CreateCameraEntity(campos, camangle, (bEndRoundPose || bSlaySurvivorsEditMode) ? false : true);
			}
			else
			{
				kv.GetString("Model", sModel, sizeof(sModel));
				kv.GetVector("position", pos);
				kv.GetVector("angles", ang);
				
				CreateSIModel(sModel, pos, ang, false);
			}
		
		} while (kv.GotoNextKey(false));
	}
	
	// Only store these for editing.
	if (bEndRoundPose)
	{
		g_hArray_SIIndexes.Clear();
	}

	delete kv;
	return true;
}

int iStartNewSection()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_PATH);
	
	KeyValues kv = new KeyValues("SImodel_Spawns");
	
	// Import file
	kv.ImportFromFile(sPath);
	kv_goToTop(kv);
	
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));
	kv.JumpToKey(sMap, true);
	
	int iName = kv_countSubDirectories(kv) + 1;
	char sName[12];
	IntToString(iName, sName, sizeof(sName));

	// config names can start at 3, 4, etc..
	// if previous configs got deleted
	// just find a name that doesn't exist yet that's the highest value.
	while (kv.JumpToKey(sName))
	{
		kv.GoBack();
		iName++;
		Format(sName, sizeof(sName), "%i", iName);
	}
	kv.JumpToKey(sName, true);
	
	kv_goToTop(kv);
	kv.ExportToFile(sPath);
	
	delete kv;
	
	return iName;
}

int PopulateMenuIDs()
{
	g_hArray_ConfigIDs.Clear();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CFG_PATH);

	KeyValues kv = new KeyValues("SImodel_Spawns");
	
	// Import file
	if (!kv.ImportFromFile(sPath))
	{
		delete kv;
		return -1;
	}

	kv_goToTop(kv);
	
	char sMap[42];
	GetCurrentMap(sMap, sizeof(sMap));

	if(!kv.JumpToKey(sMap, false))
	{
		delete kv;
		return -1;
	}

	kv.GotoFirstSubKey();

	char sSection[8];
	kv.GetSectionName(sSection, sizeof(sSection));
	g_hArray_ConfigIDs.PushString(sSection);

	while (kv.GotoNextKey())
	{
		kv.GetSectionName(sSection, sizeof(sSection));
		g_hArray_ConfigIDs.PushString(sSection);
	}

	delete kv;
	return g_hArray_ConfigIDs.Length;
}