/**
 * A match plugin.
 */
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include "include/eItems"

// set compiler options
#pragma       semicolon                             1;

// constants
const int     BUFFER_SIZE_SM                        = 63;
const int     BUFFER_SIZE_MAX                       = 2047;
const float   DELAY_FORCE_BOMB                      = 0.1;
const int     DELAY_FORCE_TEAM                      = 1;
const int     DELAY_HALF_TIME                       = 1;
const int     DELAY_WELCOME_MESSAGE                 = 5;
const int     INTERVAL_LO3                          = 3;
const int     INTERVAL_WELCOME_MESSAGE              = 30;
const int     LO3_LOOP_NUM                          = 3;
const int     LO3_PRINT_NUM                         = 4;
char          MENU_TEAM_SELECT[]                    = "specgui";
char          MENU_TEAM_SELECT_CT[]                 = "class_ct";
char          MENU_TEAM_SELECT_T []                 = "class_ter";
const int     TEAM_T                                = 0;
const int     TEAM_CT                               = 1;
const int     JOIN_TEAM_AUTO                        = 0;
const int     OBS_MODE_IN_EYE                       = 4;
const float   DELAY_REEXEC_LIGABOTS                 = 0.2;
const float   DELAY_WARMUP_EQUIP                    = 0.1;
const float   DELAY_WARMUP_RESPAWN                  = 1.0;
const int     HEALTH_WARMUP_KILL_REWARD             = 15;
const float   INTERVAL_WARMUP_RESTORE               = 0.25;
const float   MAX_BOT_BOMB_USE_DISTANCE             = 175.0;
const float   MIN_BOT_BOMB_USE_DOT                  = 0.65;
const int     REQUIRED_MAX_ROUNDS                   = 24;
const int     WARMUP_CVAR_COUNT                     = 29;
char          SOUND_WARMUP_KILL[]                   = "training/timer_bell.wav";
char          SOUND_WARMUP_HEADSHOT_KILL[]          = "training/bell_impact.wav";
bool          reexecLigaBotsPending                 = false;

// cvars
enum Cvars {
  DELAY_GAME_OVER,
  IS_DEATHMATCH,
  DEATHMATCH_GAME_TIME,
  DEATHMATCH_HEADSHOT_ONLY,
  DEATHMATCH_PISTOLS_ONLY,
  DEATHMATCH_FORCE_BUY,
  IS_AWP,
  IS_IGL,
  MAX_ROUNDS,
  SPECTATING,
}
ConVar cvars[Cvars];

// variables
bool          live, halfTime, overTime              = false;
bool          welcomed                              = false;
bool          isMatchPaused                         = false;
bool          standaloneDeathmatchActive            = false;
bool          deathmatchWarmupEndPollActive         = false;
bool          warmupDeathmatchActive                = false;
bool          warmupDeathmatchEnding                = false;
bool          warmupCvarsSaved                      = false;
bool          warmupRestorePollActive               = false;
bool          warmupSavedCvarExists[WARMUP_CVAR_COUNT];
bool          awpRestricted[MAXPLAYERS + 1];
bool          ecoAwpAllowed[MAXPLAYERS + 1];
bool          eItemsAvailable                       = false;
char          buffer[BUFFER_SIZE_MAX + 1]           = "";
char          hostname[BUFFER_SIZE_SM + 1]          = "";
char          initialHumanTeam[BUFFER_SIZE_SM + 1]  = "";
char          warmupSavedCvars[WARMUP_CVAR_COUNT][BUFFER_SIZE_SM + 1];
float         lastAwpWarn[MAXPLAYERS + 1];
char          modelsTs[][]                          = {"models/player/t_guerilla.mdl", "models/player/t_leet.mdl", "models/player/t_phoenix.mdl"};
char          modelsCTs[][]                         = {"models/player/ct_gign.mdl", "models/player/ct_gsg9.mdl", "models/player/ct_sas.mdl"};
char          warmupCvarNames[][]                   = {
  "mp_randomspawn",
  "mp_randomspawn_los",
  "mp_teammates_are_enemies",
  "mp_friendlyfire",
  "mp_respawn_on_death_t",
  "mp_respawn_on_death_ct",
  "mp_buytime",
  "mp_buy_anywhere",
  "mp_startmoney",
  "mp_maxmoney",
  "mp_playercashawards",
  "mp_teamcashawards",
  "mp_free_armor",
  "mp_death_drop_gun",
  "mp_death_drop_defuser",
  "mp_death_drop_grenade",
  "mp_death_drop_c4",
  "mp_weapons_allow_map_placed",
  "mp_respawn_immunitytime",
  "mp_timelimit",
  "mp_roundtime",
  "mp_roundtime_hostage",
  "mp_roundtime_defuse",
  "mp_damage_headshot_only",
  "mp_maxrounds",
  "spec_freeze_time",
  "spec_freeze_time_lock",
  "spec_freeze_deathanim_time",
  "spec_freeze_panel_extended_time"
};
char          warmupCvarValues[][]                  = {
  "1",
  "1",
  "1",
  "1",
  "1",
  "1",
  "0",
  "0",
  "0",
  "0",
  "0",
  "0",
  "2",
  "0",
  "0",
  "0",
  "0",
  "0",
  "0",
  "0",
  "1.92",
  "1.92",
  "1.92",
  "0",
  "24",
  "2.0",
  "0",
  "0",
  "0"
};
char          postWarmupCvarValues[][]              = {
  "0",
  "0",
  "0",
  "1",
  "0",
  "0",
  "20",
  "0",
  "800",
  "16000",
  "1",
  "1",
  "0",
  "1",
  "1",
  "2",
  "1",
  "1",
  "-1",
  "0",
  "1.92",
  "1.92",
  "1.92",
  "0",
  "24",
  "2.0",
  "0",
  "0",
  "0"
};
int           reasonWinCTs[]                        = {4, 5, 6, 7, 10, 11, 13, 16, 19};
int           reasonWinTs[]                         = {0, 3, 8, 12, 17, 18};
int           rounds                                = 0;
int           score[]                               = {0, 0};
int           scoreOverTime[]                       = {0, 0};
EngineVersion gameEngine                            = Engine_Unknown;

/**
 * Plugin information.
 */
public Plugin myinfo = {
  name        = "LIGA: Pro Journey",
  author      = "Rxpev",
  description = "Match Flow Plugin",
  version     = "1.0.5",
  url         = "http://steamcommunity.com/id/rxpev"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  MarkNativeAsOptional("eItems_RefillClipAmmo");
  MarkNativeAsOptional("eItems_GetWeaponClipAmmoByWeapon");
  return APLRes_Success;
}

