#include <sourcemod>
#include <sdktools>
#include <clientprefs>

public Plugin myinfo = 
{
    name = "Custom Achievements",
    author = "You & Grok",
    description = "Tracks damage, kills, and weapon usage across a campaign for server achievements",
    version = "1.15",
    url = ""
};

Handle g_hDamageCookie;
Handle g_hKillsCookie;
Handle g_hStartCookie;
Handle g_hT1OnlyCookie;
int g_iDamageReceived[MAXPLAYERS + 1];
int g_iKillsDealt[MAXPLAYERS + 1];
bool g_bStartedCampaign[MAXPLAYERS + 1];
bool g_bUsedT2Weapons[MAXPLAYERS + 1];
bool g_bFirstMap = true;
char g_sLastVoteIssue[64];
#define TITANIUM_FILE "addons/sourcemod/data/titanium_history.txt"
#define GLASS_FILE "addons/sourcemod/data/glass_history.txt"
#define PRO_FILE "addons/sourcemod/data/pro_history.txt"
#define ACHIEVEMENT_SOUND "ui/achievement_earned.wav"

public void OnPluginStart()
{
    g_hDamageCookie = RegClientCookie("damage_received", "Total damage received", CookieAccess_Private);
    g_hKillsCookie = RegClientCookie("kills_dealt", "Total kills dealt", CookieAccess_Private);
    g_hStartCookie = RegClientCookie("campaign_start", "Joined at campaign start", CookieAccess_Private);
    g_hT1OnlyCookie = RegClientCookie("t1_only", "Used only T1 weapons", CookieAccess_Private);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("infected_hurt", Event_InfectedHurt);
    HookEvent("item_pickup", Event_ItemPickup);
    HookEvent("finale_vehicle_leaving", Event_VehicleLeaving);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("map_transition", Event_MapTransition);
    HookEvent("player_team", Event_PlayerTeam);
    HookEvent("vote_started", Event_VoteStarted);
    HookEvent("vote_passed", Event_VotePassed);
    RegConsoleCmd("sm_titaniumtop", Command_TopTitanium, "Shows top 5 I Am Titanium achievers");
    RegConsoleCmd("sm_glasstop", Command_TopGlass, "Shows top 5 Heart Of Glass achievers");
    RegConsoleCmd("sm_protop", Command_TopPro, "Shows top 5 PROselytizer achievers");
    RegConsoleCmd("-checkti", Command_CheckTitanium, "Check I Am Titanium eligibility");
    RegConsoleCmd("-hgcheck", Command_CheckHeartOfGlass, "Check Heart Of Glass eligibility");
    RegConsoleCmd("-checkpro", Command_CheckPro, "Check PROselytizer eligibility");
    PrecacheSound(ACHIEVEMENT_SOUND, true);
}

public void OnClientCookiesCached(int client)
{
    char value[32];
    GetClientCookie(client, g_hDamageCookie, value, sizeof(value));
    g_iDamageReceived[client] = StringToInt(value);
    GetClientCookie(client, g_hKillsCookie, value, sizeof(value));
    g_iKillsDealt[client] = StringToInt(value);
    GetClientCookie(client, g_hStartCookie, value, sizeof(value));
    g_bStartedCampaign[client] = (value[0] != '\0' && StringToInt(value) == 1);
    GetClientCookie(client, g_hT1OnlyCookie, value, sizeof(value));
    g_bUsedT2Weapons[client] = (value[0] != '\0' && StringToInt(value) == 1);
}

