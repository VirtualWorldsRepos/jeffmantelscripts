// Card game plugin for Opencollar
// $ URL $
// $ Date $
// $ Revision $


// Based on:
// Template for creating a OpenCollar Plugin - OpenCollar Version 3.4+
// Inworld version for SVN storage
// Version: 3.339
// Date: 2009/10/16
// Last edited by: Cleo Collins

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

string g_szSubmenu = "CardGame"; // Name of the submenu
string g_szParentmenu = "AddOns"; // name of the menu, where the menu plugs in, should be usually Addons. Please do not use the mainmenu anymore
string g_szChatCommand = "cardgame"; // every menu should have a chat command, so the user can easily access it by type for instance *plugin
key g_keyMenuID;  // menu handler
integer g_nDebugMode=FALSE; // set to TRUE to enable Debug messages

// global settings
integer g_SettingPrimary=FALSE;
integer g_SettingTime=15;
integer g_SettingPrimaryAllowed = TRUE;

// game state
integer STATE_DISABLED = 0;
integer STATE_OFF = 1;
integer STATE_DETECT = 2;
integer STATE_ASKING = 3;
integer STATE_ASKED = 4;
integer STATE_WAITCONFIRM = 5;
integer STATE_FIRSTDRAW = 6;
integer STATE_OWNER = 7;
integer STATE_SLAVE = 8;
integer STATE_FREESLAVE = 9;
integer STATE_OWNERLOOSING = 10;


integer g_GameState = STATE_DISABLED;

key g_PartnerKey=NULL_KEY;
string g_PartnerName;
integer g_PartnerChannel=0;
integer g_PartnerAuthLevel;
integer g_WearerAuthLevel;
integer g_GamePrimary;
integer g_GameTime;

integer g_MyCard;
integer g_MyColor;
integer g_OtherCard;
integer g_OtherColor;

integer CARD_CHANNEL_OFFSET=1875;
integer COLLAR_CHANNEL_OFFSET=1111;

key g_keyWearer=NULL_KEY; // key of the current wearer to reset only on owner changes

integer g_nReshowMenu=FALSE; // some command need to wait on a processing or need to run through the auth sstem before they can show a menu again, they can use the variable and call the menu if it is set to true

list g_lstLocalbuttons;
list g_lstButtons;

// labels
string g_LabelHelp = "Help";
string g_LabelEnablePrimary = "Primary";
string g_LabelEnableSecondary = "Secondary";
string g_LabelDisable = "Disable";
string g_LabelKill = "kill";
string g_LabelSettings = "Settings";
string g_LabelPlay = "Play";
string g_LabelDraw = "draw";
string g_LabelCancel = "stop";
string g_LabelEscape = "try escape";
string g_LabelCard = "card";
string g_LabelPing = "ping";
string g_LabelPong = "pong";
string g_LabelAsk = "ask";
string g_LabelAnswer = "answer";
string g_LabelMyCard = "My";
string g_LabelOtherCard = "Other";
string g_LabelResetCards = "resetcards";
string g_LabelShowCard = "showcard";
string g_LabelTouchedCards = "touchedCards";

// disabled menu
list g_DisabledMenuButtons = [g_LabelHelp,g_LabelEnablePrimary,g_LabelEnableSecondary];

// enabled menu for everyone except the wearer
list g_EnableMenuOthersButtons = [g_LabelHelp, g_LabelKill];

// off menu
list g_OffMenuButtons = [g_LabelHelp,g_LabelSettings,g_LabelPlay,g_LabelDisable];

// owner menu
list g_OwnerMenu = [g_LabelHelp, g_LabelDraw, g_LabelCancel ];
list g_OwnerLostMenu = [g_LabelHelp, g_LabelCancel ];

// slave menu
list g_SlaveMenu = [g_LabelHelp, g_LabelEscape];

// settings menu
// be carfeul if you change the order of the buttons, need to edit the function
list g_SettingsMenuButtons = ["Primary", "Secondary", "10 min","15 min", "20 min", "30 min", "1 h", "2 h", "4 h"];
list g_SettingsMenuDelays = [ 0, 0, 10, 15, 20, 30, 60, 120, 240 ];
key g_SettingsMenuKey=NULL_KEY;

// partner menu
list g_ScanMenuButtons;
list g_ScanMenuIDs;

// draw menu
key g_DrawMenuID=NULL_KEY;

// settings database tokens
string g_SettingTokenOwner = "jm_cardgame_owner";
string g_SettingTokenDelay = "jm_cardgame_delay";

// internal messages id
string g_MessagesID = "jm_cardgame";

