// Example plugin for the add-on installer.
// $URL$
// $Date$
// $Revision$

// based on the opencollar plugin template:
// Version: 3.400
// Date: 2009/12/15
// Last edited by: mantel.jeff

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

// Please remove any unneeded code sections to save memory and sim time


string g_szSubmenu = "Inst Test"; // Name of the submenu
string g_szParentmenu = "AddOns"; // name of the menu, where the menu plugs in, should be usually Addons. Please do not use the mainmenu anymore
string g_szChatCommand = "insttest"; // every menu should have a chat command, so the user can easily access it by type for instance *plugin
key g_keyMenuID;  // menu handler
integer g_nDebugMode=FALSE; // set to TRUE to enable Debug messages

key g_keyWearer; // key of the current wearer to reset only on owner changes

integer g_nReshowMenu=FALSE; // some command need to wait on a processing or need to run through the auth sstem before they can show a menu again, they can use the variable and call the menu if it is set to true


list g_lstLocalbuttons = ["Read setting","Write setting"]; // any local, not changing buttons which will be used in this plugin, leave empty or add buttons as you like

list g_lstButtons;

// database token
string dbToken = "JMTestAddOn";
integer dbEntryIsHere = FALSE;

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


//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bit of lag caused by having IM slave scripts
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
//= parameters   :    key       id                 key of the avatar that receives the message
//=                   string    msg                message to send
//=                   integer   alsoNotifyWearer   if TRUE, a copy of the message is sent to the wearer
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
//= parameters   :    string    keyID   key of person requesting the menu
//=
//= return        :    none
//=
//= description  :    build menu and display to user
//=
//===============================================================================

DoMenu(key keyID)
{
	string prompt = "Pick an option.\n";
	list mybuttons = g_lstLocalbuttons + g_lstButtons;

	//fill in your button list and additional prompt here
	llListSort(g_lstLocalbuttons, 1, TRUE); // resort menu buttons alphabetical

	// and dispay the menu
	g_keyMenuID = Dialog(keyID, prompt, g_lstLocalbuttons, [UPMENU], 0);
}

default
{
	state_entry()
	{
		// sleep a second to allow all scripts to be initialized
		llSleep(1.0);
		// send request to main menu and ask other menus if they want to register with us
		llMessageLinked(LINK_THIS, MENUNAME_REQUEST, g_szSubmenu, NULL_KEY);
		llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_szParentmenu + "|" + g_szSubmenu, NULL_KEY);

		llOwnerSay("Installer example add-on (re)started");
	}

	// reset the script if wearer changes. By only reseting on owner change we can keep most of our
	// configuration in the script itself as global variables, so that we don't loose anything in case
	// the httpdb server isn't available
	// Cleo: As per Nan this should be a reset on every rez, this has to be handled as needed, but be prepared that the user can reset your script anytime using the OC menus
	on_rez(integer param)
	{
		if (llGetOwner()!=g_keyWearer)
		{
			// Reset if wearer changed
			llResetScript();
		}
	}


	// listen for likend messages from OC scripts
	link_message(integer sender, integer num, string str, key id)
	{
		if (num == SUBMENU && str == g_szSubmenu)
		{
			//someone asked for our menu
			//give this plugin's menu to id
			DoMenu(id);
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
			// replace "value1" by your own token
			if (token == dbToken )
			{
				// there is a database entry for us
				dbEntryIsHere = TRUE;
			}
		}
		else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
			// a validated command from a owner, secowner, groupmember or the wearer has been received
			// can also be used to listen to chat commands
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
		}

		else if (num == DIALOG_RESPONSE)
			// answer from menu system
			// careful, don't use the variable id to identify the user.
			// you have to parse the answer from the dialog system and use the parsed variable av
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
					//give av the parent menu
					llMessageLinked(LINK_THIS, SUBMENU, g_szParentmenu, av);
				}
				else if (~llListFindList(g_lstLocalbuttons, [message]))
				{
					//we got a response for something we handle locally
					if (message == "Read setting")
					{
						// check if the database entry is here
						if (dbEntryIsHere)
						{
							Notify(av,"Found some settings",FALSE);
						}
						else
						{
							Notify(av,"No settings found",FALSE);
						}

						// and restart the menu if wanted/needed
						DoMenu(av);
					}
					else if (message == "Write settings")
					{
						llMessageLinked(LINK_THIS,HTTPDB_SAVE,dbToken+"=1",NULL_KEY);
						dbEntryIsHere = TRUE;
						
						Notify(av,"settings created/updated",FALSE);
						
						// and restart the menu if wanted/needed
						DoMenu(av);
					}
				}
				else if (~llListFindList(g_lstButtons, [message]))
				{
					//we got a command which another command pluged into our menu
					llMessageLinked(LINK_THIS, SUBMENU, message, av);
				}
			}
		}
	}

}

