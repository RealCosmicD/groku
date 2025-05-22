#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
    name = "EndSaferoom/Incapped/TruckDepot Suicide",
    author = "You & Grok",
    description = "Allows suicide in end saferoom, when incapacitated, near the truck in Crash Course Truck Depot, or for admins anywhere",
    version = "2.3",
    url = ""
};

bool g_bMessageSent[MAXPLAYERS + 1]; // Tracks if message was sent to each player
bool g_bAllowSafeZoneMessages = false; // Tracks if initial delay has passed

public OnPluginStart()
{
    PrintToChatAll("\x04[Suicide]\x01 PLUGIN STARTING");
    RegConsoleCmd("sm_suicide", Command_Suicide, "Kills the player if in end saferoom, incapacitated, near the truck in Truck Depot, or admin");
    RegConsoleCmd("sm_debugsu", Command_DebugSu, "Shows suicide state privately");
    RegConsoleCmd("sm_dumpentities", Command_DumpEntities, "Dumps all prop_dynamic and prop_physics positions");
    
    // Create repeating timer to check for safe zone entry
    CreateTimer(5.0, Timer_CheckSafeZone, _, TIMER_REPEAT);
}

public OnMapStart()
{
    // Reset status for all players
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bMessageSent[i] = false;
    }
    
    // Disable safe zone messages for the first 30 seconds
    g_bAllowSafeZoneMessages = false;
    CreateTimer(30.0, Timer_EnableSafeZoneMessages, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_EnableSafeZoneMessages(Handle:timer)
{
    g_bAllowSafeZoneMessages = true;
    return Plugin_Handled;
}

public OnClientDisconnect(client)
{
    // Reset status when a client disconnects
    g_bMessageSent[client] = false;
}

bool IsInEndSaferoom(client)
{
    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);
    int entity = -1;
    
    // Check for checkpoint doors
    while ((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != -1)
    {
        float doorPos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", doorPos);
        if (GetVectorDistance(clientPos, doorPos) < 400.0)
        {
            int locked = GetEntProp(entity, Prop_Data, "m_bLocked");
            if (locked == 0)
            {
                PrintToServer("[Suicide] Player %N near unlocked saferoom door at Pos=%.1f %.1f %.1f", 
                    client, doorPos[0], doorPos[1], doorPos[2]);
                return true; // Unlocked = end saferoom
            }
        }
    }
    
    // Fallback: Check for trigger_finale (common in end saferooms)
    entity = -1;
    while ((entity = FindEntityByClassname(entity, "trigger_finale")) != -1)
    {
        float finalePos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", finalePos);
        if (GetVectorDistance(clientPos, finalePos) < 400.0)
        {
            PrintToServer("[Suicide] Player %N near trigger_finale at Pos=%.1f %.1f %.1f", 
                client, finalePos[0], finalePos[1], finalePos[2]);
            return true;
        }
    }
    
    return false;
}

bool IsInTruckDepotGreenZone(client)
{
    // Check if the map is Crash Course Truck Depot
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    if (StrContains(mapName, "l4d_garage02_lots", false) == -1)
    {
        PrintToServer("[Suicide] Not on l4d_garage02_lots for player %N (map: %s)", client, mapName);
        return false;
    }
    
    // Check distance to hardcoded truck coordinates
    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);
    float truckPos[3];
    truckPos[0] = 7835.6; // Truck center X
    truckPos[1] = 6055.9; // Truck center Y
    truckPos[2] = 48.0;   // Truck center Z
    float distance = GetVectorDistance(clientPos, truckPos);
    if (distance < 600.0)
    {
        PrintToServer("[Suicide] Player %N in green zone: distance=%.1f, truckPos=%.1f %.1f %.1f", 
            client, distance, truckPos[0], truckPos[1], truckPos[2]);
        return true;
    }
    else
    {
        PrintToServer("[Suicide] Player %N too far: distance=%.1f, truckPos=%.1f %.1f %.1f, clientPos=%.1f %.1f %.1f", 
            client, distance, truckPos[0], truckPos[1], truckPos[2], clientPos[0], clientPos[1], clientPos[2]);
    }
    
    return false;
}