//OpenCollar MESSAGE MAP
// messages for authenticating users
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;
integer COMMAND_BLACKLIST = 520;
// added for timer so when the sub is locked out they can use postions
integer COMMAND_WEARERLOCKEDOUT = 521;


//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

// messages for storing and retrieving values from http db
integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

// same as HTTPDB_*, but for storing settings locally in the settings script
integer LOCALSETTING_SAVE = 2500;
integer LOCALSETTING_REQUEST = 2501;
integer LOCALSETTING_RESPONSE = 2502;
integer LOCALSETTING_DELETE = 2503;
integer LOCALSETTING_EMPTY = 2504;


// messages for creating OC menu structure
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

// messages to the dialog helper
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;


// messages for RLV commands
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..

// messages for poses and couple anims
integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av


// menu option to go one step back in menustructure
string UPMENU = "^";//when your menu hears this, give the parent menu

//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    output debug messages
//=
//===============================================================================

Debug(string szMsg)
{
    if (!g_nDebugMode) return;
    llOwnerSay(llGetScriptName() + ": " + szMsg);
}

//===============================================================================
//= parameters   :    to complete
//=
//= return        :    none
//=
//= description  :    notify targeted id and maybe the wearer
//=
//===============================================================================

Notify(key id, string msg, integer alsoNotifyWearer)
{
    if (id == g_keyWearer)
    {
        llOwnerSay(msg);
    }
    else
    {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer)
        {
            llOwnerSay(msg);
        }
    }
}

//===============================================================================
//= parameters   :    none
//=
//= return        :    key random uuid
//=
//= description  :    random key generator, not complety unique, but enough for use in dialogs
//=
//===============================================================================


key ShortKey()
{//just pick 8 random hex digits and pad the rest with 0.  Good enough for dialog uniqueness.
    string chars = "0123456789abcdef";
    integer length = 16;
    string out;
    integer n;
    for (n = 0; n < 8; n++)
    {
        integer index = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        out += llGetSubString(chars, index, index);
    }

    return (key)(out + "-0000-0000-0000-000000000000");
}

//===============================================================================
//= parameters   :    key   rcpt  recipient of the dialog
//=                   string  prompt    dialog prompt
//=                   list  choices    true dialog buttons
//=                   list  utilitybuttons  utility buttons (kept on every page)
//=                   integer   page    page to display
//=
//= return        :    key  handler of the dialog
//=
//= description  :    displays a dialog to the given recipient
//=
//===============================================================================


key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = ShortKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}


//===============================================================================
//= parameters   :    key owner            key of the person to send the message to
//=                    integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
integer nGetOwnerChannel(key owner, integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)owner,2,7)) + nOffset;
    if (chan>0)
    {
        chan=chan*(-1);
    }
    if (chan > -10000)
    {
        chan -= 30000;
    }
    return chan;
}


//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    integer TRUE/FALSE
//=
//= description  :    checks if a string begin with another string
//=
//===============================================================================

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}

//===============================================================================
//= parameters   :    string    keyID   key of person requesting the menu
//=
//= return        :    none
//=
//= description  :    build menu and display to user
//=
//===============================================================================

