	
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	local _detalhes = 		_G._detalhes
	local Loc = LibStub ("AceLocale-3.0"):GetLocale ( "Details" )
	local _
	
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Profiles:
	--> return the current profile name
	
function _detalhes:GetCurrentProfileName()

	--> check is have a profile name
		if (_detalhes_database.active_profile == "") then --  or not _detalhes_database.active_profile
			local character_key = UnitName ("player") .. "-" .. GetRealmName()
			_detalhes_database.active_profile = character_key
		end
	
	--> end
		return _detalhes_database.active_profile
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Profiles:
	--> create a new profile

function _detalhes:CreateProfile (name)

	if (not name or type (name) ~= "string" or name == "") then
		return false
	end

	--> check if already exists
		if (_detalhes_global.__profiles [name]) then
			return false
		end
		
	--> copy the default table
		local new_profile = table_deepcopy (_detalhes.default_profile)
		new_profile.instances = {}
	
	--> add to global container
		_detalhes_global.__profiles [name] = new_profile
		
	--> end
		return new_profile
	
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Profiles:
	--> return the list os all profiles
	
function _detalhes:GetProfileList()
	
	--> build the table
		local t = {}
		for name, profile in pairs (_detalhes_global.__profiles) do 
			t [#t + 1] = name
		end
	
	--> end
		return t
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Profiles:
	--> delete a profile
	
function _detalhes:EraseProfile (profile_name)
	
	--> erase profile table
		_detalhes_global.__profiles [profile_name] = nil
	
		if (_detalhes_database.active_profile == profile_name) then
		
			local character_key = UnitName ("player") .. "-" .. GetRealmName()
			
			local my_profile = _detalhes:GetProfile (character_key)
			
			if (my_profile) then
				_detalhes:ApplyProfile (character_key, true)
			else
				local profile = _detalhes:CreateProfile (character_key)
				_detalhes:ApplyProfile (character_key, true)
			end
		
		end

	--> end
		return true
end
	
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Profiles:
	--> return the profile table requested
	
function _detalhes:GetProfile (name, create)

	--> get the profile, create and return
		if (not name) then
			name = _detalhes:GetCurrentProfileName()
		end
		
		local profile = _detalhes_global.__profiles [name]

		if (not profile and not create) then
			return false

		elseif (not profile and create) then
			profile = _detalhes:CreateProfile (name)

		end
	
	--> end
		return profile
end	

function _detalhes:SetProfileCProp (name, cprop, value)
	if (not name) then
		name = _detalhes:GetCurrentProfileName()
	end

	local profile = _detalhes:GetProfile (name, false)
	
	if (profile) then
		if (type (value) == "table") then
			rawset (profile, cprop, table_deepcopy (value))
		else
			rawset (profile, cprop, value)
		end
	else
		return
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Profiles:
	--> reset the profile
function _detalhes:ResetProfile (profile_name)

	--> get the profile
		local profile = _detalhes:GetProfile (profile_name, true)
		
		if (not profile) then
			return false
		end
	
	--> reset all already created instances
		for index, instance in _detalhes:ListInstances() do
			if (not instance.baseframe) then
				instance:AtivarInstancia()
			end
			instance.skin = ""
			instance:ChangeSkin (_detalhes.default_skin_to_use)
		end
		
		for index, instance in pairs (_detalhes.unused_instances) do
			if (not instance.baseframe) then
				instance:AtivarInstancia()
			end
			instance.skin = ""
			instance:ChangeSkin ("Minimalistic v2")
		end
	
	--> reset the profile
		table.wipe (profile.instances)

		--> export first instance
		local instance = _detalhes:GetInstance (1)
		local exported = instance:ExportSkin()
		exported.__was_opened = instance:IsEnabled()
		exported.__pos = table_deepcopy (instance:GetPosition())
		exported.__locked = instance.isLocked
		exported.__snap = {}
		exported.__snapH = false
		exported.__snapV = false
		profile.instances [1] = exported
		instance.horizontalSnap = false
		instance.verticalSnap = false
		instance.snap = {}
		
		_detalhes:ApplyProfile (profile_name, true)
		
	--> end
		return true
end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Profiles:
	--> return the profile table requested

function _detalhes:CreatePanicWarning()
	_detalhes.instance_load_failed = CreateFrame ("frame", "DetailsPanicWarningFrame", UIParent)
	_detalhes.instance_load_failed:SetHeight (80)
	--tinsert (UISpecialFrames, "DetailsPanicWarningFrame")
	_detalhes.instance_load_failed.text = _detalhes.instance_load_failed:CreateFontString (nil, "overlay", "GameFontNormal")
	_detalhes.instance_load_failed.text:SetPoint ("center", _detalhes.instance_load_failed, "center")
	_detalhes.instance_load_failed.text:SetTextColor (1, 0.6, 0)
	_detalhes.instance_load_failed:SetBackdrop ({bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
	_detalhes.instance_load_failed:SetBackdropColor (1, 0, 0, 0.2)
	_detalhes.instance_load_failed:SetPoint ("topleft", UIParent, "topleft", 0, -250)
	_detalhes.instance_load_failed:SetPoint ("topright", UIParent, "topright", 0, -250)
end

local safe_load = function (func, param1, param2)
	local okey, errortext = pcall (func, param1, param2)
	if (not okey) then
		if (not _detalhes.instance_load_failed) then
			_detalhes:CreatePanicWarning()
		end
		_detalhes.do_not_save_skins = true
		_detalhes.instance_load_failed.text:SetText ("Failed to load a Details! window.\n/reload or reboot the game client may fix the problem.\nIf the problem persist, try /details reinstall.\nError: " .. errortext .. "")
	end
	return okey
end

function _detalhes:ApplyProfile (profile_name, nosave, is_copy)

	--> get the profile
		local profile = _detalhes:GetProfile (profile_name, true)

	--> if the profile doesn't exist, just quit
		if (not profile) then
			_detalhes:Msg ("Profile Not Found.")
			return false
		end
		
	--> always save the previous profile, except if nosave flag is up
		if (not nosave) then
			--> salva o profile ativo no momento
			_detalhes:SaveProfile()
		end

	--> update profile keys before go
		for key, value in pairs (_detalhes.default_profile) do 
			if (profile [key] == nil) then
				if (type (value) == "table") then
					profile [key] = table_deepcopy (_detalhes.default_profile [key])
				else
					profile [key] = value
				end
				
			elseif (type (value) == "table") then
				for key2, value2 in pairs (value) do 
					if (profile [key] [key2] == nil) then
						if (type (value2) == "table") then
							profile [key] [key2] = table_deepcopy (_detalhes.default_profile [key] [key2])
						else
							profile [key] [key2] = value2
						end
					end
				end
				
			end
		end
		
	--> apply the profile values
		for key, _ in pairs (_detalhes.default_profile) do 
			local value = profile [key]

			if (type (value) == "table") then
				if (key == "class_specs_coords") then
					value = table_deepcopy (_detalhes.default_profile.class_specs_coords)
				end
			
				local ctable = table_deepcopy (value)
				_detalhes [key] = ctable
			else
				_detalhes [key] = value
			end
		end
		
	--> set the current profile
	if (not is_copy) then
		_detalhes.active_profile = profile_name
		_detalhes_database.active_profile = profile_name
	end
	
	--> apply the skin
		
		--> first save the local instance configs
		_detalhes:SaveLocalInstanceConfig()
		
		local saved_skins = profile.instances
		local instance_limit = _detalhes.instances_amount
		
		--> then close all opened instances
		for index, instance in _detalhes:ListInstances() do
			if (not getmetatable (instance)) then
				instance.iniciada = false
				setmetatable (instance, _detalhes)
			end
			if (instance:IsStarted()) then
				if (instance:IsEnabled()) then
					instance:ShutDown()
				end
			end
		end

		--> check if there is a skin saved or this is a empty profile
		if (#saved_skins == 0) then
			--> is empty profile, let's set "WoW Interface" on #1 window
			local instance1 = _detalhes:GetInstance (1)
			if (not instance1) then
				instance1 = _detalhes:CreateInstance (1)
			end

			--> apply default config on this instance (flat skin texture was 'ResetInstanceConfig' running).
			instance1:ResetInstanceConfig()
			instance1.skin = "no skin"
			instance1:ChangeSkin (_detalhes.default_skin_to_use)
			
			--> release the snap and lock
			instance1:LoadLocalInstanceConfig()
			instance1.snap = {}
			instance1.horizontalSnap = nil
			instance1.verticalSnap = nil
			instance1:LockInstance (false)
			
			if (#_detalhes.tabela_instancias > 1) then
				for i = #_detalhes.tabela_instancias, 2, -1 do
					_detalhes.unused_instances [i] = _detalhes.tabela_instancias [i]
					_detalhes.tabela_instancias [i] = nil
				end
			end
			
		else	
		
			--> load skins
			local instances_loaded = 0
			
			for index, skin in ipairs (saved_skins) do
				if (instance_limit < index) then
					break
				end
				
				--> fix for the old flat skin (10-10)
					if (skin.skin == "Flat Color") then
						skin.skin = "Serenity"
					end
					if (skin.skin == "Simply Gray") then
						skin.skin = "Forced Square"
					end					
					if (skin.skin == "Default Skin") then
						skin.skin = "WoW Interface"
					end
					if (skin.skin == "ElvUI Frame Style BW") then
						skin.skin = "ElvUI Style II"
					end
				
				--> fix for old left and right menus (15-10)
					if (skin.menu_icons and type (skin.menu_icons[5]) ~= "boolean") then
						skin.menu_icons[5] = true
						skin.menu_icons[6] = true
						
						local skin_profile = _detalhes.skins [skin.skin] and _detalhes.skins [skin.skin].instance_cprops
						if (skin_profile) then
							skin.menu_icons_size = skin_profile.menu_icons_size
							skin.menu_anchor = table_deepcopy (skin_profile.menu_anchor)
							--print (skin.menu_anchor[1], skin.menu_anchor[2], skin.menu_anchor.side)
							skin.menu_anchor_down = table_deepcopy (skin_profile.menu_anchor_down)
						end
					end
					if (skin.menu_icons and not skin.menu_icons.space) then
						skin.menu_icons.space = -4
					end
					if (skin.menu_icons and not skin.menu_icons.shadow) then
						skin.menu_icons.shadow = false
					end
				
				--> get the instance
				local instance = _detalhes:GetInstance (index)
				if (not instance) then
					--> create a instance without creating its frames (not initializing)
					instance = _detalhes:CreateDisabledInstance (index, skin)
				end
				
				--> copy skin
				for key, value in pairs (skin) do
					if (type (value) == "table") then
						instance [key] = table_deepcopy (value)
					else
						instance [key] = value
					end
				end
				
				--> apply default values if some key is missing
				instance:LoadInstanceConfig()
				
				--> reset basic config
				instance.snap = {}
				instance.horizontalSnap = nil
				instance.verticalSnap = nil
				instance:LockInstance (false)
				
				--> fix for old versions
				if (type (instance.segmento) ~= "number") then
					instance.segmento = 0
				end
				if (type (instance.atributo) ~= "number") then
					instance.atributo = 1
				end
				if (type (instance.sub_atributo) ~= "number") then
					instance.sub_atributo = 1
				end
				
				--> load data saved for this character only
				instance:LoadLocalInstanceConfig()
				if (skin.__was_opened) then	
					
					if (not safe_load (_detalhes.AtivarInstancia, instance)) then
						return
					end
					
				else
					instance.ativa = false
				end
				
				--> load data saved again
				instance:LoadLocalInstanceConfig()
				--> check window positioning
				if (_detalhes.profile_save_pos) then
					--print ("is profile save pos", skin.__pos.normal.x, skin.__pos.normal.y)
					if (skin.__pos) then
						instance.posicao = table_deepcopy (skin.__pos)
					else
						if (not instance.posicao) then
							print ("|cFFFF2222Details!: Position for a window wasn't found! Moving it to the center of the screen.|r\nType '/details exitlog' to check for errors.")
							instance.posicao = {normal = {x = 1, y = 1, w = 300, h = 200}, solo = {}}
						elseif (not instance.posicao.normal) then
							print ("|cFFFF2222Details!: Normal position for a window wasn't found! Moving it to the center of the screen.|r\nType '/details exitlog' to check for errors.")
							instance.posicao.normal = {x = 1, y = 1, w = 300, h = 200}
						end
					end

					instance.isLocked = skin.__locked
					instance.snap = table_deepcopy (skin.__snap) or {}
					instance.horizontalSnap = skin.__snapH
					instance.verticalSnap = skin.__snapV
				else
					if (not instance.posicao) then
						instance.posicao = {normal = {x = 1, y = 1, w = 300, h = 200}, solo = {}}
					elseif (not instance.posicao.normal) then
						instance.posicao.normal = {x = 1, y = 1, w = 300, h = 200}
					end
				end
				
				--> open the instance
				if (instance:IsEnabled()) then
					if (not instance.baseframe) then
						instance:AtivarInstancia()
					end

					instance:LockInstance (instance.isLocked)
					
					--tinsert (_detalhes.resize_debug, #_detalhes.resize_debug+1, "libwindow X (427): " .. (instance.libwindow.x or 0))
					instance:RestoreMainWindowPosition()
					instance:ReajustaGump()
					--instance:SaveMainWindowPosition()
					instance:ChangeSkin()

				else
					instance.skin = skin.skin
				end
				
				instances_loaded = instances_loaded + 1

			end
			
			--> move unused instances for unused container
			if (#_detalhes.tabela_instancias > instances_loaded) then
				for i = #_detalhes.tabela_instancias, instances_loaded+1, -1 do
					_detalhes.unused_instances [i] = _detalhes.tabela_instancias [i]
					_detalhes.tabela_instancias [i] = nil
				end
			end
			
			--> check all snaps for invalid entries
			for i = 1, instances_loaded do
				local instance = _detalhes:GetInstance (i)
				local previous_instance_id = _detalhes:GetInstance (i-1) and _detalhes:GetInstance (i-1):GetId() or 0
				local next_instance_id = _detalhes:GetInstance (i+1) and _detalhes:GetInstance (i+1):GetId() or 0
				
				for snap_side, instance_id in pairs (instance.snap) do
					if (instance_id < 1) then --> invalid instance
						instance.snap [snap_side] = nil
					elseif (instance_id ~= previous_instance_id and instance_id ~= next_instance_id) then --> no match
						instance.snap [snap_side] = nil
					end
				end
			end
			
			--> auto realign windows
			if (not _detalhes.initializing) then
				for _, instance in _detalhes:ListInstances() do
					if (instance:IsEnabled()) then
						_detalhes.move_janela_func (instance.baseframe, true, instance)
						_detalhes.move_janela_func (instance.baseframe, false, instance)
					end
				end
			else
				--> is in startup
				for _, instance in _detalhes:ListInstances() do
					for side, id in pairs (instance.snap) do
						local window = _detalhes.tabela_instancias [id]
						if (not window.ativa) then
							instance.snap [side] = nil
							if ((side == 1 or side == 3) and (not instance.snap [1] and not instance.snap [3])) then
								instance.horizontalSnap = false
							elseif ((side == 2 or side == 4) and (not instance.snap [2] and not instance.snap [4])) then
								instance.verticalSnap = false
							end
						end
					end
					if (not instance:IsEnabled()) then
						for side, id in pairs (instance.snap) do
							instance.snap [side] = nil
						end
						instance.horizontalSnap = false
						instance.verticalSnap = false
					end
				end
			end
			
		end
		
		--> check instance amount
		_detalhes.opened_windows = 0
		for index = 1, _detalhes.instances_amount do
			local instance = _detalhes.tabela_instancias [index]
			if (instance and instance.ativa) then
				_detalhes.opened_windows = _detalhes.opened_windows + 1
			end
		end
		
		--> update tooltip settings
		_detalhes:SetTooltipBackdrop()
		
		--> update player detail window
		_detalhes:ApplyPDWSkin()
		
		--> update the numerical system
		_detalhes:SelectNumericalSystem()

	if (_detalhes.initializing) then
		_detalhes.profile_loaded = true
	end
		
	--> end

		return true	
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Profiles:
	--> return the profile table requested
	
function _detalhes:SaveProfile (saveas)
	
	--> get the current profile
	
		local profile_name
	
		if (saveas) then
			profile_name = saveas
		else
			profile_name = _detalhes:GetCurrentProfileName()
		end
		
		local profile = _detalhes:GetProfile (profile_name, true)

	--> save default keys

		for key, _ in pairs (_detalhes.default_profile) do 
		
			local current_value = _detalhes [key]

			if (type (current_value) == "table") then
				local ctable = table_deepcopy (current_value)
				profile [key] = ctable
			else
				profile [key] = current_value
			end

		end

	--> save skins
		if (not _detalhes.do_not_save_skins) then
			table.wipe (profile.instances)
			for index, instance in ipairs (_detalhes.tabela_instancias) do
				local exported = instance:ExportSkin()
				exported.__was_opened = instance:IsEnabled()
				exported.__pos = table_deepcopy (instance:GetPosition())
				exported.__locked = instance.isLocked
				exported.__snap = table_deepcopy (instance.snap)
				exported.__snapH = instance.horizontalSnap
				exported.__snapV = instance.verticalSnap
				profile.instances [index] = exported
			end
		end
		_detalhes.do_not_save_skins = nil
		
		_detalhes:SaveLocalInstanceConfig()

	--> end
		return profile
end

local default_profile = {

	--> spec coords
		class_specs_coords = {
			[250] = {0, 64/512, 0, 64/512}, --> blood dk
			[251] = {64/512, 128/512, 0, 64/512}, --> frost dk
			[252] = {128/512, 192/512, 0, 64/512}, --> unholy dk
			
			[102] = {192/512, 256/512, 0, 64/512}, -->  druid balance
			[103] = {256/512, 320/512, 0, 64/512}, -->  druid feral
			[104] = {320/512, 384/512, 0, 64/512}, -->  druid guardian
			[105] = {384/512, 448/512, 0, 64/512}, -->  druid resto

			[253] = {448/512, 512/512, 0, 64/512}, -->  hunter bm
			[254] = {0, 64/512, 64/512, 128/512}, --> hunter marks
			[255] = {64/512, 128/512, 64/512, 128/512}, --> hunter survivor
			
			[62] = {(128/512) + 0.001953125, 192/512, 64/512, 128/512}, --> mage arcane
			[63] = {192/512, 256/512, 64/512, 128/512}, --> mage fire
			[64] = {256/512, 320/512, 64/512, 128/512}, --> mage frost
			
			[268] = {320/512, 384/512, 64/512, 128/512}, --> monk bm
			[269] = {448/512, 512/512, 64/512, 128/512}, --> monk ww
			[270] = {384/512, 448/512, 64/512, 128/512}, --> monk mw
			
			[65] = {0, 64/512, 128/512, 192/512}, --> paladin holy
			[66] = {64/512, 128/512, 128/512, 192/512}, --> paladin protect
			[70] = {(128/512) + 0.001953125, 192/512, 128/512, 192/512}, --> paladin ret
			
			[256] = {192/512, 256/512, 128/512, 192/512}, --> priest disc
			[257] = {256/512, 320/512, 128/512, 192/512}, --> priest holy
			[258] = {(320/512) + 0.001953125, 384/512, 128/512, 192/512}, --> priest shadow
			
			[259] = {384/512, 448/512, 128/512, 192/512}, --> rogue assassination
			[260] = {448/512, 512/512, 128/512, 192/512}, --> rogue combat
			[261] = {0, 64/512, 192/512, 256/512}, --> rogue sub
			
			[262] = {64/512, 128/512, 192/512, 256/512}, --> shaman elemental
			[263] = {128/512, 192/512, 192/512, 256/512}, --> shamel enhancement
			[264] = {192/512, 256/512, 192/512, 256/512}, --> shaman resto
			
			[265] = {256/512, 320/512, 192/512, 256/512}, --> warlock aff
			[266] = {320/512, 384/512, 192/512, 256/512}, --> warlock demo
			[267] = {384/512, 448/512, 192/512, 256/512}, --> warlock destro
			
			[71] = {448/512, 512/512, 192/512, 256/512}, --> warrior arms
			[72] = {0, 64/512, 256/512, 320/512}, --> warrior fury
			[73] = {64/512, 128/512, 256/512, 320/512}, --> warrior protect
		},

	--> class icons and colors
		class_icons_small = [[Interface\AddOns\Details\images\classes_small]],
		class_coords = {
			["HUNTER"] = {
				0, -- [1]
				0.25, -- [2]
				0.25, -- [3]
				0.5, -- [4]
			},
			["WARRIOR"] = {
				0, -- [1]
				0.25, -- [2]
				0, -- [3]
				0.25, -- [4]
			},
			["ROGUE"] = {
				0.49609375, -- [1]
				0.7421875, -- [2]
				0, -- [3]
				0.25, -- [4]
			},
			["MAGE"] = {
				0.25, -- [1]
				0.49609375, -- [2]
				0, -- [3]
				0.25, -- [4]
			},
			["PET"] = {
				0.25, -- [1]
				0.49609375, -- [2]
				0.75, -- [3]
				1, -- [4]
			},
			["DRUID"] = {
				0.7421875, -- [1]
				0.98828125, -- [2]
				0, -- [3]
				0.25, -- [4]
			},
			["MONK"] = {
				0.5, -- [1]
				0.73828125, -- [2]
				0.5, -- [3]
				0.75, -- [4]
			},
			["DEATHKNIGHT"] = {
				0.25, -- [1]
				0.5, -- [2]
				0.5, -- [3]
				0.75, -- [4]
			},
			["UNKNOW"] = {
				0.5, -- [1]
				0.75, -- [2]
				0.75, -- [3]
				1, -- [4]
			},
			["PRIEST"] = {
				0.49609375, -- [1]
				0.7421875, -- [2]
				0.25, -- [3]
				0.5, -- [4]
			},
			["UNGROUPPLAYER"] = {
				0.5, -- [1]
				0.75, -- [2]
				0.75, -- [3]
				1, -- [4]
			},
			["Alliance"] = {
				0.49609375, -- [1]
				0.7421875, -- [2]
				0.75, -- [3]
				1, -- [4]
			},
			["WARLOCK"] = {
				0.7421875, -- [1]
				0.98828125, -- [2]
				0.25, -- [3]
				0.5, -- [4]
			},
			["ENEMY"] = {
				0, -- [1]
				0.25, -- [2]
				0.75, -- [3]
				1, -- [4]
			},
			["Horde"] = {
				0.7421875, -- [1]
				0.98828125, -- [2]
				0.75, -- [3]
				1, -- [4]
			},
			["PALADIN"] = {
				0, -- [1]
				0.25, -- [2]
				0.5, -- [3]
				0.75, -- [4]
			},
			["MONSTER"] = {
				0, -- [1]
				0.25, -- [2]
				0.75, -- [3]
				1, -- [4]
			},
			["SHAMAN"] = {
				0.25, -- [1]
				0.49609375, -- [2]
				0.25, -- [3]
				0.5, -- [4]
			},
			},
		
		class_colors = {
			["HUNTER"] = {
				0.67, -- [1]
				0.83, -- [2]
				0.45, -- [3]
			},
			["WARRIOR"] = {
				0.78, -- [1]
				0.61, -- [2]
				0.43, -- [3]
			},
			["PALADIN"] = {
				0.96, -- [1]
				0.55, -- [2]
				0.73, -- [3]
			},
			["SHAMAN"] = {
				0, -- [1]
				0.44, -- [2]
				0.87, -- [3]
			},
			["MAGE"] = {
				0.41, -- [1]
				0.8, -- [2]
				0.94, -- [3]
			},
			["ROGUE"] = {
				1, -- [1]
				0.96, -- [2]
				0.41, -- [3]
			},
			["UNKNOW"] = {
				0.2, -- [1]
				0.2, -- [2]
				0.2, -- [3]
			},
			["PRIEST"] = {
				1, -- [1]
				1, -- [2]
				1, -- [3]
			},
			["WARLOCK"] = {
				0.58, -- [1]
				0.51, -- [2]
				0.79, -- [3]
			},
			["UNGROUPPLAYER"] = {
				0.4, -- [1]
				0.4, -- [2]
				0.4, -- [3]
			},
			["ENEMY"] = {
				0.94117, -- [1]
				0, -- [2]
				0.0196, -- [3]
				1, -- [4]
			},
			["version"] = 1,
			["PET"] = {
				0.3, -- [1]
				0.4, -- [2]
				0.5, -- [3]
			},
			["DRUID"] = {
				1, -- [1]
				0.49, -- [2]
				0.04, -- [3]
			},
			["MONK"] = {
				0, -- [1]
				1, -- [2]
				0.59, -- [3]
			},
			["DEATHKNIGHT"] = {
				0.77, -- [1]
				0.12, -- [2]
				0.23, -- [3]
			},
			["ARENA_GREEN"] = {
				0.1, -- [1]
				0.85, -- [2]
				0.1, -- [3]
			},
			["ARENA_YELLOW"] = {
				0.90, -- [1]
				0.90, -- [2]
				0, -- [3]
			},
			["NEUTRAL"] = {
				1, -- [1]
				1, -- [2]
				0, -- [3]
			},
			},

	--> minimap
		minimap = {hide = false, radius = 160, minimapPos = 220, onclick_what_todo = 1, text_type = 1, text_format = 3},
		data_broker_text = "",
		
	--> horcorner
		hotcorner_topleft = {hide = false},
		
	--> PvP
		only_pvp_frags = false,

	--> window settings
		max_window_size = {width = 480, height = 450},
		new_window_size = {width = 320, height = 130},
		window_clamp = {-8, 0, 21, -14},
		disable_window_groups = false,
		disable_reset_button = false,
		disable_lock_ungroup_buttons = false,
		disable_stretch_from_toolbar = false,
		disable_stretch_button = false,
		disable_alldisplays_window = false,
		damage_taken_everything = false,
	
	--> info window
		player_details_window = {
			skin = "ElvUI",
			bar_texture = "Skyline",
			scale = 1,
		},
		
	--> segments
		segments_amount = 12,
		segments_amount_to_save = 5,
		segments_panic_mode = false,
		segments_auto_erase = 1,
		
	--> instances
		instances_amount = 5,
		instances_segments_locked = false,
		instances_disable_bar_highlight = false,
		instances_menu_click_to_open = false,
		instances_no_libwindow = false,
		instances_suppress_trash = 0,
		
	--> if clear ungroup characters when logout
		clear_ungrouped = true,
		
	--> if clear graphic data when logout
		clear_graphic = true, 
		
	--> item level tracker
		track_item_level = true,
	
	--> text settings
		font_sizes = {menus = 10},
		font_faces = {menus = "Friz Quadrata TT"},
		ps_abbreviation = 3,
		total_abbreviation = 2,
		numerical_system = 1,
		numerical_system_symbols = "auto",
	
	--> performance
		use_row_animations = false,
		animate_scroll = false,
		use_scroll = false,
		scroll_speed = 2,
		update_speed = 1,
		time_type = 2,
		time_type_original = 2,
		memory_threshold = 3,
		memory_ram = 64,
		remove_realm_from_name = true,
		trash_concatenate = false,
		trash_auto_remove = true,
	
	--> death log
		deadlog_limit = 16,
		deadlog_events = 32,
	
	--> report
		report_lines = 5,
		report_to_who = "",
		report_heal_links = false,
		report_schema = 1,
		
	--> colors
		default_bg_color = 0.0941,
		default_bg_alpha = 0.5,
		
	--> fades
		row_fade_in = {"in", 0.2},
		windows_fade_in = {"in", 0.2},
		row_fade_out = {"out", 0.2},
		windows_fade_out = {"out", 0.2},

	--> captures
		capture_real = {
			["damage"] = true,
			["heal"] = true,
			["energy"] = true,
			["miscdata"] = true,
			["aura"] = true,
			["spellcast"] = true,
		},
	
	--> cloud capture
		cloud_capture = true,
		
	--> combat
		minimum_combat_time = 5,
		overall_flag = 0xD,
		overall_clear_newboss = true,
		overall_clear_newchallenge = true,
		overall_clear_logout = false,
		close_shields = false,
		pvp_as_group = true,
		use_battleground_server_parser = true,
		force_activity_time_pvp = true,
		death_tooltip_width = 300,
	
	--> skins
		standard_skin = false,
		skin = "WoW Interface",
		profile_save_pos = true,
		options_group_edit = true,
		
		chat_tab_embed = {
			enabled = false,
			tab_name = "",
			single_window = false,
		},
		
	--> tooltip
		tooltip = {
			fontface = "Friz Quadrata TT", 
			fontsize = 10,
			fontsize_title = 10,
			fontcolor = {1, 1, 1, 1}, 
			fontcolor_right = {1, 0.7, 0, 1}, --{1, 0.9254, 0.6078, 1}
			fontshadow = false, 
			background = {0.1960, 0.1960, 0.1960, 0.8697},
			abbreviation = 2, -- 2 = ToK I Upper 5 = ToK I Lower -- was 8 
			maximize_method = 1, 
			show_amount = false, 
			commands = {},
			header_text_color = {1, 0.9176, 0, 1}, --{1, 0.7, 0, 1}
			header_statusbar = {0.3, 0.3, 0.3, 0.8, false, false, "WorldState Score"},
			submenu_wallpaper = true,

			anchored_to = 1,
			anchor_screen_pos = {507.700, -350.500},
			anchor_point = "bottom",
			anchor_relative = "top",
			anchor_offset = {0, 0},
			
			border_texture = "Details BarBorder 3",
			border_color = {1, 1, 1, 0},
			border_size = 14,
			
			tooltip_max_abilities = 5,
			tooltip_max_targets = 2,
			tooltip_max_pets = 2,
			
			--menus_bg_coords = {331/512, 63/512, 109/512, 143/512}, --with gradient on right side
			menus_bg_coords = {0.309777336120606, 0.924000015258789, 0.213000011444092, 0.279000015258789},
			menus_bg_color = {.8, .8, .8, 0.2},
			menus_bg_texture = [[Interface\SPELLBOOK\Spellbook-Page-1]],
			
			icon_border_texcoord = {L = 5/64, R = 59/64, T = 5/64, B = 59/64},
			icon_size = {W = 13, H = 13}
		},
	
}

_detalhes.default_profile = default_profile

-- aqui fica as propriedades do jogador que n�o ser�o armazenadas no profile
local default_player_data = {
	--> current combat number
	
		cached_specs = {},
		cached_talents = {},
	
		last_day = date ("%d"),
	
		combat_id = 0,
		combat_counter = 0,
		last_instance_id = 0,
		last_instance_time = 0,
	--> nicktag cache
		nick_tag_cache = {},
		ignore_nicktag = false,
	--> plugin data
		plugin_database = {},
	--> information about this character
		character_data = {logons = 0},
	--> version
		last_realversion = _detalhes.realversion,
		last_version = "v1.0.0",
	--> profile
		active_profile = "",
	--> plugins tables
		SoloTablesSaved = {},
		RaidTablesSaved = {},
	--> saved skins
		savedStyles = {},
	--> instance config
		local_instances_config = {},
	--> announcements
		announce_deaths = {
			enabled = false,
			only_first = 5,
			last_hits = 1,
			where = 1,
		},
		announce_cooldowns = {
			enabled = false,
			channel = "RAID",
			ignored_cooldowns = {},
			custom = "",
		},
		announce_interrupts = {
			enabled = false,
			channel = "SAY",
			whisper = "",
			next = "",
			custom = "",
		},
		announce_prepots = {
			enabled = true,
			reverse = false,
			channel = "SELF",
		},
		announce_firsthit = {
			enabled = true,
			channel = "SELF",
		},
		
}

_detalhes.default_player_data = default_player_data

local default_global_data = {

	--> profile pool
		__profiles = {},
		always_use_profile = false,
		custom = {},
		savedStyles = {},
		savedCustomSpells = {},
		savedTimeCaptures = {},
		lastUpdateWarning = 0,
		report_where = "SAY",
		realm_sync = true,
		spell_school_cache = {},
		global_plugin_database = {},
	--> switch tables
		switchSaved = {slots = 4, table = {
			{["atributo"] = 1, ["sub_atributo"] = 1}, --damage done
			{["atributo"] = 2, ["sub_atributo"] = 1}, --healing done
			{["atributo"] = 1, ["sub_atributo"] = 6}, --enemies
			{["atributo"] = 4, ["sub_atributo"] = 5}, --deaths
		}},
		report_pos = {1, 1},
	--> tutorial
		tutorial = {
			logons = 0, 
			unlock_button = 0, 
			version_announce = 0, 
			main_help_button = 0, 
			alert_frames = {false, false, false, false, false, false}, 
			bookmark_tutorial = false,
			ctrl_click_close_tutorial = false,
		},
		performance_profiles = {
			["RaidFinder"] = {enabled = false, update_speed = 1, use_row_animations = false, damage = true, heal = true, aura = true, energy = false, miscdata = true},
			["Raid15"] = {enabled = false, update_speed = 1, use_row_animations = false, damage = true, heal = true, aura = true, energy = false, miscdata = true},
			["Raid30"] = {enabled = false, update_speed = 1, use_row_animations = false, damage = true, heal = true, aura = true, energy = false, miscdata = true},
			["Mythic"] = {enabled = false, update_speed = 1, use_row_animations = false, damage = true, heal = true, aura = true, energy = false, miscdata = true},
			["Battleground15"] = {enabled = false, update_speed = 1, use_row_animations = false, damage = true, heal = true, aura = true, energy = false, miscdata = true},
			["Battleground40"] = {enabled = false, update_speed = 1, use_row_animations = false, damage = true, heal = true, aura = true, energy = false, miscdata = true},
			["Arena"] = {enabled = false, update_speed = 1, use_row_animations = false, damage = true, heal = true, aura = true, energy = false, miscdata = true},
			["Dungeon"] = {enabled = false, update_speed = 1, use_row_animations = false, damage = true, heal = true, aura = true, energy = false, miscdata = true},
		},
	--> auras
		details_auras = {},
	--> ilvl
		item_level_pool = {},
	--> latest report
		latest_report_table = {},
}

_detalhes.default_global_data = default_global_data

function _detalhes:GetTutorialCVar (key, default)
	local value = _detalhes.tutorial [key]
	if (value == nil and default) then
		_detalhes.tutorial [key] = default
		value = default
	end
	return value
end
function _detalhes:SetTutorialCVar (key, value)
	_detalhes.tutorial [key] = value
end

function _detalhes:SaveProfileSpecial()
	
	--> get the current profile
		local profile_name = _detalhes:GetCurrentProfileName()
		local profile = _detalhes:GetProfile (profile_name, true)

	--> save default keys
		for key, _ in pairs (_detalhes.default_profile) do 

			local current_value = _detalhes_database [key] or _detalhes_global [key] or _detalhes.default_player_data [key] or _detalhes.default_global_data [key]

			if (type (current_value) == "table") then
				local ctable = table_deepcopy (current_value)
				profile [key] = ctable
			else
				profile [key] = current_value
			end

		end

	--> save skins
		table.wipe (profile.instances)

		if (_detalhes.tabela_instancias) then
			for index, instance in ipairs (_detalhes.tabela_instancias) do
				local exported = instance:ExportSkin()
				profile.instances [index] = exported
			end
		end

	--> end
		return profile
end