/**
 * Plugin initialization.
 */
public void OnPluginStart() {
  cvars[DELAY_GAME_OVER] = CreateConVar("liga_gameover_delay", "10");
  cvars[IS_DEATHMATCH] = CreateConVar(
    "isDeathmatch",
    "0",
    "0 = normal match flow; 1 = standalone LIGA deathmatch mode.",
    FCVAR_NOTIFY,
    true, 0.0,
    true, 1.0
  );
  cvars[DEATHMATCH_GAME_TIME] = CreateConVar(
    "deathmatch_game_time",
    "10",
    "Standalone deathmatch duration in minutes. Supported values: 10, 20, 30, 45, 60.",
    FCVAR_NOTIFY,
    true, 10.0,
    true, 60.0
  );
  cvars[DEATHMATCH_HEADSHOT_ONLY] = CreateConVar(
    "deathmatch_headshot_only",
    "0",
    "0 = normal damage; 1 = headshot-only damage in standalone deathmatch.",
    FCVAR_NOTIFY,
    true, 0.0,
    true, 1.0
  );
  cvars[DEATHMATCH_PISTOLS_ONLY] = CreateConVar(
    "deathmatch_pistols_only",
    "0",
    "0 = normal deathmatch weapons; 1 = Kevlar-only pistol pool.",
    FCVAR_NOTIFY,
    true, 0.0,
    true, 1.0
  );
  cvars[DEATHMATCH_FORCE_BUY] = CreateConVar(
    "deathmatch_force_buy",
    "0",
    "0 = normal deathmatch weapons; 1 = full-armor force-buy weapon pool.",
    FCVAR_NOTIFY,
    true, 0.0,
    true, 1.0
  );
  cvars[IS_DEATHMATCH].AddChangeHook(OnDeathmatchCvarChanged);
  cvars[DEATHMATCH_GAME_TIME].AddChangeHook(OnDeathmatchCvarChanged);
  cvars[DEATHMATCH_HEADSHOT_ONLY].AddChangeHook(OnDeathmatchCvarChanged);
  cvars[DEATHMATCH_PISTOLS_ONLY].AddChangeHook(OnDeathmatchCvarChanged);
  cvars[DEATHMATCH_FORCE_BUY].AddChangeHook(OnDeathmatchCvarChanged);
  cvars[IS_AWP]          = CreateConVar(
    "isAWP",
    "0",
    "0 = restrict AWP usage for non-awpers; 1 = allow normal AWP usage.",
    FCVAR_NOTIFY,
    true, 0.0,
    true, 1.0
  );
  cvars[IS_IGL]           = CreateConVar(
    "IsIGL",
    "0",
    "0 = restrict bot bomb pickup by +use; 1 = allow bot bomb pickup by +use.",
    FCVAR_NOTIFY,
    true, 0.0,
    true, 1.0
  );
  cvars[SPECTATING]      = CreateConVar("liga_spectating", "0");
  gameEngine = GetEngineVersion();

  HookEvent("player_team", Event_JoinTeam);
  HookEvent("player_spawn", Event_CSGO_PlayerSpawn);
  HookEvent("player_hurt", Event_CSGO_PlayerHurt);
  HookEvent("player_death", Event_CSGO_PlayerDeath);
  AddCommandListener(Command_JoinTeam, "jointeam");
  AddCommandListener(Command_Spectate, "spectate");
  RegConsoleCmd("ready", Command_ReadyUp, "Starts the match.");
  RegConsoleCmd("sm_pause", Command_Pause, "Pauses the match.");
  RegConsoleCmd("sm_unpause", Command_Unpause, "Unpauses the match.");

  cvars[MAX_ROUNDS] = FindConVar("mp_maxrounds");
  if(cvars[MAX_ROUNDS] != null) {
    cvars[MAX_ROUNDS].SetInt(GetRequiredMaxRounds());
    cvars[MAX_ROUNDS].AddChangeHook(OnMaxRoundsChanged);
  }
  HookEvent("cs_win_panel_match", Event_CSGO_GameOver);
  HookEventEx("warmup_end", Event_CSGO_WarmupEnd, EventHookMode_Pre);
  HookEventEx("round_prestart", Event_CSGO_RoundPreStart, EventHookMode_Pre);
  HookEvent("round_start", Event_CSGO_RoundStart);
  HookEvent("round_freeze_end", Event_CSGO_FreezeEnd);

  AddGameLogHook(Hook_Log);
}

public void OnAllPluginsLoaded() {
  eItemsAvailable = LibraryExists("eItems");
}

public void OnLibraryAdded(const char[] name) {
  if(StrEqual(name, "eItems", false)) {
    eItemsAvailable = true;
  }
}

public void OnLibraryRemoved(const char[] name) {
  if(StrEqual(name, "eItems", false)) {
    eItemsAvailable = false;
  }
}

public void OnMapStart() {
  standaloneDeathmatchActive = false;
  deathmatchWarmupEndPollActive = false;
  warmupDeathmatchActive = false;
  warmupDeathmatchEnding = false;
  warmupCvarsSaved = false;
  warmupRestorePollActive = false;
  PrecacheSound(SOUND_WARMUP_KILL, true);
  PrecacheSound(SOUND_WARMUP_HEADSHOT_KILL, true);
}

public void OnEntityCreated(int entity, const char[] classname) {
  if(StrEqual(classname, "logic_script", false) || StrEqual(classname, "trigger_multiple", false)) {
    SDKHook(entity, SDKHook_Spawn, SDK_OnWarmupEntitySpawn);
  }
}

public void SDK_OnWarmupEntitySpawn(int entity) {
  if(!HasEntProp(entity, Prop_Data, "m_iszVScripts")) {
    return;
  }

  char vScripts[BUFFER_SIZE_MAX + 1];
  GetEntPropString(entity, Prop_Data, "m_iszVScripts", vScripts, sizeof(vScripts));

  if(StrEqual(vScripts, "warmup/warmup_arena.nut", false) || StrEqual(vScripts, "warmup/warmup_teleport.nut", false)) {
    DispatchKeyValue(entity, "vscripts", "");
    DispatchKeyValue(entity, "targetname", "");
  }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
  Action result = RestrictAwpUsage(client, buttons);

  if(
    !(buttons & IN_USE) ||
    cvars[IS_IGL].BoolValue ||
    client <= 0 ||
    client > MaxClients ||
    !IsClientInGame(client) ||
    !IsPlayerAlive(client) ||
    IsFakeClient(client)
  ) {
    return result;
  }

  if(!IsUsingBotBombCarrier(client)) {
    return result;
  }

  buttons &= ~IN_USE;
  return Plugin_Changed;
}

