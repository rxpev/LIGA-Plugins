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
char          buffer[BUFFER_SIZE_MAX + 1]           = "";
char          hostname[BUFFER_SIZE_SM + 1]          = "";
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
  cvars[SPECTATING] = CreateConVar("liga_spectating", "0");
  gameEngine = GetEngineVersion();

  HookEvent("player_team", Event_JoinTeam);
  RegConsoleCmd("ready", Command_ReadyUp, "Starts the match.");


  cvars[MAX_ROUNDS] = FindConVar("mp_maxrounds");
  HookEvent("cs_win_panel_match", Event_CSGO_GameOver);
  HookEvent("round_start", Event_CSGO_RoundStart);

  // intercept log messages when needed
  AddGameLogHook(Hook_Log);
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

public Action Timer_GameOver(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
            continue;

        ClientCommand(client, "quit");
    }

    // Delay so the command has time to reach the client
    CreateTimer(0.5, Timer_ExitServer, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Stop;
}

public Action Timer_ExitServer(Handle timer)
{
    ServerCommand("exit");
    return Plugin_Stop;
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

  say("TO START THE MATCH TYPE: !ready");

  return Plugin_Continue;
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
