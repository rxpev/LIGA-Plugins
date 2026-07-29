#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#define FFADE_IN 0x0001
#define FFADE_OUT 0x0002
#define FFADE_STAYOUT 0x0008
#define FFADE_PURGE 0x0010
#define FADE_UNIT 4096.0
#define SOUND_FLASH_FEVER "Player.FlashbangTinnitus"
#define SOUND_FLASH_FEVER_ALT "Player.Flashbang"
#define SOUND_FLASH_FEVER_SAMPLE "player/flashbang.wav"
#define SOUND_FLASH_FEVER_EXPLODE_SAMPLE "weapons/flashbang/flashbang_explode2.wav"
#define MAX_STORED_LAG_POSITIONS 10

enum ChaosEffect
{
    ChaosEffect_HeavyFeet = 0,
    ChaosEffect_HighUp,
    ChaosEffect_OneShotWonder,
    ChaosEffect_Overdrive,
    ChaosEffect_FlashFever,
    ChaosEffect_Medic,
    ChaosEffect_Poisoned,
    ChaosEffect_PistolOnly,
    ChaosEffect_Shaky,
    ChaosEffect_Tank,
    ChaosEffect_LeadBoots,
    ChaosEffect_IceSkates,
    ChaosEffect_Backpedal,
    ChaosEffect_BunnyFever,
    ChaosEffect_Butterfinger,
    ChaosEffect_GunGame,
    ChaosEffect_Nighttime,
    ChaosEffect_Wallhack,
    ChaosEffect_Bomber,
    ChaosEffect_Shuffler,
    ChaosEffect_Lag,
    ChaosEffect_Count
};

ConVar g_hIsChaos = null;
bool g_bChaosAppliedThisRound = false;
Handle g_hBlindTimers[MAXPLAYERS + 1];
Handle g_hPoisonTimers[MAXPLAYERS + 1];
Handle g_hButterfingerTimers[MAXPLAYERS + 1];
Handle g_hGunGameTimers[MAXPLAYERS + 1];
Handle g_hWallhackTimers[MAXPLAYERS + 1];
Handle g_hShufflerTimers[MAXPLAYERS + 1];
Handle g_hLagTimers[MAXPLAYERS + 1];
Handle g_hLagStoreTimers[MAXPLAYERS + 1];
bool g_bPoisoned[MAXPLAYERS + 1];
bool g_bPistolOnly[MAXPLAYERS + 1];
bool g_bShaky[MAXPLAYERS + 1];
bool g_bTank[MAXPLAYERS + 1];
int g_iTankWeaponRef[MAXPLAYERS + 1];
char g_szTankWeaponClass[MAXPLAYERS + 1][64];
bool g_bLeadBoots[MAXPLAYERS + 1];
bool g_bIceSkates[MAXPLAYERS + 1];
bool g_bBackpedal[MAXPLAYERS + 1];
bool g_bBunnyFever[MAXPLAYERS + 1];
bool g_bBomber[MAXPLAYERS + 1];
bool g_bNighttime[MAXPLAYERS + 1];
int g_iLagPositionCount[MAXPLAYERS + 1];
int g_iLagPositionNext[MAXPLAYERS + 1];
float g_fNextBunnyJump[MAXPLAYERS + 1];
float g_fLagPositions[MAXPLAYERS + 1][MAX_STORED_LAG_POSITIONS][3];

public Plugin myinfo =
{
    name = "LIGA Chaos",
    author = "Rxpev",
    description = "Applies random LIGA Chaos round effects.",
    version = "1.0.0",
    url = "http://steamcommunity.com/id/rxpev"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("liga_chaos");
    CreateNative("Chaos_ShouldBotsIgnoreDroppedPrimaries", Native_ShouldBotsIgnoreDroppedPrimaries);
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_hIsChaos = CreateConVar(
        "isChaos",
        "0",
        "0 = normal match flow; 1 = enable LIGA Chaos round effects.",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    HookEvent("round_start", OnRoundStart, EventHookMode_Post);
    HookEvent("round_freeze_end", OnFreezetimeEnd, EventHookMode_Post);
    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
    g_hIsChaos.AddChangeHook(OnIsChaosChanged);

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
            SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
            SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
        }
    }
}

public void OnMapStart()
{
    PrecacheSound(SOUND_FLASH_FEVER_SAMPLE, true);
    PrecacheSound(SOUND_FLASH_FEVER_EXPLODE_SAMPLE, true);
    g_bChaosAppliedThisRound = false;
    ResetAllChaosState();
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
    SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
}

public void OnClientDisconnect(int client)
{
    StopBlindTimer(client);
    StopPoisonTimer(client);
    StopButterfingerTimer(client);
    StopGunGameTimer(client);
    StopWallhackTimer(client);
    StopShufflerTimer(client);
    StopLagTimer(client);
    StopLagStoreTimer(client);
    g_bPoisoned[client] = false;
    g_bPistolOnly[client] = false;
    g_bShaky[client] = false;
    g_bTank[client] = false;
    g_iTankWeaponRef[client] = INVALID_ENT_REFERENCE;
    g_szTankWeaponClass[client][0] = '\0';
    g_bLeadBoots[client] = false;
    g_bIceSkates[client] = false;
    g_bBackpedal[client] = false;
    g_bBunnyFever[client] = false;
    g_bBomber[client] = false;
    g_bNighttime[client] = false;
    g_iLagPositionCount[client] = 0;
    g_iLagPositionNext[client] = 0;
    g_fNextBunnyJump[client] = 0.0;
    ResetPlayerSpeed(client);
    ResetPlayerFriction(client);
}

public void OnIsChaosChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!IsChaosMode())
    {
        g_bChaosAppliedThisRound = false;
        ResetAllChaosState();
    }
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bChaosAppliedThisRound = false;
    ResetAllChaosState();
    return Plugin_Continue;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bChaosAppliedThisRound = false;
    ResetAllChaosState();
    return Plugin_Continue;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (victim > 0 && victim <= MaxClients)
    {
        StopBlindTimer(victim);
        StopPoisonTimer(victim);
    }

    if (!IsChaosMode() || attacker <= 0 || attacker > MaxClients || attacker == victim)
        return Plugin_Continue;

    if (g_bPoisoned[attacker] && IsValidChaosTarget(attacker))
    {
        SetEntityHealth(attacker, 100);
    }

    return Plugin_Continue;
}

