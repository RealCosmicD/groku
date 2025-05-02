#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
    name = "Heavy First Aid Kits (L4D1)",
    author = "You & Grok",
    description = "Increases mass of dropped first aid kits",
    version = "1.0",
    url = ""
};

public OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 2)
        return Plugin_Continue;

    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 3 || GetEntProp(attacker, Prop_Send, "m_zombieClass") != 5)
        return Plugin_Continue;

    int kitSlot = GetPlayerWeaponSlot(victim, 3);
    if (kitSlot == -1 || !IsValidEntity(kitSlot) || GetEntProp(kitSlot, Prop_Send, "m_iItemIdHigh") != 12)
        return Plugin_Continue;

    int entity = -1;
    float deathTime = GetGameTime();
    while ((entity = FindEntityByClassname(entity, "weapon_first_aid_kit")) != -1)
    {
        if (GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == -1 && GetEntPropFloat(entity, Prop_Data, "m_flCreateTime") > deathTime - 0.5)
        {
            Phys_SetMass(entity, 40.0);
            float velocity[3];
            GetEntPropVector(entity, Prop_Data, "m_vecVelocity", velocity);
            ScaleVector(velocity, 0.3);
            TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, velocity);

            PrintToServer("[HeavyKits] Adjusted kit (mass: 40, vel: %.1f)", GetVectorLength(velocity));
            break;
        }
    }

    return Plugin_Continue;
}

stock Phys_SetMass(entity, Float:mass)
{
    if (IsValidEntity(entity)) // Removed Phys_IsPhysicsObject check
    {
        int physIndex = GetEntPropEnt(entity, Prop_Data, "m_hPhysicsObject");
        if (physIndex != -1)
            SetEntPropFloat(physIndex, Prop_Data, "m_mass", mass);
    }
}