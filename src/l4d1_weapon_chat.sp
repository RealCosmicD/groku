#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define MAX_WEAPON_NAME_LENGTH 32

public Plugin myinfo = 
{
    name = "L4D1 Team Weapons",
    author = "Grok",
    description = "Lists the primary weapons of all survivors in a private message.",
    version = "1.3.0",
    url = "https://x.ai"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_teamweapons", Cmd_TeamWeapons, "Lists the primary weapons of all survivors in a private message.");
}

public Action Cmd_TeamWeapons(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[SM] This command can only be used in-game.");
        return Plugin_Handled;
    }

    PrintToChat(client, "\x01[SM] Survivor Team Weapons:");
    int survivorCount = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2)
        {
            char weaponName[MAX_WEAPON_NAME_LENGTH];
            GetClientPrimaryWeaponName(i, weaponName, sizeof(weaponName));
            char playerName[64];
            GetClientName(i, playerName, sizeof(playerName));

            if (strlen(weaponName) == 0)
            {
                PrintToChat(client, "\x01[SM] %s: No primary weapon", playerName);
            }
            else
            {
                PrintToChat(client, "\x01[SM] %s: %s", playerName, weaponName);
            }
            survivorCount++;
        }
    }

    if (survivorCount == 0)
    {
        PrintToChat(client, "\x01[SM] No survivors found.");
    }

    return Plugin_Handled;
}

void GetClientPrimaryWeaponName(int client, char[] weaponName, int maxlen)
{
    if (!IsClientInGame(client))
    {
        strcopy(weaponName, maxlen, "");
        return;
    }

    int weapon = GetPlayerWeaponSlot(client, 0);
    if (weapon == -1)
    {
        strcopy(weaponName, maxlen, "");
        return;
    }

    GetEdictClassname(weapon, weaponName, maxlen);

    if (StrEqual(weaponName, "weapon_smg"))
        strcopy(weaponName, maxlen, "SMG");
    else if (StrEqual(weaponName, "weapon_pumpshotgun"))
        strcopy(weaponName, maxlen, "Shotgun");
    else if (StrEqual(weaponName, "weapon_autoshotgun"))
        strcopy(weaponName, maxlen, "Auto Shotgun");
    else if (StrEqual(weaponName, "weapon_rifle"))
        strcopy(weaponName, maxlen, "Rifle");
    else if (StrEqual(weaponName, "weapon_hunting_rifle"))
        strcopy(weaponName, maxlen, "Hunting Rifle");
    else
    {
        strcopy(weaponName, maxlen, "Unknown");
    }
}