public void OnClientDisconnect(int client)
{
    if (AreClientCookiesCached(client))
    {
        char value[32];
        IntToString(g_iDamageReceived[client], value, sizeof(value));
        SetClientCookie(client, g_hDamageCookie, value);
        IntToString(g_iKillsDealt[client], value, sizeof(value));
        SetClientCookie(client, g_hKillsCookie, value);
        IntToString(g_bStartedCampaign[client] ? 1 : 0, value, sizeof(value));
        SetClientCookie(client, g_hStartCookie, value);
        IntToString(g_bUsedT2Weapons[client] ? 1 : 0, value, sizeof(value));
        SetClientCookie(client, g_hT1OnlyCookie, value);
    }
    g_iDamageReceived[client] = 0;
    g_iKillsDealt[client] = 0;
    g_bStartedCampaign[client] = false;
    g_bUsedT2Weapons[client] = false;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bFirstMap)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
            {
                g_bStartedCampaign[i] = true;
                g_iDamageReceived[i] = 0;
                g_iKillsDealt[i] = 0;
                g_bUsedT2Weapons[i] = false;
                if (AreClientCookiesCached(i))
                {
                    char value[32];
                    IntToString(0, value, sizeof(value));
                    SetClientCookie(i, g_hDamageCookie, value);
                    SetClientCookie(i, g_hKillsCookie, value);
                    IntToString(1, value, sizeof(value));
                    SetClientCookie(i, g_hStartCookie, value);
                    IntToString(0, value, sizeof(value));
                    SetClientCookie(i, g_hT1OnlyCookie, value);
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
    g_bFirstMap = false;
    return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int team = event.GetInt("team");
    if (client && !IsFakeClient(client) && team == 2 && g_bFirstMap)
    {
        g_bStartedCampaign[client] = true;
        g_iDamageReceived[client] = 0;
        g_iKillsDealt[client] = 0;
        g_bUsedT2Weapons[client] = false;
        if (AreClientCookiesCached(client))
        {
            char value[32];
            IntToString(0, value, sizeof(value));
            SetClientCookie(client, g_hDamageCookie, value);
            SetClientCookie(client, g_hKillsCookie, value);
            IntToString(1, value, sizeof(value));
            SetClientCookie(client, g_hStartCookie, value);
            IntToString(0, value, sizeof(value));
            SetClientCookie(client, g_hT1OnlyCookie, value);
        }
    }
    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (victim && IsClientInGame(victim) && !IsFakeClient(victim) && GetClientTeam(victim) == 2)
    {
        int damage = event.GetInt("dmg_health");
        g_iDamageReceived[victim] += damage;
        if (AreClientCookiesCached(victim))
        {
            char value[32];
            IntToString(g_iDamageReceived[victim], value, sizeof(value));
            SetClientCookie(victim, g_hDamageCookie, value);
        }
    }
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (victim && attacker && IsClientInGame(attacker) && !IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
    {
        int victimTeam = GetClientTeam(victim);
        if (victimTeam == 3)
        {
            char classname[32];
            GetClientModel(victim, classname, sizeof(classname));
            if (StrContains(classname, "smoker") != -1 || StrContains(classname, "boomer") != -1 ||
                StrContains(classname, "hunter") != -1 || StrContains(classname, "witch") != -1 ||
                StrContains(classname, "tank") != -1)
            {
                g_iKillsDealt[attacker]++;
                if (AreClientCookiesCached(attacker))
                {
                    char value[32];
                    IntToString(g_iKillsDealt[attacker], value, sizeof(value));
                    SetClientCookie(attacker, g_hKillsCookie, value);
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int infectedId = event.GetInt("entityid");
    int damage = event.GetInt("amount");
    if (attacker && IsClientInGame(attacker) && !IsFakeClient(attacker) && GetClientTeam(attacker) == 2)
    {
        char classname[32];
        if (infectedId > MaxClients && IsValidEntity(infectedId))
        {
            GetEntityClassname(infectedId, classname, sizeof(classname));
            if (StrEqual(classname, "infected"))
            {
                int health = GetEntProp(infectedId, Prop_Data, "m_iHealth");
                if (health <= 0 || damage >= health)
                {
                    g_iKillsDealt[attacker]++;
                    if (AreClientCookiesCached(attacker))
                    {
                        char value[32];
                        IntToString(g_iKillsDealt[attacker], value, sizeof(value));
                        SetClientCookie(attacker, g_hKillsCookie, value);
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    char item[32];
    event.GetString("item", item, sizeof(item));
    if (client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2)
    {
        if (StrEqual(item, "autoshotgun") || StrEqual(item, "rifle"))
        {
            g_bUsedT2Weapons[client] = true;
            if (AreClientCookiesCached(client))
            {
                char value[32];
                IntToString(1, value, sizeof(value));
                SetClientCookie(client, g_hT1OnlyCookie, value);
            }
        }
    }
    return Plugin_Continue;
}

public Action Event_VoteStarted(Event event, const char[] name, bool dontBroadcast)
{
    event.GetString("issue", g_sLastVoteIssue, sizeof(g_sLastVoteIssue));
    return Plugin_Continue;
}

public Action Event_VotePassed(Event event, const char[] name, bool dontBroadcast)
{
    if (StrEqual(g_sLastVoteIssue, "#L4D_vote_restart_game"))
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                g_iDamageReceived[i] = 0;
                g_iKillsDealt[i] = 0;
                g_bStartedCampaign[i] = true;
                g_bUsedT2Weapons[i] = false;
                if (AreClientCookiesCached(i))
                {
                    char value[32];
                    IntToString(0, value, sizeof(value));
                    SetClientCookie(i, g_hDamageCookie, value);
                    SetClientCookie(i, g_hKillsCookie, value);
                    IntToString(1, value, sizeof(value));
                    SetClientCookie(i, g_hStartCookie, value);
                    IntToString(0, value, sizeof(value));
                    SetClientCookie(i, g_hT1OnlyCookie, value);
                }
            }
        }
        g_bFirstMap = true;
    }
    return Plugin_Continue;
}

public Action Event_VehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
        {
            CheckAchievements(i);
        }
    }
    return Plugin_Continue;
}

void CheckAchievements(int client)
{
    if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2 || !g_bStartedCampaign[client])
        return;

    int totalDamage = g_iDamageReceived[client];
    int totalKills = g_iKillsDealt[client];
    bool usedT2 = g_bUsedT2Weapons[client];
    char playerName[32], steamId[32], campaign[32];
    GetClientName(client, playerName, sizeof(playerName));
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    GetCurrentMap(campaign, sizeof(campaign));

    bool awarded = false;
    if (totalDamage == 0)
    {
        PrintToChatAll("\x04[Server Achievement Earned]\x01 %s\x04 - I Am Titanium", playerName);
        EmitSoundToClient(client, ACHIEVEMENT_SOUND);
        UpdateAchievementHistory(steamId, playerName, campaign, TITANIUM_FILE);
        awarded = true;
    }
    if (totalKills == 0)
    {
        PrintToChatAll("\x04[Server Achievement Earned]\x01 %s\x04 - Heart Of Glass", playerName);
        EmitSoundToClient(client, ACHIEVEMENT_SOUND);
        UpdateAchievementHistory(steamId, playerName, campaign, GLASS_FILE);
        awarded = true;
    }
    if (!usedT2)
    {
        PrintToChatAll("\x04[Server Achievement Earned]\x01 %s\x04 - PROselytizer", playerName);
        EmitSoundToClient(client, ACHIEVEMENT_SOUND);
        UpdateAchievementHistory(steamId, playerName, campaign, PRO_FILE);
        awarded = true;
    }

    if (awarded)
    {
        g_iDamageReceived[client] = 0;
        g_iKillsDealt[client] = 0;
        g_bStartedCampaign[client] = false;
        g_bUsedT2Weapons[client] = false;
        if (AreClientCookiesCached(client))
        {
            char value[32];
            IntToString(0, value, sizeof(value));
            SetClientCookie(client, g_hDamageCookie, value);
            SetClientCookie(client, g_hKillsCookie, value);
            SetClientCookie(client, g_hStartCookie, value);
            SetClientCookie(client, g_hT1OnlyCookie, value);
        }
    }
}

void UpdateAchievementHistory(const char[] steamId, const char[] playerName, const char[] campaign, const char[] file)
{
    KeyValues kv = CreateKeyValues("History");
    if (FileExists(file))
        kv.ImportFromFile(file);

    if (kv.JumpToKey(steamId, true))
    {
        int count = kv.GetNum("count", 0) + 1;
        kv.SetNum("count", count);
        kv.SetString("name", playerName);
        kv.SetString("last_campaign", campaign);
    }
    else
    {
        kv.SetNum("count", 1);
        kv.SetString("name", playerName);
        kv.SetString("last_campaign", campaign);
    }
    kv.Rewind();
    kv.ExportToFile(file);
    delete kv;
}

public Action Command_TopTitanium(int client, int args)
{
    KeyValues kv = CreateKeyValues("History");
    if (!FileExists(TITANIUM_FILE) || !kv.ImportFromFile(TITANIUM_FILE))
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 No I Am Titanium winners yet!");
        delete kv;
        return Plugin_Handled;
    }

    char steamIds[64][32];
    int counts[64];
    int numEntries = 0;

    if (kv.GotoFirstSubKey())
    {
        do
        {
            kv.GetSectionName(steamIds[numEntries], sizeof(steamIds[]));
            counts[numEntries] = kv.GetNum("count", 0);
            numEntries++;
        } while (kv.GotoNextKey() && numEntries < 64);
    }
    kv.Rewind();

    for (int i = 0; i < numEntries - 1; i++)
    {
        for (int j = 0; j < numEntries - i - 1; j++)
        {
            if (counts[j] < counts[j + 1])
            {
                int tempCount = counts[j];
                counts[j] = counts[j + 1];
                counts[j + 1] = tempCount;
                char tempSteam[32];
                strcopy(tempSteam, sizeof(tempSteam), steamIds[j]);
                strcopy(steamIds[j], sizeof(steamIds[]), steamIds[j + 1]);
                strcopy(steamIds[j + 1], sizeof(steamIds[]), tempSteam);
            }
        }
    }

    ReplyToCommand(client, "\x04[Server Achievements]\x01 Top 5 'I Am Titanium' Winners:");
    for (int i = 0; i < min(5, numEntries); i++)
    {
        char name[32], campaign[32];
        KeyValues tempKv = CreateKeyValues("History");
        tempKv.ImportFromFile(TITANIUM_FILE);
        tempKv.JumpToKey(steamIds[i]);
        tempKv.GetString("name", name, sizeof(name));
        tempKv.GetString("last_campaign", campaign, sizeof(campaign));
        ReplyToCommand(client, "\x04#%d\x01 %s - %d times (Last: %s)", i + 1, name, counts[i], campaign);
        delete tempKv;
    }
    delete kv;
    return Plugin_Handled;
}

public Action Command_TopGlass(int client, int args)
{
    KeyValues kv = CreateKeyValues("History");
    if (!FileExists(GLASS_FILE) || !kv.ImportFromFile(GLASS_FILE))
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 No Heart Of Glass winners yet!");
        delete kv;
        return Plugin_Handled;
    }

    char steamIds[64][32];
    int counts[64];
    int numEntries = 0;

    if (kv.GotoFirstSubKey())
    {
        do
        {
            kv.GetSectionName(steamIds[numEntries], sizeof(steamIds[]));
            counts[numEntries] = kv.GetNum("count", 0);
            numEntries++;
        } while (kv.GotoNextKey() && numEntries < 64);
    }
    kv.Rewind();

    for (int i = 0; i < numEntries - 1; i++)
    {
        for (int j = 0; j < numEntries - i - 1; j++)
        {
            if (counts[j] < counts[j + 1])
            {
                int tempCount = counts[j];
                counts[j] = counts[j + 1];
                counts[j + 1] = tempCount;
                char tempSteam[32];
                strcopy(tempSteam, sizeof(tempSteam), steamIds[j]);
                strcopy(steamIds[j], sizeof(steamIds[]), steamIds[j + 1]);
                strcopy(steamIds[j + 1], sizeof(steamIds[]), tempSteam);
            }
        }
    }

    ReplyToCommand(client, "\x04[Server Achievements]\x01 Top 5 'Heart Of Glass' Winners:");
    for (int i = 0; i < min(5, numEntries); i++)
    {
        char name[32], campaign[32];
        KeyValues tempKv = CreateKeyValues("History");
        tempKv.ImportFromFile(GLASS_FILE);
        tempKv.JumpToKey(steamIds[i]);
        tempKv.GetString("name", name, sizeof(name));
        tempKv.GetString("last_campaign", campaign, sizeof(campaign));
        ReplyToCommand(client, "\x04#%d\x01 %s - %d times (Last: %s)", i + 1, name, counts[i], campaign);
        delete tempKv;
    }
    delete kv;
    return Plugin_Handled;
}

public Action Command_TopPro(int client, int args)
{
    KeyValues kv = CreateKeyValues("History");
    if (!FileExists(PRO_FILE) || !kv.ImportFromFile(PRO_FILE))
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 No PROselytizer winners yet!");
        delete kv;
        return Plugin_Handled;
    }

    char steamIds[64][32];
    int counts[64];
    int numEntries = 0;

    if (kv.GotoFirstSubKey())
    {
        do
        {
            kv.GetSectionName(steamIds[numEntries], sizeof(steamIds[]));
            counts[numEntries] = kv.GetNum("count", 0);
            numEntries++;
        } while (kv.GotoNextKey() && numEntries < 64);
    }
    kv.Rewind();

    for (int i = 0; i < numEntries - 1; i++)
    {
        for (int j = 0; j < numEntries - i - 1; j++)
        {
            if (counts[j] < counts[j + 1])
            {
                int tempCount = counts[j];
                counts[j] = counts[j + 1];
                counts[j + 1] = tempCount;
                char tempSteam[32];
                strcopy(tempSteam, sizeof(tempSteam), steamIds[j]);
                strcopy(steamIds[j], sizeof(steamIds[]), steamIds[j + 1]);
                strcopy(steamIds[j + 1], sizeof(steamIds[]), tempSteam);
            }
        }
    }

    ReplyToCommand(client, "\x04[Server Achievements]\x01 Top 5 'PROselytizer' Winners:");
    for (int i = 0; i < min(5, numEntries); i++)
    {
        char name[32], campaign[32];
        KeyValues tempKv = CreateKeyValues("History");
        tempKv.ImportFromFile(PRO_FILE);
        tempKv.JumpToKey(steamIds[i]);
        tempKv.GetString("name", name, sizeof(name));
        tempKv.GetString("last_campaign", campaign, sizeof(campaign));
        ReplyToCommand(client, "\x04#%d\x01 %s - %d times (Last: %s)", i + 1, name, counts[i], campaign);
        delete tempKv;
    }
    delete kv;
    return Plugin_Handled;
}

public Action Command_CheckTitanium(int client, int args)
{
    if (!client || !IsClientInGame(client))
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Must be in-game!");
        return Plugin_Handled;
    }
    if (!g_bStartedCampaign[client])
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Not eligible for I Am Titanium - didn't start at campaign beginning!");
    }
    else
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Eligible for I Am Titanium: %s (Damage: %d)", g_iDamageReceived[client] == 0 ? "Yes" : "No", g_iDamageReceived[client]);
    }
    return Plugin_Handled;
}

public Action Command_CheckHeartOfGlass(int client, int args)
{
    if (!client || !IsClientInGame(client))
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Must be in-game!");
        return Plugin_Handled;
    }
    if (!g_bStartedCampaign[client])
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Not eligible for Heart Of Glass - didn't start at campaign beginning!");
    }
    else
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Eligible for Heart Of Glass: %s (Kills: %d)", g_iKillsDealt[client] == 0 ? "Yes" : "No", g_iKillsDealt[client]);
    }
    return Plugin_Handled;
}

public Action Command_CheckPro(int client, int args)
{
    if (!client || !IsClientInGame(client))
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Must be in-game!");
        return Plugin_Handled;
    }
    if (!g_bStartedCampaign[client])
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Not eligible for PROselytizer - didn't start at campaign beginning!");
    }
    else
    {
        ReplyToCommand(client, "\x04[Server Achievements]\x01 Eligible for PROselytizer: %s", g_bUsedT2Weapons[client] ? "No" : "Yes");
    }
    return Plugin_Handled;
}

int min(int a, int b)
{
    return (a < b) ? a : b;
}