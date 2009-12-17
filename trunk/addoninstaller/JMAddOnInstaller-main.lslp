// Add-On installer for Opencollar
// $URL$
// $Date$
// $Revision$

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.	See "OpenCollar License" for details.

// internal setup
string g_ConfigNotecard = "installerconfig*";
string g_InstallerScript = "jmaddoninstaller - collar script*";

// configuration read from notecard
string g_ConfigName;
string g_ConfigAuthor;
string g_ConfigVersion;
string g_ConfigHelpCard;
float g_ConfigMinCollarVersion=3.380;		// 3.4 required by the installer

string g_DetectionItems;
list g_InstallItems;
string g_RemoveCleanUpItems;
string g_RemoveCleanUpHttpdb;
string g_RemoveCleanUpLocal;
string g_RemoveCleanUpScript;
string g_UpdateCleanUpItems;
string g_UpdateCleanUpHttpdb;
string g_UpdateCleanUpLocal;
string g_UpdateCleanUpScript;

// internal global config variables
string g_ConfigNoteCardRealName;
key g_ConfigNoteCardReadID;
integer g_ConfigNoteCardLineNumber;

// categories when reading notecard
integer CAT_NONE = 0;
integer CAT_MAIN = 1;
integer CAT_DETECTION = 2;
integer CAT_INSTALL = 3;
integer CAT_REMOVECLUP = 4;
integer CAT_UPDATECLUP = 5;
integer g_NotecardCategory = CAT_NONE;

// collar update procedure variables and constants
integer g_DoubleCheckChannel=-0x10CC011A; // channel for finding multiple updaters
integer g_InstallerAlone;
integer g_UpdatePin;
key g_CollarKey;
string g_LastSentCommand;
integer g_OperationType;	// install, remove or upgrade

// installation steps
integer STEP_START = 0;
integer STEP_REMOVEITEMS = 1;
integer STEP_REMOVEHTTPDB = 2;
integer STEP_REMOVELOCAL = 3;
integer STEP_CLEANUPSCRIPT = 4;
integer STEP_INSTALLITEM = 5;
integer STEP_STARTSCRIPTS = 6;
integer STEP_END = 7;
integer g_CurrentStep;
integer g_NextItemToInstall;

// Common definitions between installer and uploaded collar script
$import messages.lslm();

// utility functions
$import utils.lslm();

//===============================================================================
//= parameters :	string	origlist	original string
//=					string	item		item to add
//=
//= return :		string				updated list
//=
//= description :	adds an item to a '|' separated list in a string
//=
//===============================================================================

string AddItem2List(string origlist, string item)
{
	if (origlist == "")
	{
		return item;
	}
	else if (item == "")
	{
		return origlist;
	}
	else
	{
		return origlist + "|" + item;
	}
}


//===============================================================================
//= parameters :	string	name			Name of the item to send
//=					integer	executeScript	If TRUE and if item is a script, execute it after transfer
//=
//= return :		string	actual name of the item sent, or "" if not found
//=
//= description :	sends an item to collar
//=
//===============================================================================

string SendItem(string name, integer executeScript)
{
	list itemDetails = FindItem(name);
	integer itemType = llList2Integer(itemDetails,0);
	string itemRealName = llList2String(itemDetails,1);
	
	if (itemType == INVENTORY_NONE)
	{
		llOwnerSay("Error: item " + name + " not found");
		itemRealName = "";
	}
	else if (itemType == INVENTORY_SCRIPT)
	{
		llRemoteLoadScriptPin(g_CollarKey, itemRealName, g_UpdatePin, executeScript, 4242);
	}
	else
	{
		llGiveInventory(g_CollarKey,itemRealName);
	}
	
	return itemRealName;
}


//===============================================================================
//= parameters :	string	command			Command name
//=					string	params			Parameters
//=
//= return :		none
//=
//= description :	send a command to the collar
//=
//===============================================================================

SendCommand(string command, string params)
{
	g_LastSentCommand = command;
	llSay(g_UpdateChannel,g_MessagesHeader + "|" + AddItem2List(command,params));
}


//===============================================================================
//= parameters :	none
//=
//= return :		none
//=
//= description :	performs next step of the operation, after having rereived acknowledge from collar
//=
//===============================================================================

