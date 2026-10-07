 // Enables users to press D-pad Up to show list of Potions, Foods, and Decoctions and use it.

// Enables users to press D-pad Down to show list of Oils and use it.


@addField( W3PlayerWitcher )

private var qum_item : SItemUniqueId;


// 1. Hook into OnConfigUI where the game initially applies its hard pause

@wrapMethod( CR4ItemSelectionPopup )

function OnConfigUI()

{

    // Run vanilla setup (which issues the initial 'ItemSelectionPopup' pause)

    wrappedMethod();


    if ( qum_IsQuickUsePopup() )

    {

        // Immediately cancel the base menu's pause request

        theGame.Unpause("ItemSelectionPopup");


        // Apply slow motion (0.25f = 25% game speed)

        theGame.SetTimeScale(0.25f, 'QUM_SlowMo', 10, true, false);

    }

}


// 2. Hook into OnClosingPopup to cleanly strip away slow motion when closed

@wrapMethod( CR4ItemSelectionPopup )

function OnClosingPopup()

{

    if ( qum_IsQuickUsePopup() )

    {

        // Remove the time scale modifier using its identifier tag

        theGame.RemoveTimeScale('QUM_SlowMo');

    }


    wrappedMethod();

}


@wrapMethod( CR4ItemSelectionPopup )

function OnCallSelectItem( itemId : SItemUniqueId )

{

    var witcher : W3PlayerWitcher;

    var inv : CInventoryComponent;

    var canUse : bool;


    if ( !qum_IsQuickUsePopup() )

    {

        wrappedMethod( itemId );

    }

    else

    {

        witcher = GetWitcherPlayer();

        inv = thePlayer.GetInventory();


        canUse = true;


        if ( !witcher )

            canUse = false;


        if ( !inv.IsIdValid( itemId ) )

            canUse = false;


        if ( inv.IsItemSingletonItem( itemId ) && inv.SingletonItemGetAmmo( itemId ) == 0 )

            canUse = false;


        if ( canUse )

        {

            ClosePopup();

            witcher.qum_UseItem( itemId );

        }

        else

        {

            theSound.SoundEvent( "gui_global_denied" );

        }

    }

}


@addMethod( CR4ItemSelectionPopup )

private function qum_IsQuickUsePopup() : bool

{

    if ( !m_DataObject )

        return false;


    // Checks both Potions/Foods/Decoctions (Slots 1-4) and Oils (Steel/Silver Oil)

    return m_DataObject.selectionMode == EISPM_RadialMenuSlot1

        || m_DataObject.selectionMode == EISPM_RadialMenuSlot2

        || m_DataObject.selectionMode == EISPM_RadialMenuSlot3

        || m_DataObject.selectionMode == EISPM_RadialMenuSlot4

        || m_DataObject.selectionMode == EISPM_RadialMenuSteelOil

        || m_DataObject.selectionMode == EISPM_RadialMenuSilverOil;

}


@addMethod( W3PlayerWitcher )

public function qum_UseItem( item : SItemUniqueId ) : void

{

    qum_item = item;

    RemoveTimer( 'qum_UseItemTimer' );

    AddTimer( 'qum_UseItemTimer', 0.035f, false );

}


@addMethod( W3PlayerWitcher )

timer function qum_UseItemTimer( dt : float, id : int )

{

    if ( !inv.IsIdValid( qum_item ) )

        return;


    if ( inv.ItemHasTag( qum_item, 'Edibles' ) )

    {

        ConsumeItem( qum_item );

    }

    else if ( ToxicityLowEnoughToDrinkPotion( EES_Potion1, qum_item ) )

    {

        DrinkPreparedPotion( EES_Potion1, qum_item );

    }

    else

    {

        SendToxicityTooHighMessage();

    }

}
