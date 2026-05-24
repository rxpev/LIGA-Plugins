#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin myinfo =
{
    name = "Weapon Replacer",
    author = "Rxpev",
    description = "Replaces P2000 with USP-S on spawn, M4A4 with M4A1-S on purchase, and Five-SeveN/Tec-9 with CZ75-Auto",
    version = "1.7",
    url = "https://steamcommunity.com/id/rxpev/"
};

ConVar g_cvIsUSP = null;
ConVar g_cvIsM4A1 = null;
ConVar g_cvIsCZ = null;

// Cached enabled states (updated after configs execute and when cvars change)
bool g_bEnableUSP = false;
bool g_bEnableM4A1 = false;
bool g_bEnableCZ = false;

float g_flLastM4A1SBuy[MAXPLAYERS + 1];
float g_flLastCZ75Buy[MAXPLAYERS + 1];

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

    g_cvIsCZ = FindConVar("isCZ");
    if (g_cvIsCZ == null)
    {
        g_cvIsCZ = CreateConVar(
            "isCZ",
            "0",
            "If 1, replace Five-SeveN/Tec-9 purchase with CZ75-Auto. If 0, do nothing.",
            FCVAR_NOTIFY,
            true, 0.0,
            true, 1.0
        );
    }

    // React to runtime changes too
    g_cvIsUSP.AddChangeHook(OnCvarChanged);
    g_cvIsM4A1.AddChangeHook(OnCvarChanged);
    g_cvIsCZ.AddChangeHook(OnCvarChanged);

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
    g_bEnableCZ   = (g_cvIsCZ != null && g_cvIsCZ.IntValue == 1);
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
    if (!IsValidClient(client) || IsFakeClient(client))
        return Plugin_Continue;

    int team = GetClientTeam(client);

    if (g_bEnableM4A1 && team == CS_TEAM_CT && StrEqual(weapon, "m4a1", false))
    {
        BuyM4A1S(client);
        return Plugin_Handled;
    }

    if (g_bEnableCZ)
    {
        bool replaceFiveSeven = (team == CS_TEAM_CT && StrEqual(weapon, "fiveseven", false));
        bool replaceTec9 = (team == CS_TEAM_T && StrEqual(weapon, "tec9", false));

        if (replaceFiveSeven || replaceTec9)
        {
            BuyCZ75(client);
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

void BuyM4A1S(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client) || !IsPlayerAlive(client))
        return;

    // Re-check cached state at execution time
    if (!g_bEnableM4A1)
        return;

    int money = GetEntProp(client, Prop_Send, "m_iAccount");
    const int M4A1S_PRICE = 2900;

    if (money < M4A1S_PRICE)
        return;

    float gameTime = GetGameTime();
    if (g_flLastM4A1SBuy[client] > 0.0 && gameTime >= g_flLastM4A1SBuy[client] && gameTime - g_flLastM4A1SBuy[client] < 0.2)
        return;

    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (weapon != -1 && IsValidEntity(weapon))
    {
        CS_DropWeapon(client, weapon, true, false);
    }

    g_flLastM4A1SBuy[client] = gameTime;
    SetEntProp(client, Prop_Send, "m_iAccount", money - M4A1S_PRICE);
    GivePlayerItem(client, "weapon_m4a1_silencer");
}

void BuyCZ75(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client) || !IsPlayerAlive(client))
        return;

    // Re-check cached state at execution time
    if (!g_bEnableCZ)
        return;

    int team = GetClientTeam(client);
    if (team != CS_TEAM_CT && team != CS_TEAM_T)
        return;

    int money = GetEntProp(client, Prop_Send, "m_iAccount");
    const int CZ75_PRICE = 500;

    if (money < CZ75_PRICE)
        return;

    float gameTime = GetGameTime();
    if (g_flLastCZ75Buy[client] > 0.0 && gameTime >= g_flLastCZ75Buy[client] && gameTime - g_flLastCZ75Buy[client] < 0.2)
        return;

    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
    if (weapon != -1 && IsValidEntity(weapon))
    {
        CS_DropWeapon(client, weapon, true, false);
    }

    g_flLastCZ75Buy[client] = gameTime;
    SetEntProp(client, Prop_Send, "m_iAccount", money - CZ75_PRICE);
    GivePlayerItem(client, "weapon_cz75a");
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
