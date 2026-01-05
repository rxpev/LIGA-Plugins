#pragma semicolon 1

#define TEAM_SPECTATOR 1
#define TEAM_ONE 2
#define TEAM_TWO 3

#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin myinfo =
{
    name = "FACEIT / LIGA Damage Prints",
    author = "Rxpev",
    description = "Shows round-end damage prints (FACEIT and League).",
    version = "1.2",
    url = "http://steamcommunity.com/id/rxpev"
};

int g_DamageDealt[MAXPLAYERS+1][MAXPLAYERS+1];
int g_DamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];
int g_HitsDealt[MAXPLAYERS+1][MAXPLAYERS+1];
int g_HitsTaken[MAXPLAYERS+1][MAXPLAYERS+1];

ConVar g_hIsFaceit = null;
ConVar g_hWarmupPause = null;

public void OnPluginStart()
{
    g_hIsFaceit = CreateConVar(
        "isFaceit",
        "1",
        "If 1: FACEIT-style (green, [FACEIT^]). If 0: LIGA-style (orange, [LIGA]).",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    g_hWarmupPause = FindConVar("mp_warmup_pausetimer");

    HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);

    ResetAll();
}

public void OnMapStart()
{
    ResetAll();
}

bool IsFaceitMode()
{
    return (g_hIsFaceit != null && g_hIsFaceit.IntValue == 1);
}

bool InWarmup()
{
    return (g_hWarmupPause != null && g_hWarmupPause.IntValue == 1);
}

// Centralized chat print that switches prefix + color based on isFaceit
void PrintModeToAll(const char[] fmt, any ...)
{
    char msg[512];
    VFormat(msg, sizeof(msg), fmt, 2);

    if (IsFaceitMode())
    {
        PrintToChatAll("\x01 \x04[FACEIT^] %s", msg);
    }
    else
    {
        PrintToChatAll("\x01 \x09[LIGA] %s", msg);
    }
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (InWarmup())
        return Plugin_Continue;

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (victim <= 0 || attacker <= 0 || victim == attacker)
        return Plugin_Continue;

    int dmg = event.GetInt("dmg_health");

    g_DamageDealt[attacker][victim] += dmg;
    g_DamageTaken[victim][attacker] += dmg;
    g_HitsDealt[attacker][victim] += 1;
    g_HitsTaken[victim][attacker] += 1;

    return Plugin_Continue;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!InWarmup())
        ShowRoundSummary();

    ResetAll();
    return Plugin_Continue;
}

void ShowRoundSummary()
{
    int scoreT = GetTeamScore(CS_TEAM_T);
    int scoreCT = GetTeamScore(CS_TEAM_CT);

    char tName[32];
    char ctName[32];
    FindConVar("mp_teamname_2").GetString(tName, sizeof(tName));
    FindConVar("mp_teamname_1").GetString(ctName, sizeof(ctName));
    PrintModeToAll("%s [%d - %d] %s", tName, scoreT, scoreCT, ctName);

    for (int attacker = 1; attacker <= MaxClients; attacker++)
    {
        if (!IsClientInGame(attacker) || IsFakeClient(attacker))
            continue;

        int attackerTeam = GetClientTeam(attacker);
        if (attackerTeam != CS_TEAM_T && attackerTeam != CS_TEAM_CT)
            continue;

        for (int victim = 1; victim <= MaxClients; victim++)
        {
            if (!IsClientInGame(victim))
                continue;

            if (victim == attacker)
                continue;

            int victimTeam = GetClientTeam(victim);
            if (victimTeam == attackerTeam)
                continue;

            int dealt = g_DamageDealt[attacker][victim];
            int taken = g_DamageTaken[attacker][victim];
            int hitsDealt = g_HitsDealt[attacker][victim];
            int hitsTaken = g_HitsTaken[attacker][victim];

            if (dealt > 100) dealt = 100;
            if (taken > 100) taken = 100;

            int hp = GetClientHealth(victim);
            if (hp < 0) hp = 0;

            if (IsFaceitMode())
            {
                PrintModeToAll(
                    "To [%d / %d] From [%d / %d] - %N (%dhp)",
                    dealt, hitsDealt,
                    taken, hitsTaken,
                    victim, hp
                );
            }
            else
            {
                PrintModeToAll(
                    "To (%d / %d) From (%d / %d) - %N (%dhp)",
                    dealt, hitsDealt,
                    taken, hitsTaken,
                    victim, hp
                );
            }
        }
    }
}

void ResetAll()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        for (int j = 1; j <= MaxClients; j++)
        {
            g_DamageDealt[i][j] = 0;
            g_DamageTaken[i][j] = 0;
            g_HitsDealt[i][j] = 0;
            g_HitsTaken[i][j] = 0;
        }
    }
}
