/***********************************************************************/
/** 	QuickUseMenus - popup behaviour
/** 	D-pad Up   : vanilla item popup (potions / decoctions / food), select = use it.
/** 	D-pad Down : vanilla oil popup, select = vanilla behaviour (applies the oil).
/** 	The popup slows the game down instead of pausing it, keeps the player on the
/** 	radial-menu input context (like the vanilla wheel) and blocks RB item actions.
/** 	Do not run together with the "Quickuse Consumable" mod.
/***********************************************************************/

@addField( W3PlayerWitcher )
private var qum_item : SItemUniqueId;

// true while a quick popup opened by this mod is on screen (read by playerInput.ws)
@addField( W3PlayerWitcher )
public var qum_popupOpen : bool;

@addField( CR4ItemSelectionPopup )
private var qum_ownsContext : bool;


// Flip to false to go back to "player stands still" if the radial-style input context ever misbehaves.
@addMethod( CR4ItemSelectionPopup )
private function qum_KeepMoving() : bool
{
	return true;
}


@wrapMethod( CR4ItemSelectionPopup )
function OnConfigUI()
{
	var witcher : W3PlayerWitcher;

	// vanilla setup (this issues the initial pause)
	wrappedMethod();

	if ( qum_IsQuickUsePopup() )
	{
		// cancel the pause and slow the game down instead (same source/priority style as the radial wheel)
		theGame.Unpause( "ItemSelectionPopup" );
		theGame.SetTimeScale( 0.25f, 'QUM_SlowMo', theGame.GetTimescalePriority( ETS_RadialMenu ), false, true );

		witcher = GetWitcherPlayer();
		witcher.qum_popupOpen = true;

		// Mimic what the vanilla radial wheel sets up, unless the wheel itself is already open
		if ( qum_KeepMoving() && !qum_RadialMenuIsOpen() )
		{
			qum_ownsContext = true;
			theGame.ForceUIAnalog( true );
			theInput.StoreContext( 'RadialMenu' );
			witcher.SetUITakeInput( true );
			thePlayer.BlockAction( EIAB_Jump, 'QUM' );
		}
	}
}


@wrapMethod( CR4ItemSelectionPopup )
function OnClosingPopup()
{
	var witcher : W3PlayerWitcher;

	if ( qum_IsQuickUsePopup() )
	{
		theGame.RemoveTimeScale( 'QUM_SlowMo' );
		witcher = GetWitcherPlayer();
		witcher.qum_popupOpen = false;

		if ( qum_ownsContext )
		{
			qum_ownsContext = false;
			thePlayer.UnblockAction( EIAB_Jump, 'QUM' );
			witcher.SetUITakeInput( false );
			theInput.RestoreContext( 'RadialMenu', true );
			theGame.ForceUIAnalog( false );
		}
	}

	wrappedMethod();
}


@wrapMethod( CR4ItemSelectionPopup )
function OnCallSelectItem( itemId : SItemUniqueId )
{
	var witcher : W3PlayerWitcher;
	var inv : CInventoryComponent;
	var canUse : bool;

	// Only potion/food/decoction popups consume the item. Oil popups keep the vanilla
	// behaviour so the oil is applied to the sword.
	if ( !qum_IsConsumablePopup() )
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
private function qum_RadialMenuIsOpen() : bool
{
	var hud : CR4ScriptedHud;
	var module : CR4HudModuleRadialMenu;

	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( hud )
	{
		module = (CR4HudModuleRadialMenu)hud.GetHudModule( "RadialMenuModule" );
		if ( module )
		{
			return module.IsRadialMenuOpened();
		}
	}

	return false;
}


// Potions / foods / decoctions only (quick slots 1-4 popup modes)
@addMethod( CR4ItemSelectionPopup )
private function qum_IsConsumablePopup() : bool
{
	if ( !m_DataObject )
		return false;

	return m_DataObject.selectionMode == EISPM_RadialMenuSlot1
		|| m_DataObject.selectionMode == EISPM_RadialMenuSlot2
		|| m_DataObject.selectionMode == EISPM_RadialMenuSlot3
		|| m_DataObject.selectionMode == EISPM_RadialMenuSlot4;
}


// Any popup this mod opens: consumables and oils
@addMethod( CR4ItemSelectionPopup )
private function qum_IsQuickUsePopup() : bool
{
	if ( !m_DataObject )
		return false;

	return qum_IsConsumablePopup()
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
