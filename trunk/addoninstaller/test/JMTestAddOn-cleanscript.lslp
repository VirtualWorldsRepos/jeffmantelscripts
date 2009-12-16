// Example clean up script for add-on installer
// $URL$
// $Date$
// $Revision$

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

// Communication channel between installer and uploaded collar script
integer g_UpdateChannel = -7483214;


//===============================================================================
//= parameters   :    none
//=
//= return        :    none
//=
//= description  :    call this function when the clean up is complete
//=
//===============================================================================

CleanUpDone()
{
	llSay(g_UpdateChannel,"JMAddOnInstaller|done|script");
	llRemoveInventory(llGetScriptName());
}


default
{
	state_entry()
	{
		if (llGetStartParameter() == 4242)
		{
			// we are in the collar and started by the installer
			
			// perform clean up steps here

			llOwnerSay("Clean-up script executed!");
			
			CleanUpDone();
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
}