public void OnConfigsExecuted() {
  EnforceMaxRounds();
  UpdateDeathmatchMode();

  if(IsDeathmatchMode()) {
    return;
  }

  if(!StrEqual(initialHumanTeam, "")) {
    return;
  }

  if(cvars[SPECTATING].BoolValue) {
    ConVar mpForcePickTime = FindConVar("mp_force_pick_time");
    if(mpForcePickTime != null) {
      mpForcePickTime.SetInt(999999);
    }
  }

  ConVar mpHumanTeam = FindConVar("mp_humanteam");
  if(mpHumanTeam != null) {
    mpHumanTeam.GetString(initialHumanTeam, sizeof(initialHumanTeam));
  }
}

public void OnDeathmatchCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
  if(gameEngine != Engine_CSGO) {
    return;
  }

  UpdateDeathmatchMode();

  if(IsDeathmatchMode()) {
    EquipActiveDeathmatchPlayers();
  }
}

/**
 * Ready up command handler.
 *
 * @param id The index of the player.
 * @param args The command arguments.
 */
public Action Command_ReadyUp(int id, int args) {
  if(gameEngine == Engine_CSGO) {
    if(IsDeathmatchMode()) {
      return Plugin_Handled;
    }

    PrepareWarmupDeathmatchEnd();
    ServerCommand("mp_warmup_end");
    StartWarmupRestorePoll();
    return Plugin_Continue;
  }

  // bail if we're already live
  if(live) {
    return Plugin_Continue;
  }

  // execute the configs
  ServerCommand("competitive");

  if(overTime) {
    ServerCommand("overtime");
  }

  return Plugin_Continue;
}

public Action Command_Pause(int client, int args) {
  if (gameEngine != Engine_CSGO) {
    return Plugin_Handled;
  }

  if (isMatchPaused) {
    say("MATCH IS ALREADY PAUSED.");
    return Plugin_Handled;
  }

  ServerCommand("mp_pause_match");
  isMatchPaused = true;
  say("MATCH PAUSED.");

  return Plugin_Handled;
}

public Action Command_Unpause(int client, int args) {
  if (gameEngine != Engine_CSGO) {
    return Plugin_Handled;
  }

  if (!isMatchPaused) {
    say("MATCH IS NOT PAUSED.");
    return Plugin_Handled;
  }

  ServerCommand("mp_unpause_match");
  isMatchPaused = false;
  say("MATCH UNPAUSED.");

  return Plugin_Handled;
}

public Action Command_Spectate(int client, const char[] command, int argc) {
  if(ShouldIgnoreTeamCommand(client)) {
    return Plugin_Continue;
  }

  if(cvars[SPECTATING].BoolValue) {
    return Plugin_Continue;
  }

  PrintToChat(client, "\x01\x04<LIGA>\x01 \x07You cannot switch to spectators during this match.");
  return Plugin_Handled;
}

public Action Command_JoinTeam(int client, const char[] command, int argc) {
  if(ShouldIgnoreTeamCommand(client) || argc < 1) {
    return Plugin_Continue;
  }

  char teamArg[BUFFER_SIZE_SM + 1];
  GetCmdArg(1, teamArg, sizeof(teamArg));

  int requestedTeam = GetJoinTeamRequest(teamArg);
  if(cvars[SPECTATING].BoolValue) {
    if(requestedTeam == CS_TEAM_SPECTATOR) {
      return Plugin_Continue;
    }

    RequestFrame(Frame_JoinSpectators, GetClientUserId(client));
    return Plugin_Handled;
  }

  if(requestedTeam == CS_TEAM_SPECTATOR) {
    PrintToChat(client, "\x01\x04<LIGA>\x01 \x07You cannot switch to spectators during this match.");
    return Plugin_Handled;
  }

  int currentTeam = GetClientTeam(client);
  if(currentTeam > CS_TEAM_SPECTATOR) {
    if(requestedTeam != JOIN_TEAM_AUTO && requestedTeam != currentTeam) {
      PrintToChat(client, "\x01\x04<LIGA>\x01 \x07You cannot switch teams during this match.");
    }

    return Plugin_Handled;
  }

  int allowedTeam = GetAllowedHumanTeam();
  if(allowedTeam == CS_TEAM_NONE) {
    if(currentTeam > CS_TEAM_SPECTATOR && requestedTeam != currentTeam) {
      PrintToChat(client, "\x01\x04<LIGA>\x01 \x07You cannot switch teams during this match.");
      return Plugin_Handled;
    }

    return Plugin_Continue;
  }

  if(requestedTeam == JOIN_TEAM_AUTO) {
    if(GetClientTeam(client) <= CS_TEAM_SPECTATOR) {
      ChangeClientTeam(client, allowedTeam);
    } else if(GetClientTeam(client) != allowedTeam) {
      PrintToChat(client, "\x01\x04<LIGA>\x01 \x07You cannot switch teams during this match.");
    }

    return Plugin_Handled;
  }

  if(requestedTeam != allowedTeam) {
    PrintToChat(client, "\x01\x04<LIGA>\x01 \x07You cannot switch teams during this match.");
    return Plugin_Handled;
  }

  return Plugin_Continue;
}

