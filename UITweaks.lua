--Non Aura junk

if not CustomBuffs then
    CustomBuffs = {};
end

--Create a permanently hidden frame to set as the parent of blizzard frames
--we want to hide later
if not MyHiddenFrame then
    MyHiddenFrame = CreateFrame("Frame","MyHiddenFrame");
    MyHiddenFrame:Hide();
end

------- Macro Test Stuff -------
local hexMac1 = CreateFrame("Button", "hexMac1", UIParent, "SecureActionButtonTemplate");
hexMac1:SetAttribute("type", "macro");
hexMac1:SetAttribute("macrotext", "/changeactionbar 2\n/click [mod] ActionButton9; ActionButton10\n/changeactionbar 1\n/click hexMac2");

local hexMac2 = CreateFrame("Button", "hexMac2", UIParent, "SecureActionButtonTemplate");
hexMac2:SetAttribute("type", "macro");
hexMac2:SetAttribute("macrotext", "/stopmacro [@focus,noharm]\n/stopmacro [noexists]\n/targetlasttarget [nomod]\n/stopmacro [exists]\n/target focus");

local bwonsamdi = CreateFrame("Button", "bwns", UIParent, "SecureActionButtonTemplate");
bwonsamdi:SetAttribute("type", "macro");
bwonsamdi:SetAttribute("macrotext", "/stopmacro [noexists]\n/run ID=GetInventoryItemID(\"player\",13);if ID then _,a,b=GetItemCooldown(ID);if not UnitCastingInfo(\"player\") and a==0 and b==1 then PlaySound(122273,true);end end");

local pathetic = CreateFrame("Button", "sylv", UIParent, "SecureActionButtonTemplate");
pathetic:SetAttribute("type", "macro");
pathetic:SetAttribute("macrotext", "/run ID=GetInventoryItemID(\"player\",14);if ID then _,a,b=GetItemCooldown(ID);if not UnitCastingInfo(\"player\") and a==0 and b==1 then PlaySound(17046,true);end end");


local toy1 = CreateFrame("Button", "toy1", UIParent, "SecureActionButtonTemplate");
toy1:SetAttribute("type", "macro");
toy1:SetAttribute("macrotext", "/use Apexis Focusing Shard\n/use Autographed Hearthstone Card\n/use Azeroth Mini Collection: Mechagon\n/use Brazier of Dancing Flames\n/use Brewfest Keg Pony\n/use Bubble Wand\n/use Chalice of the Mountain Kings\n/use Croak Crock\n/click toy2");

local toy2 = CreateFrame("Button", "toy2", UIParent, "SecureActionButtonTemplate");
toy2:SetAttribute("type", "macro");
toy2:SetAttribute("macrotext", "/use Desert Flute\n/use Echoes of Rezan\n/use Enchanted Stone Whistle\n/use Everlasting Darkmoon Firework\n/use Everlasting Horde Firework\n/use Fire-Eater's Vial\n/use Foul Belly\n/use Fruit Basket\n/click toy3");

local toy3 = CreateFrame("Button", "toy3", UIParent, "SecureActionButtonTemplate");
toy3:SetAttribute("type", "macro");
toy3:SetAttribute("macrotext", "/use Hearthstone Board\n/use Hourglass of Eternity\n/use Hot Buttered Popcorn\n/use Kaldorei Wind Chimes\n/use Ley Spider Eggs\n/use Panflute of Pandaria\n/use Pendant of the Scarab Storm\n/click toy4");

local toy4 = CreateFrame("Button", "toy4", UIParent, "SecureActionButtonTemplate");
toy4:SetAttribute("type", "macro");
toy4:SetAttribute("macrotext", "/use Rainbow Generator\n/use Seafarer's Slidewhistle\n/use Slightly-Chewed Insult Book\n/use Spirit of Bashiok\n/use Stackable Stag\n/use Sylvanas' Music Box\n/use Tear of the Green Aspect\n/click toy5");

local toy5 = CreateFrame("Button", "toy5", UIParent, "SecureActionButtonTemplate");
toy5:SetAttribute("type", "macro");
toy5:SetAttribute("macrotext", "/use Titanium Seal of Dalaran\n/use Verdant Throwing Sphere\n/use Void Totem\n/use Void-Touched Souvenir Totem\n/use Words of Akunda\n/use Wisp in a Bottle\n/use Worn Doll\n/use Winning Hand\n/click toy5");

local toy6 = CreateFrame("Button", "toy6", UIParent, "SecureActionButtonTemplate");
toy6:SetAttribute("type", "macro");
toy6:SetAttribute("macrotext", "/use Xan'tish's Flute\n");



--Clean up pet frame
PetName:SetAlpha(0);
PetFrameHealthBarTextLeft:SetAlpha(0);
PetFrameManaBarTextRight:ClearAllPoints();
PetFrameManaBarTextRight:SetPoint("CENTER","PetFrameManaBar","CENTER",0,-2);
PetFrameManaBarTextLeft:SetAlpha(0);
PetFrameHealthBarTextRight:ClearAllPoints();
PetFrameHealthBarTextRight:SetPoint("CENTER","PetFrameHealthBar","CENTER",0,0);

--Hide extraactionbutton background
ExtraActionBarFrame.button.style:SetAlpha(0);
--ZoneAbilityFrame.SpellButton.Style:SetAlpha(0);