NextStep()
{
	if (g_CurrentStep == STEP_START)
	{
		g_CurrentStep = STEP_REMOVEITEMS;
		llSetText("Removing items",<1,1,0>,1);
		
		string itemsToRemove;
		
		itemsToRemove = llDumpList2String(g_InstallItems,"|");
		
		if (g_OperationType == OPERATION_UPGRADE)
		{
			itemsToRemove = AddItem2List(itemsToRemove,g_UpdateCleanUpItems);
		}
		else if (g_OperationType == OPERATION_REMOVE)
		{
			itemsToRemove = AddItem2List(itemsToRemove,g_RemoveCleanUpItems);
		}
		
		if (itemsToRemove != "")
		{
			SendCommand(g_MessagesCommandDelete,itemsToRemove);
			return;
		}
	}
	
	if (g_CurrentStep == STEP_REMOVEITEMS)
	{
		g_CurrentStep = STEP_REMOVEHTTPDB;
		llSetText("Cleaning database settings",<1,1,0>,1);
		
		string httpdbTokens="";
		
		if (g_OperationType == OPERATION_UPGRADE)
		{
			httpdbTokens = g_UpdateCleanUpHttpdb;
		}
		else if (g_OperationType == OPERATION_REMOVE)
		{
			httpdbTokens = g_RemoveCleanUpHttpdb;
		}
		
		if (httpdbTokens != "")
		{
			SendCommand(g_MessagesCommandRemoveHttpdb,httpdbTokens);
			return;
		}
	}

	if (g_CurrentStep == STEP_REMOVEHTTPDB)
	{
		g_CurrentStep = STEP_REMOVELOCAL;
		llSetText("Cleaning local settings",<1,1,0>,1);
		
		string localTokens="";
		
		if (g_OperationType == OPERATION_UPGRADE)
		{
			localTokens = g_UpdateCleanUpLocal;
		}
		else if (g_OperationType == OPERATION_REMOVE)
		{
			localTokens = g_RemoveCleanUpLocal;
		}
		
		if (localTokens != "")
		{
			SendCommand(g_MessagesCommandRemoveLocalSettings,localTokens);
			return;
		}
	}
	
	if (g_CurrentStep == STEP_REMOVELOCAL)
	{
		g_CurrentStep = STEP_CLEANUPSCRIPT;
		llSetText("Calling clean up script",<1,1,0>,1);
		
		string scriptName="";
		
		if (g_OperationType == OPERATION_UPGRADE)
		{
			scriptName = g_UpdateCleanUpScript;
		}
		else if (g_OperationType == OPERATION_REMOVE)
		{
			scriptName = g_RemoveCleanUpScript;
		}
		
		if (scriptName != "")
		{
			SendItem(scriptName,TRUE);
			g_LastSentCommand = g_MessagesScript;
			return;
		}
	}	
	
	if (g_CurrentStep == STEP_CLEANUPSCRIPT)
	{
		if (g_OperationType == OPERATION_REMOVE)
		{
			g_CurrentStep = STEP_END;
		}
		else
		{
			g_CurrentStep = STEP_INSTALLITEM;
			g_NextItemToInstall = 0;
		}
	}
	
	if (g_CurrentStep == STEP_INSTALLITEM)
	{
		if (g_NextItemToInstall >= llGetListLength(g_InstallItems))
		{
			g_CurrentStep = STEP_STARTSCRIPTS;
			llSetText("Starting scripts",<1,1,0>,1);
			SendCommand(g_MessagesCommandStartScripts,"");
			return;
		}
		else
		{
			string itemName = SendItem(llList2String(g_InstallItems,g_NextItemToInstall),FALSE);
			g_NextItemToInstall += 1;
			
			if (itemName != "")
			{
				llSetText("Installing " + itemName,<1,1,0>,1);
				SendCommand(g_MessagesCommandWaitFor,itemName);
			}
			
			return;
		}
	}
	
	if (g_CurrentStep == STEP_STARTSCRIPTS)
	{
		g_CurrentStep = STEP_END;
	}
	
	if (g_CurrentStep = STEP_END)
	{
		llSetText("Operation finished",<0,1,0>,1);
		llOwnerSay("Operation finished. You can pick up the collar");
	}
}

