// Quick use menus
// D-pad up opens the vanilla item popup (potions, decoctions, food), D-pad down the oil popup.

@addField( W3PlayerWitcher )
private var qm_item : SItemUniqueId;

@addField( W3PlayerWitcher )
public var qm_menuOpen : bool;

@addField( W3PlayerWitcher )
public var qm_popup : CR4ItemSelectionPopup;

@addField( CR4ItemSelectionPopup )
private var qm_ownsInput : bool;

@addField( W3GuiPlayerInventoryComponent )
public var qm_showEquipped : bool;


// The vanilla list leaves out equipped items. isEquipped only feeds that check, so our lists lie about it.
@wrapMethod( W3GuiPlayerInventoryComponent )
function isEquipped( item : SItemUniqueId ) : bool
{
	if ( qm_showEquipped )
		return false;

	return wrappedMethod( item );
}


@wrapMethod( CR4ItemSelectionPopup )
function OnConfigUI()
{
	var witcher : W3PlayerWitcher;

	wrappedMethod();

	if ( qm_IsQuickMenu() )
	{
		witcher = GetWitcherPlayer();
		witcher.qm_menuOpen = true;
		witcher.qm_popup = this;

		// slow down instead of pausing
		theGame.Unpause( "ItemSelectionPopup" );
		theGame.SetTimeScale( 0.25f, 'QM_SlowMo', theGame.GetTimescalePriority( ETS_RadialMenu ), false, true );

		// same input setup as the radial wheel so Geralt keeps moving (skipped if the wheel itself is open)
		if ( !qm_WheelIsOpen() )
		{
			qm_ownsInput = true;
			theGame.ForceUIAnalog( true );
			witcher.SetUITakeInput( true );
			thePlayer.BlockAction( EIAB_Jump, 'QM' );
		}
	}

	if ( qm_IsPotionMenu() )
	{
		qm_ShowEquipped();
	}
}


@wrapMethod( CR4ItemSelectionPopup )
function OnClosingPopup()
{
	var witcher : W3PlayerWitcher;

	if ( qm_IsQuickMenu() )
	{
		witcher = GetWitcherPlayer();
		witcher.qm_menuOpen = false;
		witcher.qm_popup = NULL;

		theGame.RemoveTimeScale( 'QM_SlowMo' );

		if ( qm_ownsInput )
		{
			qm_ownsInput = false;
			thePlayer.UnblockAction( EIAB_Jump, 'QM' );
			witcher.SetUITakeInput( false );
			theGame.ForceUIAnalog( false );
		}
	}

	wrappedMethod();
}


// Potions use the item on select. Oils keep the vanilla behaviour (the oil gets applied).
@wrapMethod( CR4ItemSelectionPopup )
function OnCallSelectItem( itemId : SItemUniqueId )
{
	var inv : CInventoryComponent;

	if ( !qm_IsPotionMenu() )
	{
		return wrappedMethod( itemId );
	}

	inv = thePlayer.GetInventory();

	if ( !inv.IsIdValid( itemId ) || ( inv.IsItemSingletonItem( itemId ) && inv.SingletonItemGetAmmo( itemId ) == 0 ) )
	{
		theSound.SoundEvent( "gui_global_denied" );
		return true;
	}

	GetWitcherPlayer().qm_UseItem( itemId );
	return true;
}


@addMethod( CR4ItemSelectionPopup )
public function qm_RefreshList() : void
{
	UpdateData();
}


@addMethod( CR4ItemSelectionPopup )
private function qm_ShowEquipped() : void
{
	m_potionInv.qm_showEquipped = true;
	m_mutagenInv.qm_showEquipped = true;
	m_edibleInv.qm_showEquipped = true;

	// the list is already on screen, rebuild it
	UpdateData();
}


@addMethod( CR4ItemSelectionPopup )
private function qm_WheelIsOpen() : bool
{
	var hud : CR4ScriptedHud;
	var wheel : CR4HudModuleRadialMenu;

	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( !hud )
		return false;

	wheel = (CR4HudModuleRadialMenu)hud.GetHudModule( "RadialMenuModule" );
	if ( !wheel )
		return false;

	return wheel.IsRadialMenuOpened();
}


// potion / decoction / food popup
@addMethod( CR4ItemSelectionPopup )
private function qm_IsPotionMenu() : bool
{
	var result : bool;

	if ( !m_DataObject )
		return false;

	switch ( m_DataObject.selectionMode )
	{
		case EISPM_RadialMenuSlot1:
		case EISPM_RadialMenuSlot2:
		case EISPM_RadialMenuSlot3:
		case EISPM_RadialMenuSlot4:
			result = true;
			break;
		default:
			result = false;
	}

	return result;
}


// potion or oil popup
@addMethod( CR4ItemSelectionPopup )
private function qm_IsQuickMenu() : bool
{
	if ( !m_DataObject )
		return false;

	return qm_IsPotionMenu()
		|| m_DataObject.selectionMode == EISPM_RadialMenuSteelOil
		|| m_DataObject.selectionMode == EISPM_RadialMenuSilverOil;
}


// The popup unpauses when it closes, so the item is used from a short timer.
@addMethod( W3PlayerWitcher )
public function qm_UseItem( item : SItemUniqueId ) : void
{
	qm_item = item;
	RemoveTimer( 'qm_UseItemTimer' );
	AddTimer( 'qm_UseItemTimer', 0.035f, false );
}


@addMethod( W3PlayerWitcher )
timer function qm_UseItemTimer( dt : float, id : int )
{
	var slot : EEquipmentSlots;

	if ( inv.IsIdValid( qm_item ) )
	{
		slot = qm_DrinkSlot( qm_item );

		if ( inv.ItemHasTag( qm_item, 'Edibles' ) )
			ConsumeItem( qm_item );
		else if ( ToxicityLowEnoughToDrinkPotion( slot, qm_item ) )
			DrinkPreparedPotion( slot, qm_item );
		else
			SendToxicityTooHighMessage();
	}

	if ( qm_popup )
		qm_popup.qm_RefreshList();
}


// quick slot the item sits in, or the first potion slot if it isn't equipped
@addMethod( W3PlayerWitcher )
private function qm_DrinkSlot( item : SItemUniqueId ) : EEquipmentSlots
{
	var slot : EEquipmentSlots;

	slot = GetItemSlot( item );

	if ( slot == EES_Potion1 || slot == EES_Potion2 || slot == EES_Potion3 || slot == EES_Potion4 )
		return slot;

	return EES_Potion1;
}
