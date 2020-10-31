local _, addonTable = ...
local CustomBuffs = addonTable.CustomBuffs


-------------------------------------------------------------------------
-------------------------------------------------------------------------

function CustomBuffs:Defaults()
	local defaults = {};

	defaults.profile = {
		frameScale = 1,
		loadTweaks = false,
		extraDebuffs = false,
		cleanNames = true
	};

	return defaults
end