/**
 * Handles the game over event.
 *
 * @param event The event handler.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_CSGO_GameOver(Event event, const char[] name, bool dontBroadcast) {
  say("SHUTTING DOWN SERVER IN %ds", cvars[DELAY_GAME_OVER].IntValue);
  CreateTimer(float(cvars[DELAY_GAME_OVER].IntValue), Timer_GameOver);
}

public void Event_CSGO_WarmupEnd(Event event, const char[] name, bool dontBroadcast) {
  if(IsDeathmatchMode()) {
    ApplyDeathmatchCvars();
    return;
  }

  PrepareWarmupDeathmatchEnd();
}

public void Event_CSGO_RoundPreStart(Event event, const char[] name, bool dontBroadcast) {
  if(IsDeathmatchMode()) {
    ApplyDeathmatchCvars();
    return;
  }

  if(gameEngine == Engine_CSGO && GameRules_GetProp("m_bWarmupPeriod") != 1) {
    PrepareWarmupDeathmatchEnd();
  }
}

/**
 * Handles the round start event.
 *
 * @param event The event handler.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_CSGO_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  for(int client = 1; client <= MaxClients; client++) {
    ecoAwpAllowed[client] = false;
  }

  bool isWarmup = GameRules_GetProp("m_bWarmupPeriod") == 1;
  UpdateDeathmatchMode();

  if(IsDeathmatchMode()) {
    ApplyDeathmatchCvars();
  }

  if(!isWarmup && !IsDeathmatchMode()) {
    rounds++;
  }
}

public void Event_CSGO_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  for(int client = 1; client <= MaxClients; client++) {
    ecoAwpAllowed[client] = IsEcoAwpExempt(client);
  }
}

public void Event_CSGO_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if(!ShouldRunDeathmatchRules()) {
    return;
  }

  int client = GetClientOfUserId(GetEventInt(event, "userid"));
  if(!IsWarmupPlayer(client)) {
    return;
  }

  CreateTimer(DELAY_WARMUP_EQUIP, Timer_EquipWarmupPlayer, GetClientUserId(client));
}

public void Event_CSGO_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
  if(!ShouldRunDeathmatchRules()) {
    return;
  }

  int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
  int victim = GetClientOfUserId(GetEventInt(event, "userid"));
  if(attacker == victim || !IsWarmupPlayer(attacker) || !IsWarmupPlayer(victim)) {
    return;
  }

  if(GetEventInt(event, "health") <= 0) {
    return;
  }

  PlayWarmupHitDing(attacker);
}

public void Event_CSGO_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  if(!ShouldRunDeathmatchRules()) {
    return;
  }

  int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
  bool headshot = GetEventBool(event, "headshot");
  GiveWarmupKillReward(attacker);
  RefillWarmupKillerMagazine(attacker);
  PlayWarmupKillDing(attacker, headshot);

  int client = GetClientOfUserId(GetEventInt(event, "userid"));
  if(!IsWarmupPlayer(client)) {
    return;
  }

  CreateTimer(DELAY_WARMUP_RESPAWN, Timer_RespawnWarmupPlayer, GetClientUserId(client));
}

/**
 * Triggered when the player joins a team.
 *
 * @param event         The event handle.
 * @param name          String containing the name of the event.
 * @param dontBroadcast True if event was not broadcast to clients, false otherwise.
 */
public Action Event_JoinTeam(Event event, const char[] name, bool dontBroadcast) {
  int id = GetClientOfUserId(GetEventInt(event, "userid"));

  if(IsFakeClient(id) || welcomed) {
    return Plugin_Continue;
  }

  welcomed = true;
  CreateTimer(float(DELAY_WELCOME_MESSAGE), Timer_WelcomeMessage);
  CreateTimer(float(INTERVAL_WELCOME_MESSAGE), Timer_WelcomeMessage, id, TIMER_REPEAT);
  return Plugin_Continue;
}

/**
 * Intercept incoming log messages.
 *
 * Check if log falls within the events we are tracking
 * such as player killed or round over events.
 *
 * If not live then we intercept the log message
 * and prevent it from printing to the console.
 *
 * @param message Message that is being logged.
 */
public Action Hook_Log(char[] message) {
  // check if we're live and bail if not
  bool intercept = (
    StrContains(message, "killed") != -1 ||
    StrContains(message, "triggered") != -1 ||
    StrContains(message, "assisted") != -1
  );

  if(
    gameEngine == Engine_CSGO &&
    intercept &&
    GameRules_GetProp("m_bWarmupPeriod") == 1
  ) {
      return Plugin_Handled;
  }

  // otherwise we let the log message go
  return Plugin_Continue;
}

/**
 * Signifies that the player is fully in-game.
 *
 * @param id The index of the player.
 */
public void OnClientPutInServer(int id) {
  if(StrEqual(hostname, "")) {
    new Handle:convar = FindConVar("hostname");
    GetConVarString(convar, hostname, sizeof(hostname));
  }

  if(!IsFakeClient(id)) {
    if(cvars[SPECTATING].BoolValue) {
      CreateTimer(1.0, Timer_JoinSpectators, GetClientUserId(id));
      CreateTimer(3.0, Timer_JoinSpectators, GetClientUserId(id));
    }

    ServerCommand("exec liga-bots");
  }
}

public void Frame_JoinSpectators(int userid) {
  JoinSpectators(userid);
}

public Action Timer_JoinSpectators(Handle timer, int userid) {
  JoinSpectators(userid);
  return Plugin_Stop;
}

void JoinSpectators(int userid) {
  int client = GetClientOfUserId(userid);
  if(!cvars[SPECTATING].BoolValue || ShouldIgnoreTeamCommand(client)) {
    return;
  }

  if(GetClientTeam(client) != CS_TEAM_SPECTATOR) {
    ChangeClientTeam(client, CS_TEAM_SPECTATOR);
  }

  int target = GetSpectatorTarget(client);
  if(target != -1) {
    SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
    SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_IN_EYE);
    SetEntProp(client, Prop_Data, "m_iObserverLastMode", OBS_MODE_IN_EYE);
    SetEntityMoveType(client, MOVETYPE_OBSERVER);
  }
}

int GetSpectatorTarget(int client) {
  for(int i = 1; i <= MaxClients; i++) {
    if(i == client || !IsClientInGame(i) || GetClientTeam(i) <= CS_TEAM_SPECTATOR || !IsPlayerAlive(i)) {
      continue;
    }

    return i;
  }

  return -1;
}

public void OnClientDisconnect(int client)
{
  if (client <= 0 || client > MaxClients) return;

  lastAwpWarn[client] = 0.0;
  awpRestricted[client] = false;
  ecoAwpAllowed[client] = false;

  if (!IsFakeClient(client)) return;

  // debounce so multiple bot disconnects in quick succession only trigger once
  if (reexecLigaBotsPending) return;

  reexecLigaBotsPending = true;
  CreateTimer(DELAY_REEXEC_LIGABOTS, Timer_ReExecLigaBots);
}

public Action Timer_ReExecLigaBots(Handle timer)
{
  reexecLigaBotsPending = false;
  ServerCommand("exec liga-bots");
  return Plugin_Stop;
}

public Action Timer_CheckWarmupEnded(Handle timer) {
  if(ShouldRunWarmupDeathmatch()) {
    return Plugin_Continue;
  }

  warmupRestorePollActive = false;
  StopWarmupDeathmatch();
  return Plugin_Stop;
}

public Action Timer_EndDeathmatchWarmup(Handle timer) {
  if(!IsDeathmatchMode() || !standaloneDeathmatchActive) {
    deathmatchWarmupEndPollActive = false;
    return Plugin_Stop;
  }

  ApplyDeathmatchCvars();

  if(GameRules_GetProp("m_bWarmupPeriod") != 1) {
    deathmatchWarmupEndPollActive = false;
    return Plugin_Stop;
  }

  ServerCommand("mp_warmuptime 1");
  ServerCommand("mp_warmup_pausetimer 0");
  ServerCommand("mp_warmup_end");
  return Plugin_Continue;
}