DoMenu(key keyID)
{
    string prompt;
    list mybuttons;
    
    if (g_GameState == STATE_DISABLED)
    {
        prompt = "Game is disabled. Only an owner can enable it. Please pick an option:\n";
        prompt += g_LabelEnablePrimary + " will enable the game with either primary or secondary ownership.\n";
        prompt += g_LabelEnableSecondary + " will enable the game, restricted to secondary ownership.\n";
        
        g_lstLocalbuttons = g_DisabledMenuButtons;
    }
	else if (keyID != g_keyWearer)
	{
		if (g_GameState < STATE_FIRSTDRAW)
		{
			prompt = "Game is enabled.";
		}
		else
		{
			prompt = "Game is currently running with " + g_PartnerName + ".";
		}
		prompt += "\nOnly the owner can kill the game";
		
		g_lstLocalbuttons = g_EnableMenuOthersButtons;
	}
    else if (g_GameState == STATE_OFF)
    {
        prompt = "No current game. Please pick an option.\n";
        g_lstLocalbuttons = g_OffMenuButtons;
    }
    else if (g_GameState == STATE_DETECT)
    {
        prompt = "Please pick a partner";
        g_lstLocalbuttons = g_ScanMenuButtons;
    }
    else if (g_GameState == STATE_ASKED)
    {
        prompt = g_PartnerName + " would like to play a card game with you.\n";
        prompt += "Type of ownership: ";
        if (g_GamePrimary)
        {
            prompt += "primary";
        }
        else
        {
            prompt += "secondary";
        }
        prompt += "\nDelay: ";
        
        integer minutes = g_GameTime;
        integer hours = 0;
        
        while (minutes >= 60)
        {
            hours += 1;
            minutes -= 60;
        }
        if (hours > 0)
        {
            prompt += (string)hours + " h";
        }
        if (minutes  > 0)
        {
            prompt += (string)minutes + " minutes";
        }
        prompt += "\nDo you accept?";
        g_lstLocalbuttons = ["Yes","No"];
    }
    else if (g_GameState == STATE_OWNER)
    {
        prompt = "You are currently owner of " + g_PartnerName;
        g_lstLocalbuttons = g_OwnerMenu;
    }
    else if (g_GameState == STATE_OWNERLOOSING)
    {
        prompt = g_PartnerName + " doesn't know yet that you lost";
        g_lstLocalbuttons = g_OwnerLostMenu;

        if (llGetTime() > g_GameTime * 60.0)
        {
            g_lstLocalbuttons += [g_LabelDraw];
        }
    }
    else if ((g_GameState == STATE_SLAVE) || (g_GameState == STATE_FREESLAVE))
    {
        prompt = "You are currently owned by " + g_PartnerName;
        g_lstLocalbuttons = g_SlaveMenu;
        
        if (llGetTime() > g_GameTime * 60.0)
        {
            g_lstLocalbuttons += [g_LabelDraw];
        }
    }        
    else
    {
        prompt = "Waiting for an answer from " + g_PartnerName;
        g_lstLocalbuttons = [g_LabelCancel];
    }
    mybuttons = g_lstLocalbuttons + g_lstButtons;

    //fill in your button list and additional prompt here
    llListSort(mybuttons, 1, TRUE); // resort menu buttons alphabetical

    // and dispay the menu
    g_keyMenuID = Dialog(keyID, prompt, mybuttons, [UPMENU], 0);
}

DoSettingsMenu(key keyID)
{
    string prompt;
    integer hours;
    integer minutes;

    // create prompt
    prompt = "Card game settings. Current setup:\nType of ownership:";
    if (g_SettingPrimary)
    {
        prompt = prompt + "primary";
    }
    else
    {
        prompt = prompt + "secondary";
    }
    prompt = prompt + "\nDelay between draws: ";
    if (g_SettingTime < 60)
    {
        prompt = prompt + (string)g_SettingTime + "min";
    }
    else
    {
        minutes = g_SettingTime;
        hours = 0;
        while (minutes >= 60)
        {
            hours=hours+1;
            minutes=minutes-60;
        }
        prompt = prompt + (string)hours + " h";
        if (minutes > 0)
        {
            prompt = prompt + " " + (string)minutes;
        }
    }
    prompt = prompt + "\n";
    
    //fill in your button list and additional prompt here
    llListSort(g_lstLocalbuttons, 1, TRUE); // resort menu buttons alphabetical

    // and dispay the menu
    g_SettingsMenuKey = Dialog(keyID, prompt, g_SettingsMenuButtons, [UPMENU], 0);
}

SetOwnership(integer isOwner, integer first)
{
	if (isOwner)
	{
		if (first)
		{
			// Gain own ownership
			if (g_SettingPrimary && (g_WearerAuthLevel == COMMAND_SECOWNER))
			{
				// remove secondary ownership and set primary instead
				RemoveOwner(llKey2Name(g_keyWearer),FALSE);
				AddOwner(llKey2Name(g_keyWearer),TRUE);
			}
			else if (g_SettingPrimary && (g_WearerAuthLevel == COMMAND_OWNER))
			{
				// already own primary owner
			}
			else if ((!g_SettingPrimary) && (g_WearerAuthLevel == COMMAND_SECOWNER))
			{
				// already own secondary owner
			}
			else
			{
				AddOwner(llKey2Name(g_keyWearer),g_SettingPrimary);
			}
			
			// remove ownership form other, if applicable
			if ((!g_SettingPrimary) && (g_PartnerAuthLevel == COMMAND_OWNER))
			{
			}
			else if (g_PartnerAuthLevel == COMMAND_OWNER)
			{
				RemoveOwner(g_PartnerName,TRUE);
			}
			else if (g_PartnerAuthLevel == COMMAND_SECOWNER)
			{
				RemoveOwner(g_PartnerName,FALSE);
			}
		}
		else
		{
			RemoveOwner(g_PartnerName,g_SettingPrimary);
			AddOwner(llKey2Name(g_keyWearer),g_SettingPrimary);
		}
	}
	else
	{
		if (first)
		{
			// remove self ownership, if applicable
			if ((!g_SettingPrimary) && (g_WearerAuthLevel == COMMAND_OWNER))
			{
			}
			else if (g_WearerAuthLevel == COMMAND_OWNER)
			{
				RemoveOwner(llKey2Name(g_keyWearer),TRUE);
			}
			else if (g_WearerAuthLevel == COMMAND_SECOWNER)
			{
				RemoveOwner(llKey2Name(g_keyWearer),FALSE);
			}
			
			// Other gains ownership
			if (g_SettingPrimary && (g_PartnerAuthLevel == COMMAND_SECOWNER))
			{
				// remove secondary ownership and set primary instead
				RemoveOwner(g_PartnerName,FALSE);
				AddOwner(g_PartnerName,TRUE);
			}
			else if (g_SettingPrimary && (g_PartnerAuthLevel == COMMAND_OWNER))
			{
				// already owns us as primary
			}
			else if ((!g_SettingPrimary) && (g_PartnerAuthLevel == COMMAND_SECOWNER))
			{
				// already owns us as secondary
			}
			else
			{
				AddOwner(g_PartnerName,g_SettingPrimary);
			}
		}
		else
		{
			RemoveOwner(llKey2Name(g_keyWearer),g_SettingPrimary);
			AddOwner(g_PartnerName,g_SettingPrimary);
		}
	}
}

