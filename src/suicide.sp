#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name        = "Suicide – Campaign Only (L4D1 v2.9)",
    author      = "You & Grok",
    description = "100% perfect on ALL official L4D1 maps – Death Toll + Blood Harvest fixed",
    version     = "2.9",
    url         = ""
};

bool g_bMessageSent[MAXPLAYERS+1];
bool g_bIsVersus = false;

public void OnPluginStart()
{
    RegConsoleCmd("sm_suicide",       Command_Suicide);
    RegConsoleCmd("sm_debugsu",       Command_DebugSu);
    RegConsoleCmd("sm_dumpentities",  Command_DumpEntities);

    CreateTimer(5.0, Timer_CheckZoneMessage, _, TIMER_REPEAT);
    HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart()
{
    for (int i = 1; i <= MaxClients; i++) g_bMessageSent[i] = false;

    char mode[20];
    GetConVarString(FindConVar("mp_gamemode"), mode, sizeof(mode));
    g_bIsVersus = (StrContains(mode, "versus", false) != -1);
}

bool IsPointInBox(int entity, const float pos[3])
{
    float origin[3], mins[3], maxs[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    GetEntPropVector(entity, Prop_Send, "m_vecMins",    mins);
    GetEntPropVector(entity, Prop_Send, "m_vecMaxs",    maxs);

    return (pos[0] >= origin[0] + mins[0] && pos[0] <= origin[0] + maxs[0] &&
            pos[1] >= origin[1] + mins[1] && pos[1] <= origin[1] + maxs[1] &&
            pos[2] >= origin[2] + mins[2] && pos[2] <= origin[2] + maxs[2]);
}

bool IsInEndSaferoom(int client)
{
    if (g_bIsVersus) return false;

    float pos[3];
    GetClientAbsOrigin(client, pos);

    // 1. Mid-campaign end saferooms
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "info_changelevel")) != -1)
        if (IsPointInBox(ent, pos)) return true;

    // 2. Finale rescue zones
    char map[64];
    GetCurrentMap(map, sizeof(map));

    // Crash Course
    if (StrContains(map, "garage02_lots", false) != -1)
    {
        float truck[3] = {7835.6, 6055.9, 48.0};
        return GetVectorDistance(pos, truck) < 600.0;
    }

    // Death Toll boathouse – your exact coords
    if (StrContains(map, "smalltown05_houseboat", false) != -1)
    {
        float radio[3] = {3683.88, -4101.58, -90.0};
        return GetVectorDistance(pos, radio) < 900.0;
    }

    // Blood Harvest farmhouse – your exact coords
    if (StrContains(map, "farm05_cornfield", false) != -1)
    {
        float radio[3] = {6801.21, 1310.97, 300.03};
        return GetVectorDistance(pos, radio) < 1000.0;
    }

    // No Mercy, Dead Air, Sacrifice – trigger_finale is close enough
    ent = -1;
    while ((ent = FindEntityByClassname(ent, "trigger_finale")) != -1)
    {
        float finalePos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", finalePos);
        if (GetVectorDistance(pos, finalePos) < 550.0)
            return true;
    }

    return false;
}

public Action Timer_CheckZoneMessage(Handle timer)
{
    if (g_bIsVersus) return Plugin_Continue;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2 || g_bMessageSent[client])
            continue;

        bool isAdmin  = (GetUserFlagBits(client) & (ADMFLAG_GENERIC|ADMFLAG_ROOT)) != 0;
        bool incapped = view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
        bool inZone   = IsInEndSaferoom(client);

        if (inZone || incapped)
        {
            PrintToChat(client, "\x04[Suicide]\x01 Type \x03!suicide\x01 to kill yourself (end saferoom / incapped / finale zone).");
            if (isAdmin)
                PrintToChat(client, "\x04[Suicide]\x01 As admin you can suicide anywhere in campaign!");
            g_bMessageSent[client] = true;
        }
    }
    return Plugin_Continue;
}

public Action Command_Suicide(int client, int args)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2)
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 You must be a living survivor.");
        return Plugin_Handled;
    }

    if (g_bIsVersus)
    {
        ReplyToCommand(client, "\x04[Suicide]\x01 Suicide is disabled in Versus mode.");
        return Plugin_Handled;
    }

    bool isAdmin = (GetUserFlagBits(client) & (ADMFLAG_GENERIC|ADMFLAG_ROOT)) != 0;

    if (!isAdmin)
    {
        bool incapped = view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
        bool inZone   = IsInEndSaferoom(client);
        if (!incapped && !inZone)
        {
            ReplyToCommand(client, "\x04[Suicide]\x01 Only allowed when incapacitated or in end saferoom / finale zone.");
            return Plugin_Handled;
        }
    }

    char name[32];
    GetClientName(client, name, sizeof(name));

    int r = GetRandomInt(1,4);
    switch (r)
    {
        case 1: PrintToChatAll("\x04%s\x01 has committed seppuku!", name);
        case 2: PrintToChatAll("\x04%s\x01 performed harakiri!", name);
        case 3: PrintToChatAll("\x04%s\x01 couldn't take it anymore...", name);
        case 4: PrintToChatAll("\x04%s\x01 took the quick way out!", name);
    }

    ForcePlayerSuicide(client);
    return Plugin_Handled;
}

public Action Command_DebugSu(int client, int args)
{
    if (!IsClientInGame(client)) return Plugin_Handled;

    bool incapped = view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
    float pos[3]; GetClientAbsOrigin(client, pos);
    char map[64]; GetCurrentMap(map, sizeof(map));

    PrintToChat(client, "\x04[Debug]\x01 Map:%s | Incapped:%d | InEndZone:%d | Admin:%d | Pos %.1f %.1f %.1f",
        map, incapped, IsInEndSaferoom(client), (GetUserFlagBits(client) & (ADMFLAG_GENERIC|ADMFLAG_ROOT)) != 0, pos[0], pos[1], pos[2]);

    return Plugin_Handled;
}

public Action Command_DumpEntities(int client, int args)
{
    ReplyToCommand(client, "\x04[Suicide]\x01 Entity dump sent to server console.");

    int ent = -1;
    PrintToServer("=== trigger_finale dump ===");
    while ((ent = FindEntityByClassname(ent, "trigger_finale")) != -1)
    {
        float pos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
        PrintToServer("trigger_finale %d @ %.1f %.1f %.1f", ent, pos[0], pos[1], pos[2]);
    }
    return Plugin_Handled;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {}
