/**
 * A match plugin.
 */
#include <sourcemod>
#include <sdktools>
#include <cstrike>

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
const float   DELAY_REEXEC_LIGABOTS                 = 0.2;
bool          reexecLigaBotsPending                 = false;

// cvars
enum Cvars {
  DELAY_GAME_OVER,
  MAX_ROUNDS,
  SPECTATING,
}
ConVar cvars[Cvars];

// variables
bool          live, halfTime, overTime              = false;
bool          welcomed                              = false;
bool          isMatchPaused                         = false;
char          buffer[BUFFER_SIZE_MAX + 1]           = "";
char          hostname[BUFFER_SIZE_SM + 1]          = "";
char          initialHumanTeam[BUFFER_SIZE_SM + 1]  = "";
char          modelsTs[][]                          = {"models/player/t_guerilla.mdl", "models/player/t_leet.mdl", "models/player/t_phoenix.mdl"};
char          modelsCTs[][]                         = {"models/player/ct_gign.mdl", "models/player/ct_gsg9.mdl", "models/player/ct_sas.mdl"};
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

/**
 * Plugin initialization.
 */
public void OnPluginStart() {
  cvars[DELAY_GAME_OVER] = CreateConVar("liga_gameover_delay", "10");
  cvars[SPECTATING]      = CreateConVar("liga_spectating", "0");
  gameEngine = GetEngineVersion();

  HookEvent("player_team", Event_JoinTeam);
  AddCommandListener(Command_JoinTeam, "jointeam");
  AddCommandListener(Command_Spectate, "spectate");
  RegConsoleCmd("ready", Command_ReadyUp, "Starts the match.");
  RegConsoleCmd("sm_pause", Command_Pause, "Pauses the match.");
  RegConsoleCmd("sm_unpause", Command_Unpause, "Unpauses the match.");

  cvars[MAX_ROUNDS] = FindConVar("mp_maxrounds");
  HookEvent("cs_win_panel_match", Event_CSGO_GameOver);
  HookEvent("round_start", Event_CSGO_RoundStart);

  AddGameLogHook(Hook_Log);
}

public void OnConfigsExecuted() {
  if(!StrEqual(initialHumanTeam, "")) {
    return;
  }

  ConVar mpHumanTeam = FindConVar("mp_humanteam");
  if(mpHumanTeam != null) {
    mpHumanTeam.GetString(initialHumanTeam, sizeof(initialHumanTeam));
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
    ServerCommand("mp_warmup_end");
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

    PrintToChat(client, "\x01\x04<LIGA>\x01 \x07You can only join spectators during this match.");
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

/**
 * Handles the round start event.
 *
 * @param event The event handler.
 * @param name The name of the event.
 * @param dontBroadcast Whether to broadcast the event.
 */
public void Event_CSGO_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  if(GameRules_GetProp("m_bWarmupPeriod") != 1) {
    rounds++;
  }
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
    ServerCommand("exec liga-bots");
  }
}

public void OnClientDisconnect(int client)
{
  if (client <= 0 || client > MaxClients) return;
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

  say("\x0ETO START THE MATCH TYPE: !ready");

  return Plugin_Continue;
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