ResetOwnership(integer wasOwner)
{
	if (wasOwner)
	{
		// own ownership
		if (g_WearerAuthLevel == COMMAND_OWNER)
		{
			if (!g_SettingPrimary)
			{
				// can remove secondary ownership
				RemoveOwner(llKey2Name(g_keyWearer),FALSE);
			}
		}
		else if (g_WearerAuthLevel == COMMAND_SECOWNER)
		{
			if (g_SettingPrimary)
			{
				// remove primary and put back secondary
				RemoveOwner(llKey2Name(g_keyWearer),TRUE);
				AddOwner(llKey2Name(g_keyWearer),FALSE);
			}
		}
		else
		{
			RemoveOwner(llKey2Name(g_keyWearer),g_SettingPrimary);
		}
		
		// other ownership
		if (g_PartnerAuthLevel == COMMAND_OWNER)
		{
			if (g_SettingPrimary)
			{
				AddOwner(g_PartnerName,TRUE);
			}
		}
		else if (g_PartnerAuthLevel == COMMAND_SECOWNER)
		{
			AddOwner(g_PartnerName,FALSE);
		}
	}
	else
	{
		// own ownership
		if (g_WearerAuthLevel == COMMAND_OWNER)
		{
			if (g_SettingPrimary)
			{
				AddOwner(llKey2Name(g_keyWearer),TRUE);
			}
		}
		else if (g_WearerAuthLevel == COMMAND_SECOWNER)
		{
			AddOwner(llKey2Name(g_keyWearer),g_WearerAuthLevel);
		}
		
		// other ownership
		if (g_PartnerAuthLevel == COMMAND_OWNER)
		{
			if (!g_SettingPrimary)
			{
				// can remove secondary ownership
				RemoveOwner(g_PartnerName,FALSE);
			}
		}
		else if (g_PartnerAuthLevel == COMMAND_SECOWNER)
		{
			if (g_SettingPrimary)
			{
				// remove primary and put back secondary
				RemoveOwner(g_PartnerName,TRUE);
				AddOwner(g_PartnerName,FALSE);
			}
		}
		else
		{
			RemoveOwner(g_PartnerName,g_SettingPrimary);
		}
	}
}

AddOwner(string name, integer primary)
{
	string message;
	if (primary)
	{
		message = "owner";
	}
	else
	{
		message = "secowner";
	}
	message += " " + name;
	llMessageLinked(LINK_SET, COMMAND_OWNER, message, g_keyWearer); 
	
	llOwnerSay("added " + name);
	
}

RemoveOwner(string name, integer primary)
{
	string message;
	if (primary)
	{
		message = "remowner";
	}
	else
	{
		message = "remsecowner";
	}
	message += " " + name;
	llMessageLinked(LINK_SET, COMMAND_OWNER, message, g_keyWearer); 

	llOwnerSay("removed " + name);
}

//===============================================================================
//= parameters   :    none
//=
//= return        :   string     DB prefix from the description of the collar
//=
//= description  :    prefix from the description of the collar
//=
//===============================================================================

string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

ClearCards()
{
    g_MyCard = -1;
    g_MyColor = -1;
    g_OtherCard = -1;
    g_OtherColor = -1;
    
    llSay(nGetOwnerChannel(g_keyWearer,CARD_CHANNEL_OFFSET),g_MessagesID+"|"+g_LabelResetCards);
}

ShowCard(integer myCard, integer color, integer value)
{
    string message = g_MessagesID+"|"+g_LabelShowCard+"|";
    
    if (myCard != FALSE)
    {
        message += g_LabelMyCard;
    }
    else
    {
        message += g_LabelOtherCard;
    }
    message += "|"+(string)color+"|"+(string)value;
    
    llSay(nGetOwnerChannel(g_keyWearer,CARD_CHANNEL_OFFSET),message);
}

