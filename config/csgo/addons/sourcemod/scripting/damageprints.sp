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
bool g_bMatchLive = false;
bool g_bLiveRoundActive = false;

ConVar g_hIsFaceit = null;
ConVar g_hIsDeathmatch = null;

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
    g_hIsDeathmatch = FindConVar("isDeathmatch");

    HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
    HookEvent("round_start", OnRoundStart, EventHookMode_Post);
    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
    HookEventEx("warmup_end", OnWarmupEnd, EventHookMode_Post);
    RegServerCmd("damageprints_match_start", Command_MatchStart, "Enables damageprints for the live match.");
    AddCommandListener(OnReadyCommand, "ready");
    AddCommandListener(OnReadyCommand, "sm_ready");
    AddCommandListener(OnWarmupEndCommand, "mp_warmup_end");
    AddGameLogHook(Hook_GameLog);

    g_bMatchLive = false;
    g_bLiveRoundActive = false;
    ResetAll();
}

public void OnMapStart()
{
    g_bMatchLive = false;
    g_bLiveRoundActive = false;
    ResetAll();
}

bool IsFaceitMode()
{
    return (g_hIsFaceit != null && g_hIsFaceit.IntValue == 1);
}

bool IsStandaloneDeathmatchMode()
{
    if (g_hIsDeathmatch == null)
        g_hIsDeathmatch = FindConVar("isDeathmatch");

    return (g_hIsDeathmatch != null && g_hIsDeathmatch.IntValue == 1);
}

bool ShouldTrackDamage()
{
    return !IsStandaloneDeathmatchMode() && g_bMatchLive && g_bLiveRoundActive;
}

void StartMatchDamagePrints()
{
    if (IsStandaloneDeathmatchMode())
    {
        g_bMatchLive = false;
        g_bLiveRoundActive = false;
        ResetAll();
        return;
    }

    g_bMatchLive = true;
    g_bLiveRoundActive = false;
    ResetAll();
}

// Centralized chat print that switches prefix + color based on isFaceit
void PrintModeToAll(const char[] fmt, any ...)
{
    if (IsStandaloneDeathmatchMode())
        return;

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
    if (!ShouldTrackDamage())
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

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if (StrEqual(sArgs, "!ready", false) || StrEqual(sArgs, "/ready", false))
        StartMatchDamagePrints();

    return Plugin_Continue;
}

public Action OnReadyCommand(int client, const char[] command, int argc)
{
    StartMatchDamagePrints();
    return Plugin_Continue;
}

public Action OnWarmupEndCommand(int client, const char[] command, int argc)
{
    StartMatchDamagePrints();
    return Plugin_Continue;
}

public Action Command_MatchStart(int args)
{
    StartMatchDamagePrints();
    return Plugin_Continue;
}

public Action Hook_GameLog(char[] message)
{
    if (StrContains(message, "World triggered \"Match_Start\"") != -1)
        StartMatchDamagePrints();

    return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (IsStandaloneDeathmatchMode())
    {
        g_bMatchLive = false;
        g_bLiveRoundActive = false;
        ResetAll();
        return Plugin_Continue;
    }

    if (g_bMatchLive)
        g_bLiveRoundActive = true;

    ResetAll();
    return Plugin_Continue;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (IsStandaloneDeathmatchMode())
    {
        g_bMatchLive = false;
        g_bLiveRoundActive = false;
        ResetAll();
        return Plugin_Continue;
    }

    if (!g_bLiveRoundActive)
    {
        ResetAll();
        return Plugin_Continue;
    }

    if (ShouldTrackDamage())
        ShowRoundSummary();

    ResetAll();
    g_bLiveRoundActive = false;
    return Plugin_Continue;
}

public Action OnWarmupEnd(Event event, const char[] name, bool dontBroadcast)
{
    StartMatchDamagePrints();
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