default
{
	state_entry()
	{
		list notecardDetails = FindItem(g_ConfigNotecard);
		integer notecardType = llList2Integer(notecardDetails,0);
		g_ConfigNoteCardRealName = llList2String(notecardDetails,1);
		
		if (notecardType == INVENTORY_NOTECARD)
		{
			g_ConfigNoteCardLineNumber = 0;
			g_ConfigNoteCardReadID = llGetNotecardLine(g_ConfigNoteCardRealName,0);
		}
		else
		{
			llOwnerSay("Error, configuration notecard not found!");
		}
		
		llSetText("Initializing... Please wait",<1,1,0>,1);
		UnRunScripts();
	}

	// reset the script on rezzing
	on_rez(integer param)
	{
		llResetScript();
	}

	// reset the script if inventory changed
	changed(integer change)
	{
		if (change & CHANGED_INVENTORY)
		{
			llSleep(2.0);
			llResetScript();
		}
	}
	
	// read notecard lines
	dataserver(key query_id, string data)
	{
		if (query_id == g_ConfigNoteCardReadID)
		{
			if (data == EOF)
			{
				state file_read;
			}
			else
			{
				data = llToLower(llStringTrim(data,STRING_TRIM));
				
				if ((data == "") || (llGetSubString(data,0,0) == "#"))
				{
					// comment or empty line
				}
				else if (llGetSubString(data,0,0) == "[")
				{
					// new category
					if (data == "[main]")
					{
						g_NotecardCategory = CAT_MAIN;
					}
					else if (data == "[detection]")
					{
						g_NotecardCategory = CAT_DETECTION;
					}
					else if (data == "[install]")
					{
						g_NotecardCategory = CAT_INSTALL;
					}
					else if (data == "[removecleanup]")
					{
						g_NotecardCategory = CAT_REMOVECLUP;
					}
					else if (data == "[upgradecleanup]")
					{
						g_NotecardCategory = CAT_UPDATECLUP;
					}
					else
					{
						llOwnerSay("Unknown category " + data);
						g_ConfigNoteCardLineNumber = -1;
					}
				}
				else
				{
					if (g_NotecardCategory == CAT_NONE)
					{
						llOwnerSay("line '"+data+"' outside of valid category");
						g_ConfigNoteCardLineNumber = -1;						
					}
					else if (g_NotecardCategory == CAT_DETECTION)
					{
						g_DetectionItems = AddItem2List(g_DetectionItems,data);
					}
					else if (g_NotecardCategory == CAT_INSTALL)
					{
						g_InstallItems += [ data ];
					}
					else
					{
						list parsedData = llParseString2List(data,["="],[]);
						if (llGetListLength(parsedData) != 2)
						{
							llOwnerSay("bad synax '" + data + "'");
							g_ConfigNoteCardLineNumber = -1;		
						}
						else
						{
							string keyName = llList2String(parsedData,0);
							string keyValue = llList2String(parsedData,1);
							
							if (g_NotecardCategory == CAT_MAIN)
							{
								if (keyName == "name")
								{
									g_ConfigName = keyValue;
								}
								else if (keyName == "author")
								{
									g_ConfigAuthor = keyValue;
								}
								else if (keyName == "version")
								{
									g_ConfigVersion = keyValue;
								}
								else if (keyName == "help")
								{
									g_ConfigHelpCard = keyValue;
								}
								else if (keyName == "mincollarversion")
								{
									float newVersion = (float)keyValue;
									
									if (newVersion > g_ConfigMinCollarVersion)
									{
										g_ConfigMinCollarVersion = newVersion;
									}
								}
								else
								{
									llOwnerSay("Unknown key '" + keyName + "'");
									g_ConfigNoteCardLineNumber = -1;		
								}
							}
							else if (g_NotecardCategory == CAT_REMOVECLUP)
							{
								if (keyName == "item")
								{
									g_RemoveCleanUpItems = AddItem2List(g_RemoveCleanUpItems,keyValue);
								}
								else if (keyName == "httpdb")
								{
									g_RemoveCleanUpHttpdb = AddItem2List(g_RemoveCleanUpHttpdb,keyValue);
								}
								else if (keyName == "localsetting")
								{
									g_RemoveCleanUpLocal = AddItem2List(g_RemoveCleanUpLocal,keyValue);
								}
								else if (keyName == "script")
								{
									g_RemoveCleanUpScript = keyValue;
								}
								else
								{
									llOwnerSay("Unknown key '" + keyName + "'");
									g_ConfigNoteCardLineNumber = -1;		
								}
							}
							else if (g_NotecardCategory == CAT_UPDATECLUP)
							{
								if (keyName == "item")
								{
									g_UpdateCleanUpItems = AddItem2List(g_UpdateCleanUpItems,keyValue);
								}
								else if (keyName == "httpdb")
								{
									g_UpdateCleanUpHttpdb = AddItem2List(g_UpdateCleanUpHttpdb,keyValue);
								}
								else if (keyName == "localsetting")
								{
									g_UpdateCleanUpLocal = AddItem2List(g_UpdateCleanUpLocal,keyValue);
								}
								else if (keyName == "script")
								{
									g_UpdateCleanUpScript = keyValue;
								}
								else
								{
									llOwnerSay("Unknown key '" + keyName + "'");
									g_ConfigNoteCardLineNumber = -1;		
								}
							}
						}
					}
				}
			}

			if (g_ConfigNoteCardLineNumber>=0)
			{
				g_ConfigNoteCardLineNumber++;
				g_ConfigNoteCardReadID = llGetNotecardLine(g_ConfigNoteCardRealName,
					g_ConfigNoteCardLineNumber);
			}			
		}
	}
}

