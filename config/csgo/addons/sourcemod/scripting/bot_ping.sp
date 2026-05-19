#include <sourcemod>
#include <sdktools>

int g_iMaxClients = 0;

float g_fTimer = 0.0;

char g_szPlayerManager[50] = "";

// Entities
int g_iPlayerManager = -1;

// Offsets
int g_iPing = -1;

// ConVars
ConVar g_hIsLan = null;
ConVar g_hInterval = null;

#define PLUGIN_VERSION "1.0.2"

public Plugin myinfo =
{
    name = "Bot Ping",
    author = "Knagg0, modified by Rxpev",
    description = "Changes the ping of BOTs on the scoreboard with LAN/online mode for LIGA: Pro Journey",
    version = PLUGIN_VERSION,
    url = "http://www.mfzb.de"
};

public void OnPluginStart()
{
    CreateConVar("bp_version", PLUGIN_VERSION, "", FCVAR_REPLICATED | FCVAR_NOTIFY);

    g_hIsLan = CreateConVar(
        "isLan",
        "0",
        "Bot ping mode: 1 = LAN pings 0-5, 0 = online pings 11-45",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );

    g_hInterval = CreateConVar(
        "bp_interval",
        "5",
        "How often bot scoreboard pings are randomized, in seconds",
        FCVAR_NOTIFY,
        true,
        1.0
    );

    g_iPing = FindSendPropInfo("CPlayerResource", "m_iPing");

    char szBuffer[100];
    GetGameFolderName(szBuffer, sizeof(szBuffer));

    if (StrEqual("csgo", szBuffer))
    {
        strcopy(g_szPlayerManager, sizeof(g_szPlayerManager), "cs_player_manager");
    }
    else if (StrEqual("dod", szBuffer))
    {
        strcopy(g_szPlayerManager, sizeof(g_szPlayerManager), "dod_player_manager");
    }
    else
    {
        strcopy(g_szPlayerManager, sizeof(g_szPlayerManager), "player_manager");
    }

    AutoExecConfig(true, "bot_ping");
}

public void OnMapStart()
{
    g_iMaxClients = MaxClients;
    g_iPlayerManager = FindEntityByClassname(g_iMaxClients + 1, g_szPlayerManager);
    g_fTimer = 0.0;
}

public void OnGameFrame()
{
    if (g_fTimer < GetGameTime() - g_hInterval.IntValue)
    {
        g_fTimer = GetGameTime();

        if (g_iPlayerManager == -1 || g_iPing == -1)
        {
            return;
        }

        int minPing;
        int maxPing;

        if (g_hIsLan.BoolValue)
        {
            minPing = 0;
            maxPing = 5;
        }
        else
        {
            minPing = 11;
            maxPing = 45;
        }

        for (int i = 1; i <= g_iMaxClients; i++)
        {
            if (!IsValidEdict(i) || !IsClientInGame(i) || !IsFakeClient(i))
            {
                continue;
            }

            SetEntData(
                g_iPlayerManager,
                g_iPing + (i * 4),
                GetRandomInt(minPing, maxPing)
            );
        }
    }
}