#include <a_samp>
#include <a_mysql>
#include <zcmd>
#include <sscanf2>
#include <foreach>

#define MYSQL_HOST "localhost"
#define MYSQL_USER "root"
#define MYSQL_PASSWORD ""
#define MYSQL_DATABASE "samp_db"

new MySQL:dbHandle;
new PlayerLogged[MAX_PLAYERS];
new PlayerName[MAX_PLAYERS][MAX_PLAYER_NAME];
new PlayerPassword[MAX_PLAYERS][64];

public OnGameModeInit()
{
    print("Gamemode successfully loaded.");
    dbHandle = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE);
    if (dbHandle == MYSQL_INVALID_HANDLE)
    {
        print("MySQL connection failed.");
        SendRconCommand("exit");
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    GetPlayerName(playerid, PlayerName[playerid], MAX_PLAYER_NAME);
    PlayerLogged[playerid] = 0;
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    PlayerLogged[playerid] = 0;
    return 1;
}

CMD:register(playerid, params[])
{
    new password[64];
    if (sscanf(params, "s[64]", password)) return SendClientMessage(playerid, -1, "Usage: /register [password]");

    new query[256];
    format(query, sizeof(query), "INSERT INTO users (name, password) VALUES ('%s', '%s')", PlayerName[playerid], password);
    mysql_query(dbHandle, query);

    SendClientMessage(playerid, -1, "You have successfully registered.");
    return 1;
}

CMD:login(playerid, params[])
{
    new password[64];
    if (sscanf(params, "s[64]", password)) return SendClientMessage(playerid, -1, "Usage: /login [password]");

    new query[256];
    format(query, sizeof(query), "SELECT password FROM users WHERE name = '%s'", PlayerName[playerid]);
    mysql_query(dbHandle, query);
    mysql_store_result();

    if (mysql_num_rows() == 0)
    {
        SendClientMessage(playerid, -1, "Account not found. Please register first.");
        mysql_free_result();
        return 1;
    }

    mysql_fetch_row_format(PlayerPassword[playerid], "|");
    mysql_free_result();

    if (strcmp(PlayerPassword[playerid], password, false) == 0)
    {
        PlayerLogged[playerid] = 1;
        SendClientMessage(playerid, -1, "Login successful.");
    }
    else
    {
        SendClientMessage(playerid, -1, "Incorrect password.");
    }
    return 1;
}

new PlayerAdminLevel[MAX_PLAYERS];

CMD:setadmin(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 5) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid, level;
    if (sscanf(params, "ii", targetid, level)) return SendClientMessage(playerid, -1, "Usage: /setadmin [playerid] [level]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");

    PlayerAdminLevel[targetid] = level;

    new msg[128];
    format(msg, sizeof(msg), "You have set admin level %d for player %s.", level, PlayerName[targetid]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "Your admin level has been set to %d.", level);
    SendClientMessage(targetid, -1, msg);
    return 1;
}

CMD:kick(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 1) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid;
    if (sscanf(params, "i", targetid)) return SendClientMessage(playerid, -1, "Usage: /kick [playerid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");

    new msg[128];
    format(msg, sizeof(msg), "Admin %s has kicked player %s.", PlayerName[playerid], PlayerName[targetid]);
    SendClientMessageToAll(-1, msg);

    Kick(targetid);
    return 1;
}

CMD:ban(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 2) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid;
    if (sscanf(params, "i", targetid)) return SendClientMessage(playerid, -1, "Usage: /ban [playerid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");

    new msg[128];
    format(msg, sizeof(msg), "Admin %s has banned player %s.", PlayerName[playerid], PlayerName[targetid]);
    SendClientMessageToAll(-1, msg);

    Ban(targetid);
    return 1;
}

CMD:veh(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 1) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new modelid;
    if (sscanf(params, "i", modelid)) return SendClientMessage(playerid, -1, "Usage: /veh [modelid]");

    if (modelid < 400 || modelid > 611) return SendClientMessage(playerid, -1, "Invalid vehicle model ID.");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    CreateVehicle(modelid, x + 2.0, y, z, 0.0, -1, -1, 60);

    SendClientMessage(playerid, -1, "Vehicle spawned.");
    return 1;
}

CMD:goto(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 1) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid;
    if (sscanf(params, "i", targetid)) return SendClientMessage(playerid, -1, "Usage: /goto [playerid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(targetid, x, y, z);
    SetPlayerPos(playerid, x + 1.0, y, z);

    SendClientMessage(playerid, -1, "Teleported to player.");
    return 1;
}

CMD:bring(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 1) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid;
    if (sscanf(params, "i", targetid)) return SendClientMessage(playerid, -1, "Usage: /bring [playerid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    SetPlayerPos(targetid, x + 1.0, y, z);

    SendClientMessage(playerid, -1, "Player brought to your location.");
    return 1;
}

new PlayerJob[MAX_PLAYERS];
new PlayerMoney[MAX_PLAYERS];

enum Jobs
{
    JOB_NONE,
    JOB_DRIVER,
    JOB_MECHANIC,
    JOB_POLICE
};

CMD:setjob(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 2) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid, jobid;
    if (sscanf(params, "ii", targetid, jobid)) return SendClientMessage(playerid, -1, "Usage: /setjob [playerid] [jobid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");
    if (jobid < JOB_NONE || jobid > JOB_POLICE) return SendClientMessage(playerid, -1, "Invalid job ID.");

    PlayerJob[targetid] = jobid;

    new msg[128];
    format(msg, sizeof(msg), "You have assigned job ID %d to player %s.", jobid, PlayerName[targetid]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "Your job has been set to ID %d.", jobid);
    SendClientMessage(targetid, -1, msg);
    return 1;
}

CMD:work(playerid, params[])
{
    if (PlayerJob[playerid] == JOB_NONE) return SendClientMessage(playerid, -1, "You don't have a job. Ask an admin to assign one.");

    new earned = 0;
    switch (PlayerJob[playerid])
    {
        case JOB_DRIVER: earned = 500;
        case JOB_MECHANIC: earned = 700;
        case JOB_POLICE: earned = 1000;
    }

    PlayerMoney[playerid] += earned;

    new msg[128];
    format(msg, sizeof(msg), "You worked as a %s and earned $%d.",
        (PlayerJob[playerid] == JOB_DRIVER) ? "Driver" :
        (PlayerJob[playerid] == JOB_MECHANIC) ? "Mechanic" :
        (PlayerJob[playerid] == JOB_POLICE) ? "Police Officer" : "Unknown",
        earned);

    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:money(playerid, params[])
{
    new msg[64];
    format(msg, sizeof(msg), "Your current money: $%d", PlayerMoney[playerid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if (PlayerLogged[playerid] == 1)
    {
        new query[256];
        format(query, sizeof(query),
            "UPDATE users SET job = %d, money = %d WHERE name = '%s'",
            PlayerJob[playerid], PlayerMoney[playerid], PlayerName[playerid]);
        mysql_query(dbHandle, query);
    }

    PlayerLogged[playerid] = 0;
    return 1;
}

CMD:login(playerid, params[])
{
    new password[64];
    if (sscanf(params, "s[64]", password)) return SendClientMessage(playerid, -1, "Usage: /login [password]");

    new query[256];
    format(query, sizeof(query), "SELECT password, job, money FROM users WHERE name = '%s'", PlayerName[playerid]);
    mysql_query(dbHandle, query);
    mysql_store_result();

    if (mysql_num_rows() == 0)
    {
        SendClientMessage(playerid, -1, "Account not found. Please register first.");
        mysql_free_result();
        return 1;
    }

    new row[256];
    mysql_fetch_row(row);
    mysql_free_result();

    new dbPassword[64], jobStr[16], moneyStr[16];
    sscanf(row, "p<|>s[64]s[16]s[16]", dbPassword, jobStr, moneyStr);

    if (strcmp(dbPassword, password, false) == 0)
    {
        PlayerLogged[playerid] = 1;
        PlayerJob[playerid] = strval(jobStr);
        PlayerMoney[playerid] = strval(moneyStr);
        SendClientMessage(playerid, -1, "Login successful. Data loaded.");
    }
    else
    {
        SendClientMessage(playerid, -1, "Incorrect password.");
    }
    return 1;
}

#define MAX_HOUSES 100

enum HouseData
{
    Float:HouseX,
    Float:HouseY,
    Float:HouseZ,
    HousePrice,
    HouseOwner[MAX_PLAYER_NAME],
    HousePickupID
};

new Houses[MAX_HOUSES][HouseData];

stock CreateHouse(id, Float:x, Float:y, Float:z, price)
{
    Houses[id][HouseX] = x;
    Houses[id][HouseY] = y;
    Houses[id][HouseZ] = z;
    Houses[id][HousePrice] = price;
    strmid(Houses[id][HouseOwner], "None", 0, 4);
    Houses[id][HousePickupID] = CreatePickup(1273, 23, x, y, z, -1);
}

CMD:buyhouse(playerid, params[])
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_HOUSES; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, 3.0, Houses[i][HouseX], Houses[i][HouseY], Houses[i][HouseZ]))
        {
            if (strcmp(Houses[i][HouseOwner], "None", true) != 0)
                return SendClientMessage(playerid, -1, "This house is already owned.");

            if (PlayerMoney[playerid] < Houses[i][HousePrice])
                return SendClientMessage(playerid, -1, "You don't have enough money to buy this house.");

            PlayerMoney[playerid] -= Houses[i][HousePrice];
            strmid(Houses[i][HouseOwner], PlayerName[playerid], 0, MAX_PLAYER_NAME);

            new msg[128];
            format(msg, sizeof(msg), "You bought the house for $%d.", Houses[i][HousePrice]);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You're not near any house.");
    return 1;
}

CMD:enterhouse(playerid, params[])
{
    for (new i = 0; i < MAX_HOUSES; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, 3.0, Houses[i][HouseX], Houses[i][HouseY], Houses[i][HouseZ]))
        {
            if (strcmp(Houses[i][HouseOwner], PlayerName[playerid], true) != 0)
                return SendClientMessage(playerid, -1, "You don't own this house.");

            SetPlayerPos(playerid, Houses[i][HouseX] + 1.0, Houses[i][HouseY], Houses[i][HouseZ]);
            SendClientMessage(playerid, -1, "You entered your house.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You're not near any house.");
    return 1;
}

#define MAX_FACTIONS 5

enum Factions
{
    FACTION_NONE,
    FACTION_POLICE,
    FACTION_MEDIC,
    FACTION_GANG,
    FACTION_ARMY
};

new PlayerFaction[MAX_PLAYERS];

CMD:setfaction(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 3) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid, factionid;
    if (sscanf(params, "ii", targetid, factionid)) return SendClientMessage(playerid, -1, "Usage: /setfaction [playerid] [factionid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");
    if (factionid < FACTION_NONE || factionid >= MAX_FACTIONS) return SendClientMessage(playerid, -1, "Invalid faction ID.");

    PlayerFaction[targetid] = factionid;

    new msg[128];
    format(msg, sizeof(msg), "You assigned faction ID %d to player %s.", factionid, PlayerName[targetid]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "You have been assigned to faction ID %d.", factionid);
    SendClientMessage(targetid, -1, msg);
    return 1;
}

CMD:factionchat(playerid, params[])
{
    if (PlayerFaction[playerid] == FACTION_NONE) return SendClientMessage(playerid, -1, "You're not in a faction.");

    new message[128];
    if (sscanf(params, "s[128]", message)) return SendClientMessage(playerid, -1, "Usage: /factionchat [message]");

    new msg[160];
    format(msg, sizeof(msg), "[Faction Chat] %s: %s", PlayerName[playerid], message);

    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && PlayerFaction[i] == PlayerFaction[playerid])
        {
            SendClientMessage(i, -1, msg);
        }
    }
    return 1;
}

new PlayerBank[MAX_PLAYERS];

