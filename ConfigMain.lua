local _, addonTable = ...
local CustomBuffs = addonTable.CustomBuffs


-------------------------------------------------------------------------
-------------------------------------------------------------------------

function CustomBuffs:CreateGeneralOptions()
	local THIRD_WIDTH = 1.15

	local generalOptions = {
		type = "group",
		childGroups = "tree",
		name = "Options",
		args  = {
			-------------------------------------------------
			topSpacer = {
				type = "header",
				name = "",
				order = 3,
			},
			blizzardRaidOptionsButton = {
				type = 'execute',
				name = "Open the Blizzard Raid Profiles Menu",
				desc = "",
				func = function() InterfaceOptionsFrame_OpenToCategory("Raid Profiles") end,
				width = THIRD_WIDTH * 1.5,
				order = 4,
			},
            -------------------------------------------------
            spacer2 = {
                type = "header",
				name = "",
				order = 50,
            },
			frameScale = {
				type = "range",
				name = "Raidframe Scale",
				desc = "",
				min = 0.5,
				max = 2,
				step = 0.1,
				get = function() return self.db.profile.frameScale end,
				set = function(_, value)
					self.db.profile.frameScale = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 51,
			},
            spacer3 = {
                type = "header",
                name = "",
                order = 10,
            },
            useTweaks = {
				type = "toggle",
				name = "Enable UI Tweaks (requires reload on disable)",
				desc = "",
				get = function() return self.db.profile.loadTweaks end,
				set = function(_, value)
					self.db.profile.loadTweaks = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH * 2,
				order = 11,
			},
            extraDebuffs = {
				type = "toggle",
				name = "Enable Extra Party Debuffs",
				desc = "Creates 9 Extra debuff frames to the left of each of the raid frames when the group size is smaller than 6",
				get = function() return self.db.profile.extraDebuffs end,
				set = function(_, value)
					self.db.profile.extraDebuffs = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 52,
			},
            cleanNames = {
				type = "toggle",
				name = "Clean Names",
				desc = "Trim server names and shorten player names on raid frames",
				get = function() return self.db.profile.cleanNames end,
				set = function(_, value)
					self.db.profile.cleanNames = value;
					self:UpdateConfig();
				end,
				width = THIRD_WIDTH,
				order = 53,
			},
		}
	}

	return generalOptions
end
