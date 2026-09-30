local httpService = game:GetService('HttpService')

local ThemeManager = {} do
	ThemeManager.Folder = 'LinoriaLibSettings'
	ThemeManager.Library = nil
	ThemeManager.BuiltInThemes = {
		['Default'] = { 1, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"0055ff","BackgroundColor":"141414","OutlineColor":"323232"}') },
		['BBot'] = { 2, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1e1e","AccentColor":"7e48a3","BackgroundColor":"232323","OutlineColor":"141414"}') },
		['Fatality'] = { 3, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}') },
		['Jester'] = { 4, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"db4467","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
		['Mint'] = { 5, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"3db488","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
		['Tokyo Night'] = { 6, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"191925","AccentColor":"6759b3","BackgroundColor":"16161f","OutlineColor":"323232"}') },
		['Ubuntu'] = { 7, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"3e3e3e","AccentColor":"e2581e","BackgroundColor":"323232","OutlineColor":"191919"}') },
		['Quartz'] = { 8, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"232330","AccentColor":"426e87","BackgroundColor":"1d1b26","OutlineColor":"27232f"}') },
	}

	local function pathJoin(...)
		return table.concat({ ... }, '/')
	end

	local function ensureFolder(path)
		if type(path) ~= 'string' or path == '' then return end
		if isfolder and isfolder(path) then return end
		if not makefolder then return end
		local built = ''
		for segment in string.gmatch(path, '[^/\\]+') do
			built = (built == '') and segment or (built .. '/' .. segment)
			if not (isfolder and isfolder(built)) then
				pcall(makefolder, built)
			end
		end
	end

	local function safeWrite(path, data)
		if not writefile then return false, 'writefile not supported' end
		local ok, err = pcall(writefile, path, data)
		return ok, ok and nil or tostring(err)
	end

	local function safeRead(path)
		if not readfile then return nil end
		local ok, data = pcall(readfile, path)
		if ok then return data end
		return nil
	end

	local function sanitizeName(name)
		if type(name) ~= 'string' then return nil end
		name = name:match('^%s*(.-)%s*$') or ''
		if name == '' then return nil end
		name = name:gsub('[/\\:*?"<>|]', '_')
		name = name:gsub('%.json$', '')
		if name == '' then return nil end
		return name
	end

	function ThemeManager:ApplyTheme(theme)
		if not theme or theme == '' then return end
		if not self.Library then return end

		local customThemeData = self:GetCustomTheme(theme)
		local data = customThemeData or self.BuiltInThemes[theme]
		if not data then return end

		local scheme = customThemeData or data[2]
		if type(scheme) ~= 'table' then return end

		for idx, col in next, scheme do
			if type(col) == 'string' then
				local ok, color = pcall(Color3.fromHex, col)
				if ok and typeof(color) == 'Color3' then
					self.Library[idx] = color
					if Options and Options[idx] and Options[idx].SetValueRGB then
						pcall(function() Options[idx]:SetValueRGB(color) end)
					end
				end
			end
		end

		self:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		if not self.Library then return end
		local fields = { 'FontColor', 'MainColor', 'AccentColor', 'BackgroundColor', 'OutlineColor' }
		for _, field in next, fields do
			if Options and Options[field] and Options[field].Value then
				self.Library[field] = Options[field].Value
			end
		end

		if self.Library.GetDarkerColor then
			self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor)
		end
		if self.Library.UpdateColorsUsingRegistry then
			self.Library:UpdateColorsUsingRegistry()
		end
	end

	function ThemeManager:GetCustomTheme(theme)
		theme = sanitizeName(theme)
		if not theme then return nil end
		-- accept with or without .json
		local path = pathJoin(self.Folder, 'themes', theme .. '.json')
		if isfile and not isfile(path) then
			path = pathJoin(self.Folder, 'themes', theme)
			if isfile and not isfile(path) then
				return nil
			end
		end
		local data = safeRead(path)
		if not data then return nil end
		local ok, decoded = pcall(httpService.JSONDecode, httpService, data)
		if not ok or type(decoded) ~= 'table' then return nil end
		return decoded
	end

	function ThemeManager:SaveCustomTheme(file)
		file = sanitizeName(file)
		if not file then
			return self.Library:Notify('Invalid theme name (empty)', 3)
		end

		self:BuildFolderTree()

		local theme = {}
		local fields = { 'FontColor', 'MainColor', 'AccentColor', 'BackgroundColor', 'OutlineColor' }
		for _, field in next, fields do
			if Options and Options[field] and Options[field].Value then
				theme[field] = Options[field].Value:ToHex()
			elseif self.Library and self.Library[field] then
				theme[field] = self.Library[field]:ToHex()
			end
		end

		local path = pathJoin(self.Folder, 'themes', file .. '.json')
		local ok, err = safeWrite(path, httpService:JSONEncode(theme))
		if not ok then
			return self.Library:Notify('Failed to save theme: ' .. tostring(err), 3)
		end
		self.Library:Notify(string.format('Saved theme %q', file))
	end

	function ThemeManager:ReloadCustomThemes()
		local dir = pathJoin(self.Folder, 'themes')
		ensureFolder(dir)

		local list = {}
		if listfiles then
			local ok, files = pcall(listfiles, dir)
			if ok and type(files) == 'table' then
				list = files
			end
		end

		local out = {}
		for i = 1, #list do
			local file = tostring(list[i])
			if file:sub(-5) == '.json' then
				local name = file:match('([^/\\]+)%.json$')
				if name and name ~= '' and name ~= 'default' then
					table.insert(out, name)
				end
			end
		end
		table.sort(out)
		return out
	end

	function ThemeManager:LoadDefault()
		local theme = 'Default'
		local path = pathJoin(self.Folder, 'themes', 'default.txt')
		local content = (isfile and isfile(path)) and safeRead(path) or nil
		if content then
			content = content:match('^%s*(.-)%s*$')
		end

		local isDefault = true
		if content and content ~= '' then
			if self.BuiltInThemes[content] then
				theme = content
			elseif self:GetCustomTheme(content) then
				theme = content
				isDefault = false
			end
		elseif self.DefaultTheme and self.BuiltInThemes[self.DefaultTheme] then
			theme = self.DefaultTheme
		end

		if isDefault and Options and Options.ThemeManager_ThemeList then
			Options.ThemeManager_ThemeList:SetValue(theme)
		else
			self:ApplyTheme(theme)
		end
	end

	function ThemeManager:SaveDefault(theme)
		if type(theme) ~= 'string' or theme == '' then return end
		self:BuildFolderTree()
		safeWrite(pathJoin(self.Folder, 'themes', 'default.txt'), theme)
	end

	function ThemeManager:BuildFolderTree()
		local paths = {}
		local parts = {}
		for segment in string.gmatch(self.Folder or '', '[^/\\]+') do
			table.insert(parts, segment)
		end
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, '/', 1, idx)
		end
		table.insert(paths, pathJoin(self.Folder, 'themes'))
		table.insert(paths, pathJoin(self.Folder, 'settings'))
		for i = 1, #paths do
			ensureFolder(paths[i])
		end
	end

	function ThemeManager:SetLibrary(lib)
		self.Library = lib
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function ThemeManager:CreateThemeManager(groupbox)
		local function bindColorUpdate(idx)
			if Options and Options[idx] and Options[idx].OnChanged then
				Options[idx]:OnChanged(function()
					self:ThemeUpdate()
				end)
			end
		end

		groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', {
			Default = self.Library.BackgroundColor,
			Callback = function() self:ThemeUpdate() end,
		})
		groupbox:AddLabel('Main color'):AddColorPicker('MainColor', {
			Default = self.Library.MainColor,
			Callback = function() self:ThemeUpdate() end,
		})
		groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', {
			Default = self.Library.AccentColor,
			Callback = function() self:ThemeUpdate() end,
		})
		groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', {
			Default = self.Library.OutlineColor,
			Callback = function() self:ThemeUpdate() end,
		})
		groupbox:AddLabel('Font color'):AddColorPicker('FontColor', {
			Default = self.Library.FontColor,
			Callback = function() self:ThemeUpdate() end,
		})

		bindColorUpdate('BackgroundColor')
		bindColorUpdate('MainColor')
		bindColorUpdate('AccentColor')
		bindColorUpdate('OutlineColor')
		bindColorUpdate('FontColor')

		local ThemesArray = {}
		for Name in next, self.BuiltInThemes do
			table.insert(ThemesArray, Name)
		end
		table.sort(ThemesArray, function(a, b)
			return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1]
		end)

		groupbox:AddDivider()
		groupbox:AddDropdown('ThemeManager_ThemeList', {
			Text = 'Theme list',
			Values = ThemesArray,
			Default = 1,
		})

		groupbox:AddButton('Set as default', function()
			local v = Options.ThemeManager_ThemeList.Value
			if not v then
				return self.Library:Notify('Select a theme first', 2)
			end
			self:SaveDefault(v)
			self.Library:Notify(string.format('Set default theme to %q', tostring(v)))
		end)

		Options.ThemeManager_ThemeList:OnChanged(function()
			local v = Options.ThemeManager_ThemeList.Value
			if v then
				self:ApplyTheme(v)
			end
		end)

		groupbox:AddDivider()
		groupbox:AddInput('ThemeManager_CustomThemeName', {
			Text = 'Custom theme name',
			Placeholder = 'my theme',
		})
		groupbox:AddDropdown('ThemeManager_CustomThemeList', {
			Text = 'Custom themes',
			Values = self:ReloadCustomThemes(),
			AllowNull = true,
		})
		groupbox:AddDivider()

		groupbox:AddButton('Save theme', function()
			local name = Options.ThemeManager_CustomThemeName.Value
			self:SaveCustomTheme(name)
			if Options.ThemeManager_CustomThemeList then
				Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
				local cleaned = sanitizeName(name)
				if cleaned then
					Options.ThemeManager_CustomThemeList:SetValue(cleaned)
				end
			end
		end):AddButton('Load theme', function()
			local v = Options.ThemeManager_CustomThemeList.Value
			if not v or v == '' then
				return self.Library:Notify('Select a custom theme first', 2)
			end
			self:ApplyTheme(v)
			self.Library:Notify(string.format('Loaded theme %q', tostring(v)))
		end)

		groupbox:AddButton('Refresh list', function()
			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
			self.Library:Notify('Theme list refreshed')
		end)

		groupbox:AddButton('Set as default', function()
			local v = Options.ThemeManager_CustomThemeList.Value
			if v ~= nil and v ~= '' then
				self:SaveDefault(v)
				self.Library:Notify(string.format('Set default theme to %q', tostring(v)))
			else
				self.Library:Notify('Select a custom theme first', 2)
			end
		end)

		task.defer(function()
			pcall(function() self:LoadDefault() end)
		end)
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Themes')
	end

	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		local groupbox = self:CreateGroupBox(tab)
		self:CreateThemeManager(groupbox)
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
