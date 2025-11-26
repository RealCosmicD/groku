#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
    name = "EndSaferoom/Incapped/TruckDepot Suicide (Campaign Only)",
    author = "You & Grok",
    description = "Allows suicide in end saferoom, when incapacitated, near truck in Truck Depot — CAMPAIGN/COOP ONLY. Fully disabled in Versus.",
    version = "2.4",
    url = ""
};

bool g_bMessageSent[MAXPLAYERS + 1];
bool g_bAllowSafeZoneMessages = false;
bool g_bIsVersus = false;

public void OnPluginStart()
{
    PrintToChatAll("\x04[Suicide]\x01 PLUGIN STARTING (Campaign/Co-op only)");
    
    RegConsoleCmd("sm_suicide", Command_Suicide, "Kills the player under specific conditions (campaign only)");
    RegConsoleCmd("sm_debugsu", Command_DebugSu, "Shows suicide state privately (debug)");
    
    CreateTimer(5.0, Timer_CheckSafeZone, _, TIMER_REPEAT);
    
    HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart()
{
    for (int i = 1; i <= MaxClients; i++)
        g_bMessageSent[i] = false;

    g_bAllowSafeZoneMessages = false;
    CreateTimer(30.0, Timer_EnableSafeZoneMessages, _, TIMER_FLAG_NO_MAPCHANGE);

    // Detect game mode once per map
    char gameMode[16];
    GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
    g_bIsVersus = (StrContains(gameMode, "versus", false) != -1);
    
    PrintToServer("[Suicide] Map started. Versus mode detected: %s", g_bIsVersus ? "YES → Plugin fully disabled" : "NO → Plugin active");
}

public Action Timer_EnableSafeZoneMessages(Handle timer)
{
    g_bAllowSafeZoneMessages = true;
    return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
    g_bMessageSent[client] = false;
}

// Optional: re-check on round start in case of live game mode changes (very rare)
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    char gameMode[16];
    GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
    g_bIsVersus = (StrContains(gameMode, "versus", false) != -1);
}

// ——————————————————————————————————————
//  CORE CHECKS — ONLY ACTIVE IN CAMPAIGN/COOP
// ——————————————————————————————————————

bool IsInEndSaferoom(int client)
{
    if (g_bIsVersus) return false;

    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);
    int entity = -1;

    while ((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != -1)
    {
        float doorPos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", doorPos);
        if (GetVectorDistance(clientPos, doorPos) < 400.0)
        {
            if (GetEntProp(entity, Prop_Data, "m_bLocked") == 0)
                return true;
        }
    }

    entity = -1;
    while ((entity = FindEntityByClassname(entity, "trigger_finale")) != -1)
    {
        float finalePos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", finalePos);
        if (GetVectorDistance(clientPos, finalePos) < 400.0)
            return true;
    }

    return false;
}

bool IsInTruckDepotGreenZone(int client)
{
    if (g_bIsVersus) return false;

    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    if (StrContains(mapName, "l4d_garage02_lots", false) == -1)
        return false;

    float clientPos[3], truckPos[3] = {7835.6, 6055.9, 48.0};
    GetClientAbsOrigin(client, clientPos);

    return (GetVectorDistance(clientPos, truckPos) < 600.0);
}

// ——————————————————————————————————————
//  TIMER: Safe zone reminder (only in campaign)
// ——————————————————————————————————————

public Action Timer_CheckSafeZone(Handle timer)
{
    if (g_bIsVersus || !g_bAllowSafeZoneMessages)
        return Plugin_Continue;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 && !g_bMessageSent[client])
        {
            if (IsInEndSaferoom(client) || IsInTruckDepotGreenZone(client))
            {
                PrintToChat(client, "\x04[Suicide]\x01 Type \x03!suicide\x01 to kill yourself (end saferoom / incapped / truck depot).");
                g_bMessageSent[client] = true;
            }
        }
    }
    return Plugin_Continue;
}

// ——————————————————————————————————————
//  MAIN COMMAND
// ——————————————————————————————————————

public Action Command_Suicide(int client, int args)
{
    if (!IsClientInGame(client))
        return Plugin_Handled;

    // Completely block everything in Versus — even admins
    if (g_bIsVersus)
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 Suicide is disabled in Versus mode to prevent griefing.");
        return Plugin_Handled;
    }

    if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 You must be a living survivor to use this!");
        return Plugin_Handled;
    }

    bool isIncapped = (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0);
    bool inEndSaferoom = IsInEndSaferoom(client);
    bool inTruckDepot = IsInTruckDepotGreenZone(client);

    if (!isIncapped && !inEndSaferoom && !inTruckDepot)
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 Only allowed when incapped, in end saferoom, or near truck in Truck Depot.");
        return Plugin_Handled;
    }

    char name[32];
    GetClientName(client, name, sizeof(name));

    int rand = GetRandomInt(1, 4);
    switch (rand)
    {
        case 1: PrintToChatAll("\x04%s\x01 has committed seppuku!", name);
        case 2: PrintToChatAll("\x04%s\x01 has committed harakiri!", name);
        case 3: PrintToChatAll("\x04%s\x01 couldn't take it anymore...", name);
        case 4: PrintToChatAll("\x04%s\x01 chose the quick way out!", name);
    }

    ForcePlayerSuicide(client);
    return Plugin_Handled;
}

// ——————————————————————————————————————
//  DEBUG COMMAND (still works in Versus for you)
// ——————————————————————————————————————

public Action Command_DebugSu(int client, int args)
{
    if (!IsClientInGame(client)) return Plugin_Handled;

    bool incapped = (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0);
    float pos[3]; GetClientAbsOrigin(client, pos);
    char map[64]; GetCurrentMap(map, sizeof(map));

    PrintToChat(client, "\x04[Suicide Debug]\x01 Versus=%d | Incapped=%d | EndSR=%d | TruckZone=%d | Pos=%.0f %.0f %.0f",
        g_bIsVersus, incapped, IsInEndSaferoom(client), IsInTruckDepotGreenZone(client), pos[0], pos[1], pos[2]);

    return Plugin_Handled;
}
