// In-collar script for add-on installer
// $URL$
// $Date$
// $Revision$

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

key g_keyMenuID;  // menu handler
integer g_nDebugMode=FALSE; // set to TRUE to enable Debug messages

// buttons
string g_ButtonInstall = "Install";
string g_ButtonUpgrade = "Upgrade";
string g_ButtonRemove = "Remove";

// menus
list g_MenuNew = [ g_ButtonInstall ];
list g_MenuExists = [ g_ButtonUpgrade, g_ButtonRemove ];
list g_MenuNoDetect = [ g_ButtonInstall, g_ButtonRemove ];

// global variables
integer operationAsked;		// type of operation asked (install, remove, or upgrae)
string itemToWaitFor;		// name of item to wait for

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

// Common definitions between installer and uploaded collar script
$import messages.lslm();

// utility functions
$import utils.lslm();

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
//= parameters   :    string  command   command to execute
//=                   list    objects   list of objects to execute the command on
//=
//= return        :    none
//=
//= description  :    execute a command on a list of objects
//=
//===============================================================================
ExecuteCommand(string command, list objects)
{
	integer numItems = llGetListLength(objects)-2;
	integer i;
	
	for (i=0; i<numItems; i++)
	{
		string item = llList2String(objects,i+2);
		
		if (command == g_MessagesCommandDelete)
		{
			// look for item in inventory
			list findInfo = FindItem(item);
			
			if (llList2Integer(findInfo,0) != INVENTORY_NONE)
			{
				// remove item
				llRemoveInventory(llList2String(findInfo,1));
			}
		}
		else if (command == g_MessagesCommandRemoveHttpdb)
		{
			llMessageLinked(LINK_THIS,HTTPDB_DELETE,item,NULL_KEY);
		}
		else if (command == g_MessagesCommandRemoveLocalSettings)
		{
			llMessageLinked(LINK_THIS,LOCALSETTING_DELETE,item,NULL_KEY);
		}
	}
}


//===============================================================================
//= parameters   :    none
//=
//= return        :    none
//=
//= description  :    checks if the item we are currently waiting for is here and signal it to the installer
//=
//===============================================================================