state file_read
{
	state_entry()
	{
		// listen on a channel
		llListen(g_DoubleCheckChannel,"",NULL_KEY,"");
		// and say on the same channel we are here
		llSay(g_DoubleCheckChannel,"UpdateCheck:"+(string)llGetKey());
		llSetTimerEvent(2.0);

		llSetText("Looking for other updaters...",<1,1,0>,1);
		g_InstallerAlone = TRUE;
	}

    listen(integer channel, string name, key id, string message)
    {
        if ((channel==g_DoubleCheckChannel)&&(llGetOwnerKey(id)==llGetOwner()))
        {
            // we received our own message back
            if (message=="UpdateCheck:"+(string)llGetKey())
            {
				// so we delete ourself
				llSetText("Other updater/installer detected.\nThis installer is DISABLED",<1,0,0>,1);
				
				g_InstallerAlone = FALSE;
            }
            else
            {
                llSay(g_DoubleCheckChannel,message);
            }
        }
    }
	
	// reset the script on rezzing
	on_rez(integer param)
	{
		llResetScript();
	}

	// reset the script if inventory changed
	changed(integer change)
	{
		if (change & CHANGED_INVENTORY)
		{
			llSleep(2.0);
			llResetScript();
		}
	}
	
	timer()
	{
		if (g_InstallerAlone)
		{
			state start_update;
		}
		else
		{
			// test again
			g_InstallerAlone = TRUE;
			llSay(g_DoubleCheckChannel,"UpdateCheck:"+(string)llGetKey());
		}
	}
}
	
state start_update
{
	state_entry()
	{
		string message = g_ConfigName;
		if (g_ConfigAuthor != "")
		{
			message += " - by " + g_ConfigAuthor;
		}
		if (g_ConfigVersion != "")
		{
			message += " - version " + g_ConfigVersion;
		}
		message += "\nInstaller is ready. Rez your collar\nnext to me, touch it and select Help/Debug->Update.\nOr touch me for help";
				
		llSetText(message,<0,1,1>,1);
		
		// we need to listen to the double check channel as long as we exist
		llListen(g_DoubleCheckChannel,"",NULL_KEY,"");
		
		llListen(g_UpdateChannel, "", "", "");
	}
	
	// reset the script on rezzing
	on_rez(integer param)
	{
		llResetScript();
	}

	// reset the script if inventory changed
	changed(integer change)
	{
		if (change & CHANGED_INVENTORY)
		{
			llSleep(2.0);
			llResetScript();
		}
	}

	listen(integer channel, string name, key id, string message)
	{
		if (llGetOwnerKey(id) == llGetOwner()) //collar has to have the same owner as the updater!
		{
			if (channel==g_DoubleCheckChannel)
			// we still check the double updater channel
			{
				// and reply if we get a message here
				llSay(g_DoubleCheckChannel,message);
			}
			else
			{
				//debug(message);
				list temp = llParseString2List(message, ["|"], []);
				string command0 = llList2String(temp,0);
				string command1 = llList2String(temp,1);

				if (command0 == "UPDATE")
				{
					// Collar responded with update
					if ((float)command1 > g_ConfigMinCollarVersion)
					{
						//Collar version is high enough
						llWhisper(g_UpdateChannel, "get ready");
					}
					else
					{
						llOwnerSay("Please update your collar to at least version " + (string)g_ConfigMinCollarVersion + " before running this updater.");
					}						
				}
				else if (command0 == "ready")
				{
					// Collar responed everything is ready, duplicate items were deleted so start to send stuff over
					g_UpdatePin = (integer)command1;
					g_CollarKey = id;
					SendItem(g_InstallerScript, TRUE);
					
					llSetText("Waiting for owner to choose action...",<1,1,0>,1);
				}
				else if ((command0 == g_MessagesHeader) && id == g_CollarKey)
				{
					if (command1 == g_MessagesLoaded)
					{
						// send information to collar script
						SendCommand(g_MessagesAskOwner,AddItem2List(g_ConfigName,g_DetectionItems));
					}
					else if (command1 == g_MessagesStart)
					{
						g_OperationType = llList2Integer(temp,2);
						g_CurrentStep = STEP_START;
						NextStep();
					}
					else if (command1 == g_MessagesDone)
					{
						if (llList2String(temp,2) == g_LastSentCommand)
						{
							NextStep();
						}
						else
						{
							llOwnerSay("Error, bad acknowledge received...");
						}
					}
				}
			}
		}
	}	

	touch_start(integer num_detected)
	{
		if (llDetectedKey(0) != llGetOwner())
		{
			llInstantMessage(llDetectedKey(0),"Sorry, only the owner can use the installer");
		}
		else
		{
			list notecardDetails = FindItem(g_ConfigHelpCard);
			
			if (llList2Integer(notecardDetails,0) == INVENTORY_NONE)
			{
				llOwnerSay("Help notecard not found");
			}
			else
			{
				llOwnerSay("Sending help notecard");
				llGiveInventory(llGetOwner(),llList2String(notecardDetails,1));
			}
		}
	}
}