--Hide group number on player frame
PlayerFrameGroupIndicator.Show = function() return; end
PlayerFrameGroupIndicator:Hide();

--Move action bars around
MultiBarBottomLeft:ClearAllPoints();
MultiBarBottomLeft:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT",0,7);
MultiBarBottomLeft.ignoreFramePositionManager = true;

MultiBarBottomRightButton7:ClearAllPoints();
MultiBarBottomRightButton7:SetPoint("BOTTOMLEFT", MultiBarBottomRightButton1, "TOPLEFT",0,7);
MultiBarBottomRightButton7.ignoreFramePositionManager = true;

--Reassign menu buttons to more intuitive parents
AchievementMicroButton:SetParent(MicroButtonAndBagsBar);
CharacterMicroButton:SetParent(MicroButtonAndBagsBar);
CollectionsMicroButton:SetParent(MicroButtonAndBagsBar);
EJMicroButton:SetParent(MicroButtonAndBagsBar);
GuildMicroButton:SetParent(MicroButtonAndBagsBar);
HelpMicroButton:SetParent(MicroButtonAndBagsBar);
LFDMicroButton:SetParent(MicroButtonAndBagsBar);
QuestLogMicroButton:SetParent(MicroButtonAndBagsBar);
SpellbookMicroButton:SetParent(MicroButtonAndBagsBar);
StoreMicroButton:SetParent(MicroButtonAndBagsBar);
TalentMicroButton:SetParent(MicroButtonAndBagsBar);
MainMenuMicroButton:SetParent(MicroButtonAndBagsBar);

--Scale the row of menu buttons down
local BUTTON_SCALE = 0.7;
MicroButtonAndBagsBar.MicroBagBar:Hide();
MicroButtonAndBagsBar:ClearAllPoints();
MicroButtonAndBagsBar:SetPoint("BOTTOMLEFT",StatusTrackingBarManager,"BOTTOMRIGHT",-5,-23);
MicroButtonAndBagsBar:SetScale(BUTTON_SCALE);

MainMenuBarArtFrame.LeftEndCap:Hide();
MainMenuBarArtFrame.RightEndCap:Hide();
MainMenuBarArtFrameBackground:Hide();

StanceBarFrame.ignoreFramePositionManager = true;
StanceBarFrame:Hide();
StanceBarFrame:SetParent("MyHiddenFrame");

TargetFramePowerBarAlt.ignoreFramePositionManager = true;
TargetFramePowerBarAlt:Hide();
TargetFramePowerBarAlt:SetParent("MyHiddenFrame");





--Debug Stuff
if CustomBuffs and not CustomBuffs.DeepCopy then
    CustomBuffs.DeepCopy = function(obj, seen)
      -- Handle non-tables and previously-seen tables.
      if type(obj) ~= 'table' then return obj end
      if seen and seen[obj] then return seen[obj] end

      -- New table; mark it as seen an copy recursively.
      local s = seen or {}
      local res = setmetatable({}, getmetatable(obj))
      s[obj] = res
      for k, v in pairs(obj) do res[CustomBuffs.DeepCopy(k, s)] = CustomBuffs.DeepCopy(v, s) end
      return res
    end
end

if CustomBuffs and not CustomBuffs.DebugPrintTable then
    CustomBuffs.DebugPrintTable = function(node)
        -- to make output beautiful
        local function tab(amt)
            local str = ""
            for i=1,amt do
                str = str .. "\t"
            end
            return str
        end

        local cache, stack, output = {},{},{}
        local depth = 1
        local output_str = "{\n"

        while true do
            local size = 0
            for k,v in pairs(node) do
                size = size + 1
            end

            local cur_index = 1
            for k,v in pairs(node) do
                if (cache[node] == nil) or (cur_index >= cache[node]) then

                    if (string.find(output_str,"}",output_str:len())) then
                        output_str = output_str .. ",\n"
                    elseif not (string.find(output_str,"\n",output_str:len())) then
                        output_str = output_str .. "\n"
                    end

                    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                    table.insert(output,output_str)
                    output_str = ""

                    local key
                    if (type(k) == "number" or type(k) == "boolean") then
                        key = "["..tostring(k).."]"
                    else
                        key = "['"..tostring(k).."']"
                    end

                    if (type(v) == "number" or type(v) == "boolean") then
                        output_str = output_str .. tab(depth) .. key .. " = "..tostring(v)
                    elseif (type(v) == "table") then
                        output_str = output_str .. tab(depth) .. key .. " = {\n"
                        table.insert(stack,node)
                        table.insert(stack,v)
                        cache[node] = cur_index+1
                        break
                    else
                        output_str = output_str .. tab(depth) .. key .. " = '"..tostring(v).."'"
                    end

                    if (cur_index == size) then
                        output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                    else
                        output_str = output_str .. ","
                    end
                else
                    -- close the table
                    if (cur_index == size) then
                        output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                    end
                end

                cur_index = cur_index + 1
            end

            if (size == 0) then
                output_str = output_str .. "\n" .. tab(depth-1) .. "}"
            end

            if (#stack > 0) then
                node = stack[#stack]
                stack[#stack] = nil
                depth = cache[node] == nil and depth + 1 or depth - 1
            else
                break
            end
        end

        -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
        table.insert(output,output_str)
        output_str = table.concat(output)

        return output_str
    end
end