CheckItem()
{
	if (itemToWaitFor != "")
	{
		list itemInfo = FindItem(itemToWaitFor);
		if (llList2Integer(itemInfo,0) != INVENTORY_NONE)
		{
			// found it
			llSay(g_UpdateChannel,g_MessagesHeader+"|"+g_MessagesDone+
				"|"+g_MessagesCommandWaitFor);
		}
	}
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

default
{
	state_entry()
	{
		if (llGetStartParameter() == 4242)
		{
			// we are in the collar and started by the installer
			
			// listen for installer instructions
			llListen(g_UpdateChannel, "", "", "");

			// tell installer we are here
			llSay(g_UpdateChannel,g_MessagesHeader + "|" + g_MessagesLoaded);
		}
		else
		{
			// we are in the installer, or in the collar but not just after a transfer from the installer
			// stop the script
			llSetScriptState(llGetScriptName(), FALSE);
		}
	}

	on_rez(integer param)
	{
		// we are in the installer, or in the collar but not just after a transfer from the installer
		// stop the script
		llSetScriptState(llGetScriptName(), FALSE);
	}


	// listen for linked messages from OC scripts
	link_message(integer sender, integer num, string str, key id)
	{
		if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
			// a validated command from a owner, secowner, groupmember or the wearer has been received
			// can also be used to listen to chat commands
		{
			if (str == "reset")
				// it is a request for a reset
			{
				if (num == COMMAND_WEARER || num == COMMAND_OWNER)
				{   //only owner and wearer may reset
					// in our case we just disable the script
					llSetScriptState(llGetScriptName(), FALSE);
				}
			}
		}
		else if (num == DIALOG_RESPONSE)
			// answer from menu system
			// carefull, dont use the variable id to identify for the user.
			// you have to parse the answer from the dialog system and use the parsed variable av
		{
			if (id == g_keyMenuID)
			{
				//got a menu response meant for us, extract the values
				list menuparams = llParseString2List(str, ["|"], []);
				key av = (key)llList2String(menuparams, 0);
				string message = llList2String(menuparams, 1);
				integer page = (integer)llList2String(menuparams, 2);
				operationAsked = -1;
				
				if (message == g_ButtonInstall)
				{
					operationAsked = OPERATION_INSTALL;
				}
				else if (message == g_ButtonUpgrade)
				{
					operationAsked = OPERATION_UPGRADE;
				}
				else if (message == g_ButtonRemove)
				{
					operationAsked = OPERATION_REMOVE;
				}
				
				// send operation type to installer
				llSay(g_UpdateChannel,g_MessagesHeader + "|" + 
					g_MessagesStart + "|" + (string)operationAsked);
			}
		}
		else if (num == DIALOG_TIMEOUT)
			// timeout from menu system, you do not have to react on this, but you can
		{
			if (id == g_keyMenuID)
				// if you react, make sure the timeout is from your menu by checking the g_keyMenuID variable
			{
				llOwnerSay("Menu timeout. Please start the installation again by selecting Held/Debug > Update in your collar");
			}
		}
	}
	
	// listen for commands from the installer
	listen(integer channel, string name, key id, string message)
	{
		if ((channel == g_UpdateChannel) && (llGetOwnerKey(id) == llGetOwner()))
		{
			list params = llParseString2List(message,["|"],[]);
						
			if (llList2String(params,0) == g_MessagesHeader)
			{
				string command = llList2String(params,1);
				integer sendAnswer = FALSE;

				// default values
				itemToWaitFor = "";
				
				if (command == g_MessagesAskOwner)
				{
					// start detection of items
					integer alreadyInstalled = TRUE;
					integer numItems = llGetListLength(params)-3;
					integer i;
					
					for(i=0; i<numItems; i++)
					{
						list findResult = FindItem(llList2String(params,i+3));
						
						if (llList2Integer(findResult,0) == INVENTORY_NONE)
						{
							// one item not found, this means that the add-on isn't installed
							alreadyInstalled = FALSE;
						}
					}
					
					list menuButtons;
					
					if (numItems == 0)
					{
						menuButtons = g_MenuNoDetect;
					}
					else
					{
						if (alreadyInstalled)
						{
							menuButtons = g_MenuExists;
						}
						else
						{
							menuButtons = g_MenuNew;
						}
					}
					
					// show menu to user
					g_keyMenuID = Dialog(llGetOwner(),
						"Welcome to the installer for " + llList2String(params,2) + ".\nPlease select an operation to perform:",
							menuButtons, [], 0);
				}
				else if (command == g_MessagesCommandDelete)
				{
					ExecuteCommand(command,params);
					sendAnswer = TRUE;
				}
				else if (command == g_MessagesCommandWaitFor)
				{
					itemToWaitFor = llList2String(params,2);
					CheckItem();
				}
				else if (command == g_MessagesCommandStartScripts)
				{
					// reset opencollar scripts and start add-on scripts
					// this can be necessary in case the add-on added anything in the
					// collar that must be picked up by the OC scripts
					llMessageLinked(LINK_THIS,COMMAND_OWNER,"resetscripts",NULL_KEY);
					sendAnswer = TRUE;
				}
				else if (command == g_MessagesCommandRemoveHttpdb)
				{
					ExecuteCommand(command,params);
					sendAnswer = TRUE;
				}
				else if (command == g_MessagesCommandRemoveLocalSettings)
				{
					ExecuteCommand(command,params);
					sendAnswer = TRUE;
				}
				else if (command == g_MessagesEnd)
				{
					// installation was successful
					llSetRemoteScriptAccessPin(0);
					
					// change name
					string objName = llGetObjectName();
					
					if (operationAsked == OPERATION_INSTALL)
					{
						objName += "I";
					}
					else if (operationAsked == OPERATION_UPGRADE)
					{
						objName += "U";
					}
					else if (operationAsked == OPERATION_REMOVE)
					{
						objName += "R";
					}
					
					llSetObjectName(objName);
					
					// remove self
					llRemoveInventory(llGetScriptName());
				}
				else
				{
					llOwnerSay("Unknown command received from installer: " + message);
				}
				
				// send acknowledge to installer
				if (sendAnswer)
				{
					llSay(g_UpdateChannel,g_MessagesHeader + "|" + g_MessagesDone +
						"|" + command);
				}
			}
		}
	}
}