public Action OnFreezetimeEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsChaosMode() || g_bChaosAppliedThisRound)
        return Plugin_Continue;

    g_bChaosAppliedThisRound = true;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidChaosTarget(client))
            continue;

        ChaosEffect effect = RollEffectForClient(client);
        ApplyChaosEffect(client, effect);
        AnnounceChaosEffect(client, effect);
    }

    return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
    if (!IsChaosMode() || !IsValidChaosTarget(client))
        return Plugin_Continue;

    if (IsValidEntity(weapon) && g_bPistolOnly[client] && IsPrimaryWeapon(weapon))
        return Plugin_Handled;

    if (IsValidEntity(weapon) && g_bTank[client] && IsPrimaryWeapon(weapon) && !CanUseTankPrimary(client, weapon))
        return Plugin_Handled;

    if (IsValidEntity(weapon) && g_bBomber[client] && !IsAllowedBomberWeapon(weapon))
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action OnWeaponEquip(int client, int weapon)
{
    if (!IsChaosMode() || !IsValidChaosTarget(client) || !IsValidEntity(weapon))
        return Plugin_Continue;

    if (g_bTank[client] && IsPrimaryWeapon(weapon) && !CanUseTankPrimary(client, weapon))
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action OnWeaponDrop(int client, int weapon)
{
    if (ShouldBlockTankWeaponDrop(client, weapon))
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action CS_OnCSWeaponDrop(int client, int weaponIndex, bool donated)
{
    if (ShouldBlockTankWeaponDrop(client, weaponIndex))
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!IsChaosMode() || !IsValidChaosTarget(client))
        return Plugin_Continue;

    bool changed = false;

    if (g_bPistolOnly[client])
        StripPrimaryWeapon(client);

    if (g_bTank[client])
        EnforceTankWeapon(client);

    if (g_bBomber[client])
        EnforceBomber(client);

    if (g_bLeadBoots[client])
        buttons &= ~IN_JUMP;

    if (g_bBackpedal[client])
    {
        bool movingForward = (buttons & IN_FORWARD) == IN_FORWARD;
        bool back = (buttons & IN_BACK) == IN_BACK;

        if (movingForward)
            buttons &= ~IN_FORWARD;
        if (back)
            buttons &= ~IN_BACK;
        if (movingForward)
            buttons |= IN_BACK;
        if (back)
            buttons |= IN_FORWARD;

        vel[0] *= -1.0;
        changed = true;
    }

    if (g_bIceSkates[client])
        ApplyIceSkates(client);

    if (
        g_bBunnyFever[client]
        && (GetEntityFlags(client) & FL_ONGROUND) == FL_ONGROUND
        && GetGameTime() >= g_fNextBunnyJump[client]
    )
    {
        buttons |= IN_JUMP;
        g_fNextBunnyJump[client] = GetGameTime() + 2.0;
        changed = true;
    }

    if (g_bShaky[client] && (buttons & IN_ATTACK) == IN_ATTACK)
    {
        GetClientEyeAngles(client, angles);
        angles[0] = ClampFloat(angles[0] + GetRandomFloat(-1.5, 1.5), -89.0, 89.0);
        angles[1] = NormalizeYaw(angles[1] + GetRandomFloat(-2.25, 2.25));
        angles[2] = 0.0;
        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
        changed = true;
    }

    return changed ? Plugin_Changed : Plugin_Continue;
}

bool IsChaosMode()
{
    return g_hIsChaos != null && g_hIsChaos.IntValue == 1;
}

bool IsValidChaosTarget(int client)
{
    return client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && IsPlayerAlive(client)
        && GetClientTeam(client) >= 2;
}

public int Native_ShouldBotsIgnoreDroppedPrimaries(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return ShouldBotsIgnoreDroppedPrimaries(client);
}

bool ShouldBotsIgnoreDroppedPrimaries(int client)
{
    return IsChaosMode()
        && IsValidChaosTarget(client)
        && (g_bPistolOnly[client] || g_bTank[client]);
}

bool ShouldBlockTankWeaponDrop(int client, int weapon)
{
    return IsChaosMode()
        && IsValidChaosTarget(client)
        && g_bTank[client]
        && IsValidEntity(weapon)
        && IsTankWeaponForClient(client, weapon);
}

bool CanUseTankPrimary(int client, int weapon)
{
    if (!IsValidEntity(weapon))
        return false;

    if (IsTankWeaponForClient(client, weapon))
        return true;

    int assignedWeapon = EntRefToEntIndex(g_iTankWeaponRef[client]);
    return assignedWeapon == INVALID_ENT_REFERENCE && IsTankWeapon(weapon);
}

bool IsTankWeaponForClient(int client, int weapon)
{
    if (!IsValidEntity(weapon))
        return false;

    int assignedWeapon = EntRefToEntIndex(g_iTankWeaponRef[client]);
    if (assignedWeapon != INVALID_ENT_REFERENCE && assignedWeapon == weapon)
        return true;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    return g_szTankWeaponClass[client][0] != '\0'
        && StrEqual(classname, g_szTankWeaponClass[client]);
}

ChaosEffect RollEffectForClient(int client)
{
    int effects[view_as<int>(ChaosEffect_Count)];
    int weights[view_as<int>(ChaosEffect_Count)];
    int count = 0;
    int totalWeight = 0;

    for (int effect = 0; effect < view_as<int>(ChaosEffect_Count); effect++)
    {
        ChaosEffect chaosEffect = view_as<ChaosEffect>(effect);
        int weight = GetEffectWeight(chaosEffect);

        if (weight <= 0 || !CanApplyEffectToClient(client, chaosEffect))
            continue;

        effects[count] = effect;
        weights[count] = weight;
        totalWeight += weight;
        count++;
    }

    if (count <= 0 || totalWeight <= 0)
        return ChaosEffect_HeavyFeet;

    int roll = GetRandomInt(1, totalWeight);
    int runningWeight = 0;

    for (int index = 0; index < count; index++)
    {
        runningWeight += weights[index];
        if (roll <= runningWeight)
            return view_as<ChaosEffect>(effects[index]);
    }

    return view_as<ChaosEffect>(effects[count - 1]);
}

int GetEffectWeight(ChaosEffect effect)
{
    switch (effect)
    {
        case ChaosEffect_HeavyFeet,
             ChaosEffect_HighUp,
             ChaosEffect_OneShotWonder,
             ChaosEffect_Overdrive,
             ChaosEffect_FlashFever,
             ChaosEffect_Medic,
             ChaosEffect_Poisoned,
             ChaosEffect_PistolOnly,
             ChaosEffect_Shaky,
             ChaosEffect_LeadBoots,
             ChaosEffect_Tank,
             ChaosEffect_IceSkates,
             ChaosEffect_Backpedal,
             ChaosEffect_BunnyFever,
             ChaosEffect_Butterfinger,
             ChaosEffect_GunGame,
             ChaosEffect_Wallhack,
             ChaosEffect_Bomber,
             ChaosEffect_Shuffler,
             ChaosEffect_Lag,
             ChaosEffect_Nighttime:
        {
            return 1;
        }
    }

    return 0;
}

bool CanApplyEffectToClient(int client, ChaosEffect effect)
{
    switch (effect)
    {
        case ChaosEffect_HighUp,
             ChaosEffect_FlashFever,
             ChaosEffect_Medic,
             ChaosEffect_LeadBoots,
             ChaosEffect_Backpedal,
             ChaosEffect_BunnyFever,
             ChaosEffect_Butterfinger,
             ChaosEffect_Nighttime,
             ChaosEffect_Wallhack,
             ChaosEffect_Bomber:
        {
            return !IsFakeClient(client);
        }
    }

    return true;
}

void ApplyChaosEffect(int client, ChaosEffect effect)
{
    switch (effect)
    {
        case ChaosEffect_HeavyFeet:
        {
            SetPlayerSpeed(client, 0.5);
        }
        case ChaosEffect_HighUp:
        {
            GivePlayerItem(client, "weapon_bumpmine");
            GivePlayerItem(client, "weapon_bumpmine");
        }
        case ChaosEffect_OneShotWonder:
        {
            SetEntityHealth(client, 1);
        }
        case ChaosEffect_Overdrive:
        {
            SetPlayerSpeed(client, 2.0);
        }
        case ChaosEffect_FlashFever:
        {
            ScheduleNextBlind(client);
        }
        case ChaosEffect_Medic:
        {
            GivePlayerItem(client, "weapon_healthshot");
        }
        case ChaosEffect_Poisoned:
        {
            g_bPoisoned[client] = true;
            SchedulePoison(client);
        }
        case ChaosEffect_PistolOnly:
        {
            g_bPistolOnly[client] = true;
            ReplaceWithRandomPistol(client);
        }
        case ChaosEffect_Shaky:
        {
            g_bShaky[client] = true;
        }
        case ChaosEffect_Tank:
        {
            g_bTank[client] = true;
            EnableHeavyAssaultSuit();
            ReplaceWithRandomTankWeapon(client);
            GivePlayerItem(client, "item_heavyassaultsuit");
            if (HasEntProp(client, Prop_Send, "m_bHasHeavyArmor"))
                SetEntProp(client, Prop_Send, "m_bHasHeavyArmor", 1);
            SetEntProp(client, Prop_Send, "m_ArmorValue", 200);
        }
        case ChaosEffect_LeadBoots:
        {
            g_bLeadBoots[client] = true;
        }
        case ChaosEffect_IceSkates:
        {
            g_bIceSkates[client] = true;
            SetPlayerFriction(client, 0.15);
        }
        case ChaosEffect_Backpedal:
        {
            g_bBackpedal[client] = true;
        }
        case ChaosEffect_BunnyFever:
        {
            g_bBunnyFever[client] = true;
            g_fNextBunnyJump[client] = GetGameTime() + 2.0;
        }
        case ChaosEffect_Butterfinger:
        {
            ScheduleButterfinger(client);
        }
        case ChaosEffect_GunGame:
        {
            ReplaceWithRandomPrimary(client);
            ScheduleGunGame(client);
        }
        case ChaosEffect_Nighttime:
        {
            g_bNighttime[client] = true;
            SendNighttimeFade(client);
        }
        case ChaosEffect_Wallhack:
        {
            ScheduleWallhack(client);
        }
        case ChaosEffect_Bomber:
        {
            g_bBomber[client] = true;
            EnforceBomber(client);
        }
        case ChaosEffect_Shuffler:
        {
            ScheduleShuffler(client);
        }
        case ChaosEffect_Lag:
        {
            StartLagEffect(client);
        }
    }
}

void AnnounceChaosEffect(int client, ChaosEffect effect)
{
    char effectName[32];
    char effectDescription[128];
    GetEffectName(effect, effectName, sizeof(effectName));
    GetEffectDescription(effect, effectDescription, sizeof(effectDescription));

    PrintToChat(client, "\x01 \x09[LIGA] Applied \x02\"%s\"", effectName);
    PrintHintText(client, "%s", effectDescription);
}

void GetEffectName(ChaosEffect effect, char[] buffer, int maxlen)
{
    switch (effect)
    {
        case ChaosEffect_HeavyFeet:
        {
            strcopy(buffer, maxlen, "Heavy Feet");
        }
        case ChaosEffect_HighUp:
        {
            strcopy(buffer, maxlen, "Bumpy Ride");
        }
        case ChaosEffect_OneShotWonder:
        {
            strcopy(buffer, maxlen, "One-Shot Wonder");
        }
        case ChaosEffect_Overdrive:
        {
            strcopy(buffer, maxlen, "Overdrive");
        }
        case ChaosEffect_FlashFever:
        {
            strcopy(buffer, maxlen, "Flash Fever");
        }
        case ChaosEffect_Medic:
        {
            strcopy(buffer, maxlen, "Medic");
        }
        case ChaosEffect_Poisoned:
        {
            strcopy(buffer, maxlen, "Poisoned");
        }
        case ChaosEffect_PistolOnly:
        {
            strcopy(buffer, maxlen, "Pistol Only");
        }
        case ChaosEffect_Shaky:
        {
            strcopy(buffer, maxlen, "Shaky");
        }
        case ChaosEffect_Tank:
        {
            strcopy(buffer, maxlen, "Tank");
        }
        case ChaosEffect_LeadBoots:
        {
            strcopy(buffer, maxlen, "Lead Boots");
        }
        case ChaosEffect_IceSkates:
        {
            strcopy(buffer, maxlen, "Ice Skates");
        }
        case ChaosEffect_Backpedal:
        {
            strcopy(buffer, maxlen, "Backpedal");
        }
        case ChaosEffect_BunnyFever:
        {
            strcopy(buffer, maxlen, "Bunny Fever");
        }
        case ChaosEffect_Butterfinger:
        {
            strcopy(buffer, maxlen, "Butterfinger");
        }
        case ChaosEffect_GunGame:
        {
            strcopy(buffer, maxlen, "Gun Game");
        }
        case ChaosEffect_Nighttime:
        {
            strcopy(buffer, maxlen, "Lights Out");
        }
        case ChaosEffect_Wallhack:
        {
            strcopy(buffer, maxlen, "Radar Hack");
        }
        case ChaosEffect_Bomber:
        {
            strcopy(buffer, maxlen, "Bomber");
        }
        case ChaosEffect_Shuffler:
        {
            strcopy(buffer, maxlen, "Shuffler");
        }
        case ChaosEffect_Lag:
        {
            strcopy(buffer, maxlen, "Lag");
        }
    }
}

void GetEffectDescription(ChaosEffect effect, char[] buffer, int maxlen)
{
    switch (effect)
    {
        case ChaosEffect_HeavyFeet:
        {
            strcopy(buffer, maxlen, "Movement speed is halved.");
        }
        case ChaosEffect_HighUp:
        {
            strcopy(buffer, maxlen, "Received bumpmines.");
        }
        case ChaosEffect_OneShotWonder:
        {
            strcopy(buffer, maxlen, "Only 1 HP.");
        }
        case ChaosEffect_Overdrive:
        {
            strcopy(buffer, maxlen, "Movement speed is doubled.");
        }
        case ChaosEffect_FlashFever:
        {
            strcopy(buffer, maxlen, "Flash effect is applied randomly.");
        }
        case ChaosEffect_Medic:
        {
            strcopy(buffer, maxlen, "Received a healthshot.");
        }
        case ChaosEffect_Poisoned:
        {
            strcopy(buffer, maxlen, "HP is lost over time. Kills replenish health.");
        }
        case ChaosEffect_PistolOnly:
        {
            strcopy(buffer, maxlen, "Primary weapons are removed and blocked.");
        }
        case ChaosEffect_Shaky:
        {
            strcopy(buffer, maxlen, "Aim shake while shooting.");
        }
        case ChaosEffect_Tank:
        {
            strcopy(buffer, maxlen, "Received heavy assault armor.");
        }
        case ChaosEffect_LeadBoots:
        {
            strcopy(buffer, maxlen, "Disabled jumping.");
        }
        case ChaosEffect_IceSkates:
        {
            strcopy(buffer, maxlen, "Ground friction is reduced.");
        }
        case ChaosEffect_Backpedal:
        {
            strcopy(buffer, maxlen, "Forward and backward movement are swapped.");
        }
        case ChaosEffect_BunnyFever:
        {
            strcopy(buffer, maxlen, "Jump every 2 seconds.");
        }
        case ChaosEffect_Butterfinger:
        {
            strcopy(buffer, maxlen, "Weapons are dropped randomly.");
        }
        case ChaosEffect_GunGame:
        {
            strcopy(buffer, maxlen, "Random weapons every 10 seconds.");
        }
        case ChaosEffect_Nighttime:
        {
            strcopy(buffer, maxlen, "View is heavily darkened.");
        }
        case ChaosEffect_Wallhack:
        {
            strcopy(buffer, maxlen, "Enemies are marked on radar.");
        }
        case ChaosEffect_Bomber:
        {
            strcopy(buffer, maxlen, "Unlimited HE grenades only.");
        }
        case ChaosEffect_Shuffler:
        {
            strcopy(buffer, maxlen, "Positions with enemies are swapped randomly.");
        }
        case ChaosEffect_Lag:
        {
            strcopy(buffer, maxlen, "Randomly teleport to a previous position.");
        }
    }
}

void SetPlayerSpeed(int client, float speed)
{
    if (!IsValidChaosTarget(client))
        return;

    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", speed);
}

void ResetPlayerSpeed(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return;

    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
}

void SetPlayerFriction(int client, float friction)
{
    if (!IsValidChaosTarget(client))
        return;

    if (HasEntProp(client, Prop_Data, "m_flFriction"))
        SetEntPropFloat(client, Prop_Data, "m_flFriction", friction);

    if (HasEntProp(client, Prop_Send, "m_flFriction"))
        SetEntPropFloat(client, Prop_Send, "m_flFriction", friction);
}

void ResetPlayerFriction(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return;

    if (HasEntProp(client, Prop_Data, "m_flFriction"))
        SetEntPropFloat(client, Prop_Data, "m_flFriction", 1.0);

    if (HasEntProp(client, Prop_Send, "m_flFriction"))
        SetEntPropFloat(client, Prop_Send, "m_flFriction", 1.0);
}

void EnableHeavyAssaultSuit()
{
    ConVar heavySuitCvar = FindConVar("mp_weapons_allow_heavyassaultsuit");
    if (heavySuitCvar != null && heavySuitCvar.IntValue != 1)
        heavySuitCvar.SetInt(1);
}

void RemoveHeavyAssaultSuit(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return;

    if (HasEntProp(client, Prop_Send, "m_bHasHeavyArmor"))
        SetEntProp(client, Prop_Send, "m_bHasHeavyArmor", 0);
}

void ApplyIceSkates(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    SetPlayerFriction(client, 0.03);

    if ((GetEntityFlags(client) & FL_ONGROUND) != FL_ONGROUND)
        return;

    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

    velocity[0] *= 1.035;
    velocity[1] *= 1.035;

    float horizontalSpeed = SquareRoot((velocity[0] * velocity[0]) + (velocity[1] * velocity[1]));
    if (horizontalSpeed > 450.0)
    {
        float scale = 450.0 / horizontalSpeed;
        velocity[0] *= scale;
        velocity[1] *= scale;
    }

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
}

void ResetAllPlayerSpeeds()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        ResetPlayerSpeed(client);
    }
}