public Action Timer_ApplyDeathmatchCvars(Handle timer) {
  if(IsDeathmatchMode() && standaloneDeathmatchActive) {
    ApplyDeathmatchCvars();
    EquipActiveDeathmatchPlayers();
  }

  return Plugin_Stop;
}

public Action Timer_EquipWarmupPlayer(Handle timer, int userid) {
  int client = GetClientOfUserId(userid);
  if(!ShouldRunDeathmatchRules() || !IsWarmupPlayer(client) || !IsPlayerAlive(client)) {
    return Plugin_Stop;
  }

  EquipWarmupPlayer(client);
  return Plugin_Stop;
}

public Action Timer_RespawnWarmupPlayer(Handle timer, int userid) {
  int client = GetClientOfUserId(userid);
  if(!ShouldRunDeathmatchRules() || !IsWarmupPlayer(client) || IsPlayerAlive(client)) {
    return Plugin_Stop;
  }

  CS_RespawnPlayer(client);
  return Plugin_Stop;
}

void UpdateDeathmatchMode() {
  if(IsDeathmatchMode()) {
    StartStandaloneDeathmatch();
    return;
  }

  StopStandaloneDeathmatch();
  UpdateWarmupDeathmatch();
}

void UpdateWarmupDeathmatch() {
  if(ShouldRunWarmupDeathmatch()) {
    StartWarmupDeathmatch();
    return;
  }

  StopWarmupDeathmatch();
}

void PrepareWarmupDeathmatchEnd() {
  if(!warmupDeathmatchActive && !warmupCvarsSaved) {
    return;
  }

  warmupDeathmatchEnding = true;
  ApplyPostWarmupCvars();
}

void StartWarmupRestorePoll() {
  if(warmupRestorePollActive) {
    return;
  }

  warmupRestorePollActive = true;
  CreateTimer(INTERVAL_WARMUP_RESTORE, Timer_CheckWarmupEnded, _, TIMER_REPEAT);
}

bool ShouldRunWarmupDeathmatch() {
  return (
    gameEngine == Engine_CSGO &&
    !warmupDeathmatchEnding &&
    GameRules_GetProp("m_bWarmupPeriod") == 1
  );
}

bool ShouldRunDeathmatchRules() {
  return ShouldRunWarmupDeathmatch() || (gameEngine == Engine_CSGO && standaloneDeathmatchActive);
}

bool IsDeathmatchMode() {
  return gameEngine == Engine_CSGO && cvars[IS_DEATHMATCH] != null && cvars[IS_DEATHMATCH].BoolValue;
}

void StartStandaloneDeathmatch() {
  bool justStarted = !standaloneDeathmatchActive;
  if(justStarted) {
    SaveWarmupCvars();
    standaloneDeathmatchActive = true;
  }

  ApplyDeathmatchCvars();

  if(justStarted) {
    CreateTimer(0.1, Timer_ApplyDeathmatchCvars);
    CreateTimer(1.0, Timer_ApplyDeathmatchCvars);

    if(GameRules_GetProp("m_bWarmupPeriod") == 1) {
      StartDeathmatchWarmupEndPoll();
    }

    for(int client = 1; client <= MaxClients; client++) {
      if(IsWarmupPlayer(client) && IsPlayerAlive(client)) {
        CreateTimer(DELAY_WARMUP_EQUIP, Timer_EquipWarmupPlayer, GetClientUserId(client));
      }
    }
  }
}

void EquipActiveDeathmatchPlayers() {
  if(!standaloneDeathmatchActive) {
    return;
  }

  for(int client = 1; client <= MaxClients; client++) {
    if(IsWarmupPlayer(client) && IsPlayerAlive(client)) {
      CreateTimer(DELAY_WARMUP_EQUIP, Timer_EquipWarmupPlayer, GetClientUserId(client));
    }
  }
}

void StartDeathmatchWarmupEndPoll() {
  if(deathmatchWarmupEndPollActive) {
    return;
  }

  deathmatchWarmupEndPollActive = true;
  CreateTimer(INTERVAL_WARMUP_RESTORE, Timer_EndDeathmatchWarmup, _, TIMER_REPEAT);
}

void StopStandaloneDeathmatch() {
  if(!standaloneDeathmatchActive) {
    return;
  }

  RestoreWarmupCvars();
  standaloneDeathmatchActive = false;
}

void StartWarmupDeathmatch() {
  bool justStarted = !warmupDeathmatchActive;
  if(justStarted) {
    SaveWarmupCvars();
    warmupDeathmatchActive = true;
  }

  ApplyWarmupCvars();

  if(justStarted) {
    for(int client = 1; client <= MaxClients; client++) {
      if(IsWarmupPlayer(client) && IsPlayerAlive(client)) {
        CreateTimer(DELAY_WARMUP_EQUIP, Timer_EquipWarmupPlayer, GetClientUserId(client));
      }
    }
  }
}

void StopWarmupDeathmatch() {
  if(!warmupDeathmatchActive && !warmupCvarsSaved && !warmupDeathmatchEnding) {
    return;
  }

  RestoreWarmupCvars();
  ApplyPostWarmupCvars();
  warmupDeathmatchActive = false;
  warmupDeathmatchEnding = false;
  EnforceMaxRounds();
}

void SaveWarmupCvars() {
  if(warmupCvarsSaved) {
    return;
  }

  for(int i = 0; i < WARMUP_CVAR_COUNT; i++) {
    ConVar convar = FindConVar(warmupCvarNames[i]);
    warmupSavedCvarExists[i] = convar != null;

    if(warmupSavedCvarExists[i]) {
      convar.GetString(warmupSavedCvars[i], sizeof(warmupSavedCvars[]));
    } else {
      warmupSavedCvars[i][0] = '\0';
    }
  }

  warmupCvarsSaved = true;
}

void ApplyWarmupCvars() {
  for(int i = 0; i < WARMUP_CVAR_COUNT; i++) {
    ConVar convar = FindConVar(warmupCvarNames[i]);
    if(convar != null) {
      convar.SetString(warmupCvarValues[i]);
    }
  }
}

