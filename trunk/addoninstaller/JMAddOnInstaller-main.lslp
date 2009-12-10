// Add-On installer for Opencollar
// $URL$
// $Date$
// $Revision$

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.	See "OpenCollar License" for details.

// internal setup
string g_ConfigNotecard = "InstallerConfig*";
string g_InstallerScript = "JMAddonInstaller - Collar Script*";

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
integer g_UpdateChannel = -7483214;
integer g_DoubleCheckChannel=-0x10CC011A; // channel for finding multiple updaters
integer g_InstallerAlone;
integer g_UpdatePin;
key g_CollarKey;

// Common definitions between installer and uploaded collar script

$import messages.lslm() g_Messages;

//===============================================================================
//= parameters :	string	pattern		pattern to match
//=
//= return :		list				0: item type, or -1 of item doesn't exist
//=										1: item name
//=
//= description :	looks for an item in the local inventory
//=
//===============================================================================
list FindItem(string pattern)
{
	integer type = INVENTORY_NONE;
	string foundName;
	
	if (llGetSubString(pattern,-1,-1) == "*")
	{
		string nameStart = llGetSubString(pattern,0,-2);
		integer nameStartSize = llStringLength(nameStart)-1;
		integer numOfItems = llGetInventoryNumber(INVENTORY_ALL);
		integer i;
		
		for(i=0; i<numOfItems; i++)
		{
			if (llGetSubString(llGetInventoryName(INVENTORY_ALL,i),0,nameStartSize))
			{
				foundName = llGetInventoryName(INVENTORY_ALL,i);
			}
		}
	}
	else
	{
		foundName = pattern;
	}
	type = llGetInventoryType(foundName);
	
	return [type, foundName];
}


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
	else
	{
		return origlist + "|" + item;
	}
}


//===============================================================================
//= parameters :	none
//=
//= return :		none
//=
//= description :	stops all scripts in inventory
//=
//===============================================================================

UnRunScripts()
{
    // set all scripts in me to NOT RUNNING
    integer n;
    for (n = 0; n < llGetInventoryNumber(INVENTORY_SCRIPT); n++)
    {
        string script = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (script != llGetScriptName())
        {
            if (llGetInventoryType(script) == INVENTORY_SCRIPT)
            {
                if(llGetScriptState(script))
                {
                    llSetScriptState(script, FALSE);
                } 
            }
            else
            {
                //somehow we got passed a script we can't find.  Wait a sec and try again
                if (llGetInventoryType(script) == INVENTORY_SCRIPT)
                {
                    llSetScriptState(script, FALSE);        
                }        
                else
                {
                    llWhisper(DEBUG_CHANNEL, "Could not set " + script + " to not running.");
                }
            }
        }
    }    
}

//===============================================================================
//= parameters :	string	name			Name of the item to send
//=					integer	executeScript	If TRUE and if item is a script, execute it after transfer
//=
//= return :		none
//=
//= description :	sends an item to collar
//=
//===============================================================================

SendItem(string name, integer executeScript)
{
	list itemDetails = FindItem(name);
	integer itemType = llList2Integer(itemDetails,0);
	string itemRealName = llList2String(itemDetails,1);
	
	if (itemType == INVENTORY_NONE)
	{
		llOwnerSay("Error: item " + name + " not found");
	}
	else if (itemType == INVENTORY_SCRIPT)
	{
		llRemoteLoadScriptPin(g_CollarKey, itemRealName, g_UpdatePin, executeScript, 4242);
	}
	else
	{
		llGiveInventory(g_CollarKey,itemRealName);
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
				data = llStringTrim(data,STRING_TRIM);
				
				if ((data == "") || (llGetSubString(data,0,0) == "#"))
				{
					// comment or empty line
				}
				else if (llGetSubString(data,0,0) == "[")
				{
					// new category
					if (data == "[Main]")
					{
						g_NotecardCategory = CAT_MAIN;
					}
					else if (data == "[Detection]")
					{
						g_NotecardCategory = CAT_DETECTION;
					}
					else if (data == "[Install]")
					{
						g_NotecardCategory = CAT_INSTALL;
					}
					else if (data == "[RemoveCleanUp]")
					{
						g_NotecardCategory = CAT_REMOVECLUP;
					}
					else if (data == "[UpgradeCleanUp]")
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
					if (g_NotecardCategory = CAT_NONE)
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
								if (keyName == "Name")
								{
									g_ConfigName = keyValue;
								}
								else if (keyName == "Author")
								{
									g_ConfigAuthor = keyValue;
								}
								else if (keyName == "Version")
								{
									g_ConfigVersion = keyValue;
								}
								else if (keyName == "Help")
								{
									g_ConfigHelpCard = keyValue;
								}
								else if (keyName == "MinCollarVersion")
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
								if (keyName = "Item")
								{
									g_RemoveCleanUpItems = AddItem2List(g_RemoveCleanUpItems,data);
								}
								else if (keyName = "Httpdb")
								{
									g_RemoveCleanUpHttpdb = AddItem2List(g_RemoveCleanUpHttpdb,data);
								}
								else if (keyName = "LocalSetting")
								{
									g_RemoveCleanUpLocal = AddItem2List(g_RemoveCleanUpLocal,data);
								}
								else if (keyName = "Script")
								{
									g_RemoveCleanUpScript = data;
								}
								else
								{
									llOwnerSay("Unknown key '" + keyName + "'");
									g_ConfigNoteCardLineNumber = -1;		
								}
							}
							else if (g_NotecardCategory == CAT_UPDATECLUP)
							{
								if (keyName = "Item")
								{
									g_UpdateCleanUpItems = AddItem2List(g_UpdateCleanUpItems,data);
								}
								else if (keyName = "Httpdb")
								{
									g_UpdateCleanUpHttpdb = AddItem2List(g_UpdateCleanUpHttpdb,data);
								}
								else if (keyName = "LocalSetting")
								{
									g_UpdateCleanUpLocal = AddItem2List(g_UpdateCleanUpLocal,data);
								}
								else if (keyName = "Script")
								{
									g_UpdateCleanUpScript = data;
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

			if (g_ConfigNoteCardLineNumber>0)
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
		message += "\nInstaller is ready. Rez your collar\nnext to me, touch it and select Help/Debug->Update";
				
		llSetText(message,<0,0,1>,1);
		
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
					// Collar responed everything is ready, douplicate items were deleted so start to send stuff over
					g_UpdatePin = (integer)command1;
					g_CollarKey = id;
					SendItem(g_InstallerScript, TRUE);
					
					llSetText("Waiting for owner to choose action...",<1,1,0>,1);
				}
				else if (command0 == g_MessagesHeader)
				{
					if (command1 == g_MessagesStart)
					{
						string mode = llList2String(temp,2);
					}
				}
			}
		}
	}	
}