void ScheduleNextBlind(int client)
{
    if (!IsValidChaosTarget(client) || IsFakeClient(client))
        return;

    StopBlindTimer(client);

    float delay = GetRandomFloat(5.0, 20.0);
    g_hBlindTimers[client] = CreateTimer(delay, Timer_BlindClient, GetClientUserId(client));
}

public Action Timer_BlindClient(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients)
        return Plugin_Stop;

    g_hBlindTimers[client] = null;

    if (!IsChaosMode() || !IsValidChaosTarget(client) || IsFakeClient(client))
        return Plugin_Stop;

    float duration = GetRandomFloat(2.0, 3.0);
    SendBlindFade(client, duration);
    PlayFlashFeverSound(client);

    ScheduleNextBlind(client);
    return Plugin_Stop;
}

void PlayFlashFeverSound(int client)
{
    EmitGameSoundToClient(client, SOUND_FLASH_FEVER);
    EmitGameSoundToClient(client, SOUND_FLASH_FEVER_ALT);
    EmitSoundToClient(client, SOUND_FLASH_FEVER_SAMPLE);
    EmitSoundToClient(client, SOUND_FLASH_FEVER_EXPLODE_SAMPLE);
    ClientCommand(client, "playgamesound %s", SOUND_FLASH_FEVER);
    ClientCommand(client, "playgamesound %s", SOUND_FLASH_FEVER_ALT);
    ClientCommand(client, "playvol %s 1.0", SOUND_FLASH_FEVER_SAMPLE);
    ClientCommand(client, "playvol %s 0.55", SOUND_FLASH_FEVER_EXPLODE_SAMPLE);
}