void ApplyDeathmatchCvars() {
  for(int i = 0; i < WARMUP_CVAR_COUNT; i++) {
    ConVar convar = FindConVar(warmupCvarNames[i]);
    if(convar == null) {
      continue;
    }

    if(StrEqual(warmupCvarNames[i], "mp_free_armor", false)) {
      convar.SetInt(GetDeathmatchFreeArmor());
    } else if(StrEqual(warmupCvarNames[i], "mp_maxrounds", false)) {
      convar.SetInt(1);
    } else if(
      StrEqual(warmupCvarNames[i], "spec_freeze_time", false) ||
      StrEqual(warmupCvarNames[i], "spec_freeze_time_lock", false) ||
      StrEqual(warmupCvarNames[i], "spec_freeze_deathanim_time", false) ||
      StrEqual(warmupCvarNames[i], "spec_freeze_panel_extended_time", false)
    ) {
      convar.SetInt(0);
    } else if(
      StrEqual(warmupCvarNames[i], "mp_timelimit", false) ||
      StrEqual(warmupCvarNames[i], "mp_roundtime", false) ||
      StrEqual(warmupCvarNames[i], "mp_roundtime_hostage", false) ||
      StrEqual(warmupCvarNames[i], "mp_roundtime_defuse", false)
    ) {
      convar.SetInt(GetDeathmatchGameTime());
    } else if(StrEqual(warmupCvarNames[i], "mp_damage_headshot_only", false)) {
      convar.SetInt(cvars[DEATHMATCH_HEADSHOT_ONLY].BoolValue ? 1 : 0);
    } else {
      convar.SetString(warmupCvarValues[i]);
    }
  }
}

void RestoreWarmupCvars() {
  if(!warmupCvarsSaved) {
    return;
  }

  for(int i = 0; i < WARMUP_CVAR_COUNT; i++) {
    if(!warmupSavedCvarExists[i]) {
      continue;
    }

    ConVar convar = FindConVar(warmupCvarNames[i]);
    if(convar != null) {
      convar.SetString(warmupSavedCvars[i]);
    }

    warmupSavedCvarExists[i] = false;
    warmupSavedCvars[i][0] = '\0';
  }

  warmupCvarsSaved = false;
}

void ApplyPostWarmupCvars() {
  for(int i = 0; i < WARMUP_CVAR_COUNT; i++) {
    ConVar convar = FindConVar(warmupCvarNames[i]);
    if(convar != null) {
      convar.SetString(postWarmupCvarValues[i]);
    }
  }
}

void GiveWarmupKillReward(int client) {
  if(!IsWarmupPlayer(client) || !IsPlayerAlive(client)) {
    return;
  }

  int health = GetClientHealth(client);
  int rewardedHealth = health + HEALTH_WARMUP_KILL_REWARD;
  if(rewardedHealth > 100) {
    rewardedHealth = 100;
  }

  SetEntityHealth(client, rewardedHealth);
}

void RefillWarmupKillerMagazine(int client) {
  if(!IsWarmupPlayer(client) || !IsPlayerAlive(client)) {
    return;
  }

  int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  if(weapon <= 0 || !IsValidEntity(weapon)) {
    return;
  }

  int clip = GetWarmupWeaponClipCapacity(weapon);
  if(clip <= 0) {
    return;
  }

  SetWeaponClip(weapon, clip);
}

void PlayWarmupKillDing(int client, bool headshot) {
  if(!IsWarmupPlayer(client)) {
    return;
  }

  EmitSoundToClient(client, headshot ? SOUND_WARMUP_HEADSHOT_KILL : SOUND_WARMUP_KILL);
}

void PlayWarmupHitDing(int client) {
  if(!IsWarmupPlayer(client)) {
    return;
  }

  EmitSoundToClient(client, SOUND_WARMUP_KILL);
}

int GetDeathmatchGameTime() {
  int minutes = cvars[DEATHMATCH_GAME_TIME].IntValue;

  if(minutes == 10 || minutes == 20 || minutes == 30 || minutes == 45 || minutes == 60) {
    return minutes;
  }

  return 10;
}

int GetDeathmatchFreeArmor() {
  if(cvars[DEATHMATCH_PISTOLS_ONLY].BoolValue) {
    return 1;
  }

  return 2;
}

int GetWarmupWeaponClipCapacity(int weapon) {
  if(weapon <= 0 || !IsValidEntity(weapon)) {
    return 0;
  }

  if(eItemsAvailable) {
    int clip = eItems_GetWeaponClipAmmoByWeapon(weapon);
    if(clip > 0) {
      return clip;
    }
  }

  char classname[BUFFER_SIZE_SM + 1];
  if(!GetEntityClassname(weapon, classname, sizeof(classname))) {
    return 0;
  }

  return GetDefaultWarmupWeaponClipCapacity(classname);
}

int GetDefaultWarmupWeaponClipCapacity(const char[] classname) {
  if(StrEqual(classname, "weapon_ak47", false) || StrEqual(classname, "weapon_m4a1", false)) {
    return 30;
  }

  if(StrEqual(classname, "weapon_m4a1_silencer", false)) {
    return 20;
  }

  if(StrEqual(classname, "weapon_awp", false)) {
    return 10;
  }

  if(StrEqual(classname, "weapon_deagle", false)) {
    return 7;
  }

  if(StrEqual(classname, "weapon_galilar", false) || StrEqual(classname, "weapon_famas", false)) {
    return 30;
  }

  if(StrEqual(classname, "weapon_ssg08", false)) {
    return 10;
  }

  if(StrEqual(classname, "weapon_mp9", false) || StrEqual(classname, "weapon_mac10", false)) {
    return 30;
  }

  if(StrEqual(classname, "weapon_usp_silencer", false) || StrEqual(classname, "weapon_glock", false)) {
    return 20;
  }

  if(StrEqual(classname, "weapon_p250", false)) {
    return 13;
  }

  return 0;
}

void SetWeaponClip(int weapon, int clip) {
  if(HasEntProp(weapon, Prop_Data, "m_iClip1")) {
    SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
  }

  if(HasEntProp(weapon, Prop_Send, "m_iClip1")) {
    SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
  }
}

bool IsWarmupPlayer(int client) {
  return (
    client > 0 &&
    client <= MaxClients &&
    IsClientInGame(client) &&
    GetClientTeam(client) > CS_TEAM_SPECTATOR
  );
}

void EquipWarmupPlayer(int client) {
  StripWeaponSlot(client, CS_SLOT_PRIMARY);
  StripWeaponSlot(client, CS_SLOT_SECONDARY);
  StripWeaponSlot(client, CS_SLOT_GRENADE);
  StripWeaponSlot(client, CS_SLOT_C4);

  char weapon[BUFFER_SIZE_SM + 1];
  GetWarmupWeapon(weapon, sizeof(weapon));
  GivePlayerItem(client, weapon);
  SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
  SetEntProp(client, Prop_Send, "m_bHasHelmet", ShouldEquipDeathmatchHelmet() ? 1 : 0);
  SetEntProp(client, Prop_Send, "m_iAccount", 0);
}

