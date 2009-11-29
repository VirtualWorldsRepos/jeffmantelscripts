// Card game plugin for Opencollar: HUD root
// $ URL $
// $ Date $
// $ Revision $

// put this script in the root prim covering the cards

integer CARD_CHANNEL_OFFSET=1875;
integer COLLAR_CHANNEL_OFFSET=1111;

integer LINK_FROMCOLLAR = 1000;
integer LINK_TOCOLLAR = 1001;

key g_Wearer=NULL_KEY;

// internal messages id
string g_MessagesID = "jm_cardgame";

string g_LabelResetCards = "resetcards";
string g_LabelTouchedCards = "touchedCards";

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

Reset()
{
    llMessageLinked(LINK_SET, LINK_FROMCOLLAR, g_MessagesID+"|"+g_LabelResetCards, NULL_KEY);
    g_Wearer = llGetOwner();
    llListen(nGetOwnerChannel(g_Wearer,CARD_CHANNEL_OFFSET),"",NULL_KEY,"");
}

default
{
    state_entry()
    {
        if (g_Wearer == NULL_KEY)
        {
            g_Wearer = llGetOwner();
            Reset();
        }
    }
    
    on_rez(integer param)
    {
        if (g_Wearer != llGetOwner())
        {
            // reset script if owner changed
            llResetScript();
        }
    }

    touch_start(integer total_number)
    {
        llMessageLinked(LINK_SET, LINK_TOCOLLAR, g_MessagesID+"|"+g_LabelTouchedCards, NULL_KEY);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (llGetOwnerKey(id) == g_Wearer)
        {
            llMessageLinked(LINK_SET, LINK_FROMCOLLAR, message, NULL_KEY);
        }
    }
    
    link_message(integer sender_num, integer num, string str, key id)
    {
        if (num == LINK_TOCOLLAR)
        {
            llSay(nGetOwnerChannel(g_Wearer,COLLAR_CHANNEL_OFFSET),str);
        }
    }
}