void StopBlindTimer(int client)
{
    if (client <= 0 || client > MaxClients || g_hBlindTimers[client] == null)
        return;

    KillTimer(g_hBlindTimers[client]);
    g_hBlindTimers[client] = null;
}

void StopAllBlindTimers()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        StopBlindTimer(client);
    }
}

void SchedulePoison(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    StopPoisonTimer(client);
    g_hPoisonTimers[client] = CreateTimer(0.5, Timer_PoisonClient, GetClientUserId(client), TIMER_REPEAT);
}

public Action Timer_PoisonClient(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients)
        return Plugin_Stop;

    if (g_hPoisonTimers[client] == timer && (!IsChaosMode() || !g_bPoisoned[client] || !IsValidChaosTarget(client)))
    {
        g_hPoisonTimers[client] = null;
        return Plugin_Stop;
    }

    int health = GetClientHealth(client);
    if (health <= 1)
    {
        g_hPoisonTimers[client] = null;
        ForcePlayerSuicide(client);
        return Plugin_Stop;
    }

    SetEntityHealth(client, health - 1);
    return Plugin_Continue;
}

void StopPoisonTimer(int client)
{
    if (client <= 0 || client > MaxClients || g_hPoisonTimers[client] == null)
        return;

    KillTimer(g_hPoisonTimers[client]);
    g_hPoisonTimers[client] = null;
}

