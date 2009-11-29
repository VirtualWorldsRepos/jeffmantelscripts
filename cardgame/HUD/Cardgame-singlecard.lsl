// Card game plugin for Opencollar: HUD card
// $URL$
// $Date$
// $Revision$

// script to put in a single card

integer CARD_SIDE=4;

integer LINK_FROMCOLLAR = 1000;
integer LINK_TOCOLLAR = 1001;

string g_CardName;

// internal messages id
string g_MessagesID = "jm_cardgame";

string g_LabelResetCard = "resetcards";
string g_LabelShowCard = "showcard";

SetImage(integer x, integer y)
{
    llOffsetTexture((x-5)/11.0,(2-y)/5.0,CARD_SIDE);
}

HideCard()
{
    SetImage(8,4);
}    

SetCard(integer color, integer value)
{
    integer imageNumber;
    
    color = color % 4;
    imageNumber = color * 13 + (13 - value);
    SetImage(imageNumber % 11,imageNumber / 11);
}

default
{
    state_entry()
    {
        list objDescargs = llParseString2List(llGetObjectDesc(),[" "],[]);
        g_CardName = llList2String(objDescargs,0);
    }

    link_message(integer sender_num, integer num, string str, key id)
    {
        if (num == LINK_FROMCOLLAR)
        {
            list args = llParseString2List(str,["|"],[]);
            if (llList2String(args,0) == g_MessagesID)
            {
                if (llList2String(args,1) == g_LabelResetCard)
                {
                    HideCard();
                }
                else if (llList2String(args,1) == g_LabelShowCard)
                {
                    if (llList2String(args,2) == g_CardName)
                    {
                        SetCard(llList2Integer(args,3),llList2Integer(args,4));
                    }
                }
            }
        }
    }
}


