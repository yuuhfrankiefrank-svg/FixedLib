local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object)
				return { type = 'Toggle', idx = idx, value = object.Value }
			end,
			Load = function(idx, data)
				if Toggles[idx] then
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	local function pathJoin(...)
		local parts = { ... }
		return table.concat(parts, '/')
	end

	local function ensureFolder(path)
		if type(path) ~= 'string' or path == '' then return false end
		if isfolder and isfolder(path) then return true end
		if not makefolder then return false end

		local built = ''
		for segment in string.gmatch(path, '[^/\\]+') do
			if built == '' then
				built = segment
			else
				built = built .. '/' .. segment
			end
			if not (isfolder and isfolder(built)) then
				pcall(makefolder, built)
			end
		end
		return true
	end

	local function safeWrite(path, content)
		if not writefile then
			return false, 'writefile is not supported by this executor'
		end
		local ok, err = pcall(writefile, path, content)
		if not ok then
			return false, tostring(err)
		end
		return true
	end

	local function safeRead(path)
		if not readfile then
			return nil, 'readfile is not supported by this executor'
		end
		local ok, data = pcall(readfile, path)
		if not ok then
			return nil, tostring(data)
		end
		return data
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

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self._foldersReady = false
		self:BuildFolderTree()
	end

	function SaveManager:BuildFolderTree()
		if self._foldersReady and self._foldersFor == self.Folder then
			return
		end
		local paths = {
			self.Folder,
			pathJoin(self.Folder, 'themes'),
			pathJoin(self.Folder, 'settings'),
		}
		for i = 1, #paths do
			ensureFolder(paths[i])
		end
		self._foldersReady = true
		self._foldersFor = self.Folder
	end

	function SaveManager:Save(name)
		name = sanitizeName(name)
		if not name then
			return false, 'no config name'
		end

		self:BuildFolderTree()

		local fullPath = pathJoin(self.Folder, 'settings', name .. '.json')
		local data = { objects = {} }

		local parser, ignore = self.Parser, self.Ignore
		for idx, toggle in next, Toggles do
			if not ignore[idx] then
				local p = toggle.Type and parser[toggle.Type]
				if p then
					table.insert(data.objects, p.Save(idx, toggle))
				end
			end
		end

		for idx, option in next, Options do
			if not ignore[idx] then
				local p = option.Type and parser[option.Type]
				if p then
					table.insert(data.objects, p.Save(idx, option))
				end
			end
		end

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		local wOk, wErr = safeWrite(fullPath, encoded)
		if not wOk then
			return false, wErr or 'write failed'
		end

		return true
	end

	function SaveManager:Load(name)
		name = sanitizeName(name)
		if not name then
			return false, 'no config selected'
		end

		local file = pathJoin(self.Folder, 'settings', name .. '.json')
		if isfile and not isfile(file) then
			return false, 'config not found: ' .. name
		end

		local raw, rErr = safeRead(file)
		if not raw then
			return false, rErr or 'read failed'
		end

		local success, decoded = pcall(httpService.JSONDecode, httpService, raw)
		if not success or type(decoded) ~= 'table' then
			return false, 'decode error'
		end

		local objects = decoded.objects or decoded
		if type(objects) ~= 'table' then
			return false, 'invalid config format'
		end

		for _, option in next, objects do
			if type(option) == 'table' and option.type and self.Parser[option.type] then
				task.spawn(function()
					pcall(self.Parser[option.type].Load, option.idx, option)
				end)
			end
		end

		return true
	end

	function SaveManager:Delete(name)
		name = sanitizeName(name)
		if not name then
			return false, 'no config selected'
		end
		local file = pathJoin(self.Folder, 'settings', name .. '.json')
		if isfile and isfile(file) and delfile then
			local ok, err = pcall(delfile, file)
			if not ok then
				return false, tostring(err)
			end
			return true
		end
		return false, 'config not found'
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			'BackgroundColor', 'MainColor', 'AccentColor', 'OutlineColor', 'FontColor',
			'ThemeManager_ThemeList', 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
		})
	end

	function SaveManager:RefreshConfigList()
		local dir = pathJoin(self.Folder, 'settings')
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
				if name and name ~= '' then
					table.insert(out, name)
				end
			end
		end

		table.sort(out)
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		local path = pathJoin(self.Folder, 'settings', 'autoload.txt')
		if isfile and isfile(path) then
			local name = select(1, safeRead(path))
			if not name then return end
			name = sanitizeName(name)
			if not name then return end

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load autoload config: ' .. tostring(err))
			end
			self.Library:Notify(string.format('Auto loaded config %q', name))
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		self:BuildFolderTree()

		local section = tab:AddRightGroupbox('Configuration')

		section:AddInput('SaveManager_ConfigName', { Text = 'Config name', Placeholder = 'my config' })
		section:AddDropdown('SaveManager_ConfigList', {
			Text = 'Config list',
			Values = self:RefreshConfigList(),
			AllowNull = true,
		})

		section:AddDivider()

		local function resolveCreateName()
			local typed = Options.SaveManager_ConfigName and Options.SaveManager_ConfigName.Value
			local selected = Options.SaveManager_ConfigList and Options.SaveManager_ConfigList.Value
			return sanitizeName(typed) or sanitizeName(selected)
		end

		local function resolveSelectedName()
			local selected = Options.SaveManager_ConfigList and Options.SaveManager_ConfigList.Value
			local typed = Options.SaveManager_ConfigName and Options.SaveManager_ConfigName.Value
			return sanitizeName(selected) or sanitizeName(typed)
		end

		local function refreshList(selectName)
			local values = self:RefreshConfigList()
			Options.SaveManager_ConfigList:SetValues(values)
			if selectName then
				Options.SaveManager_ConfigList:SetValue(selectName)
			else
				Options.SaveManager_ConfigList:SetValue(nil)
			end
		end

		section:AddButton('Create config', function()
			local name = resolveCreateName()
			if not name then
				return self.Library:Notify('Type a config name first', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. tostring(err), 3)
			end

			self.Library:Notify(string.format('Created config %q', name))
			refreshList(name)
		end):AddButton('Load config', function()
			local name = resolveSelectedName()
			if not name then
				return self.Library:Notify('Select or type a config name', 2)
			end

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. tostring(err), 3)
			end

			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = resolveSelectedName()
			if not name then
				return self.Library:Notify('Select or type a config name', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. tostring(err), 3)
			end

			self.Library:Notify(string.format('Overwrote config %q', name))
			refreshList(name)
		end):AddButton('Delete config', function()
			local name = resolveSelectedName()
			if not name then
				return self.Library:Notify('Select a config first', 2)
			end

			local success, err = self:Delete(name)
			if not success then
				return self.Library:Notify('Failed to delete: ' .. tostring(err), 3)
			end

			self.Library:Notify(string.format('Deleted config %q', name))
			refreshList(nil)
		end)

		section:AddButton('Refresh list', function()
			refreshList(nil)
			self.Library:Notify('Config list refreshed')
		end)

		section:AddButton('Set as autoload', function()
			local name = resolveSelectedName()
			if not name then
				return self.Library:Notify('Select a config first', 2)
			end

			self:BuildFolderTree()
			local ok, err = safeWrite(pathJoin(self.Folder, 'settings', 'autoload.txt'), name)
			if not ok then
				return self.Library:Notify('Failed to set autoload: ' .. tostring(err), 3)
			end

			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		local autoPath = pathJoin(self.Folder, 'settings', 'autoload.txt')
		if isfile and isfile(autoPath) then
			local name = select(1, safeRead(autoPath))
			if name then
				SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. tostring(name))
			end
		end

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