void StopAllPoisonTimers()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        StopPoisonTimer(client);
    }
}

void ScheduleButterfinger(int client)
{
    if (!IsValidChaosTarget(client) || IsFakeClient(client))
        return;

    StopButterfingerTimer(client);
    g_hButterfingerTimers[client] = CreateTimer(GetRandomFloat(15.0, 25.0), Timer_Butterfinger, GetClientUserId(client));
}

public Action Timer_Butterfinger(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients)
        return Plugin_Stop;

    g_hButterfingerTimers[client] = null;

    if (!IsChaosMode() || !IsValidChaosTarget(client) || IsFakeClient(client))
        return Plugin_Stop;

    DropAllWeapons(client);
    ScheduleButterfinger(client);
    return Plugin_Stop;
}

void StopButterfingerTimer(int client)
{
    if (client <= 0 || client > MaxClients || g_hButterfingerTimers[client] == null)
        return;

    KillTimer(g_hButterfingerTimers[client]);
    g_hButterfingerTimers[client] = null;
}

void StopAllButterfingerTimers()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        StopButterfingerTimer(client);
    }
}

void ScheduleGunGame(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    StopGunGameTimer(client);
    g_hGunGameTimers[client] = CreateTimer(10.0, Timer_GunGame, GetClientUserId(client), TIMER_REPEAT);
}

public Action Timer_GunGame(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients)
        return Plugin_Stop;

    if (g_hGunGameTimers[client] == timer && (!IsChaosMode() || !IsValidChaosTarget(client)))
    {
        g_hGunGameTimers[client] = null;
        return Plugin_Stop;
    }

    ReplaceWithRandomPrimary(client);
    return Plugin_Continue;
}

void StopGunGameTimer(int client)
{
    if (client <= 0 || client > MaxClients || g_hGunGameTimers[client] == null)
        return;

    KillTimer(g_hGunGameTimers[client]);
    g_hGunGameTimers[client] = null;
}

void StopAllGunGameTimers()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        StopGunGameTimer(client);
    }
}

void ScheduleWallhack(int client)
{
    if (!IsValidChaosTarget(client) || IsFakeClient(client))
        return;

    StopWallhackTimer(client);
    g_hWallhackTimers[client] = CreateTimer(0.5, Timer_Wallhack, GetClientUserId(client), TIMER_REPEAT);
}