public Action:Timer_CheckSafeZone(Handle:timer)
{
    if (!g_bAllowSafeZoneMessages)
    {
        return Plugin_Continue;
    }
    
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !g_bMessageSent[client] && IsPlayerAlive(client))
        {
            bool inEndSaferoom = IsInEndSaferoom(client);
            bool inTruckDepotGreenZone = IsInTruckDepotGreenZone(client);
            if (inEndSaferoom || inTruckDepotGreenZone)
            {
                PrintToChat(client, "\x04[Suicide]\x01 Type !suicide to kill yourself. Only works in the end saferoom, when incapacitated, or near the truck in Truck Depot.");
                if (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_ROOT))
                {
                    PrintToChat(client, "\x04[Suicide]\x01 As an admin, you can suicide anywhere!");
                }
                g_bMessageSent[client] = true;
            }
            else
            {
                float pos[3];
                GetClientAbsOrigin(client, pos);
                char mapName[64];
                GetCurrentMap(mapName, sizeof(mapName));
                PrintToServer("[Suicide] No message for %N: Map=%s, EndSaferoom=%d, TruckDepot=%d, Pos=%.1f %.1f %.1f", 
                    client, mapName, inEndSaferoom, inTruckDepotGreenZone, pos[0], pos[1], pos[2]);
            }
        }
    }
    return Plugin_Continue;
}

public Action:Command_Suicide(client, args)
{
    if (!client || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 You must be a living survivor to use this!");
        return Plugin_Handled;
    }
    
    bool isIncapped = GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0;
    bool inEndSaferoom = IsInEndSaferoom(client);
    bool inTruckDepotGreenZone = IsInTruckDepotGreenZone(client);
    bool isAdmin = (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_ROOT)) != 0;
    bool canSuicide = isAdmin || inEndSaferoom || isIncapped || inTruckDepotGreenZone;
    
    if (!canSuicide)
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 You can only suicide in the end saferoom, when incapacitated, or near the truck in Truck Depot!");
        return Plugin_Handled;
    }
    
    char playerName[32];
    GetClientName(client, playerName, sizeof(playerName));
    char message[64];
    int rand = GetRandomInt(1, 3);
    switch (rand)
    {
        case 1: Format(message, sizeof(message), "\x04%s\x01 has committed seppuku!", playerName);
        case 2: Format(message, sizeof(message), "\x04%s\x01 has committed harakiri!", playerName);
        case 3: Format(message, sizeof(message), "\x04%s\x01 suicided!", playerName);
    }
    PrintToChatAll(message);
    
    ForcePlayerSuicide(client);
    return Plugin_Handled;
}

public Action:Command_DebugSu(client, args)
{
    if (!client || !IsClientInGame(client))
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 You must be in-game to use this!");
        return Plugin_Handled;
    }
    
    bool isIncapped = GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0;
    bool inEndSaferoom = IsInEndSaferoom(client);
    bool inTruckDepotGreenZone = IsInTruckDepotGreenZone(client);
    bool isAdmin = (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_ROOT)) != 0;
    float pos[3];
    GetClientAbsOrigin(client, pos);
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    PrintToChat(client, "\x04[Suicide]\x01 Debug: Map=%s, EndSaferoom=%d, Incapped=%d, TruckDepotGreenZone=%d, IsAdmin=%d, Pos=%.1f %.1f %.1f, CanSuicide=%d", 
        mapName, inEndSaferoom, isIncapped, inTruckDepotGreenZone, isAdmin, pos[0], pos[1], pos[2], isAdmin || inEndSaferoom || isIncapped || inTruckDepotGreenZone);
    return Plugin_Handled;
}

public Action:Command_DumpEntities(client, args)
{
    if (!client || !IsClientInGame(client))
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 You must be in-game to use this!");
        return Plugin_Handled;
    }
    
    int entity = -1;
    PrintToServer("[Suicide] Dumping prop_dynamic entities:");
    while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != -1)
    {
        char modelName[128];
        GetEntPropString(entity, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
        float pos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
        PrintToServer("Entity=%d, Model=%s, Pos=%.1f %.1f %.1f", entity, modelName, pos[0], pos[1], pos[2]);
    }
    
    entity = -1;
    PrintToServer("[Suicide] Dumping prop_physics entities:");
    while ((entity = FindEntityByClassname(entity, "prop_physics")) != -1)
    {
        char modelName[128];
        GetEntPropString(entity, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
        float pos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
        PrintToServer("Entity=%d, Model=%s, Pos=%.1f %.1f %.1f", entity, modelName, pos[0], pos[1], pos[2]);
    }
    
    // Dump trigger_finale entities for debugging
    entity = -1;
    PrintToServer("[Suicide] Dumping trigger_finale entities:");
    while ((entity = FindEntityByClassname(entity, "trigger_finale")) != -1)
    {
        float pos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
        PrintToServer("Entity=%d, Class=trigger_finale, Pos=%.1f %.1f %.1f", entity, pos[0], pos[1], pos[2]);
    }
    
    ReplyToCommand(client, "\x04[Suicide]\x01 Entity positions logged to server console.");
    return Plugin_Handled;
}