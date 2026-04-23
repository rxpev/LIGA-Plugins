#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin myinfo =
{
    name = "Weapon Replacer",
    author = "Rxpev",
    description = "Replaces P2000 with USP-S on spawn and M4A4 with M4A1-S on purchase for CTs",
    version = "1.6",
    url = "https://steamcommunity.com/id/rxpev/"
};

ConVar g_cvIsUSP = null;
ConVar g_cvIsM4A1 = null;

// Cached enabled states (updated after configs execute and when cvars change)
bool g_bEnableUSP = false;
bool g_bEnableM4A1 = false;

public void OnPluginStart()
{
    // Bind to existing cvars if they exist, otherwise create them.
    g_cvIsUSP = FindConVar("isUSP");
    if (g_cvIsUSP == null)
    {
        g_cvIsUSP = CreateConVar(
            "isUSP",
            "0",
            "If 1, replace P2000 with USP-S on CT spawn. If 0, do nothing.",
            FCVAR_NOTIFY,
            true, 0.0,
            true, 1.0
        );
    }

    g_cvIsM4A1 = FindConVar("isM4A1");
    if (g_cvIsM4A1 == null)
    {
        g_cvIsM4A1 = CreateConVar(
            "isM4A1",
            "0",
            "If 1, replace M4A4 purchase with M4A1-S for CTs. If 0, do nothing.",
            FCVAR_NOTIFY,
            true, 0.0,
            true, 1.0
        );
    }

    // React to runtime changes too
    g_cvIsUSP.AddChangeHook(OnCvarChanged);
    g_cvIsM4A1.AddChangeHook(OnCvarChanged);

    HookEvent("player_spawn", Event_PlayerSpawn);
}

// Runs after server cfgs are executed (best time to read final values)
public void OnConfigsExecuted()
{
    RefreshToggleCache();
}

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    RefreshToggleCache();
}

void RefreshToggleCache()
{
    g_bEnableUSP  = (g_cvIsUSP != null && g_cvIsUSP.IntValue == 1);
    g_bEnableM4A1 = (g_cvIsM4A1 != null && g_cvIsM4A1.IntValue == 1);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bEnableUSP)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || IsFakeClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT)
        return;

    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

    if (weapon == -1)
    {
        GivePlayerItem(client, "weapon_usp_silencer");
        return;
    }

    char weaponName[32];
    GetEntityClassname(weapon, weaponName, sizeof(weaponName));

    if (StrEqual(weaponName, "weapon_hkp2000"))
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
        GivePlayerItem(client, "weapon_usp_silencer");
    }
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
    if (!g_bEnableM4A1)
        return Plugin_Continue;

    if (!IsValidClient(client) || IsFakeClient(client) || GetClientTeam(client) != CS_TEAM_CT)
        return Plugin_Continue;

    if (StrEqual(weapon, "m4a1", false))
    {
        DataPack pack;
        CreateDataTimer(0.1, Timer_ReplaceM4A4, pack);
        pack.WriteCell(GetClientUserId(client));
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Timer_ReplaceM4A4(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());

    if (!IsValidClient(client) || IsFakeClient(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    // Re-check cached state at execution time
    if (!g_bEnableM4A1)
        return Plugin_Stop;

    int money = GetEntProp(client, Prop_Send, "m_iAccount");
    const int M4A1S_PRICE = 2900;

    if (money < M4A1S_PRICE)
        return Plugin_Stop;

    SetEntProp(client, Prop_Send, "m_iAccount", money - M4A1S_PRICE);

    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (weapon != -1 && IsValidEntity(weapon))
    {
        char weaponName[32];
        GetEntityClassname(weapon, weaponName, sizeof(weaponName));
        if (StrEqual(weaponName, "weapon_m4a1"))
        {
            RemovePlayerItem(client, weapon);
            AcceptEntityInput(weapon, "Kill");
        }
    }

    GivePlayerItem(client, "weapon_m4a1_silencer");
    return Plugin_Stop;
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}