public Action Timer_Wallhack(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients)
        return Plugin_Stop;

    if (g_hWallhackTimers[client] == timer && (!IsChaosMode() || !IsValidChaosTarget(client) || IsFakeClient(client)))
    {
        g_hWallhackTimers[client] = null;
        return Plugin_Stop;
    }

    MarkEnemiesSpotted(client);
    return Plugin_Continue;
}

void StopWallhackTimer(int client)
{
    if (client <= 0 || client > MaxClients || g_hWallhackTimers[client] == null)
        return;

    KillTimer(g_hWallhackTimers[client]);
    g_hWallhackTimers[client] = null;
}

void StopAllWallhackTimers()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        StopWallhackTimer(client);
    }
}

void ScheduleShuffler(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    StopShufflerTimer(client);
    g_hShufflerTimers[client] = CreateTimer(30.0, Timer_Shuffler, GetClientUserId(client), TIMER_REPEAT);
}

public Action Timer_Shuffler(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients)
        return Plugin_Stop;

    if (g_hShufflerTimers[client] == timer && (!IsChaosMode() || !IsValidChaosTarget(client)))
    {
        g_hShufflerTimers[client] = null;
        return Plugin_Stop;
    }

    SwapWithRandomEnemy(client);
    return Plugin_Continue;
}

void StopShufflerTimer(int client)
{
    if (client <= 0 || client > MaxClients || g_hShufflerTimers[client] == null)
        return;

    KillTimer(g_hShufflerTimers[client]);
    g_hShufflerTimers[client] = null;
}

void StopAllShufflerTimers()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        StopShufflerTimer(client);
    }
}

void StartLagEffect(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    StopLagTimer(client);
    StopLagStoreTimer(client);
    g_iLagPositionCount[client] = 0;
    g_iLagPositionNext[client] = 0;
    StoreLagPosition(client);
    g_hLagStoreTimers[client] = CreateTimer(0.5, Timer_StoreLagPosition, GetClientUserId(client), TIMER_REPEAT);
    g_hLagTimers[client] = CreateTimer(GetRandomFloat(5.0, 10.0), Timer_LagTeleport, GetClientUserId(client));
}

public Action Timer_StoreLagPosition(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients)
        return Plugin_Stop;

    if (g_hLagStoreTimers[client] == timer && (!IsChaosMode() || !IsValidChaosTarget(client)))
    {
        g_hLagStoreTimers[client] = null;
        return Plugin_Stop;
    }

    StoreLagPosition(client);
    return Plugin_Continue;
}

public Action Timer_LagTeleport(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients)
        return Plugin_Stop;

    g_hLagTimers[client] = null;

    if (!IsChaosMode() || !IsValidChaosTarget(client))
        return Plugin_Stop;

    TeleportToLagPosition(client);
    g_hLagTimers[client] = CreateTimer(GetRandomFloat(5.0, 10.0), Timer_LagTeleport, GetClientUserId(client));
    return Plugin_Stop;
}

void StopLagTimer(int client)
{
    if (client <= 0 || client > MaxClients || g_hLagTimers[client] == null)
        return;

    KillTimer(g_hLagTimers[client]);
    g_hLagTimers[client] = null;
}

void StopLagStoreTimer(int client)
{
    if (client <= 0 || client > MaxClients || g_hLagStoreTimers[client] == null)
        return;

    KillTimer(g_hLagStoreTimers[client]);
    g_hLagStoreTimers[client] = null;
}

void StopAllLagTimers()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        StopLagTimer(client);
        StopLagStoreTimer(client);
    }
}

int GetRandomLivingEnemy(int client)
{
    int enemies[MAXPLAYERS + 1];
    int count = 0;
    int team = GetClientTeam(client);

    for (int target = 1; target <= MaxClients; target++)
    {
        if (!IsValidChaosTarget(target) || GetClientTeam(target) == team)
            continue;

        enemies[count] = target;
        count++;
    }

    if (count <= 0)
        return 0;

    return enemies[GetRandomInt(0, count - 1)];
}

void DropAllWeapons(int client)
{
    for (int slot = 0; slot <= 5; slot++)
    {
        if (slot == CS_SLOT_KNIFE)
            continue;

        int weapon = GetPlayerWeaponSlot(client, slot);
        while (weapon != -1 && IsValidEntity(weapon))
        {
            CS_DropWeapon(client, weapon, true, true);
            weapon = GetPlayerWeaponSlot(client, slot);
        }
    }
}

void StripWeaponSlot(int client, int slot)
{
    int weapon = GetPlayerWeaponSlot(client, slot);
    while (weapon != -1 && IsValidEntity(weapon))
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
        weapon = GetPlayerWeaponSlot(client, slot);
    }
}

void StripNonHeWeapons(int client)
{
    StripWeaponSlot(client, CS_SLOT_PRIMARY);
    StripWeaponSlot(client, CS_SLOT_SECONDARY);
    StripWeaponSlot(client, CS_SLOT_C4);

    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE);
    while (weapon != -1 && IsValidEntity(weapon) && !IsHeGrenade(weapon))
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
        weapon = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE);
    }
}

void EnforceBomber(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    StripNonHeWeapons(client);

    if (!HasHeGrenade(client))
        GivePlayerItem(client, "weapon_hegrenade");
}

bool HasHeGrenade(int client)
{
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "weapon_hegrenade")) != -1)
    {
        if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client)
            return true;
    }

    return false;
}

bool IsHeGrenade(int weapon)
{
    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));
    return StrEqual(classname, "weapon_hegrenade");
}

bool IsKnifeWeapon(int weapon)
{
    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));
    return StrContains(classname, "weapon_knife", false) == 0 || StrEqual(classname, "weapon_bayonet");
}

bool IsAllowedBomberWeapon(int weapon)
{
    return IsHeGrenade(weapon) || IsKnifeWeapon(weapon);
}