CMD:deposit(playerid, params[])
{
    new amount;
    if (sscanf(params, "i", amount)) return SendClientMessage(playerid, -1, "Usage: /deposit [amount]");

    if (amount <= 0) return SendClientMessage(playerid, -1, "Invalid amount.");
    if (PlayerMoney[playerid] < amount) return SendClientMessage(playerid, -1, "You don't have enough money.");

    PlayerMoney[playerid] -= amount;
    PlayerBank[playerid] += amount;

    new msg[128];
    format(msg, sizeof(msg), "You deposited $%d into your bank account.", amount);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:withdraw(playerid, params[])
{
    new amount;
    if (sscanf(params, "i", amount)) return SendClientMessage(playerid, -1, "Usage: /withdraw [amount]");

    if (amount <= 0) return SendClientMessage(playerid, -1, "Invalid amount.");
    if (PlayerBank[playerid] < amount) return SendClientMessage(playerid, -1, "You don't have enough in your bank account.");

    PlayerBank[playerid] -= amount;
    PlayerMoney[playerid] += amount;

    new msg[128];
    format(msg, sizeof(msg), "You withdrew $%d from your bank account.", amount);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:bank(playerid, params[])
{
    new msg[128];
    format(msg, sizeof(msg), "Bank Balance: $%d | Cash: $%d", PlayerBank[playerid], PlayerMoney[playerid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:setskin(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 2) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid, skinid;
    if (sscanf(params, "ii", targetid, skinid)) return SendClientMessage(playerid, -1, "Usage: /setskin [playerid] [skinid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");
    if (skinid < 0 || skinid > 311) return SendClientMessage(playerid, -1, "Invalid skin ID.");

    SetPlayerSkin(targetid, skinid);

    new msg[128];
    format(msg, sizeof(msg), "You set skin ID %d for player %s.", skinid, PlayerName[targetid]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "Your skin has been changed to ID %d.", skinid);
    SendClientMessage(targetid, -1, msg);
    return 1;
}

CMD:skin(playerid, params[])
{
    new skinid;
    if (sscanf(params, "i", skinid)) return SendClientMessage(playerid, -1, "Usage: /skin [skinid]");

    if (skinid < 0 || skinid > 311) return SendClientMessage(playerid, -1, "Invalid skin ID.");

    SetPlayerSkin(playerid, skinid);

    new msg[64];
    format(msg, sizeof(msg), "You changed your skin to ID %d.", skinid);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

#define MAX_PLAYER_VEHICLES 5

new PlayerVehicles[MAX_PLAYERS][MAX_PLAYER_VEHICLES];

CMD:storeveh(playerid, params[])
{
    new vehicleid = GetPlayerVehicleID(playerid);
    if (vehicleid == 0) return SendClientMessage(playerid, -1, "You're not in a vehicle.");

    for (new i = 0; i < MAX_PLAYER_VEHICLES; i++)
    {
        if (PlayerVehicles[playerid][i] == 0)
        {
            PlayerVehicles[playerid][i] = vehicleid;
            SendClientMessage(playerid, -1, "Vehicle stored in your garage.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "Your garage is full.");
    return 1;
}

CMD:myvehicles(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your stored vehicles:");

    for (new i = 0; i < MAX_PLAYER_VEHICLES; i++)
    {
        if (PlayerVehicles[playerid][i] != 0)
        {
            new msg[64];
            format(msg, sizeof(msg), "Slot %d: Vehicle ID %d", i + 1, PlayerVehicles[playerid][i]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:spawnveh(playerid, params[])
{
    new slot;
    if (sscanf(params, "i", slot)) return SendClientMessage(playerid, -1, "Usage: /spawnveh [slot]");

    if (slot < 1 || slot > MAX_PLAYER_VEHICLES) return SendClientMessage(playerid, -1, "Invalid slot number.");

    new modelid = PlayerVehicles[playerid][slot - 1];
    if (modelid == 0) return SendClientMessage(playerid, -1, "No vehicle stored in that slot.");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    CreateVehicle(modelid, x + 2.0, y, z, 0.0, -1, -1, 60);

    SendClientMessage(playerid, -1, "Vehicle spawned from garage.");
    return 1;
}

enum Licenses
{
    LICENSE_NONE = 0,
    LICENSE_DRIVE = 1,
    LICENSE_FLY = 2,
    LICENSE_WEAPON = 4
};

new PlayerLicenses[MAX_PLAYERS];

CMD:givelicense(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 2) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid, licenseid;
    if (sscanf(params, "ii", targetid, licenseid)) return SendClientMessage(playerid, -1, "Usage: /givelicense [playerid] [licenseid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");
    if (licenseid != LICENSE_DRIVE && licenseid != LICENSE_FLY && licenseid != LICENSE_WEAPON)
        return SendClientMessage(playerid, -1, "Invalid license ID.");

    PlayerLicenses[targetid] |= licenseid;

    new msg[128];
    format(msg, sizeof(msg), "You gave license ID %d to player %s.", licenseid, PlayerName[targetid]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "You received license ID %d.", licenseid);
    SendClientMessage(targetid, -1, msg);
    return 1;
}

CMD:licenses(playerid, params[])
{
    new msg[256];
    format(msg, sizeof(msg), "Your licenses: %s%s%s",
        (PlayerLicenses[playerid] & LICENSE_DRIVE) ? "Driving " : "",
        (PlayerLicenses[playerid] & LICENSE_FLY) ? "Flying " : "",
        (PlayerLicenses[playerid] & LICENSE_WEAPON) ? "Weapons" : "");

    if (strlen(msg) < 15) format(msg, sizeof(msg), "You have no licenses.");
    SendClientMessage(playerid, -1, msg);
    return 1;
}

#define MAX_ACHIEVEMENTS 10

enum Achievements
{
    ACH_WORKED,
    ACH_EARNED_1000,
    ACH_BOUGHT_HOUSE
};

new PlayerAchievements[MAX_PLAYERS][MAX_ACHIEVEMENTS];

stock UnlockAchievement(playerid, achievementid)
{
    if (PlayerAchievements[playerid][achievementid] == 1) return;

    PlayerAchievements[playerid][achievementid] = 1;

    new msg[128];
    switch (achievementid)
    {
        case ACH_WORKED: msg = "Achievement Unlocked: First Job!";
        case ACH_EARNED_1000: msg = "Achievement Unlocked: Earned $1000!";
        case ACH_BOUGHT_HOUSE: msg = "Achievement Unlocked: Homeowner!";
        default: msg = "Achievement Unlocked!";
    }

    SendClientMessage(playerid, -1, msg);
}

CMD:achievements(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your Achievements:");

    if (PlayerAchievements[playerid][ACH_WORKED]) SendClientMessage(playerid, -1, "- First Job");
    if (PlayerAchievements[playerid][ACH_EARNED_1000]) SendClientMessage(playerid, -1, "- Earned $1000");
    if (PlayerAchievements[playerid][ACH_BOUGHT_HOUSE]) SendClientMessage(playerid, -1, "- Homeowner");

    if (!PlayerAchievements[playerid][ACH_WORKED] &&
        !PlayerAchievements[playerid][ACH_EARNED_1000] &&
        !PlayerAchievements[playerid][ACH_BOUGHT_HOUSE])
    {
        SendClientMessage(playerid, -1, "- No achievements yet.");
    }

    return 1;
}

new PlayerPhoneNumber[MAX_PLAYERS];
new PlayerInCall[MAX_PLAYERS];

CMD:setnumber(playerid, params[])
{
    new number;
    if (sscanf(params, "i", number)) return SendClientMessage(playerid, -1, "Usage: /setnumber [number]");

    if (number < 1000 || number > 9999) return SendClientMessage(playerid, -1, "Phone number must be between 1000 and 9999.");

    PlayerPhoneNumber[playerid] = number;

    new msg[64];
    format(msg, sizeof(msg), "Your phone number is now %d.", number);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:call(playerid, params[])
{
    new targetNumber;
    if (sscanf(params, "i", targetNumber)) return SendClientMessage(playerid, -1, "Usage: /call [number]");

    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && PlayerPhoneNumber[i] == targetNumber)
        {
            PlayerInCall[playerid] = i;
            PlayerInCall[i] = playerid;

            new msg[64];
            format(msg, sizeof(msg), "You are now in a call with %s.", PlayerName[i]);
            SendClientMessage(playerid, -1, msg);

            format(msg, sizeof(msg), "%s is calling you. You are now in a call.", PlayerName[playerid]);
            SendClientMessage(i, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "Number not found.");
    return 1;
}

CMD:endcall(playerid, params[])
{
    new target = PlayerInCall[playerid];
    if (target == 0 || !IsPlayerConnected(target)) return SendClientMessage(playerid, -1, "You're not in a call.");

    PlayerInCall[playerid] = 0;
    PlayerInCall[target] = 0;

    SendClientMessage(playerid, -1, "Call ended.");
    SendClientMessage(target, -1, "Call ended.");
    return 1;
}

CMD:sms(playerid, params[])
{
    new targetNumber;
    new message[128];
    if (sscanf(params, "is[128]", targetNumber, message)) return SendClientMessage(playerid, -1, "Usage: /sms [number] [message]");

    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i) && PlayerPhoneNumber[i] == targetNumber)
        {
            new msg[160];
            format(msg, sizeof(msg), "SMS from %s: %s", PlayerName[playerid], message);
            SendClientMessage(i, -1, msg);

            SendClientMessage(playerid, -1, "SMS sent.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "Number not found.");
    return 1;
}

#define MAX_ITEMS 10
#define MAX_ITEM_NAME 32

enum ItemData
{
    ItemName[MAX_ITEM_NAME],
    ItemQuantity
};

new PlayerInventory[MAX_PLAYERS][MAX_ITEMS][ItemData];

stock AddItem(playerid, itemName[], quantity)
{
    for (new i = 0; i < MAX_ITEMS; i++)
    {
        if (strcmp(PlayerInventory[playerid][i][ItemName], itemName, true) == 0)
        {
            PlayerInventory[playerid][i][ItemQuantity] += quantity;
            return;
        }

        if (PlayerInventory[playerid][i][ItemQuantity] == 0)
        {
            strmid(PlayerInventory[playerid][i][ItemName], itemName, 0, MAX_ITEM_NAME);
            PlayerInventory[playerid][i][ItemQuantity] = quantity;
            return;
        }
    }
}

CMD:giveitem(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 2) return SendClientMessage(playerid, -1, "You don't have permission to use this command.");

    new targetid, itemName[32], quantity;
    if (sscanf(params, "is[32]i", targetid, itemName, quantity)) return SendClientMessage(playerid, -1, "Usage: /giveitem [playerid] [item] [quantity]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");

    AddItem(targetid, itemName, quantity);

    new msg[128];
    format(msg, sizeof(msg), "You gave %d x %s to %s.", quantity, itemName, PlayerName[targetid]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "You received %d x %s.", quantity, itemName);
    SendClientMessage(targetid, -1, msg);
    return 1;
}

CMD:inventory(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your Inventory:");

    for (new i = 0; i < MAX_ITEMS; i++)
    {
        if (PlayerInventory[playerid][i][ItemQuantity] > 0)
        {
            new msg[64];
            format(msg, sizeof(msg), "- %s x%d", PlayerInventory[playerid][i][ItemName], PlayerInventory[playerid][i][ItemQuantity]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:useitem(playerid, params[])
{
    new itemName[32];
    if (sscanf(params, "s[32]", itemName)) return SendClientMessage(playerid, -1, "Usage: /useitem [item]");

    for (new i = 0; i < MAX_ITEMS; i++)
    {
        if (strcmp(PlayerInventory[playerid][i][ItemName], itemName, true) == 0 &&
            PlayerInventory[playerid][i][ItemQuantity] > 0)
        {
            PlayerInventory[playerid][i][ItemQuantity]--;

            new msg[64];
            format(msg, sizeof(msg), "You used one %s.", itemName);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "Item not found in your inventory.");
    return 1;
}

new PlayerLevel[MAX_PLAYERS];
new PlayerXP[MAX_PLAYERS];
new XPToLevel[MAX_PLAYERS];

stock InitializeStats(playerid)
{
    PlayerLevel[playerid] = 1;
    PlayerXP[playerid] = 0;
    XPToLevel[playerid] = 100;
}

stock AddXP(playerid, amount)
{
    PlayerXP[playerid] += amount;

    new msg[64];
    format(msg, sizeof(msg), "You gained %d XP.", amount);
    SendClientMessage(playerid, -1, msg);

    if (PlayerXP[playerid] >= XPToLevel[playerid])
    {
        PlayerLevel[playerid]++;
        PlayerXP[playerid] = 0;
        XPToLevel[playerid] += 50;

        format(msg, sizeof(msg), "Level up! You are now level %d.", PlayerLevel[playerid]);
        SendClientMessage(playerid, -1, msg);
    }
}

CMD:stats(playerid, params[])
{
    new msg[128];
    format(msg, sizeof(msg), "Level: %d | XP: %d / %d", PlayerLevel[playerid], PlayerXP[playerid], XPToLevel[playerid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

stock HasItem(playerid, itemName[], quantity)
{
    for (new i = 0; i < MAX_ITEMS; i++)
    {
        if (strcmp(PlayerInventory[playerid][i][ItemName], itemName, true) == 0 &&
            PlayerInventory[playerid][i][ItemQuantity] >= quantity)
        {
            return true;
        }
    }
    return false;
}

stock RemoveItem(playerid, itemName[], quantity)
{
    for (new i = 0; i < MAX_ITEMS; i++)
    {
        if (strcmp(PlayerInventory[playerid][i][ItemName], itemName, true) == 0)
        {
            PlayerInventory[playerid][i][ItemQuantity] -= quantity;
            if (PlayerInventory[playerid][i][ItemQuantity] < 0)
                PlayerInventory[playerid][i][ItemQuantity] = 0;
            return;
        }
    }
}

CMD:craft(playerid, params[])
{
    new recipe[32];
    if (sscanf(params, "s[32]", recipe)) return SendClientMessage(playerid, -1, "Usage: /craft [item]");

    if (strcmp(recipe, "medkit", true) == 0)
    {
        if (HasItem(playerid, "bandage", 2) && HasItem(playerid, "alcohol", 1))
        {
            RemoveItem(playerid, "bandage", 2);
            RemoveItem(playerid, "alcohol", 1);
            AddItem(playerid, "medkit", 1);
            SendClientMessage(playerid, -1, "You crafted a medkit.");
        }
        else
        {
            SendClientMessage(playerid, -1, "You need 2 bandages and 1 alcohol to craft a medkit.");
        }
        return 1;
    }

    SendClientMessage(playerid, -1, "Unknown recipe.");
    return 1;
}

new PlayerHunger[MAX_PLAYERS];
new PlayerThirst[MAX_PLAYERS];

stock InitializeNeeds(playerid)
{
    PlayerHunger[playerid] = 100;
    PlayerThirst[playerid] = 100;
}

public OnPlayerUpdate(playerid)
{
    if (!IsPlayerConnected(playerid)) return 1;

    PlayerHunger[playerid]--;
    PlayerThirst[playerid]--;

    if (PlayerHunger[playerid] <= 0 || PlayerThirst[playerid] <= 0)
    {
        SetPlayerHealth(playerid, 0.0);
        SendClientMessage(playerid, -1, "You died from hunger or thirst.");
    }

    return 1;
}

CMD:eat(playerid, params[])
{
    if (HasItem(playerid, "food", 1))
    {
        RemoveItem(playerid, "food", 1);
        PlayerHunger[playerid] += 25;
        if (PlayerHunger[playerid] > 100) PlayerHunger[playerid] = 100;
        SendClientMessage(playerid, -1, "You ate some food.");
    }
    else
    {
        SendClientMessage(playerid, -1, "You have no food.");
    }
    return 1;
}

CMD:drink(playerid, params[])
{
    if (HasItem(playerid, "water", 1))
    {
        RemoveItem(playerid, "water", 1);
        PlayerThirst[playerid] += 25;
        if (PlayerThirst[playerid] > 100) PlayerThirst[playerid] = 100;
        SendClientMessage(playerid, -1, "You drank some water.");
    }
    else
    {
        SendClientMessage(playerid, -1, "You have no water.");
    }
    return 1;
}

CMD:needs(playerid, params[])
{
    new msg[128];
    format(msg, sizeof(msg), "Hunger: %d | Thirst: %d", PlayerHunger[playerid], PlayerThirst[playerid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

#define MAX_SKILLS 5

enum Skills
{
    SKILL_STRENGTH,
    SKILL_SPEED,
    SKILL_CRAFTING,
    SKILL_DRIVING,
    SKILL_SHOOTING
};

new PlayerSkills[MAX_PLAYERS][MAX_SKILLS];

CMD:skillup(playerid, params[])
{
    new skillid;
    if (sscanf(params, "i", skillid)) return SendClientMessage(playerid, -1, "Usage: /skillup [skillid]");

    if (skillid < 0 || skillid >= MAX_SKILLS) return SendClientMessage(playerid, -1, "Invalid skill ID.");

    PlayerSkills[playerid][skillid]++;
    new msg[128];
    format(msg, sizeof(msg), "You upgraded skill ID %d to level %d.", skillid, PlayerSkills[playerid][skillid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:skills(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your Skills:");

    new msg[128];
    format(msg, sizeof(msg), "- Strength: %d", PlayerSkills[playerid][SKILL_STRENGTH]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "- Speed: %d", PlayerSkills[playerid][SKILL_SPEED]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "- Crafting: %d", PlayerSkills[playerid][SKILL_CRAFTING]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "- Driving: %d", PlayerSkills[playerid][SKILL_DRIVING]);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "- Shooting: %d", PlayerSkills[playerid][SKILL_SHOOTING]);
    SendClientMessage(playerid, -1, msg);

    return 1;
}

#define MAX_QUESTS 10
#define QUEST_NAME_LEN 32

enum QuestData
{
    QuestName[QUEST_NAME_LEN],
    QuestCompleted
};

new PlayerQuests[MAX_PLAYERS][MAX_QUESTS][QuestData];

stock AssignQuest(playerid, questid, name[])
{
    if (questid < 0 || questid >= MAX_QUESTS) return;

    strmid(PlayerQuests[playerid][questid][QuestName], name, 0, QUEST_NAME_LEN);
    PlayerQuests[playerid][questid][QuestCompleted] = 0;

    new msg[128];
    format(msg, sizeof(msg), "New quest assigned: %s", name);
    SendClientMessage(playerid, -1, msg);
}

CMD:quests(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your Quests:");

    for (new i = 0; i < MAX_QUESTS; i++)
    {
        if (strlen(PlayerQuests[playerid][i][QuestName]) > 0)
        {
            new msg[128];
            format(msg, sizeof(msg), "- %s [%s]",
                PlayerQuests[playerid][i][QuestName],
                PlayerQuests[playerid][i][QuestCompleted] ? "Completed" : "In Progress");
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:completequest(playerid, params[])
{
    new questid;
    if (sscanf(params, "i", questid)) return SendClientMessage(playerid, -1, "Usage: /completequest [id]");

    if (questid < 0 || questid >= MAX_QUESTS) return SendClientMessage(playerid, -1, "Invalid quest ID.");
    if (PlayerQuests[playerid][questid][QuestCompleted]) return SendClientMessage(playerid, -1, "Quest already completed.");

    PlayerQuests[playerid][questid][QuestCompleted] = 1;

    new msg[128];
    format(msg, sizeof(msg), "Quest completed: %s", PlayerQuests[playerid][questid][QuestName]);
    SendClientMessage(playerid, -1, msg);

    AddXP(playerid, 50); // Reward XP
    UnlockAchievement(playerid, ACH_WORKED); // Example achievement
    return 1;
}

new PlayerReputation[MAX_PLAYERS];
new PlayerTitle[MAX_PLAYERS][32];

CMD:addrep(playerid, params[])
{
    new amount;
    if (sscanf(params, "i", amount)) return SendClientMessage(playerid, -1, "Usage: /addrep [amount]");

    PlayerReputation[playerid] += amount;

    new msg[64];
    format(msg, sizeof(msg), "You gained %d reputation.", amount);
    SendClientMessage(playerid, -1, msg);

    UpdateTitle(playerid);
    return 1;
}

CMD:rep(playerid, params[])
{
    new msg[64];
    format(msg, sizeof(msg), "Reputation: %d | Title: %s", PlayerReputation[playerid], PlayerTitle[playerid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

stock UpdateTitle(playerid)
{
    if (PlayerReputation[playerid] >= 1000)
        strmid(PlayerTitle[playerid], "Legend", 0, 32);
    else if (PlayerReputation[playerid] >= 500)
        strmid(PlayerTitle[playerid], "Veteran", 0, 32);
    else if (PlayerReputation[playerid] >= 200)
        strmid(PlayerTitle[playerid], "Experienced", 0, 32);
    else if (PlayerReputation[playerid] >= 50)
        strmid(PlayerTitle[playerid], "Novice", 0, 32);
    else
        strmid(PlayerTitle[playerid], "Unknown", 0, 32);
}

#define MAX_NPCS 50
#define NPC_NAME_LEN 32

enum NPCData
{
    NPCID,
    NPCName[NPC_NAME_LEN],
    Float:NPCX,
    Float:NPCY,
    Float:NPCZ
};

new NPCs[MAX_NPCS][NPCData];

stock CreateNPC(id, name[], Float:x, Float:y, Float:z)
{
    NPCs[id][NPCID] = CreateActor(0, x, y, z, 0.0);
    strmid(NPCs[id][NPCName], name, 0, NPC_NAME_LEN);
    NPCs[id][NPCX] = x;
    NPCs[id][NPCY] = y;
    NPCs[id][NPCZ] = z;
}

CMD:npcs(playerid, params[])
{
    SendClientMessage(playerid, -1, "Nearby NPCs:");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_NPCS; i++)
    {
        if (NPCs[i][NPCID] != INVALID_ACTOR_ID &&
            IsPlayerInRangeOfPoint(playerid, 5.0, NPCs[i][NPCX], NPCs[i][NPCY], NPCs[i][NPCZ]))
        {
            new msg[64];
            format(msg, sizeof(msg), "- %s", NPCs[i][NPCName]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:talk(playerid, params[])
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_NPCS; i++)
    {
        if (NPCs[i][NPCID] != INVALID_ACTOR_ID &&
            IsPlayerInRangeOfPoint(playerid, 3.0, NPCs[i][NPCX], NPCs[i][NPCY], NPCs[i][NPCZ]))
        {
            new msg[128];
            format(msg, sizeof(msg), "%s says: Hello %s! Need help?", NPCs[i][NPCName], PlayerName[playerid]);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No NPC nearby to talk to.");
    return 1;
}

#define MAX_SHOP_ITEMS 10
#define ITEM_NAME_LEN 32

enum ShopItemData
{
    ShopItemName[ITEM_NAME_LEN],
    ShopItemPrice
};

new NPCShop[MAX_NPCS][MAX_SHOP_ITEMS][ShopItemData];

stock AddShopItem(npcid, slot, name[], price)
{
    strmid(NPCShop[npcid][slot][ShopItemName], name, 0, ITEM_NAME_LEN);
    NPCShop[npcid][slot][ShopItemPrice] = price;
}

CMD:shop(playerid, params[])
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_NPCS; i++)
    {
        if (NPCs[i][NPCID] != INVALID_ACTOR_ID &&
            IsPlayerInRangeOfPoint(playerid, 3.0, NPCs[i][NPCX], NPCs[i][NPCY], NPCs[i][NPCZ]))
        {
            SendClientMessage(playerid, -1, "Shop Items:");

            for (new j = 0; j < MAX_SHOP_ITEMS; j++)
            {
                if (strlen(NPCShop[i][j][ShopItemName]) > 0)
                {
                    new msg[128];
                    format(msg, sizeof(msg), "- %s ($%d)", NPCShop[i][j][ShopItemName], NPCShop[i][j][ShopItemPrice]);
                    SendClientMessage(playerid, -1, msg);
                }
            }
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No shop nearby.");
    return 1;
}

CMD:buy(playerid, params[])
{
    new itemName[32];
    if (sscanf(params, "s[32]", itemName)) return SendClientMessage(playerid, -1, "Usage: /buy [item]");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_NPCS; i++)
    {
        if (NPCs[i][NPCID] != INVALID_ACTOR_ID &&
            IsPlayerInRangeOfPoint(playerid, 3.0, NPCs[i][NPCX], NPCs[i][NPCY], NPCs[i][NPCZ]))
        {
            for (new j = 0; j < MAX_SHOP_ITEMS; j++)
            {
                if (strcmp(NPCShop[i][j][ShopItemName], itemName, true) == 0)
                {
                    new price = NPCShop[i][j][ShopItemPrice];
                    if (PlayerMoney[playerid] < price)
                        return SendClientMessage(playerid, -1, "You don't have enough money.");

                    PlayerMoney[playerid] -= price;
                    AddItem(playerid, itemName, 1);

                    new msg[128];
                    format(msg, sizeof(msg), "You bought 1 x %s for $%d.", itemName, price);
                    SendClientMessage(playerid, -1, msg);
                    return 1;
                }
            }
        }
    }

    SendClientMessage(playerid, -1, "Item not found or no shop nearby.");
    return 1;
}

#define MAX_BUSINESSES 50

enum BusinessData
{
    Float:BizX,
    Float:BizY,
    Float:BizZ,
    BizPrice,
    BizOwner[MAX_PLAYER_NAME],
    BizEarnings
};

new Businesses[MAX_BUSINESSES][BusinessData];

stock CreateBusiness(id, Float:x, Float:y, Float:z, price)
{
    Businesses[id][BizX] = x;
    Businesses[id][BizY] = y;
    Businesses[id][BizZ] = z;
    Businesses[id][BizPrice] = price;
    strmid(Businesses[id][BizOwner], "None", 0, 4);
    Businesses[id][BizEarnings] = 0;
    CreatePickup(1274, 23, x, y, z, -1);
}

CMD:buybiz(playerid, params[])
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_BUSINESSES; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, 3.0, Businesses[i][BizX], Businesses[i][BizY], Businesses[i][BizZ]))
        {
            if (strcmp(Businesses[i][BizOwner], "None", true) != 0)
                return SendClientMessage(playerid, -1, "This business is already owned.");

            if (PlayerMoney[playerid] < Businesses[i][BizPrice])
                return SendClientMessage(playerid, -1, "You don't have enough money.");

            PlayerMoney[playerid] -= Businesses[i][BizPrice];
            strmid(Businesses[i][BizOwner], PlayerName[playerid], 0, MAX_PLAYER_NAME);

            new msg[128];
            format(msg, sizeof(msg), "You bought the business for $%d.", Businesses[i][BizPrice]);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You're not near any business.");
    return 1;
}

CMD:collectbiz(playerid, params[])
{
    for (new i = 0; i < MAX_BUSINESSES; i++)
    {
        if (strcmp(Businesses[i][BizOwner], PlayerName[playerid], true) == 0)
        {
            new earnings = Businesses[i][BizEarnings];
            if (earnings == 0) return SendClientMessage(playerid, -1, "No earnings to collect.");

            PlayerMoney[playerid] += earnings;
            Businesses[i][BizEarnings] = 0;

            new msg[128];
            format(msg, sizeof(msg), "You collected $%d from your business.", earnings);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You don't own any business.");
    return 1;
}

enum HouseData
{
    Float:HouseX,
    Float:HouseY,
    Float:HouseZ,
    HousePrice,
    HouseOwner[MAX_PLAYER_NAME],
    HousePickupID,
    HouseInteriorID,
    Float:InteriorX,
    Float:InteriorY,
    Float:InteriorZ
};

new Houses[MAX_HOUSES][HouseData];

stock CreateHouse(id, Float:x, Float:y, Float:z, price, interiorID, Float:intX, Float:intY, Float:intZ)
{
    Houses[id][HouseX] = x;
    Houses[id][HouseY] = y;
    Houses[id][HouseZ] = z;
    Houses[id][HousePrice] = price;
    Houses[id][HouseInteriorID] = interiorID;
    Houses[id][InteriorX] = intX;
    Houses[id][InteriorY] = intY;
    Houses[id][InteriorZ] = intZ;
    strmid(Houses[id][HouseOwner], "None", 0, 4);
    Houses[id][HousePickupID] = CreatePickup(1273, 23, x, y, z, -1);
}

CMD:enterhouse(playerid, params[])
{
    for (new i = 0; i < MAX_HOUSES; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, 3.0, Houses[i][HouseX], Houses[i][HouseY], Houses[i][HouseZ]))
        {
            if (strcmp(Houses[i][HouseOwner], PlayerName[playerid], true) != 0)
                return SendClientMessage(playerid, -1, "You don't own this house.");

            SetPlayerInterior(playerid, Houses[i][HouseInteriorID]);
            SetPlayerPos(playerid, Houses[i][InteriorX], Houses[i][InteriorY], Houses[i][InteriorZ]);
            SendClientMessage(playerid, -1, "You entered your house.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You're not near any house.");
    return 1;
}

CMD:exithouse(playerid, params[])
{
    for (new i = 0; i < MAX_HOUSES; i++)
    {
        if (strcmp(Houses[i][HouseOwner], PlayerName[playerid], true) == 0)
        {
            SetPlayerInterior(playerid, 0);
            SetPlayerPos(playerid, Houses[i][HouseX] + 1.0, Houses[i][HouseY], Houses[i][HouseZ]);
            SendClientMessage(playerid, -1, "You exited your house.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You don't own a house.");
    return 1;
}

new CurrentEvent[64];
new EventActive = 0;

CMD:startevent(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 4) return SendClientMessage(playerid, -1, "You don't have permission to start events.");

    new eventName[64];
    if (sscanf(params, "s[64]", eventName)) return SendClientMessage(playerid, -1, "Usage: /startevent [name]");

    strmid(CurrentEvent, eventName, 0, 64);
    EventActive = 1;

    new msg[128];
    format(msg, sizeof(msg), "World Event Started: %s", CurrentEvent);
    SendClientMessageToAll(-1, msg);

    // Example: Give all players bonus XP
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i)) AddXP(i, 25);
    }

    return 1;
}

CMD:stopevent(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 4) return SendClientMessage(playerid, -1, "You don't have permission to stop events.");

    EventActive = 0;
    strmid(CurrentEvent, "None", 0, 64);
    SendClientMessageToAll(-1, "World Event has ended.");
    return 1;
}

CMD:event(playerid, params[])
{
    if (EventActive)
    {
        new msg[128];
        format(msg, sizeof(msg), "Current World Event: %s", CurrentEvent);
        SendClientMessage(playerid, -1, msg);
    }
    else
    {
        SendClientMessage(playerid, -1, "No active world event.");
    }
    return 1;
}

#define MAX_PLAYER_VEHICLES 5

enum VehicleData
{
    VehicleModel,
    Float:VehicleX,
    Float:VehicleY,
    Float:VehicleZ,
    VehicleOwned
};

new PlayerVehicles[MAX_PLAYERS][MAX_PLAYER_VEHICLES][VehicleData];

CMD:buyvehicle(playerid, params[])
{
    new modelid;
    if (sscanf(params, "i", modelid)) return SendClientMessage(playerid, -1, "Usage: /buyvehicle [modelid]");

    if (modelid < 400 || modelid > 611) return SendClientMessage(playerid, -1, "Invalid vehicle model ID.");

    for (new i = 0; i < MAX_PLAYER_VEHICLES; i++)
    {
        if (PlayerVehicles[playerid][i][VehicleOwned] == 0)
        {
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid, x, y, z);

            PlayerVehicles[playerid][i][VehicleModel] = modelid;
            PlayerVehicles[playerid][i][VehicleX] = x;
            PlayerVehicles[playerid][i][VehicleY] = y;
            PlayerVehicles[playerid][i][VehicleZ] = z;
            PlayerVehicles[playerid][i][VehicleOwned] = 1;

            CreateVehicle(modelid, x + 2.0, y, z, 0.0, -1, -1, 60);

            new msg[128];
            format(msg, sizeof(msg), "You bought vehicle ID %d and it was spawned.", modelid);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "Your garage is full.");
    return 1;
}

CMD:myvehicles(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your Owned Vehicles:");

    for (new i = 0; i < MAX_PLAYER_VEHICLES; i++)
    {
        if (PlayerVehicles[playerid][i][VehicleOwned] == 1)
        {
            new msg[128];
            format(msg, sizeof(msg), "- Slot %d: Model %d", i + 1, PlayerVehicles[playerid][i][VehicleModel]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:spawnmyveh(playerid, params[])
{
    new slot;
    if (sscanf(params, "i", slot)) return SendClientMessage(playerid, -1, "Usage: /spawnmyveh [slot]");

    if (slot < 1 || slot > MAX_PLAYER_VEHICLES) return SendClientMessage(playerid, -1, "Invalid slot.");

    slot -= 1;

    if (PlayerVehicles[playerid][slot][VehicleOwned] == 0)
        return SendClientMessage(playerid, -1, "No vehicle in that slot.");

    CreateVehicle(
        PlayerVehicles[playerid][slot][VehicleModel],
        PlayerVehicles[playerid][slot][VehicleX] + 2.0,
        PlayerVehicles[playerid][slot][VehicleY],
        PlayerVehicles[playerid][slot][VehicleZ],
        0.0, -1, -1, 60
    );

    SendClientMessage(playerid, -1, "Your vehicle has been spawned.");
    return 1;
}

new CurrentWeather = 1;
new WeatherTimer;

stock SetDynamicWeather(weatherid)
{
    CurrentWeather = weatherid;
    SetWeather(weatherid);

    new msg[64];
    format(msg, sizeof(msg), "Weather changed to ID %d.", weatherid);
    SendClientMessageToAll(-1, msg);
}

public OnGameModeInit()
{
    WeatherTimer = SetTimer("CycleWeather", 60000, true); // every 60 seconds
    return 1;
}

forward CycleWeather();
public CycleWeather()
{
    CurrentWeather++;
    if (CurrentWeather > 45) CurrentWeather = 1;

    SetDynamicWeather(CurrentWeather);
    return 1;
}

CMD:setweather(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 3) return SendClientMessage(playerid, -1, "You don't have permission to change weather.");

    new weatherid;
    if (sscanf(params, "i", weatherid)) return SendClientMessage(playerid, -1, "Usage: /setweather [id]");

    if (weatherid < 0 || weatherid > 45) return SendClientMessage(playerid, -1, "Invalid weather ID.");

    SetDynamicWeather(weatherid);
    return 1;
}

CMD:weather(playerid, params[])
{
    new msg[64];
    format(msg, sizeof(msg), "Current weather ID: %d", CurrentWeather);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

#define MAX_VEHICLES 1000

new VehicleFuel[MAX_VEHICLES];

public OnVehicleSpawn(vehicleid)
{
    VehicleFuel[vehicleid] = 100; // Full tank
    return 1;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    if (!ispassenger)
    {
        new msg[64];
        format(msg, sizeof(msg), "Fuel: %d%%", VehicleFuel[vehicleid]);
        SendClientMessage(playerid, -1, msg);
    }
    return 1;
}

public OnPlayerUpdate(playerid)
{
    new vehicleid = GetPlayerVehicleID(playerid);
    if (vehicleid != 0 && IsPlayerInAnyVehicle(playerid))
    {
        VehicleFuel[vehicleid]--;
        if (VehicleFuel[vehicleid] <= 0)
        {
            VehicleFuel[vehicleid] = 0;
            SetVehicleParamsEx(vehicleid, 0, 0, 0, 0, 0, 0, 0);
            SendClientMessage(playerid, -1, "Your vehicle is out of fuel!");
        }
    }
    return 1;
}

CMD:refuel(playerid, params[])
{
    new vehicleid = GetPlayerVehicleID(playerid);
    if (vehicleid == 0) return SendClientMessage(playerid, -1, "You're not in a vehicle.");

    if (HasItem(playerid, "fuelcan", 1))
    {
        RemoveItem(playerid, "fuelcan", 1);
        VehicleFuel[vehicleid] = 100;
        SetVehicleParamsEx(vehicleid, 1, 1, 0, 0, 0, 0, 0);
        SendClientMessage(playerid, -1, "You refueled your vehicle.");
    }
    else
    {
        SendClientMessage(playerid, -1, "You need a fuel can to refuel.");
    }
    return 1;
}

#define MAX_MISSIONS 20
#define MISSION_NAME_LEN 32

enum MissionData
{
    MissionName[MISSION_NAME_LEN],
    MissionObjective[MISSION_NAME_LEN],
    MissionReward,
    MissionActive
};

new PlayerMissions[MAX_PLAYERS][MAX_MISSIONS][MissionData];

stock AssignMission(playerid, missionid, name[], objective[], reward)
{
    strmid(PlayerMissions[playerid][missionid][MissionName], name, 0, MISSION_NAME_LEN);
    strmid(PlayerMissions[playerid][missionid][MissionObjective], objective, 0, MISSION_NAME_LEN);
    PlayerMissions[playerid][missionid][MissionReward] = reward;
    PlayerMissions[playerid][missionid][MissionActive] = 1;

    new msg[128];
    format(msg, sizeof(msg), "Mission Assigned: %s - Objective: %s", name, objective);
    SendClientMessage(playerid, -1, msg);
}

CMD:missions(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your Active Missions:");

    for (new i = 0; i < MAX_MISSIONS; i++)
    {
        if (PlayerMissions[playerid][i][MissionActive] == 1)
        {
            new msg[128];
            format(msg, sizeof(msg), "- %s: %s (Reward: $%d)",
                PlayerMissions[playerid][i][MissionName],
                PlayerMissions[playerid][i][MissionObjective],
                PlayerMissions[playerid][i][MissionReward]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:completemission(playerid, params[])
{
    new missionid;
    if (sscanf(params, "i", missionid)) return SendClientMessage(playerid, -1, "Usage: /completemission [id]");

    if (missionid < 0 || missionid >= MAX_MISSIONS) return SendClientMessage(playerid, -1, "Invalid mission ID.");
    if (PlayerMissions[playerid][missionid][MissionActive] == 0) return SendClientMessage(playerid, -1, "No active mission in that slot.");

    PlayerMoney[playerid] += PlayerMissions[playerid][missionid][MissionReward];
    PlayerMissions[playerid][missionid][MissionActive] = 0;

    new msg[128];
    format(msg, sizeof(msg), "Mission Completed: %s. You earned $%d.",
        PlayerMissions[playerid][missionid][MissionName],
        PlayerMissions[playerid][missionid][MissionReward]);
    SendClientMessage(playerid, -1, msg);

    AddXP(playerid, 50); // Optional XP reward
    return 1;
}

new PlayerTemperature[MAX_PLAYERS];
new PlayerFatigue[MAX_PLAYERS];

stock InitializeSurvival(playerid)
{
    PlayerTemperature[playerid] = 37; // Normal body temp
    PlayerFatigue[playerid] = 0;      // Fully rested
}

public OnPlayerUpdate(playerid)
{
    // Temperature drops at night or in cold zones
    new hour;
    gettime(hour, _, _);
    if (hour >= 0 && hour <= 6) PlayerTemperature[playerid]--;

    // Fatigue increases over time
    PlayerFatigue[playerid]++;
    if (PlayerFatigue[playerid] >= 100)
    {
        SetPlayerHealth(playerid, GetPlayerHealth(playerid) - 1.0);
        SendClientMessage(playerid, -1, "You're exhausted. Find a place to sleep.");
    }

    // Hypothermia risk
    if (PlayerTemperature[playerid] <= 30)
    {
        SetPlayerHealth(playerid, GetPlayerHealth(playerid) - 1.0);
        SendClientMessage(playerid, -1, "You're freezing! Find warmth.");
    }

    return 1;
}

CMD:sleep(playerid, params[])
{
    PlayerFatigue[playerid] = 0;
    SetPlayerHealth(playerid, GetPlayerHealth(playerid) + 10.0);
    SendClientMessage(playerid, -1, "You slept and feel refreshed.");
    return 1;
}

CMD:warmup(playerid, params[])
{
    PlayerTemperature[playerid] += 5;
    if (PlayerTemperature[playerid] > 37) PlayerTemperature[playerid] = 37;
    SendClientMessage(playerid, -1, "You warmed up.");
    return 1;
}

CMD:status(playerid, params[])
{
    new msg[128];
    format(msg, sizeof(msg), "Temperature: %d°C | Fatigue: %d%%", PlayerTemperature[playerid], PlayerFatigue[playerid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

#define MAX_CROPS 100

enum CropData
{
    Float:CropX,
    Float:CropY,
    Float:CropZ,
    CropType[32],
    CropGrowth
};

new Crops[MAX_CROPS];

stock PlantCrop(playerid, type[])
{
    for (new i = 0; i < MAX_CROPS; i++)
    {
        if (Crops[i][CropGrowth] == 0)
        {
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid, x, y, z);

            Crops[i][CropX] = x;
            Crops[i][CropY] = y;
            Crops[i][CropZ] = z;
            strmid(Crops[i][CropType], type, 0, 32);
            Crops[i][CropGrowth] = 1;

            SendClientMessage(playerid, -1, "Crop planted.");
            return;
        }
    }
    SendClientMessage(playerid, -1, "No space to plant more crops.");
}

public OnPlayerUpdate(playerid)
{
    // Crop growth simulation
    for (new i = 0; i < MAX_CROPS; i++)
    {
        if (Crops[i][CropGrowth] > 0 && Crops[i][CropGrowth] < 100)
        {
            Crops[i][CropGrowth]++;
        }
    }
    return 1;
}

CMD:plant(playerid, params[])
{
    new cropType[32];
    if (sscanf(params, "s[32]", cropType)) return SendClientMessage(playerid, -1, "Usage: /plant [crop]");

    if (!HasItem(playerid, cropType, 1)) return SendClientMessage(playerid, -1, "You don't have that seed.");

    RemoveItem(playerid, cropType, 1);
    PlantCrop(playerid, cropType);
    return 1;
}

CMD:harvest(playerid, params[])
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_CROPS; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, 3.0, Crops[i][CropX], Crops[i][CropY], Crops[i][CropZ]) &&
            Crops[i][CropGrowth] >= 100)
        {
            AddItem(playerid, Crops[i][CropType], 2); // Reward
            Crops[i][CropGrowth] = 0;
            SendClientMessage(playerid, -1, "You harvested your crop.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No ripe crop nearby.");
    return 1;
}

enum CraftTier
{
    TIER_BASIC,
    TIER_ADVANCED,
    TIER_ELITE
};

new PlayerCraftTier[MAX_PLAYERS];
new PlayerBlueprints[MAX_PLAYERS][10][32];

CMD:crafttier(playerid, params[])
{
    new msg[64];
    format(msg, sizeof(msg), "Your crafting tier: %d", PlayerCraftTier[playerid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:unlockbp(playerid, params[])
{
    new bpName[32];
    if (sscanf(params, "s[32]", bpName)) return SendClientMessage(playerid, -1, "Usage: /unlockbp [name]");

    for (new i = 0; i < 10; i++)
    {
        if (strlen(PlayerBlueprints[playerid][i]) == 0)
        {
            strmid(PlayerBlueprints[playerid][i], bpName, 0, 32);
            SendClientMessage(playerid, -1, "Blueprint unlocked.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You can't unlock more blueprints.");
    return 1;
}

CMD:blueprints(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your Blueprints:");
    for (new i = 0; i < 10; i++)
    {
        if (strlen(PlayerBlueprints[playerid][i]) > 0)
        {
            new msg[64];
            format(msg, sizeof(msg), "- %s", PlayerBlueprints[playerid][i]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:craftbp(playerid, params[])
{
    new bpName[32];
    if (sscanf(params, "s[32]", bpName)) return SendClientMessage(playerid, -1, "Usage: /craftbp [name]");

    for (new i = 0; i < 10; i++)
    {
        if (strcmp(PlayerBlueprints[playerid][i], bpName, true) == 0)
        {
            // Example: check tier
            if (PlayerCraftTier[playerid] < TIER_ADVANCED)
                return SendClientMessage(playerid, -1, "You need a higher crafting tier.");

            AddItem(playerid, bpName, 1);
            SendClientMessage(playerid, -1, "Item crafted from blueprint.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You don't have that blueprint.");
    return 1;
}

new EventParticipants[MAX_PLAYERS];
new EventInProgress = 0;
new EventType[32];
new EventReward = 0;

CMD:joinevent(playerid, params[])
{
    if (!EventInProgress) return SendClientMessage(playerid, -1, "No event is currently active.");

    if (EventParticipants[playerid]) return SendClientMessage(playerid, -1, "You're already in the event.");

    EventParticipants[playerid] = 1;
    new msg[64];
    format(msg, sizeof(msg), "You joined the event: %s", EventType);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:startevent(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 4) return SendClientMessage(playerid, -1, "You don't have permission.");

    new type[32], reward;
    if (sscanf(params, "s[32]i", type, reward)) return SendClientMessage(playerid, -1, "Usage: /startevent [type] [reward]");

    strmid(EventType, type, 0, 32);
    EventReward = reward;
    EventInProgress = 1;

    for (new i = 0; i < MAX_PLAYERS; i++) EventParticipants[i] = 0;

    new msg[128];
    format(msg, sizeof(msg), "Event Started: %s | Reward: $%d | Use /joinevent to participate!", EventType, EventReward);
    SendClientMessageToAll(-1, msg);
    return 1;
}

CMD:finishevent(playerid, params[])
{
    if (!EventInProgress) return SendClientMessage(playerid, -1, "No event is active.");

    if (!EventParticipants[playerid]) return SendClientMessage(playerid, -1, "You're not part of the event.");

    PlayerMoney[playerid] += EventReward;
    AddXP(playerid, 100);
    UnlockAchievement(playerid, ACH_EARNED_1000);

    EventParticipants[playerid] = 0;

    new msg[128];
    format(msg, sizeof(msg), "You completed the event and earned $%d!", EventReward);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:stopevent(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 4) return SendClientMessage(playerid, -1, "You don't have permission.");

    EventInProgress = 0;
    strmid(EventType, "None", 0, 32);
    EventReward = 0;

    SendClientMessageToAll(-1, "Event has ended.");
    return 1;
}

new ServerTaxRate = 10; // percent
new ServerInflation = 0;

CMD:earn(playerid, params[])
{
    new amount;
    if (sscanf(params, "i", amount)) return SendClientMessage(playerid, -1, "Usage: /earn [amount]");

    new taxed = amount * ServerTaxRate / 100;
    new finalAmount = amount - taxed;

    PlayerMoney[playerid] += finalAmount;
    ServerInflation += taxed;

    new msg[128];
    format(msg, sizeof(msg), "You earned $%d (Tax: $%d)", finalAmount, taxed);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:taxrate(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 4) return SendClientMessage(playerid, -1, "You don't have permission.");

    new rate;
    if (sscanf(params, "i", rate)) return SendClientMessage(playerid, -1, "Usage: /taxrate [percent]");

    if (rate < 0 || rate > 50) return SendClientMessage(playerid, -1, "Tax rate must be between 0 and 50.");

    ServerTaxRate = rate;
    new msg[64];
    format(msg, sizeof(msg), "Server tax rate set to %d%%.", rate);
    SendClientMessageToAll(-1, msg);
    return 1;
}

CMD:economy(playerid, params[])
{
    new msg[128];
    format(msg, sizeof(msg), "Current Tax Rate: %d%% | Inflation Pool: $%d", ServerTaxRate, ServerInflation);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:stimulus(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 4) return SendClientMessage(playerid, -1, "You don't have permission.");

    new payout = ServerInflation / GetPlayerCount();
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i))
        {
            PlayerMoney[i] += payout;
            SendClientMessage(i, -1, "You received a stimulus payout.");
        }
    }

    ServerInflation = 0;
    SendClientMessageToAll(-1, "Stimulus distributed. Inflation reset.");
    return 1;
}

#define MAX_TOWNS 50
#define TOWN_NAME_LEN 32

enum TownData
{
    TownName[TOWN_NAME_LEN],
    Float:TownX,
    Float:TownY,
    Float:TownZ,
    TownRadius,
    TownOwner[MAX_PLAYER_NAME]
};

new Towns[MAX_TOWNS][TownData];

stock CreateTown(id, name[], Float:x, Float:y, Float:z, radius)
{
    strmid(Towns[id][TownName], name, 0, TOWN_NAME_LEN);
    Towns[id][TownX] = x;
    Towns[id][TownY] = y;
    Towns[id][TownZ] = z;
    Towns[id][TownRadius] = radius;
    strmid(Towns[id][TownOwner], "None", 0, 4);
}

CMD:claimtown(playerid, params[])
{
    for (new i = 0; i < MAX_TOWNS; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, Towns[i][TownRadius], Towns[i][TownX], Towns[i][TownY], Towns[i][TownZ]))
        {
            if (strcmp(Towns[i][TownOwner], "None", true) != 0)
                return SendClientMessage(playerid, -1, "This town is already claimed.");

            strmid(Towns[i][TownOwner], PlayerName[playerid], 0, MAX_PLAYER_NAME);

            new msg[128];
            format(msg, sizeof(msg), "You claimed the town: %s", Towns[i][TownName]);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You're not near any unclaimed town.");
    return 1;
}

CMD:mytowns(playerid, params[])
{
    SendClientMessage(playerid, -1, "Your Towns:");

    for (new i = 0; i < MAX_TOWNS; i++)
    {
        if (strcmp(Towns[i][TownOwner], PlayerName[playerid], true) == 0)
        {
            new msg[64];
            format(msg, sizeof(msg), "- %s", Towns[i][TownName]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:towns(playerid, params[])
{
    SendClientMessage(playerid, -1, "All Towns:");

    for (new i = 0; i < MAX_TOWNS; i++)
    {
        new msg[128];
        format(msg, sizeof(msg), "- %s | Owner: %s", Towns[i][TownName], Towns[i][TownOwner]);
        SendClientMessage(playerid, -1, msg);
    }
    return 1;
}

#define MAX_CONTRACTS 50

enum ContractData
{
    ContractCreator[MAX_PLAYER_NAME],
    ContractDescription[64],
    ContractReward,
    ContractAcceptedBy[MAX_PLAYER_NAME],
    ContractCompleted
};

new WorkContracts[MAX_CONTRACTS][ContractData];

CMD:createcontract(playerid, params[])
{
    new desc[64], reward;
    if (sscanf(params, "s[64]i", desc, reward)) return SendClientMessage(playerid, -1, "Usage: /createcontract [description] [reward]");

    for (new i = 0; i < MAX_CONTRACTS; i++)
    {
        if (WorkContracts[i][ContractCompleted] == 0 && strlen(WorkContracts[i][ContractCreator]) == 0)
        {
            strmid(WorkContracts[i][ContractCreator], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            strmid(WorkContracts[i][ContractDescription], desc, 0, 64);
            WorkContracts[i][ContractReward] = reward;
            strmid(WorkContracts[i][ContractAcceptedBy], "None", 0, 4);
            SendClientMessage(playerid, -1, "Contract created.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No space for more contracts.");
    return 1;
}

CMD:contracts(playerid, params[])
{
    SendClientMessage(playerid, -1, "Available Contracts:");

    for (new i = 0; i < MAX_CONTRACTS; i++)
    {
        if (WorkContracts[i][ContractCompleted] == 0 && strcmp(WorkContracts[i][ContractAcceptedBy], "None", true) == 0)
        {
            new msg[128];
            format(msg, sizeof(msg), "[%d] %s - $%d | By: %s",
                i,
                WorkContracts[i][ContractDescription],
                WorkContracts[i][ContractReward],
                WorkContracts[i][ContractCreator]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:acceptcontract(playerid, params[])
{
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /acceptcontract [id]");

    if (id < 0 || id >= MAX_CONTRACTS) return SendClientMessage(playerid, -1, "Invalid contract ID.");
    if (strcmp(WorkContracts[id][ContractAcceptedBy], "None", true) != 0)
        return SendClientMessage(playerid, -1, "Contract already accepted.");

    strmid(WorkContracts[id][ContractAcceptedBy], PlayerName[playerid], 0, MAX_PLAYER_NAME);
    SendClientMessage(playerid, -1, "You accepted the contract.");
    return 1;
}

CMD:completecontract(playerid, params[])
{
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /completecontract [id]");

    if (id < 0 || id >= MAX_CONTRACTS) return SendClientMessage(playerid, -1, "Invalid contract ID.");
    if (strcmp(WorkContracts[id][ContractAcceptedBy], PlayerName[playerid], true) != 0)
        return SendClientMessage(playerid, -1, "You didn't accept this contract.");

    WorkContracts[id][ContractCompleted] = 1;
    PlayerMoney[playerid] += WorkContracts[id][ContractReward];
    AddXP(playerid, 50);

    SendClientMessage(playerid, -1, "Contract completed. You earned your reward.");
    return 1;
}

new PlayerRatings[MAX_PLAYERS];
new PlayerRatingCount[MAX_PLAYERS];

CMD:rate(playerid, params[])
{
    new targetid, score;
    if (sscanf(params, "ii", targetid, score)) return SendClientMessage(playerid, -1, "Usage: /rate [playerid] [1-5]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");
    if (score < 1 || score > 5) return SendClientMessage(playerid, -1, "Rating must be between 1 and 5.");

    PlayerRatings[targetid] += score;
    PlayerRatingCount[targetid]++;

    new msg[64];
    format(msg, sizeof(msg), "You rated %s with %d stars.", PlayerName[targetid], score);
    SendClientMessage(playerid, -1, msg);

    format(msg, sizeof(msg), "You received a rating of %d stars.", score);
    SendClientMessage(targetid, -1, msg);
    return 1;
}

CMD:reputation(playerid, params[])
{
    new avg;
    if (PlayerRatingCount[playerid] > 0)
        avg = PlayerRatings[playerid] / PlayerRatingCount[playerid];
    else
        avg = 0;

    new msg[64];
    format(msg, sizeof(msg), "Your reputation: %d stars (%d ratings)", avg, PlayerRatingCount[playerid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:viewrep(playerid, params[])
{
    new targetid;
    if (sscanf(params, "i", targetid)) return SendClientMessage(playerid, -1, "Usage: /viewrep [playerid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");

    new avg;
    if (PlayerRatingCount[targetid] > 0)
        avg = PlayerRatings[targetid] / PlayerRatingCount[targetid];
    else
        avg = 0;

    new msg[64];
    format(msg, sizeof(msg), "%s's reputation: %d stars (%d ratings)", PlayerName[targetid], avg, PlayerRatingCount[targetid]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

#define MAX_GUILDS 50
#define MAX_GUILD_MEMBERS 20
#define GUILD_NAME_LEN 32

enum GuildData
{
    GuildName[GUILD_NAME_LEN],
    GuildLeader[MAX_PLAYER_NAME],
    GuildMembers[MAX_GUILD_MEMBERS][MAX_PLAYER_NAME]
};

new Guilds[MAX_GUILDS][GuildData];

CMD:createguild(playerid, params[])
{
    new name[GUILD_NAME_LEN];
    if (sscanf(params, "s[32]", name)) return SendClientMessage(playerid, -1, "Usage: /createguild [name]");

    for (new i = 0; i < MAX_GUILDS; i++)
    {
        if (strlen(Guilds[i][GuildName]) == 0)
        {
            strmid(Guilds[i][GuildName], name, 0, GUILD_NAME_LEN);
            strmid(Guilds[i][GuildLeader], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            strmid(Guilds[i][GuildMembers][0], PlayerName[playerid], 0, MAX_PLAYER_NAME);

            new msg[64];
            format(msg, sizeof(msg), "Guild '%s' created. You are the leader.", name);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No space for more guilds.");
    return 1;
}

CMD:inviteguild(playerid, params[])
{
    new targetid;
    if (sscanf(params, "i", targetid)) return SendClientMessage(playerid, -1, "Usage: /inviteguild [playerid]");

    if (!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "Player not connected.");

    for (new i = 0; i < MAX_GUILDS; i++)
    {
        if (strcmp(Guilds[i][GuildLeader], PlayerName[playerid], true) == 0)
        {
            for (new j = 0; j < MAX_GUILD_MEMBERS; j++)
            {
                if (strlen(Guilds[i][GuildMembers][j]) == 0)
                {
                    strmid(Guilds[i][GuildMembers][j], PlayerName[targetid], 0, MAX_PLAYER_NAME);
                    SendClientMessage(playerid, -1, "Player invited to your guild.");
                    SendClientMessage(targetid, -1, "You have been invited to a guild.");
                    return 1;
                }
            }
            return SendClientMessage(playerid, -1, "Your guild is full.");
        }
    }

    SendClientMessage(playerid, -1, "You're not a guild leader.");
    return 1;
}

CMD:guilds(playerid, params[])
{
    SendClientMessage(playerid, -1, "Guilds:");

    for (new i = 0; i < MAX_GUILDS; i++)
    {
        if (strlen(Guilds[i][GuildName]) > 0)
        {
            new msg[128];
            format(msg, sizeof(msg), "- %s | Leader: %s", Guilds[i][GuildName], Guilds[i][GuildLeader]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:myguild(playerid, params[])
{
    for (new i = 0; i < MAX_GUILDS; i++)
    {
        for (new j = 0; j < MAX_GUILD_MEMBERS; j++)
        {
            if (strcmp(Guilds[i][GuildMembers][j], PlayerName[playerid], true) == 0)
            {
                new msg[128];
                format(msg, sizeof(msg), "Guild: %s | Leader: %s", Guilds[i][GuildName], Guilds[i][GuildLeader]);
                SendClientMessage(playerid, -1, msg);
                return 1;
            }
        }
    }

    SendClientMessage(playerid, -1, "You're not in a guild.");
    return 1;
}

new GuildBank[MAX_GUILDS];

CMD:depositguild(playerid, params[])
{
    new amount;
    if (sscanf(params, "i", amount)) return SendClientMessage(playerid, -1, "Usage: /depositguild [amount]");

    if (PlayerMoney[playerid] < amount) return SendClientMessage(playerid, -1, "You don't have enough money.");

    for (new i = 0; i < MAX_GUILDS; i++)
    {
        for (new j = 0; j < MAX_GUILD_MEMBERS; j++)
        {
            if (strcmp(Guilds[i][GuildMembers][j], PlayerName[playerid], true) == 0)
            {
                PlayerMoney[playerid] -= amount;
                GuildBank[i] += amount;

                new msg[128];
                format(msg, sizeof(msg), "You deposited $%d into your guild bank.", amount);
                SendClientMessage(playerid, -1, msg);
                return 1;
            }
        }
    }

    SendClientMessage(playerid, -1, "You're not in a guild.");
    return 1;
}

CMD:withdrawguild(playerid, params[])
{
    new amount;
    if (sscanf(params, "i", amount)) return SendClientMessage(playerid, -1, "Usage: /withdrawguild [amount]");

    for (new i = 0; i < MAX_GUILDS; i++)
    {
        if (strcmp(Guilds[i][GuildLeader], PlayerName[playerid], true) == 0)
        {
            if (GuildBank[i] < amount) return SendClientMessage(playerid, -1, "Guild bank doesn't have enough funds.");

            GuildBank[i] -= amount;
            PlayerMoney[playerid] += amount;

            new msg[128];
            format(msg, sizeof(msg), "You withdrew $%d from your guild bank.", amount);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You're not a guild leader.");
    return 1;
}

CMD:guildbank(playerid, params[])
{
    for (new i = 0; i < MAX_GUILDS; i++)
    {
        for (new j = 0; j < MAX_GUILD_MEMBERS; j++)
        {
            if (strcmp(Guilds[i][GuildMembers][j], PlayerName[playerid], true) == 0)
            {
                new msg[64];
                format(msg, sizeof(msg), "Guild Bank Balance: $%d", GuildBank[i]);
                SendClientMessage(playerid, -1, msg);
                return 1;
            }
        }
    }

    SendClientMessage(playerid, -1, "You're not in a guild.");
    return 1;
}

#define MAX_ZONES 30
#define ZONE_NAME_LEN 32

enum ZoneData
{
    ZoneName[ZONE_NAME_LEN],
    Float:ZoneX,
    Float:ZoneY,
    Float:ZoneZ,
    ZoneRadius,
    ZoneOwner[MAX_PLAYER_NAME],
    ZoneUnderAttack
};

new Zones[MAX_ZONES][ZoneData];

stock CreateZone(id, name[], Float:x, Float:y, Float:z, radius)
{
    strmid(Zones[id][ZoneName], name, 0, ZONE_NAME_LEN);
    Zones[id][ZoneX] = x;
    Zones[id][ZoneY] = y;
    Zones[id][ZoneZ] = z;
    Zones[id][ZoneRadius] = radius;
    strmid(Zones[id][ZoneOwner], "None", 0, 4);
    Zones[id][ZoneUnderAttack] = 0;
}

CMD:claimzone(playerid, params[])
{
    for (new i = 0; i < MAX_ZONES; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, Zones[i][ZoneRadius], Zones[i][ZoneX], Zones[i][ZoneY], Zones[i][ZoneZ]))
        {
            if (strcmp(Zones[i][ZoneOwner], "None", true) != 0)
                return SendClientMessage(playerid, -1, "Zone already claimed.");

            strmid(Zones[i][ZoneOwner], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            SendClientMessage(playerid, -1, "You claimed this zone.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You're not near any unclaimed zone.");
    return 1;
}

CMD:attackzone(playerid, params[])
{
    for (new i = 0; i < MAX_ZONES; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, Zones[i][ZoneRadius], Zones[i][ZoneX], Zones[i][ZoneY], Zones[i][ZoneZ]))
        {
            if (strcmp(Zones[i][ZoneOwner], PlayerName[playerid], true) == 0)
                return SendClientMessage(playerid, -1, "You already own this zone.");

            Zones[i][ZoneUnderAttack] = 1;
            new msg[128];
            format(msg, sizeof(msg), "Zone '%s' is under attack by %s!", Zones[i][ZoneName], PlayerName[playerid]);
            SendClientMessageToAll(-1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You're not near any zone.");
    return 1;
}

CMD:conquerzone(playerid, params[])
{
    for (new i = 0; i < MAX_ZONES; i++)
    {
        if (Zones[i][ZoneUnderAttack] == 1 &&
            IsPlayerInRangeOfPoint(playerid, Zones[i][ZoneRadius], Zones[i][ZoneX], Zones[i][ZoneY], Zones[i][ZoneZ]))
        {
            strmid(Zones[i][ZoneOwner], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            Zones[i][ZoneUnderAttack] = 0;

            new msg[128];
            format(msg, sizeof(msg), "Zone '%s' has been conquered by %s!", Zones[i][ZoneName], PlayerName[playerid]);
            SendClientMessageToAll(-1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No zone to conquer here.");
    return 1;
}

CMD:zones(playerid, params[])
{
    SendClientMessage(playerid, -1, "Zones:");

    for (new i = 0; i < MAX_ZONES; i++)
    {
        new msg[128];
        format(msg, sizeof(msg), "- %s | Owner: %s | Status: %s",
            Zones[i][ZoneName],
            Zones[i][ZoneOwner],
            Zones[i][ZoneUnderAttack] ? "Under Attack" : "Stable");
        SendClientMessage(playerid, -1, msg);
    }
    return 1;
}

#define MAX_DIALOGUES 100
#define DIALOGUE_TEXT_LEN 128

enum DialogueData
{
    DialogueNPC[MAX_PLAYER_NAME],
    DialogueText[DIALOGUE_TEXT_LEN],
    DialogueOption1[DIALOGUE_TEXT_LEN],
    DialogueOption2[DIALOGUE_TEXT_LEN],
    DialogueNext1,
    DialogueNext2
};

new Dialogues[MAX_DIALOGUES][DialogueData];

stock CreateDialogue(id, npc[], text[], opt1[], opt2[], next1, next2)
{
    strmid(Dialogues[id][DialogueNPC], npc, 0, MAX_PLAYER_NAME);
    strmid(Dialogues[id][DialogueText], text, 0, DIALOGUE_TEXT_LEN);
    strmid(Dialogues[id][DialogueOption1], opt1, 0, DIALOGUE_TEXT_LEN);
    strmid(Dialogues[id][DialogueOption2], opt2, 0, DIALOGUE_TEXT_LEN);
    Dialogues[id][DialogueNext1] = next1;
    Dialogues[id][DialogueNext2] = next2;
}

new PlayerDialogueStage[MAX_PLAYERS];

CMD:talknpc(playerid, params[])
{
    new npcname[MAX_PLAYER_NAME];
    if (sscanf(params, "s[24]", npcname)) return SendClientMessage(playerid, -1, "Usage: /talknpc [name]");

    for (new i = 0; i < MAX_DIALOGUES; i++)
    {
        if (strcmp(Dialogues[i][DialogueNPC], npcname, true) == 0)
        {
            PlayerDialogueStage[playerid] = i;
            ShowDialogue(playerid, i);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No dialogue found for that NPC.");
    return 1;
}

stock ShowDialogue(playerid, id)
{
    new msg[256];
    format(msg, sizeof(msg), "%s\n1. %s\n2. %s",
        Dialogues[id][DialogueText],
        Dialogues[id][DialogueOption1],
        Dialogues[id][DialogueOption2]);
    ShowPlayerDialog(playerid, 1000, DIALOG_STYLE_LIST, "NPC Dialogue", msg, "Select", "Exit");
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == 1000 && response)
    {
        new stage = PlayerDialogueStage[playerid];
        new nextStage = listitem == 0 ? Dialogues[stage][DialogueNext1] : Dialogues[stage][DialogueNext2];

        if (nextStage == -1)
        {
            SendClientMessage(playerid, -1, "The conversation ends here.");
            return 1;
        }

        PlayerDialogueStage[playerid] = nextStage;
        ShowDialogue(playerid, nextStage);
    }
    return 1;
}

#define MAX_STATIONS 20
#define STATION_NAME_LEN 32

enum StationData
{
    StationName[STATION_NAME_LEN],
    Float:StationX,
    Float:StationY,
    Float:StationZ,
    StationType[32]
};

new CraftStations[MAX_STATIONS][StationData];

stock CreateStation(id, name[], type[], Float:x, Float:y, Float:z)
{
    strmid(CraftStations[id][StationName], name, 0, STATION_NAME_LEN);
    strmid(CraftStations[id][StationType], type, 0, 32);
    CraftStations[id][StationX] = x;
    CraftStations[id][StationY] = y;
    CraftStations[id][StationZ] = z;
    CreatePickup(1239, 23, x, y, z, -1); // Visual marker
}

CMD:craftat(playerid, params[])
{
    new item[32];
    if (sscanf(params, "s[32]", item)) return SendClientMessage(playerid, -1, "Usage: /craftat [item]");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_STATIONS; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, 3.0, CraftStations[i][StationX], CraftStations[i][StationY], CraftStations[i][StationZ]))
        {
            if (IsItemCraftableAt(item, CraftStations[i][StationType]))
            {
                AddItem(playerid, item, 1);
                SendClientMessage(playerid, -1, "Item crafted successfully.");
                return 1;
            }
            else
            {
                SendClientMessage(playerid, -1, "This item can't be crafted at this station.");
                return 1;
            }
        }
    }

    SendClientMessage(playerid, -1, "You're not near any crafting station.");
    return 1;
}

stock IsItemCraftableAt(item[], type[])
{
    // Example logic
    if (strcmp(item, "iron_sword", true) == 0 && strcmp(type, "forge", true) == 0) return true;
    if (strcmp(item, "healing_potion", true) == 0 && strcmp(type, "alchemy", true) == 0) return true;
    return false;
}

#define MAX_PLAYER_SHOPS 50
#define SHOP_ITEM_NAME_LEN 32

enum ShopData
{
    ShopOwner[MAX_PLAYER_NAME],
    Float:ShopX,
    Float:ShopY,
    Float:ShopZ,
    ShopItem[SHOP_ITEM_NAME_LEN],
    ShopPrice
};

new PlayerShops[MAX_PLAYER_SHOPS][ShopData];

stock CreatePlayerShop(playerid, item[], price)
{
    for (new i = 0; i < MAX_PLAYER_SHOPS; i++)
    {
        if (strlen(PlayerShops[i][ShopOwner]) == 0)
        {
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid, x, y, z);

            strmid(PlayerShops[i][ShopOwner], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            PlayerShops[i][ShopX] = x;
            PlayerShops[i][ShopY] = y;
            PlayerShops[i][ShopZ] = z;
            strmid(PlayerShops[i][ShopItem], item, 0, SHOP_ITEM_NAME_LEN);
            PlayerShops[i][ShopPrice] = price;

            CreatePickup(1274, 23, x, y, z, -1);
            SendClientMessage(playerid, -1, "Shop created.");
            return;
        }
    }

    SendClientMessage(playerid, -1, "No space for more shops.");
}

CMD:createshop(playerid, params[])
{
    new item[32], price;
    if (sscanf(params, "s[32]i", item, price)) return SendClientMessage(playerid, -1, "Usage: /createshop [item] [price]");

    if (!HasItem(playerid, item, 1)) return SendClientMessage(playerid, -1, "You don't have that item.");

    RemoveItem(playerid, item, 1);
    CreatePlayerShop(playerid, item, price);
    return 1;
}

CMD:buyfromshop(playerid, params[])
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for (new i = 0; i < MAX_PLAYER_SHOPS; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, 3.0, PlayerShops[i][ShopX], PlayerShops[i][ShopY], PlayerShops[i][ShopZ]))
        {
            new price = PlayerShops[i][ShopPrice];
            if (PlayerMoney[playerid] < price) return SendClientMessage(playerid, -1, "You don't have enough money.");

            PlayerMoney[playerid] -= price;
            AddItem(playerid, PlayerShops[i][ShopItem], 1);

            new ownerid = GetPlayerIDByName(PlayerShops[i][ShopOwner]);
            if (ownerid != INVALID_PLAYER_ID) PlayerMoney[ownerid] += price;

            new msg[128];
            format(msg, sizeof(msg), "You bought %s for $%d.", PlayerShops[i][ShopItem], price);
            SendClientMessage(playerid, -1, msg);
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No shop nearby.");
    return 1;
}

#define MAX_AUCTIONS 50
#define AUCTION_ITEM_LEN 32

enum AuctionData
{
    AuctionItem[AUCTION_ITEM_LEN],
    AuctionSeller[MAX_PLAYER_NAME],
    AuctionPrice,
    AuctionActive
};

new Auctions[MAX_AUCTIONS][AuctionData];

CMD:listauction(playerid, params[])
{
    new item[32], price;
    if (sscanf(params, "s[32]i", item, price)) return SendClientMessage(playerid, -1, "Usage: /listauction [item] [price]");

    if (!HasItem(playerid, item, 1)) return SendClientMessage(playerid, -1, "You don't have that item.");

    for (new i = 0; i < MAX_AUCTIONS; i++)
    {
        if (Auctions[i][AuctionActive] == 0)
        {
            strmid(Auctions[i][AuctionItem], item, 0, AUCTION_ITEM_LEN);
            strmid(Auctions[i][AuctionSeller], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            Auctions[i][AuctionPrice] = price;
            Auctions[i][AuctionActive] = 1;

            RemoveItem(playerid, item, 1);
            SendClientMessage(playerid, -1, "Item listed in auction house.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "Auction house is full.");
    return 1;
}

CMD:auctions(playerid, params[])
{
    SendClientMessage(playerid, -1, "Auction Listings:");

    for (new i = 0; i < MAX_AUCTIONS; i++)
    {
        if (Auctions[i][AuctionActive] == 1)
        {
            new msg[128];
            format(msg, sizeof(msg), "[%d] %s - $%d | Seller: %s",
                i,
                Auctions[i][AuctionItem],
                Auctions[i][AuctionPrice],
                Auctions[i][AuctionSeller]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:buyauction(playerid, params[])
{
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /buyauction [id]");

    if (id < 0 || id >= MAX_AUCTIONS || Auctions[id][AuctionActive] == 0)
        return SendClientMessage(playerid, -1, "Invalid auction ID.");

    new price = Auctions[id][AuctionPrice];
    if (PlayerMoney[playerid] < price) return SendClientMessage(playerid, -1, "You don't have enough money.");

    PlayerMoney[playerid] -= price;
    AddItem(playerid, Auctions[id][AuctionItem], 1);

    new sellerid = GetPlayerIDByName(Auctions[id][AuctionSeller]);
    if (sellerid != INVALID_PLAYER_ID) PlayerMoney[sellerid] += price;

    Auctions[id][AuctionActive] = 0;

    new msg[128];
    format(msg, sizeof(msg), "You bought %s for $%d.", Auctions[id][AuctionItem], price);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

#define MAX_LEADERBOARD_ENTRIES 100

enum LeaderboardData
{
    LBName[MAX_PLAYER_NAME],
    LBXP,
    LBMoney,
    LBKills
};

new Leaderboard[MAX_LEADERBOARD_ENTRIES][LeaderboardData];

stock UpdateLeaderboard(playerid)
{
    for (new i = 0; i < MAX_LEADERBOARD_ENTRIES; i++)
    {
        if (strcmp(Leaderboard[i][LBName], PlayerName[playerid], true) == 0)
        {
            Leaderboard[i][LBXP] = PlayerXP[playerid];
            Leaderboard[i][LBMoney] = PlayerMoney[playerid];
            Leaderboard[i][LBKills] = PlayerKills[playerid];
            return;
        }
    }

    for (new i = 0; i < MAX_LEADERBOARD_ENTRIES; i++)
    {
        if (strlen(Leaderboard[i][LBName]) == 0)
        {
            strmid(Leaderboard[i][LBName], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            Leaderboard[i][LBXP] = PlayerXP[playerid];
            Leaderboard[i][LBMoney] = PlayerMoney[playerid];
            Leaderboard[i][LBKills] = PlayerKills[playerid];
            return;
        }
    }
}

CMD:leaderboard(playerid, params[])
{
    SendClientMessage(playerid, -1, "Top Players:");

    for (new i = 0; i < 10; i++)
    {
        if (strlen(Leaderboard[i][LBName]) > 0)
        {
            new msg[128];
            format(msg, sizeof(msg), "[%d] %s | XP: %d | $%d | Kills: %d",
                i + 1,
                Leaderboard[i][LBName],
                Leaderboard[i][LBXP],
                Leaderboard[i][LBMoney],
                Leaderboard[i][LBKills]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

#define MAX_DUNGEONS 20

enum DungeonData
{
    DungeonName[32],
    Float:EntryX,
    Float:EntryY,
    Float:EntryZ,
    DungeonInterior,
    Float:InsideX,
    Float:InsideY,
    Float:InsideZ,
    DungeonActive
};

new Dungeons[MAX_DUNGEONS][DungeonData];
new PlayerInDungeon[MAX_PLAYERS];

stock CreateDungeon(id, name[], Float:entryX, Float:entryY, Float:entryZ, interior, Float:insideX, Float:insideY, Float:insideZ)
{
    strmid(Dungeons[id][DungeonName], name, 0, 32);
    Dungeons[id][EntryX] = entryX;
    Dungeons[id][EntryY] = entryY;
    Dungeons[id][EntryZ] = entryZ;
    Dungeons[id][DungeonInterior] = interior;
    Dungeons[id][InsideX] = insideX;
    Dungeons[id][InsideY] = insideY;
    Dungeons[id][InsideZ] = insideZ;
    Dungeons[id][DungeonActive] = 1;

    CreatePickup(1318, 23, entryX, entryY, entryZ, -1); // Dungeon entrance
}

CMD:enterdungeon(playerid, params[])
{
    for (new i = 0; i < MAX_DUNGEONS; i++)
    {
        if (Dungeons[i][DungeonActive] &&
            IsPlayerInRangeOfPoint(playerid, 3.0, Dungeons[i][EntryX], Dungeons[i][EntryY], Dungeons[i][EntryZ]))
        {
            SetPlayerInterior(playerid, Dungeons[i][DungeonInterior]);
            SetPlayerPos(playerid, Dungeons[i][InsideX], Dungeons[i][InsideY], Dungeons[i][InsideZ]);
            PlayerInDungeon[playerid] = i;

            SendClientMessage(playerid, -1, "You entered the dungeon.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "No dungeon nearby.");
    return 1;
}

CMD:exitdungeon(playerid, params[])
{
    new id = PlayerInDungeon[playerid];
    if (id == -1) return SendClientMessage(playerid, -1, "You're not in a dungeon.");

    SetPlayerInterior(playerid, 0);
    SetPlayerPos(playerid, Dungeons[id][EntryX] + 1.0, Dungeons[id][EntryY], Dungeons[id][EntryZ]);
    PlayerInDungeon[playerid] = -1;

    SendClientMessage(playerid, -1, "You exited the dungeon.");
    return 1;
}

new CurrentSeason[32];
new SeasonActive = 0;

CMD:startseason(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 4) return SendClientMessage(playerid, -1, "You don't have permission.");

    new season[32];
    if (sscanf(params, "s[32]", season)) return SendClientMessage(playerid, -1, "Usage: /startseason [name]");

    strmid(CurrentSeason, season, 0, 32);
    SeasonActive = 1;

    new msg[128];
    format(msg, sizeof(msg), "?? Seasonal Event Started: %s!", CurrentSeason);
    SendClientMessageToAll(-1, msg);

    // Example: Give all players a seasonal item
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i)) AddItem(i, "season_token", 1);
    }

    return 1;
}

CMD:endseason(playerid, params[])
{
    if (PlayerAdminLevel[playerid] < 4) return SendClientMessage(playerid, -1, "You don't have permission.");

    SeasonActive = 0;
    strmid(CurrentSeason, "None", 0, 32);
    SendClientMessageToAll(-1, "?? Seasonal Event has ended.");
    return 1;
}

CMD:season(playerid, params[])
{
    if (SeasonActive)
    {
        new msg[64];
        format(msg, sizeof(msg), "Current Season: %s", CurrentSeason);
        SendClientMessage(playerid, -1, msg);
    }
    else
    {
        SendClientMessage(playerid, -1, "No seasonal event is active.");
    }
    return 1;
}

CMD:redeemseason(playerid, params[])
{
    if (!SeasonActive) return SendClientMessage(playerid, -1, "No seasonal event is active.");
    if (!HasItem(playerid, "season_token", 1)) return SendClientMessage(playerid, -1, "You need a season token.");

    RemoveItem(playerid, "season_token", 1);
    AddItem(playerid, "season_reward", 1);
    SendClientMessage(playerid, -1, "You redeemed a seasonal reward!");
    return 1;
}

#define MAX_LORE_ENTRIES 50
#define LORE_TEXT_LEN 256

enum LoreData
{
    LoreTitle[64],
    LoreText[LORE_TEXT_LEN],
    LoreUnlockedBy[MAX_PLAYERS]
};

new LoreEntries[MAX_LORE_ENTRIES][LoreData];

stock CreateLoreEntry(id, title[], text[])
{
    strmid(LoreEntries[id][LoreTitle], title, 0, 64);
    strmid(LoreEntries[id][LoreText], text, 0, LORE_TEXT_LEN);
    for (new i = 0; i < MAX_PLAYERS; i++) LoreEntries[id][LoreUnlockedBy][i] = 0;
}

CMD:readlore(playerid, params[])
{
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /readlore [id]");

    if (id < 0 || id >= MAX_LORE_ENTRIES) return SendClientMessage(playerid, -1, "Invalid lore ID.");
    if (LoreEntries[id][LoreUnlockedBy][playerid] == 0)
        return SendClientMessage(playerid, -1, "You haven't unlocked this lore yet.");

    new msg[LORE_TEXT_LEN + 64];
    format(msg, sizeof(msg), "?? %s:\n%s", LoreEntries[id][LoreTitle], LoreEntries[id][LoreText]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:unlocklore(playerid, params[])
{
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /unlocklore [id]");

    if (id < 0 || id >= MAX_LORE_ENTRIES) return SendClientMessage(playerid, -1, "Invalid lore ID.");

    LoreEntries[id][LoreUnlockedBy][playerid] = 1;
    new msg[64];
    format(msg, sizeof(msg), "You unlocked lore entry: %s", LoreEntries[id][LoreTitle]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:lorebook(playerid, params[])
{
    SendClientMessage(playerid, -1, "?? Your Lore Entries:");

    for (new i = 0; i < MAX_LORE_ENTRIES; i++)
    {
        if (LoreEntries[i][LoreUnlockedBy][playerid] == 1)
        {
            new msg[64];
            format(msg, sizeof(msg), "- %s (ID: %d)", LoreEntries[i][LoreTitle], i);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

new Text:HUD_XP[MAX_PLAYERS];
new Text:HUD_Money[MAX_PLAYERS];

stock CreatePlayerHUD(playerid)
{
    HUD_XP[playerid] = TextDrawCreate(10.0, 350.0, "XP: 0");
    TextDrawFont(HUD_XP[playerid], 1);
    TextDrawLetterSize(HUD_XP[playerid], 0.3, 1.0);
    TextDrawColor(HUD_XP[playerid], 0x00FF00FF);
    TextDrawSetOutline(HUD_XP[playerid], 1);
    TextDrawShowForPlayer(playerid, HUD_XP[playerid]);

    HUD_Money[playerid] = TextDrawCreate(10.0, 370.0, "$0");
    TextDrawFont(HUD_Money[playerid], 1);
    TextDrawLetterSize(HUD_Money[playerid], 0.3, 1.0);
    TextDrawColor(HUD_Money[playerid], 0xFFFF00FF);
    TextDrawSetOutline(HUD_Money[playerid], 1);
    TextDrawShowForPlayer(playerid, HUD_Money[playerid]);
}

stock UpdatePlayerHUD(playerid)
{
    new xpText[32], moneyText[32];
    format(xpText, sizeof(xpText), "XP: %d", PlayerXP[playerid]);
    format(moneyText, sizeof(moneyText), "$%d", PlayerMoney[playerid]);

    TextDrawSetString(HUD_XP[playerid], xpText);
    TextDrawSetString(HUD_Money[playerid], moneyText);
}

public OnPlayerConnect(playerid)
{
    CreatePlayerHUD(playerid);
    return 1;
}

public OnPlayerUpdate(playerid)
{
    UpdatePlayerHUD(playerid);
    return 1;
}

#define MAX_BOOKS 100
#define BOOK_TEXT_LEN 256

enum BookData
{
    BookTitle[64],
    BookAuthor[MAX_PLAYER_NAME],
    BookText[BOOK_TEXT_LEN]
};

new PlayerBooks[MAX_BOOKS][BookData];

CMD:writebook(playerid, params[])
{
    new title[64], text[BOOK_TEXT_LEN];
    if (sscanf(params, "s[64]s[256]", title, text)) return SendClientMessage(playerid, -1, "Usage: /writebook [title] [text]");

    for (new i = 0; i < MAX_BOOKS; i++)
    {
        if (strlen(PlayerBooks[i][BookTitle]) == 0)
        {
            strmid(PlayerBooks[i][BookTitle], title, 0, 64);
            strmid(PlayerBooks[i][BookAuthor], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            strmid(PlayerBooks[i][BookText], text, 0, BOOK_TEXT_LEN);

            SendClientMessage(playerid, -1, "?? Your book has been published.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "Library is full.");
    return 1;
}

CMD:library(playerid, params[])
{
    SendClientMessage(playerid, -1, "?? Available Books:");

    for (new i = 0; i < MAX_BOOKS; i++)
    {
        if (strlen(PlayerBooks[i][BookTitle]) > 0)
        {
            new msg[128];
            format(msg, sizeof(msg), "[%d] %s by %s", i, PlayerBooks[i][BookTitle], PlayerBooks[i][BookAuthor]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:readbook(playerid, params[])
{
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /readbook [id]");

    if (id < 0 || id >= MAX_BOOKS || strlen(PlayerBooks[id][BookTitle]) == 0)
        return SendClientMessage(playerid, -1, "Invalid book ID.");

    new msg[BOOK_TEXT_LEN + 64];
    format(msg, sizeof(msg), "?? %s by %s:\n%s",
        PlayerBooks[id][BookTitle],
        PlayerBooks[id][BookAuthor],
        PlayerBooks[id][BookText]);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

#define MAX_CUSTOM_QUESTS 100
#define QUEST_TEXT_LEN 128

enum CustomQuestData
{
    QuestCreator[MAX_PLAYER_NAME],
    QuestTitle[64],
    QuestObjective[QUEST_TEXT_LEN],
    QuestReward,
    QuestAcceptedBy[MAX_PLAYER_NAME],
    QuestCompleted
};

new CustomQuests[MAX_CUSTOM_QUESTS][CustomQuestData];

CMD:createquest(playerid, params[])
{
    new title[64], objective[128], reward;
    if (sscanf(params, "s[64]s[128]i", title, objective, reward))
        return SendClientMessage(playerid, -1, "Usage: /createquest [title] [objective] [reward]");

    for (new i = 0; i < MAX_CUSTOM_QUESTS; i++)
    {
        if (CustomQuests[i][QuestCompleted] == 0 && strlen(CustomQuests[i][QuestCreator]) == 0)
        {
            strmid(CustomQuests[i][QuestCreator], PlayerName[playerid], 0, MAX_PLAYER_NAME);
            strmid(CustomQuests[i][QuestTitle], title, 0, 64);
            strmid(CustomQuests[i][QuestObjective], objective, 0, QUEST_TEXT_LEN);
            CustomQuests[i][QuestReward] = reward;
            strmid(CustomQuests[i][QuestAcceptedBy], "None", 0, 4);

            SendClientMessage(playerid, -1, "?? Quest created.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "Quest list is full.");
    return 1;
}

CMD:quests(playerid, params[])
{
    SendClientMessage(playerid, -1, "?? Available Player Quests:");

    for (new i = 0; i < MAX_CUSTOM_QUESTS; i++)
    {
        if (CustomQuests[i][QuestCompleted] == 0 && strcmp(CustomQuests[i][QuestAcceptedBy], "None", true) == 0)
        {
            new msg[128];
            format(msg, sizeof(msg), "[%d] %s - %s ($%d) by %s",
                i,
                CustomQuests[i][QuestTitle],
                CustomQuests[i][QuestObjective],
                CustomQuests[i][QuestReward],
                CustomQuests[i][QuestCreator]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:acceptquest(playerid, params[])
{
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /acceptquest [id]");

    if (id < 0 || id >= MAX_CUSTOM_QUESTS || strcmp(CustomQuests[id][QuestAcceptedBy], "None", true) != 0)
        return SendClientMessage(playerid, -1, "Invalid or already accepted quest.");

    strmid(CustomQuests[id][QuestAcceptedBy], PlayerName[playerid], 0, MAX_PLAYER_NAME);
    SendClientMessage(playerid, -1, "You accepted the quest.");
    return 1;
}

CMD:completequest(playerid, params[])
{
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /completequest [id]");

    if (id < 0 || id >= MAX_CUSTOM_QUESTS) return SendClientMessage(playerid, -1, "Invalid quest ID.");
    if (strcmp(CustomQuests[id][QuestAcceptedBy], PlayerName[playerid], true) != 0)
        return SendClientMessage(playerid, -1, "You haven't accepted this quest.");

    CustomQuests[id][QuestCompleted] = 1;
    PlayerMoney[playerid] += CustomQuests[id][QuestReward];
    AddXP(playerid, 50);

    SendClientMessage(playerid, -1, "Quest completed. You earned your reward!");
    return 1;
}

#define MAX_PLAYER_VEHICLES 5

enum VehicleData
{
    VehicleModel,
    Float:VehicleX,
    Float:VehicleY,
    Float:VehicleZ,
    VehicleColor1,
    VehicleColor2,
    VehicleOwned
};

new PlayerVehicles[MAX_PLAYERS][MAX_PLAYER_VEHICLES][VehicleData];

CMD:buyvehicle(playerid, params[])
{
    new model;
    if (sscanf(params, "i", model)) return SendClientMessage(playerid, -1, "Usage: /buyvehicle [modelid]");

    for (new i = 0; i < MAX_PLAYER_VEHICLES; i++)
    {
        if (PlayerVehicles[playerid][i][VehicleOwned] == 0)
        {
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid, x, y, z);

            PlayerVehicles[playerid][i][VehicleModel] = model;
            PlayerVehicles[playerid][i][VehicleX] = x;
            PlayerVehicles[playerid][i][VehicleY] = y;
            PlayerVehicles[playerid][i][VehicleZ] = z;
            PlayerVehicles[playerid][i][VehicleColor1] = random(126);
            PlayerVehicles[playerid][i][VehicleColor2] = random(126);
            PlayerVehicles[playerid][i][VehicleOwned] = 1;

            CreateVehicle(model, x, y, z, 0.0, PlayerVehicles[playerid][i][VehicleColor1], PlayerVehicles[playerid][i][VehicleColor2], -1);
            SendClientMessage(playerid, -1, "?? Vehicle purchased and spawned.");
            return 1;
        }
    }

    SendClientMessage(playerid, -1, "You can't own more vehicles.");
    return 1;
}

CMD:myvehicles(playerid, params[])
{
    SendClientMessage(playerid, -1, "?? Your Vehicles:");

    for (new i = 0; i < MAX_PLAYER_VEHICLES; i++)
    {
        if (PlayerVehicles[playerid][i][VehicleOwned] == 1)
        {
            new msg[64];
            format(msg, sizeof(msg), "- Slot %d: Model %d", i, PlayerVehicles[playerid][i][VehicleModel]);
            SendClientMessage(playerid, -1, msg);
        }
    }
    return 1;
}

CMD:customizevehicle(playerid, params[])
{
    new slot, color1, color2;
    if (sscanf(params, "iii", slot, color1, color2)) return SendClientMessage(playerid, -1, "Usage: /customizevehicle [slot] [color1] [color2]");

    if (slot < 0 || slot >= MAX_PLAYER_VEHICLES || PlayerVehicles[playerid][slot][VehicleOwned] == 0)
        return SendClientMessage(playerid, -1, "Invalid vehicle slot.");

    PlayerVehicles[playerid][slot][VehicleColor1] = color1;
    PlayerVehicles[playerid][slot][VehicleColor2] = color2;

    SendClientMessage(playerid, -1, "?? Vehicle colors updated.");
    return 1;
}

new CurrentWeather;
new WeatherTimer;

stock SetDynamicWeather(weatherid)
{
    CurrentWeather = weatherid;
    SetWeather(weatherid);

    new msg[64];
    format(msg, sizeof(msg), "??? Weather changed to ID %d.", weatherid);
    SendClientMessageToAll(-1, msg);
}

public OnGameModeInit()
{
    WeatherTimer = SetTimer("UpdateWeatherCycle", 60000, true); // Every 60 seconds
    return 1;
}

forward UpdateWeatherCycle();
public UpdateWeatherCycle()
{
    new nextWeather = random(20); // Random weather ID
    SetDynamicWeather(nextWeather);
    return 1;
}

public OnPlayerUpdate(playerid)
{
    // Example: rain slows movement
    if (CurrentWeather == 8 || CurrentWeather == 16) // Rain or storm
    {
        ApplyPlayerSlow(playerid);
    }

    // Example: sandstorm reduces visibility
    if (CurrentWeather == 19)
    {
        SetPlayerCameraPos(playerid, 0.0, 0.0, 0.0); // Simulate fog
    }

    // Example: cold weather affects temperature
    if (CurrentWeather == 6 || CurrentWeather == 7)
    {
        PlayerTemperature[playerid] -= 1;
    }

    return 1;
}

stock ApplyPlayerSlow(playerid)
{
    new Float:x, Float:y, Float:z;
    GetPlayerVelocity(playerid, x, y, z);
    SetPlayerVelocity(playerid, x * 0.8, y * 0.8, z); // Reduce speed
}