AskForDraw()
{
    llOwnerSay("Click on one of the cards to draw");
    ClearCards();
}

ProcessCancelRequest()
{
    llOwnerSay("Cancelling game");
    
    if (g_PartnerChannel!= 0)
    {
        llSay(g_PartnerChannel,g_MessagesID+"|" + g_LabelCancel);
    }
    
	if ((g_GameState == STATE_OWNER) || (g_GameState == STATE_OWNERLOOSING))
	{
		ResetOwnership(TRUE);
	}
	else if ((g_GameState == STATE_SLAVE) || (g_GameState == STATE_FREESLAVE))
	{
		ResetOwnership(FALSE);
	}
	
    g_GameState = STATE_OFF;
    g_PartnerKey = NULL_KEY;
    g_PartnerChannel = 0;
	ClearCards();
}

CardDraw()
{
    if (g_MyCard == -1)
    {
        g_MyCard = ((integer)llFrand(12.0))+1;
        g_MyColor = ((integer)llFrand(4.0))+1;
        llSay(g_PartnerChannel,g_MessagesID + "|" + g_LabelCard + "|" +
            (string)g_MyCard+"|"+(string)g_MyColor);
        ShowCard(TRUE,g_MyColor,g_MyCard);
        ProcessCard();
    }
}

ProcessCard()
{
    // display the card of the other player in some cases
    if ((g_OtherCard != -1) && ((g_GameState == STATE_FIRSTDRAW) || (g_GameState == STATE_OWNER) ||
        (g_GameState == STATE_OWNERLOOSING)))
    {
        ShowCard(FALSE,g_OtherColor,g_OtherCard);
    }
    
    // only continue if both cards have been drawn
    if ((g_MyCard == -1) || (g_OtherCard == -1))
    {
        return;
    }
    
    llResetTime();
    
    if (g_GameState == STATE_FIRSTDRAW)
    {
        if (g_MyCard > g_OtherCard)
        {
            llOwnerSay("You are now owner!");
            g_GameState = STATE_OWNER;
			SetOwnership(TRUE,TRUE);
        }
        else if (g_MyCard < g_OtherCard)
        {
            llOwnerSay("You are now slave!");
            g_GameState = STATE_SLAVE;
			SetOwnership(FALSE,TRUE);
        }
        else
        {
            llOwnerSay("Need to draw again!");
			llSleep(5);
            AskForDraw();
        }
    }
    else if ((g_GameState == STATE_OWNER) || (g_GameState == STATE_OWNERLOOSING))
    {
        if (g_MyCard < g_OtherCard)
        {
            llOwnerSay("You lost! " +g_PartnerName + " can escape!");
            g_GameState = STATE_OWNERLOOSING;
        }
        else
        {
            llOwnerSay("You remain owner");
        }
    }
    else if ((g_GameState == STATE_SLAVE) || (g_GameState == STATE_FREESLAVE))
    {
        if (g_MyCard > g_OtherCard)
        {
            g_GameState = STATE_FREESLAVE;
        }
    }
}