void ReplaceWithRandomPistol(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    static char pistols[][] = {
        "weapon_deagle",
        "weapon_tec9",
        "weapon_fiveseven",
        "weapon_p250",
        "weapon_cz75a",
        "weapon_revolver",
        "weapon_elite"
    };

    StripWeaponSlot(client, CS_SLOT_PRIMARY);
    StripWeaponSlot(client, CS_SLOT_SECONDARY);
    GivePlayerItem(client, pistols[GetRandomInt(0, sizeof(pistols) - 1)]);
}

void ReplaceWithRandomTankWeapon(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    static char weapons[][] = {
        "weapon_mp9",
        "weapon_mp7",
        "weapon_mac10",
        "weapon_bizon",
        "weapon_p90",
        "weapon_mp5sd",
        "weapon_ump45",
        "weapon_nova",
        "weapon_xm1014",
        "weapon_sawedoff",
        "weapon_mag7"
    };

    int index = GetRandomInt(0, sizeof(weapons) - 1);
    strcopy(g_szTankWeaponClass[client], sizeof(g_szTankWeaponClass[]), weapons[index]);

    StripPrimaryWeapon(client);
    int weapon = GivePlayerItem(client, g_szTankWeaponClass[client]);
    StoreTankWeapon(client, weapon);
}

void StoreTankWeapon(int client, int weapon)
{
    if (IsValidEntity(weapon))
    {
        g_iTankWeaponRef[client] = EntIndexToEntRef(weapon);
        GetEntityClassname(weapon, g_szTankWeaponClass[client], sizeof(g_szTankWeaponClass[]));
    }
    else
    {
        g_iTankWeaponRef[client] = INVALID_ENT_REFERENCE;
    }
}

void EnforceTankWeapon(int client)
{
    if (!IsValidChaosTarget(client) || !g_bTank[client])
        return;

    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (IsValidEntity(primary) && IsTankWeaponForClient(client, primary))
    {
        StoreTankWeapon(client, primary);
        return;
    }

    if (IsValidEntity(primary))
        StripPrimaryWeapon(client);

    if (g_szTankWeaponClass[client][0] == '\0')
    {
        ReplaceWithRandomTankWeapon(client);
        return;
    }

    int weapon = GivePlayerItem(client, g_szTankWeaponClass[client]);
    StoreTankWeapon(client, weapon);
}

bool IsTankWeapon(int weapon)
{
    if (!IsValidEntity(weapon))
        return false;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));
    return IsTankWeaponClassname(classname);
}

bool IsTankWeaponClassname(const char[] classname)
{
    return StrEqual(classname, "weapon_mp9")
        || StrEqual(classname, "weapon_mp7")
        || StrEqual(classname, "weapon_mac10")
        || StrEqual(classname, "weapon_bizon")
        || StrEqual(classname, "weapon_p90")
        || StrEqual(classname, "weapon_mp5sd")
        || StrEqual(classname, "weapon_ump45")
        || StrEqual(classname, "weapon_nova")
        || StrEqual(classname, "weapon_xm1014")
        || StrEqual(classname, "weapon_sawedoff")
        || StrEqual(classname, "weapon_mag7");
}

void ReplaceWithRandomPrimary(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    static char primaries[][] = {
        "weapon_ak47",
        "weapon_aug",
        "weapon_awp",
        "weapon_famas",
        "weapon_galilar",
        "weapon_m4a1",
        "weapon_m4a1_silencer",
        "weapon_mac10",
        "weapon_mp9",
        "weapon_p90",
        "weapon_sg556",
        "weapon_ssg08",
        "weapon_ump45",
        "weapon_xm1014"
    };

    StripPrimaryWeapon(client);
    GivePlayerItem(client, primaries[GetRandomInt(0, sizeof(primaries) - 1)]);
}

void MarkEnemiesSpotted(int client)
{
    int team = GetClientTeam(client);
    int mask = 1 << (client - 1);

    for (int target = 1; target <= MaxClients; target++)
    {
        if (!IsValidChaosTarget(target) || GetClientTeam(target) == team)
            continue;

        SetEntProp(target, Prop_Send, "m_bSpotted", 1);
        SetEntProp(target, Prop_Send, "m_bSpottedByMask", mask, 4, 0);
    }
}

void SwapWithRandomEnemy(int client)
{
    int enemy = GetRandomLivingEnemy(client);
    if (enemy <= 0)
        return;

    float clientOrigin[3];
    float enemyOrigin[3];
    float clientAngles[3];
    float enemyAngles[3];
    float zeroVelocity[3] = {0.0, 0.0, 0.0};

    GetClientAbsOrigin(client, clientOrigin);
    GetClientAbsOrigin(enemy, enemyOrigin);
    GetClientEyeAngles(client, clientAngles);
    GetClientEyeAngles(enemy, enemyAngles);

    clientOrigin[2] += 8.0;
    enemyOrigin[2] += 8.0;
    TeleportEntity(enemy, clientOrigin, enemyAngles, zeroVelocity);
    TeleportEntity(client, enemyOrigin, clientAngles, zeroVelocity);
}

void StoreLagPosition(int client)
{
    if (!IsValidChaosTarget(client))
        return;

    GetClientAbsOrigin(client, g_fLagPositions[client][g_iLagPositionNext[client]]);
    g_iLagPositionNext[client] = (g_iLagPositionNext[client] + 1) % MAX_STORED_LAG_POSITIONS;

    if (g_iLagPositionCount[client] < MAX_STORED_LAG_POSITIONS)
        g_iLagPositionCount[client]++;
}

void TeleportToLagPosition(int client)
{
    if (g_iLagPositionCount[client] <= 0)
        return;

    int index = GetRandomInt(0, g_iLagPositionCount[client] - 1);
    float angles[3];
    float zeroVelocity[3] = {0.0, 0.0, 0.0};

    GetClientEyeAngles(client, angles);
    TeleportEntity(client, g_fLagPositions[client][index], angles, zeroVelocity);
}