void GetWarmupWeapon(char[] weapon, int size) {
  if(IsDeathmatchMode() && cvars[DEATHMATCH_PISTOLS_ONLY].BoolValue) {
    GetDeathmatchPistolWeapon(weapon, size);
    return;
  }

  if(IsDeathmatchMode() && cvars[DEATHMATCH_FORCE_BUY].BoolValue) {
    GetDeathmatchForceBuyWeapon(weapon, size);
    return;
  }

  int roll = GetRandomInt(1, 100);

  if(IsDeathmatchMode() && cvars[DEATHMATCH_HEADSHOT_ONLY].BoolValue) {
    if(roll <= 70) {
      strcopy(weapon, size, "weapon_ak47");
      return;
    }

    if(roll <= 85) {
      strcopy(weapon, size, "weapon_m4a1_silencer");
      return;
    }

    if(roll <= 95) {
      strcopy(weapon, size, "weapon_m4a1");
      return;
    }

    strcopy(weapon, size, "weapon_deagle");
    return;
  }

  if(roll <= 60) {
    strcopy(weapon, size, "weapon_ak47");
    return;
  }

  if(roll <= 75) {
    strcopy(weapon, size, "weapon_m4a1_silencer");
    return;
  }

  if(roll <= 85) {
    strcopy(weapon, size, "weapon_m4a1");
    return;
  }

  if(roll <= 95) {
    strcopy(weapon, size, "weapon_awp");
    return;
  }

  strcopy(weapon, size, "weapon_deagle");
}

void GetDeathmatchPistolWeapon(char[] weapon, int size) {
  int roll = GetRandomInt(1, 100);

  if(roll <= 90) {
    strcopy(weapon, size, "weapon_usp_silencer");
    return;
  }

  if(roll <= 95) {
    strcopy(weapon, size, "weapon_glock");
    return;
  }

  strcopy(weapon, size, "weapon_p250");
}

void GetDeathmatchForceBuyWeapon(char[] weapon, int size) {
  int roll = GetRandomInt(1, 100);

  if(roll <= 45) {
    strcopy(weapon, size, "weapon_galilar");
    return;
  }

  if(roll <= 60) {
    strcopy(weapon, size, "weapon_ssg08");
    return;
  }

  if(roll <= 70) {
    strcopy(weapon, size, "weapon_mp9");
    return;
  }

  if(roll <= 80) {
    strcopy(weapon, size, "weapon_mac10");
    return;
  }

  if(roll <= 90) {
    strcopy(weapon, size, "weapon_deagle");
    return;
  }

  strcopy(weapon, size, "weapon_famas");
}

bool ShouldEquipDeathmatchHelmet() {
  return !IsDeathmatchMode() || !cvars[DEATHMATCH_PISTOLS_ONLY].BoolValue;
}

void StripWeaponSlot(int client, int slot) {
  int safety = 0;
  int weapon = GetPlayerWeaponSlot(client, slot);

  while(weapon != -1 && IsValidEntity(weapon) && safety < 16) {
    RemovePlayerItem(client, weapon);
    AcceptEntityInput(weapon, "Kill");

    safety++;
    weapon = GetPlayerWeaponSlot(client, slot);
  }
}

/**
 * Handles the half-time event by executing the
 * appropriate half-time or overtime config.
 *
 * @param timer The timer handler.
 */
public Action Timer_HalfTime(Handle timer) {
  live = false;
  halfTime = !halfTime;

  // in first half of overtime we do not switch sides
  if(overTime && !halfTime) {
    ServerCommand("exec liga-overtime.cfg");
  } else {
    ServerCommand("exec liga-halftime.cfg");
  }

  return Plugin_Continue;
}

/**
 * Exits the game once the game is over.
 *
 * @param timer The timer handler.
 */
public Action Timer_GameOver(Handle timer) {

  // shut the server down
  ServerCommand("exit");
  return Plugin_Continue;
}

/**
 * Displays the welcome message on a
 * repeat until the game is live.
 *
 * @param timer The timer handler.
 * @param id The index of the player.
 */
public Action Timer_WelcomeMessage(Handle timer, int id) {
  // bail if we're live
  if(gameEngine == Engine_CSGO && GameRules_GetProp("m_bWarmupPeriod") != 1)
  {
    return Plugin_Stop;
  }

  if(cvars[SPECTATING].BoolValue) {
    say("YOU ARE SPECTATING THIS MATCH.");
  }

  PrintToChatAll("\x01 \x09<%s> \x02TO START THE MATCH TYPE: !ready", hostname);

  return Plugin_Continue;
}

bool IsUsingBotBombCarrier(int client) {
  float clientEyePosition[3];
  float clientEyeAngles[3];
  float clientForward[3];

  GetClientEyePosition(client, clientEyePosition);
  GetClientEyeAngles(client, clientEyeAngles);
  GetAngleVectors(clientEyeAngles, clientForward, NULL_VECTOR, NULL_VECTOR);
  NormalizeVector(clientForward, clientForward);

  int team = GetClientTeam(client);
  for(int target = 1; target <= MaxClients; target++) {
    if(
      target == client ||
      !IsClientInGame(target) ||
      !IsPlayerAlive(target) ||
      !IsFakeClient(target) ||
      GetClientTeam(target) != team ||
      !ClientHasBomb(target)
    ) {
      continue;
    }

    float targetEyePosition[3];
    float direction[3];

    GetClientEyePosition(target, targetEyePosition);
    direction[0] = targetEyePosition[0] - clientEyePosition[0];
    direction[1] = targetEyePosition[1] - clientEyePosition[1];
    direction[2] = targetEyePosition[2] - clientEyePosition[2];

    if(GetVectorLength(direction) > MAX_BOT_BOMB_USE_DISTANCE) {
      continue;
    }

    NormalizeVector(direction, direction);
    if(GetVectorDotProduct(clientForward, direction) >= MIN_BOT_BOMB_USE_DOT) {
      return true;
    }
  }

  return false;
}

