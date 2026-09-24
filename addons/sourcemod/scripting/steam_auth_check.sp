#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <SteamWorks>


public Plugin myinfo =
{
    name        = "Steam Auth Check",
    author      = "Yekta.T, TouchMe",
    description = "If the server has a Steam connection and the Steam auth values of the players joining the server cannot be retrieved, they will be kicked from the game.",
    version     = "build_0000",
    url         = "vortexguys.com"
};


ConVar g_cvRetryTime = null;
ConVar g_cvMaxAttempts = null;

bool g_bConnectedtoSteam = true;
bool g_bAwaitingAuth[MAXPLAYERS + 1] = { false, ... };

float g_fRetryTime;
int g_iMaxAttempts;
int g_iAttempts[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_cvRetryTime = CreateConVar("sm_authcontrol_retrytime", "5.0", "How many seconds should the server wait before retrying if the Steam auth information of the player joining the server cannot be retrieved?");
    g_cvMaxAttempts = CreateConVar("sm_vxauthcontrol_maxattempts", "2", "After each retry time, if the auth value cannot be retrieved, it is recorded as a failed attempt. At which failed attempt should the player be kicked from the server?", _, true, 1.0);

    HookConVarChange(g_cvRetryTime, Callback_ConvarChange);
    HookConVarChange(g_cvMaxAttempts, Callback_ConvarChange);

    g_iMaxAttempts = GetConVarInt(g_cvMaxAttempts);
    g_fRetryTime = GetConVarFloat(g_cvRetryTime);
}

public void Callback_ConvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (StrEqual(oldValue, newValue, false))
        return;

    g_iMaxAttempts = GetConVarInt(g_cvMaxAttempts);
    g_fRetryTime = GetConVarFloat(g_cvRetryTime);
}

public void OnClientPutInServer(int iClient)
{
    g_bAwaitingAuth[iClient] = true;
    g_iAttempts[iClient] = g_iMaxAttempts;
    CreateTimer(g_fRetryTime, Timer_AuthCheck, GetClientUserId(iClient), TIMER_REPEAT);
}

public void OnClientAuthorized(int iClient, const char[] szAuthId) {
    g_bAwaitingAuth[iClient] = false;
}

public Action Timer_AuthCheck(Handle timer, any iUserId)
{
    int iClient = GetClientOfUserId(iUserId);

    if (!iClient || !g_bAwaitingAuth[iClient] || !g_bConnectedtoSteam) {
        return Plugin_Stop;
    }

    char szAuth[MAX_AUTHID_LENGTH];

    if (!GetClientAuthId(iClient, AuthId_Steam2, szAuth, sizeof szAuth)
        || (StrContains(szAuth, "STEAM_ID", false) != -1))
    {
        if (--g_iAttempts[iClient] > 1)
        {
            LogMessage("Player %N has failed check Steam Auth. %i attempts left.", iClient, g_iAttempts[iClient]);

            return Plugin_Continue;
        } else {
            KickClient(iClient, "Invalid steamId");
        }
    }

    return Plugin_Stop;
}

public void SteamWorks_SteamServersConnected() {
    g_bConnectedtoSteam = true;
}

public void SteamWorks_SteamServersConnectFailure(EResult result) {
    g_bConnectedtoSteam = false;
}

public void SteamWorks_SteamServersDisconnected(EResult result) {
    g_bConnectedtoSteam = false;
}