void SendNighttimeFade(int client)
{
    Handle message = StartMessageOne("Fade", client, USERMSG_RELIABLE);
    if (message == INVALID_HANDLE)
        return;

    int duration = RoundToNearest(0.5 * FADE_UNIT);
    int holdTime = 0;
    int flags = FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE;

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
    {
        int color[4];
        color[0] = 0;
        color[1] = 0;
        color[2] = 0;
        color[3] = 245;

        PbSetInt(message, "duration", duration);
        PbSetInt(message, "hold_time", holdTime);
        PbSetInt(message, "flags", flags);
        PbSetColor(message, "clr", color);
    }
    else
    {
        BfWriteShort(message, duration);
        BfWriteShort(message, holdTime);
        BfWriteShort(message, flags);
        BfWriteByte(message, 0);
        BfWriteByte(message, 0);
        BfWriteByte(message, 0);
        BfWriteByte(message, 245);
    }

    EndMessage();
}

void StripPrimaryWeapon(int client)
{
    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

    while (weapon != -1 && IsValidEntity(weapon))
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
        weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    }
}

bool IsPrimaryWeapon(int weapon)
{
    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    return StrEqual(classname, "weapon_ak47")
        || StrEqual(classname, "weapon_aug")
        || StrEqual(classname, "weapon_awp")
        || StrEqual(classname, "weapon_bizon")
        || StrEqual(classname, "weapon_famas")
        || StrEqual(classname, "weapon_g3sg1")
        || StrEqual(classname, "weapon_galilar")
        || StrEqual(classname, "weapon_m249")
        || StrEqual(classname, "weapon_m4a1")
        || StrEqual(classname, "weapon_m4a1_silencer")
        || StrEqual(classname, "weapon_mac10")
        || StrEqual(classname, "weapon_mag7")
        || StrEqual(classname, "weapon_mp5sd")
        || StrEqual(classname, "weapon_mp7")
        || StrEqual(classname, "weapon_mp9")
        || StrEqual(classname, "weapon_negev")
        || StrEqual(classname, "weapon_nova")
        || StrEqual(classname, "weapon_p90")
        || StrEqual(classname, "weapon_sawedoff")
        || StrEqual(classname, "weapon_scar20")
        || StrEqual(classname, "weapon_sg556")
        || StrEqual(classname, "weapon_ssg08")
        || StrEqual(classname, "weapon_ump45")
        || StrEqual(classname, "weapon_xm1014");
}

void SendBlindFade(int client, float seconds)
{
    Handle message = StartMessageOne("Fade", client, USERMSG_RELIABLE);
    if (message == INVALID_HANDLE)
        return;

    int duration = RoundToNearest(0.01 * FADE_UNIT);
    int holdTime = RoundToNearest(seconds * FADE_UNIT);
    int flags = FFADE_OUT | FFADE_PURGE;

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
    {
        int color[4];
        color[0] = 255;
        color[1] = 255;
        color[2] = 255;
        color[3] = 255;

        PbSetInt(message, "duration", duration);
        PbSetInt(message, "hold_time", holdTime);
        PbSetInt(message, "flags", flags);
        PbSetColor(message, "clr", color);
    }
    else
    {
        BfWriteShort(message, duration);
        BfWriteShort(message, holdTime);
        BfWriteShort(message, flags);
        BfWriteByte(message, 255);
        BfWriteByte(message, 255);
        BfWriteByte(message, 255);
        BfWriteByte(message, 255);
    }

    EndMessage();
    CreateTimer(seconds, Timer_ClearBlindFade, GetClientUserId(client));
}

public Action Timer_ClearBlindFade(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return Plugin_Stop;

    SendClearBlindFade(client);
    return Plugin_Stop;
}

void SendClearBlindFade(int client)
{
    Handle message = StartMessageOne("Fade", client, USERMSG_RELIABLE);
    if (message == INVALID_HANDLE)
        return;

    int duration = RoundToNearest(0.15 * FADE_UNIT);
    int holdTime = 0;
    int flags = FFADE_IN | FFADE_PURGE;

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
    {
        int color[4];
        color[0] = 255;
        color[1] = 255;
        color[2] = 255;
        color[3] = 255;

        PbSetInt(message, "duration", duration);
        PbSetInt(message, "hold_time", holdTime);
        PbSetInt(message, "flags", flags);
        PbSetColor(message, "clr", color);
    }
    else
    {
        BfWriteShort(message, duration);
        BfWriteShort(message, holdTime);
        BfWriteShort(message, flags);
        BfWriteByte(message, 255);
        BfWriteByte(message, 255);
        BfWriteByte(message, 255);
        BfWriteByte(message, 255);
    }

    EndMessage();
}

void ResetAllChaosState()
{
    StopAllBlindTimers();
    StopAllPoisonTimers();
    StopAllButterfingerTimers();
    StopAllGunGameTimers();
    StopAllWallhackTimers();
    StopAllShufflerTimers();
    StopAllLagTimers();
    ResetAllPlayerSpeeds();

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            ResetPlayerFriction(client);
            RemoveHeavyAssaultSuit(client);
            if (g_bNighttime[client])
                SendClearBlindFade(client);
        }

        g_bPoisoned[client] = false;
        g_bPistolOnly[client] = false;
        g_bShaky[client] = false;
        g_bTank[client] = false;
        g_iTankWeaponRef[client] = INVALID_ENT_REFERENCE;
        g_szTankWeaponClass[client][0] = '\0';
        g_bLeadBoots[client] = false;
        g_bIceSkates[client] = false;
        g_bBackpedal[client] = false;
        g_bBunnyFever[client] = false;
        g_bBomber[client] = false;
        g_bNighttime[client] = false;
        g_iLagPositionCount[client] = 0;
        g_iLagPositionNext[client] = 0;
        g_fNextBunnyJump[client] = 0.0;
    }
}

float ClampFloat(float value, float min, float max)
{
    if (value < min)
        return min;

    if (value > max)
        return max;

    return value;
}

float NormalizeYaw(float yaw)
{
    while (yaw > 180.0)
    {
        yaw -= 360.0;
    }

    while (yaw < -180.0)
    {
        yaw += 360.0;
    }

    return yaw;
}