Action RestrictAwpUsage(int client, int &buttons) {
  if(
    client <= 0 ||
    client > MaxClients ||
    !IsClientInGame(client) ||
    !IsPlayerAlive(client) ||
    IsFakeClient(client)
  ) {
    return Plugin_Continue;
  }

  int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  if(activeWeapon <= 0) {
    return Plugin_Continue;
  }

  char classname[64];
  if(!GetEntityClassname(activeWeapon, classname, sizeof(classname)) || !StrEqual(classname, "weapon_awp", false)) {
    return Plugin_Continue;
  }

  int team = GetClientTeam(client);
  if(team <= CS_TEAM_SPECTATOR) {
    return Plugin_Continue;
  }

  float now = GetGameTime();
  if(IsDeathmatchMode() || GameRules_GetProp("m_bWarmupPeriod") == 1 || cvars[IS_AWP].BoolValue || ecoAwpAllowed[client] || !HasAliveTeammate(client, team)) {
    if(awpRestricted[client]) {
      awpRestricted[client] = false;
      SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack", now);
      SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextSecondaryAttack", now);
      SetEntPropFloat(client, Prop_Send, "m_flNextAttack", now);
      lastAwpWarn[client] = 0.0;
    }

    return Plugin_Continue;
  }

  awpRestricted[client] = true;
  if(now - lastAwpWarn[client] >= 5.0) {
    lastAwpWarn[client] = now;
    PrintToChat(client, "[PRO JOURNEY] You are not allowed to use the AWP.");
    PrintCenterText(client, "You are not an AWPer.\nDrop the AWP to your AWPer!");
  }

  float blockTime = now + 3600.0;
  SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack", blockTime);
  SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextSecondaryAttack", blockTime);
  SetEntPropFloat(client, Prop_Send, "m_flNextAttack", blockTime);

  buttons &= ~IN_ATTACK;
  buttons &= ~IN_ATTACK2;
  return Plugin_Changed;
}

bool HasAliveTeammate(int client, int team) {
  for(int target = 1; target <= MaxClients; target++) {
    if(
      target != client &&
      IsClientInGame(target) &&
      IsPlayerAlive(target) &&
      GetClientTeam(target) == team
    ) {
      return true;
    }
  }

  return false;
}

bool IsEcoAwpExempt(int client) {
  if(
    client <= 0 ||
    client > MaxClients ||
    !IsClientInGame(client) ||
    !IsPlayerAlive(client) ||
    IsFakeClient(client) ||
    cvars[IS_AWP].BoolValue ||
    ClientHasPrimary(client)
  ) {
    return false;
  }

  int team = GetClientTeam(client);
  if(team <= CS_TEAM_SPECTATOR) {
    return false;
  }

  for(int teammate = 1; teammate <= MaxClients; teammate++) {
    if(
      teammate != client &&
      IsClientInGame(teammate) &&
      IsPlayerAlive(teammate) &&
      GetClientTeam(teammate) == team &&
      ClientHasPrimary(teammate)
    ) {
      return false;
    }
  }

  return true;
}

bool ClientHasPrimary(int client) {
  int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
  return primary != -1 && IsValidEntity(primary);
}

public void OnMaxRoundsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
  int requiredMaxRounds = GetRequiredMaxRounds();
  if(convar.IntValue != requiredMaxRounds) {
    convar.SetInt(requiredMaxRounds);
  }
}

void EnforceMaxRounds() {
  int requiredMaxRounds = GetRequiredMaxRounds();
  if(cvars[MAX_ROUNDS] != null && cvars[MAX_ROUNDS].IntValue != requiredMaxRounds) {
    cvars[MAX_ROUNDS].SetInt(requiredMaxRounds);
  }
}

int GetRequiredMaxRounds() {
  if(IsDeathmatchMode()) {
    return 1;
  }

  return REQUIRED_MAX_ROUNDS;
}

bool ClientHasBomb(int client) {
  int c4 = GetPlayerWeaponSlot(client, CS_SLOT_C4);
  return c4 != -1 && IsValidEntity(c4);
}

bool ShouldIgnoreTeamCommand(int client) {
  return (
    client <= 0 ||
    client > MaxClients ||
    !IsClientInGame(client) ||
    IsFakeClient(client)
  );
}

int GetJoinTeamRequest(const char[] teamArg) {
  if(StrEqual(teamArg, "0")) {
    return JOIN_TEAM_AUTO;
  }

  if(StrEqual(teamArg, "1") || StrEqual(teamArg, "spec", false) || StrEqual(teamArg, "spectate", false) || StrEqual(teamArg, "spectator", false)) {
    return CS_TEAM_SPECTATOR;
  }

  if(StrEqual(teamArg, "2") || StrEqual(teamArg, "t", false) || StrEqual(teamArg, "terrorist", false)) {
    return CS_TEAM_T;
  }

  if(StrEqual(teamArg, "3") || StrEqual(teamArg, "ct", false)) {
    return CS_TEAM_CT;
  }

  return -1;
}

int GetAllowedHumanTeam() {
  int team = GetInitialHumanTeam();
  if(team == CS_TEAM_NONE) {
    return CS_TEAM_NONE;
  }

  return HaveTeamsSwapped()
    ? GetOppositeTeam(team)
    : team
  ;
}

bool HaveTeamsSwapped() {
  int maxRounds = cvars[MAX_ROUNDS].IntValue;
  return halfTime || (maxRounds > 0 && rounds > (maxRounds / 2));
}

int GetInitialHumanTeam() {
  if(StrEqual(initialHumanTeam, "t", false)) {
    return CS_TEAM_T;
  }

  if(StrEqual(initialHumanTeam, "ct", false)) {
    return CS_TEAM_CT;
  }

  return CS_TEAM_NONE;
}

int GetOppositeTeam(int team) {
  if(team == CS_TEAM_T) {
    return CS_TEAM_CT;
  }

  if(team == CS_TEAM_CT) {
    return CS_TEAM_T;
  }

  return team;
}

/**
 * Gets the sum of an array of integers.
 *
 * @param data The array of integers.
 * @param size The size of the array.
 * @return The sum.
 */
int getArraySum(int[] data, int size) {
  int sum = 0;

  for(int i = 0; i < size; i++) {
    sum += data[i];
  }

  return sum;
}

/**
 * Gets a team's score depending on the stage of the game.
 *
 * @param id The team enum id.
 */
int getScore(int id) {
  return overTime
    ? scoreOverTime[id]
    : score[id]
  ;
}

/**
 * Emulates the chat behavior from `rcon say` where the
 * server's hostname is prefixed before the message.
 *
 * @param message The message to print.
 */
public void say(const char[] message, any ...) {
  VFormat(buffer, sizeof(buffer), message, 2);
   PrintToChatAll("\x01\x04<%s>\x01 %s", hostname, buffer);
}

/**
 * Prints a message to chat x-amount of times.
 *
 * @param x The number of times to print the message.
 * @param message The message to print.
 */
public void sayX(int x, const char[] message, any ...) {
  VFormat(buffer, sizeof(buffer), message, 3);
  for(int i = 0; i < x; i++) {
    say(buffer);
  }
}
