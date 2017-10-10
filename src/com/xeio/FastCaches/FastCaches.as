import com.GameInterface.DistributedValue;
import com.GameInterface.Game.Character;
import com.GameInterface.Inventory;
import com.GameInterface.Tooltip.TooltipData;
import com.Utils.Archive;
import com.Utils.ID32;
import com.Utils.LDBFormat;
import mx.utils.Delegate;

class FastCaches
{    
    private var m_swfRoot: MovieClip;

    private var m_baseOpenChest:Function;
    private var m_isLootbox:Boolean = false;
    private var m_lootboxWindowValue:DistributedValue;
    private var m_inventory:Inventory;
    private var m_lastChangedCache:String;
    
    private var CACHEKEY_NAME:String = LDBFormat.LDBGetText(10028, 102502534);

    public static function main(swfRoot:MovieClip):Void 
    {
        var fastCaches = new FastCaches(swfRoot);

        swfRoot.onLoad = function() { fastCaches.OnLoad(); };
        swfRoot.OnUnload = function() { fastCaches.OnUnload(); };
        swfRoot.OnModuleActivated = function(config:Archive) { fastCaches.Activate(config); };
        swfRoot.OnModuleDeactivated = function() { return fastCaches.Deactivate(); };
    }

    public function FastCaches(swfRoot: MovieClip) 
    {
        m_swfRoot = swfRoot;
    }

    public function OnUnload()
    {
        UnwireLootboxUIEvents();
        
        m_lootboxWindowValue.SignalChanged.Disconnect(LootboxWindowVisibleChange, this);
        m_lootboxWindowValue = undefined;
        
        m_inventory.SignalItemStatChanged.Disconnect(SlotItemUpdated, this);
        m_inventory.SignalItemChanged.Disconnect(SlotItemUpdated, this);
        m_inventory = undefined;
    }

    public function Activate(config: Archive)
    {
    }

    public function Deactivate(): Archive
    {
        var archive: Archive = new Archive();			
        return archive;
    }

    public function OnLoad()
    {
        setTimeout(Delegate.create(this, Initialize), 200);
    }

    public function Initialize()
    {
        m_inventory = new Inventory(new com.Utils.ID32(_global.Enums.InvType.e_Type_GC_BackpackContainer, Character.GetClientCharID().GetInstance()));
        
        m_lootboxWindowValue = DistributedValue.Create("lootBox_window");
        m_lootboxWindowValue.SignalChanged.Connect(LootboxWindowVisibleChange, this);
        
        m_inventory.SignalItemStatChanged.Connect(SlotItemUpdated, this);
        m_inventory.SignalItemChanged.Connect(SlotItemUpdated, this);
    }
    
    private function LootboxWindowVisibleChange()
    {
        if (m_lootboxWindowValue.GetValue())
        {
            m_isLootbox = false;
            WireLootboxUIEvents();
        }
        else
        {
            UnwireLootboxUIEvents();
            if (m_isLootbox && m_lastChangedCache && Character.GetClientCharacter().GetTokens(_global.Enums.Token.e_Lockbox_Key) > 0)
            {
                setTimeout(Delegate.create(this, FindLootBoxToOpen), 100);
            }
        }
    }
    
    private function WireLootboxUIEvents()
    {
        if (!_root.lootbox.m_Window.m_Content)
        {
            if (m_lootboxWindowValue.GetValue())
            {
                //UI hasn't shown yet, lets give it another moment...
                setTimeout(Delegate.create(this, WireLootboxUIEvents), 50);
            }
            return;
        }
        m_baseOpenChest = Delegate.create(_root.lootbox.m_Window.m_Content, _root.lootbox.m_Window.m_Content.OpenChest);
        _root.lootbox.m_Window.m_Content.OpenChest = Delegate.create(this, FastOpenChest);
        _root.lootbox.m_Window.m_Content.m_Hovered = false;
        _root.lootbox.m_Window.m_Content.CheckHover();
    }
    
    private function UnwireLootboxUIEvents()
    {
        if (m_baseOpenChest)
        {
            _root.lootbox.m_Window.m_Content.OpenChest = m_baseOpenChest;
            m_baseOpenChest = undefined;
        }
    }
        
    function FastOpenChest()
    {
        m_baseOpenChest();
        m_isLootbox = _root.lootbox.m_Window.m_Content.m_TokenType == _global.Enums.Token.e_Lockbox_Key;
        _root.lootbox.m_Window.m_Content.m_Chest.stop();
        _root.lootbox.m_Window.m_Content.m_Chest.gotoAndStop(_root.lootbox.m_Window.m_Content.m_Chest._totalframes);
    }
    
    function FindLootBoxToOpen()
    {
        for (var i = 0 ; i < m_inventory.GetMaxItems(); i++)
        {
            if (m_inventory.GetItemAt(i).m_Name == m_lastChangedCache)
            {
                m_inventory.UseItem(i);
                break;
            }
        }
    }
    
    function SlotItemUpdated(inventoryID:ID32, itemPos:Number)
    {
        if (m_inventory.GetItemAt(itemPos).m_ItemTypeGUI == 180871029) //Consumable type for caches
        {
            var tooltipData:TooltipData = com.GameInterface.Tooltip.TooltipDataProvider.GetInventoryItemTooltip(inventoryID, itemPos);
            if (tooltipData && tooltipData.m_Descriptions[0].indexOf(CACHEKEY_NAME) > 0)
            {
                m_lastChangedCache = m_inventory.GetItemAt(itemPos).m_Name;
            }
        }
    }
}