default
{
    state_entry()
    {
        if (g_keyWearer == NULL_KEY)
        {
            g_keyWearer=llGetOwner();
        }
        
        // sleep a sceond to allow all scripts to be initialized
        llSleep(1.0);
        // send reequest to main menu and ask other menus if the wnt to register with us
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, g_szSubmenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_szParentmenu + "|" + g_szSubmenu, NULL_KEY);
    }

    // reset the script on rezzing, data should be received than from httpdb.
    // by only reseting on owner change we store our most values internal and
    // they do not get lost, if the httpdb for the wearer is "full"
    on_rez(integer param)
    {
        if (llGetOwner()!=g_keyWearer)
        {
            // Reset if wearer changed
            llResetScript();
        }
    }


    // listen for likend messages fromOC scripts
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == SUBMENU && str == g_szSubmenu)
        {
            //someone asked for our menu
            //send the command through the auth system of the collar
            llMessageLinked(LINK_SET,COMMAND_NOAUTH,g_szChatCommand,id);
        }
        else if (num == MENUNAME_REQUEST && str == g_szParentmenu)
            // our parent menu requested to receive buttons, so send ours
        {

            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_szParentmenu + "|" + g_szSubmenu, NULL_KEY);
        }
        else if (num == MENUNAME_RESPONSE)
            // a button is send to be added to a menu
        {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == g_szSubmenu)
            {//someone wants to stick something in our menu
                string button = llList2String(parts, 1);
                if (llListFindList(g_lstButtons, [button]) == -1)
                    // if the button isnt in our menu yet, than we add it
                {
                    g_lstButtons = llListSort(g_lstButtons + [button], 1, TRUE);
                }
            }
        }
        else if (num == HTTPDB_RESPONSE)
            // response from httpdb have been received
        {
            // pares the answer
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            // and check if any values for use are received
            if (token == g_SettingTokenOwner )
            {
                g_SettingPrimary = (integer)value;
				if (!g_SettingPrimaryAllowed)
				{
					g_SettingPrimary = FALSE;
				}
            }
            else if (token == g_SettingTokenDelay)
            {
                g_SettingTime = (integer)value;
            }
        }
        else if (num >= COMMAND_OWNER && num <= COMMAND_EVERYONE)
            // command / chat command received
        {
            if (str == "reset")
                // it is a request for a reset
            {
                if (num == COMMAND_WEARER || num == COMMAND_OWNER)
                {   //only owner and wearer may reset
                    llResetScript();
                }
            }                                   
            else if (str == g_szChatCommand)
                // an authorized user requested the plugin menu by typing the chat command
            {             
                DoMenu(id);
            }
            else if (llGetSubString(str,0,llStringLength(g_MessagesID)) == g_MessagesID+"|")
            {
                list args = llParseString2List(str,["|"],[]);
                string command = llList2String(args,1);
                
                if (command == g_LabelCancel)
                {
                    if (g_PartnerKey != NULL_KEY)
                    {
                        llOwnerSay(g_PartnerName+" stopped the game");
                    }
                    
                    ProcessCancelRequest();
                }
                else if (command == g_LabelPing)
                {
                    Debug("pinged");
					if ((g_GameState >= STATE_OFF) && (g_GameState < STATE_FIRSTDRAW))
					{
						llSay(nGetOwnerChannel(id, COLLAR_CHANNEL_OFFSET),g_MessagesID+"|"+g_LabelPong);
					}
				}
                else if (command == g_LabelPong)
                {
                    Debug("ponged");
                    
                    if (g_GameState == STATE_DETECT)
                    {
                        g_ScanMenuIDs += [id];
                        g_ScanMenuButtons += [llKey2Name(id)];
                    }
                }
                else if (((command == g_LabelEnablePrimary) ||
                    (command == g_LabelEnableSecondary))&&
                    (g_GameState == STATE_DISABLED))
                {
                    // the message went through the authentification system
                    if (num != COMMAND_OWNER)
                    {
                        Notify(id,"Only an owner can do that",FALSE);
                    }
                    else
                    {
                        if (command == g_LabelEnablePrimary)
                        {
                            g_SettingPrimaryAllowed = TRUE;
                        }
                        else
                        {
                            g_SettingPrimaryAllowed = FALSE;
                            g_SettingPrimary=FALSE;
                        }
                        g_GameState = STATE_OFF;
                        llOwnerSay("Game enabled");
                    }
                }
                else if (command == g_LabelAsk)
                {
                    if (g_GameState == STATE_OFF)
                    {
                        g_PartnerKey = id;
                        g_PartnerName = llKey2Name(id);
                        g_PartnerAuthLevel = num;
                        g_PartnerChannel = nGetOwnerChannel(id, COLLAR_CHANNEL_OFFSET);
                        
                        g_GamePrimary = llList2Integer(args,2);
                        g_GameTime = llList2Integer(args,3);
                        
                        if (g_GamePrimary && !g_SettingPrimaryAllowed)
                        {
                            llOwnerSay(g_PartnerName + " asked to play a game, but your owner forbid playing with primary ownership. Please try again with secondary ownership.");
                            llSay(g_PartnerChannel,g_MessagesID + "|" + g_LabelAnswer + "|no");
                        }
                        else
                        {
                            g_GameState = STATE_ASKED;
                            DoMenu(g_keyWearer);
                        }
                    }
                    else
                    {
                        llSay(g_PartnerChannel,g_MessagesID + "|" + g_LabelAnswer + "|no");
                    }
                }
                else if ((command == g_LabelAnswer) && (g_GameState == STATE_ASKING))
                {
                    if (llList2String(args,2) == "yes")
                    {
                        llOwnerSay(g_PartnerName+" accepted to play");
                        g_PartnerAuthLevel = num;
                        llMessageLinked(LINK_SET,COMMAND_NOAUTH,g_MessagesID+"|start",g_keyWearer);
                            // we add this step to record the authorization level of the wearer
                        llSay(g_PartnerChannel,g_MessagesID+"|confirmed");
                    }
                    else if (llList2String(args,2) == "no")
                    {
                        llOwnerSay(g_PartnerName+" refused to play");
                        g_GameState = STATE_OFF;
                    }
                }
                else if ((command == "confirmed") &&
                    (g_GameState == STATE_WAITCONFIRM) && (id == g_PartnerKey))
                {
                    llMessageLinked(LINK_SET,COMMAND_NOAUTH,g_MessagesID+"|start",g_keyWearer);
                        // we add this step to record the authorization level of the wearer                    
                }
                else if ((command == "start") && (id == g_keyWearer) &&
                    ((g_GameState == STATE_ASKING) || (g_GameState == STATE_WAITCONFIRM)))
                {
                    g_WearerAuthLevel = num;
                    g_GameState = STATE_FIRSTDRAW;
                    AskForDraw();
                }
                else if ((command == g_LabelCard) && (g_OtherCard == -1) && (id == g_PartnerKey))
                {
                    g_OtherCard = llList2Integer(args,2);
                    g_OtherColor = llList2Integer(args,3);
                    
                    ProcessCard();
                }
                else if ((command == g_LabelDraw) && (g_GameState >= STATE_FIRSTDRAW) &&
                    (id == g_PartnerKey))
                {
                    AskForDraw();
                }
                else if ((command == g_LabelTouchedCards) && (g_GameState >= STATE_FIRSTDRAW) &&
                    (id == g_keyWearer))
                {
                    CardDraw();
                }
               else if ((command == g_LabelEscape) && (id == g_PartnerKey))
                {
                    if (g_GameState == STATE_OWNER)
                    {
                        llOwnerSay(g_PartnerName + " tryed to escape but failed");
                    }
                    else if (g_GameState == STATE_OWNERLOOSING)
                    {
                        llOwnerSay(g_PartnerName + " managed to escape and owns you now");
                        g_GameState = STATE_SLAVE;
						SetOwnership(FALSE,FALSE);
                    }
                }
            }
        }

        else if (num == COMMAND_SAFEWORD)
            // Safeword has been received, release any restricition that should be released than
        {
            Debug("Safeword reveived, releasing the subs restricions as needed");
        }
        else if (num == DIALOG_RESPONSE)
            // answer from menu system
            // carefull, dont use the variable id from here for the user, you have to parse the answer from the dialog system and use the parsed variable av
        {
            if (id == g_keyMenuID)
            {
                //got a menu response meant for us, extract the values
                list menuparams = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                // request to change to parent menu
                if (message == UPMENU)
                {
                    // if in the detect mode, return to normal mode
                    if (g_GameState == STATE_DETECT)
                    {
                        g_GameState = STATE_OFF;
                        DoMenu(av);
                    }
                    else
                    {
                        //give av the parent menu
                        llMessageLinked(LINK_THIS, SUBMENU, g_szParentmenu, av);
                    }
                }
                else if (~llListFindList(g_lstLocalbuttons, [message]))
                {
                    if ((message == g_LabelCancel) || (message == g_LabelKill))
                    {
                        ProcessCancelRequest();
                    }
                    if (g_GameState == STATE_DISABLED)
                    {
                        if ((message == g_LabelEnablePrimary) || (message == g_LabelEnableSecondary))
                        {
                            // send a message through the authentification system
                            llMessageLinked(LINK_SET,COMMAND_NOAUTH,g_MessagesID+"|"+message,av);
                        }
                    }
                    //we got a response for something we handle locally
                    else if (g_GameState == STATE_OFF)
                    {
                        if (message == g_LabelSettings)
                        {
                             DoSettingsMenu(av);
                        }
                        if (message == g_LabelPlay)
                        {
                            llOwnerSay("Detecting other players. If your partner doesn't appear in the list, ask him/her to come closer, and to check that the game is active in his/her collar.");
                            
                            // start scanning
                            g_GameState = STATE_DETECT;
                            g_ScanMenuButtons = [];
                            llSensor("",NULL_KEY,AGENT,10.0,PI);
                        }
                        if (message == g_LabelDisable)
                        {
                            llOwnerSay("Game disabled");
                            g_GameState = STATE_DISABLED;
                        }
                    }
                    else if (g_GameState == STATE_DETECT)
                    {
                        integer partnerNum = llListFindList(g_ScanMenuButtons,[message]);
                        
                        if (partnerNum>=0)
                        {
                            g_PartnerKey = llList2Key(g_ScanMenuIDs,partnerNum);
                            g_PartnerName = message;
                            g_PartnerChannel = nGetOwnerChannel(g_PartnerKey, COLLAR_CHANNEL_OFFSET);
                            llOwnerSay("Asking " + message + " for a game");
                            
                            llSay(g_PartnerChannel,g_MessagesID+"|"+g_LabelAsk+
                                "|"+(string)g_SettingPrimary+
                                "|"+(string)g_SettingTime);
                            
                            g_GameState = STATE_ASKING;
                            g_GamePrimary = g_SettingPrimary;
                            g_GameTime = g_SettingTime;
                        }
                    }
                    else if (g_GameState == STATE_ASKED)
                    {
                        if (message == "Yes")
                        {
                            llSay(g_PartnerChannel,g_MessagesID+"|"+
                                g_LabelAnswer+"|yes");
                            g_GameState = STATE_WAITCONFIRM;
                        }
                        else if (message == "No")
                        {
                            llSay(g_PartnerChannel,g_MessagesID+"|"+
                                g_LabelAnswer+"|no");
                            g_GameState = STATE_OFF;
                        }
                    }
                    else if ((message == g_LabelDraw) &&
                        (g_GameState >= STATE_OWNER))
                    {
                        ClearCards();
                        llSay(g_PartnerChannel,g_MessagesID+"|"+g_LabelDraw);
                        CardDraw();
                    }
                    else if (message == g_LabelEscape)
                    {
                        llSay(g_PartnerChannel,g_MessagesID+"|"+g_LabelEscape);
                        if (g_GameState == STATE_FREESLAVE)
                        {
                            llOwnerSay("You managed to escape and are now owning " +
                                g_PartnerName);
                            g_GameState = STATE_OWNER;
							ShowCard(FALSE,g_OtherColor,g_OtherCard);
							SetOwnership(TRUE,FALSE);
                        }
                        else if (g_GameState == STATE_SLAVE)
                        {
                            llOwnerSay("Your escape attempt failed");
                        }
                    }
                }
                else if (~llListFindList(g_lstButtons, [message]))
                {
                    //we got a command which another command pluged into our menu
                    llMessageLinked(LINK_THIS, SUBMENU, message, av);
                }
            }
            else if (id == g_SettingsMenuKey)
            {
                //got a menu response meant for us, extract the values
                list menuparams = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                integer optionNum = llListFindList(g_SettingsMenuButtons,[message]);
                // request to change to parent menu
                if (message == UPMENU)
                {
                    //give av the parent menu
                    llMessageLinked(LINK_THIS, SUBMENU, g_szParentmenu, av);
                    return;
                }
                else if (optionNum == 0)
                {
					if (g_SettingPrimaryAllowed)
					{
						// owner = primary
						g_SettingPrimary=TRUE;
						llMessageLinked(LINK_SET, HTTPDB_SAVE,
							g_SettingTokenOwner+"="+(string)g_SettingPrimary, NULL_KEY);
					}
					else
					{
						llOwnerSay("Your owner didn't allow you to play as primary owner");
					}
				}
                else if (optionNum == 1)
                {
                    // owner = secondary
                    g_SettingPrimary=FALSE;
                    llMessageLinked(LINK_SET, HTTPDB_SAVE,
                        g_SettingTokenOwner+"="+(string)g_SettingPrimary, NULL_KEY);
                }
                else if (optionNum >= 2)
                {
                    // delay
                    g_SettingTime = llList2Integer(g_SettingsMenuDelays,optionNum);
                    llMessageLinked(LINK_SET, HTTPDB_SAVE,
                        g_SettingTokenDelay+"="+(string)g_SettingTime, NULL_KEY);                    
                }
                DoSettingsMenu(av);
            }
            else if (id == g_DrawMenuID)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);

                if (message == g_LabelDraw)
                {
                    CardDraw();
                }
                else
                {
                    //we got a command which another command pluged into our menu
                    llMessageLinked(LINK_THIS, SUBMENU, message, av);
                }
            }
        }
        else if (num == DIALOG_TIMEOUT)
            // tiimout from menu system, you do not have to react on this, but you can
        {
            if (id == g_keyMenuID)
                // if you treact, make sure the timout is for your menu by checking the g_keyMenuID variable
            {
                Debug("The user was to slow or lazy, we got a timeout");
            }
        }
    }
    
    sensor(integer total_number) // total_number is the number of avatars detected.
    {
        integer i;
        
        for (i = 0; i < total_number; i++)
        {
            llSay(nGetOwnerChannel(llDetectedKey(i), COLLAR_CHANNEL_OFFSET),g_MessagesID+"|"+
                g_LabelPing);
            Debug("Pinging "+llDetectedName(i));
        }
        
        // set a timer to show the menu
        llSetTimerEvent(10);
    }
    
    // if nobody is within 10 meters, say so.
    no_sensor() {
        llOwnerSay("No players found...");
        DoMenu(g_keyWearer);
    }
    
    timer()
    {
        llSetTimerEvent(0);
        
        if (g_GameState == STATE_DETECT)
        {
            DoMenu(g_keyWearer);
        }
    }
}


