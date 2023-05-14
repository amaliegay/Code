local this = {}

local config = mwse.loadConfig("console", { logLevel = "INFO", tabWidth = 4, palette = {} })
local log = require("logging.logger").new({ name = "console", logLevel = config.logLevel })

-- The path that lua scripts are stored in.
local dir = "Data Files\\MWSE\\config\\Console\\"

local function isLuaFile(file) return file:sub(-4, -1) == ".lua" end

-- Converts tabs to spaces
---@param text string 
---@return string
local function detab(text)
	local tabWidth = config.tabWidth
	local function repl(match)
		local spaces = -match:len()
		while spaces < 1 do spaces = spaces + tabWidth end
		return match .. string.rep(" ", spaces)
	end
	text = text:gsub("([^\n]-)\t", repl)
	return text
end

---@param command string
---@return string fn?
---@return string[] args
local function getArgs(command)
	local args = {} ---@type string[]
	for w in string.gmatch(command, "%S+") do table.insert(args, w) end
	local fn = args[1] and args[1]:lower()
	if fn then table.remove(args, 1) end
	return fn, args
end

local function updateFilesTextSelect(e)
	if this.previousSelectedFile then this.previousSelectedFile.widget.state = tes3.uiState.normal end
	if e then
		e.source.widget.state = tes3.uiState.active
		this.previousSelectedFile = e.source ---@type tes3uiElement
	end
end

local function updateEditorScroll(e)
	if not this.menu then return end
	local scroll = this.menu:findChild(this.id_code_editor_scroll)
	local pane = scroll:findChild(this.id_pane)
	if not pane then return end
	pane:destroyChildren()

	if e then
		local path = dir .. e.source.text
		local linenum = 0
		for line in io.lines(path) do
			linenum = linenum + 1
			local blockLine = pane:createBlock{ id = tes3ui.registerID(string.format("Code:Line_%s_block", linenum)) }
			blockLine.widthProportional = 1.0
			blockLine.autoHeight = true
			blockLine.flowDirection = "left_to_right"
			local labelLineNum = blockLine:createLabel{ id = tes3ui.registerID(string.format("Code:LineNum_%s", linenum)) }
			labelLineNum.minWidth = 32
			labelLineNum.autoHeight = true
			labelLineNum.color = tes3ui.getPalette(tes3.palette.linkPressedColor)
			labelLineNum.text = tostring(linenum)
			labelLineNum.font = 1
			local labelLine = blockLine:createLabel{ id = tes3ui.registerID(string.format("Code:Line_%s", linenum)) }
			labelLine.autoWidth = true
			labelLine.autoHeight = true
			labelLine.color = tes3ui.getPalette(tes3.palette.headerColor)
			labelLine.text = detab(line)
			labelLine.font = 1
			labelLine.wrapText = true
		end
	end

	local scrollPaneWidget = scroll.widget ---@cast scrollPaneWidget tes3uiScrollPane
	if not scrollPaneWidget then return end
	scrollPaneWidget:contentsChanged()
	scrollPaneWidget.positionY = 0
	pane:updateLayout()
end

--- The callback of selecting file text select
local function selectFileCallback(e)
	this.selectedFile = e.source ---@type tes3uiElement
	updateFilesTextSelect(e)
	updateEditorScroll(e)
end

local function updateFiles()
	if not this.menu then return end
	local scroll = this.menu:findChild(this.id_code_files_scroll)
	for file in lfs.dir(dir) do
		if isLuaFile(file) then
			local textSelectFile = scroll:createTextSelect{ id = string.format("Code:%s", file), text = file }
			textSelectFile.minHeight = 16
			textSelectFile.borderAllSides = 2
			textSelectFile.wrapText = true
			textSelectFile:register("mouseClick", selectFileCallback)
		end
	end
end

local function updateFilesScroll()
	if not this.menu then return end
	local scroll = this.menu:findChild(this.id_code_files_scroll)
	local pane = scroll:findChild(this.id_pane)
	if not pane then return end
	pane:destroyChildren()
	updateFiles()
	local scrollPaneWidget = scroll.widget ---@cast scrollPaneWidget tes3uiScrollPane
	if not scrollPaneWidget then return end
	scrollPaneWidget:contentsChanged()
	scrollPaneWidget.positionY = 0
	pane:updateLayout()
end

local function showDeleteConfirmMessage()
	local uiFile = this.selectedFile
	if not uiFile then return end
	local file = uiFile.text
	local path = dir .. file
	tes3.messageBox({
		message = string.format("Are you sure you want to delete `%s`?", file),
		buttons = { "Delete", "Keep" },
		callback = function(e)
			if e.button == 0 then
				this.selectedFile = nil
				updateEditorScroll()
				updateFilesTextSelect()
				os.remove(path)
				updateFilesScroll()
			end
		end,
	})
end

local function run()
	local file = this.selectedFile.text
	local path = dir .. file
	local result, err = pcall(dofile, path)
	if not result then
		tes3ui.log("[Console] ERROR: Failed to run script '%s':", file)
		if (type(err) == "table") then
			tes3ui.log(json.encode(err))
		else
			tes3ui.log(err)
		end
	end
end

local function createCode()
	local menu = tes3ui.createMenu({ id = this.id_code, dragFrame = true })
	this.menu = menu
	menu.text = "Code"
	menu.minWidth = 200
	menu.minHeight = 100
	menu.width = 1300
	menu.height = 700
	menu.positionX = -menu.width / 2
	menu.positionY = menu.height

	local files = menu:createBlock{ id = this.id_code_files }
	files.width = 160
	files.minWidth = 160
	files.maxWidth = 200
	files.autoWidth = true
	files.borderAllSides = 8
	files.heightProportional = 1.0
	files.parent.flowDirection = "left_to_right"
	files.flowDirection = "top_to_bottom"

	local buttonsFiles = files:createBlock{ id = this.id_code_files_buttons }
	buttonsFiles.widthProportional = 1.0
	buttonsFiles.autoHeight = true

	local buttonDelete = buttonsFiles:createButton{ id = this.id_code_files_button_delete, text = "Delete" }
	buttonDelete.borderAllSides = 0
	buttonDelete.borderBottom = 8
	buttonDelete:register("mouseClick", showDeleteConfirmMessage)

	local scrollFiles = files:createVerticalScrollPane{ id = this.id_code_files_scroll }
	updateFiles()

	local editor = menu:createBlock{ id = this.id_code_editor }
	editor.borderAllSides = 8
	editor.widthProportional = 1.0
	editor.heightProportional = 1.0
	editor.flowDirection = "top_to_bottom"

	local buttonsEditor = editor:createBlock{ id = this.id_code_editor_buttons }
	buttonsEditor.widthProportional = 1.0
	buttonsEditor.autoHeight = true

	local buttonRun = buttonsEditor:createButton{ id = this.id_code_editor_button_run, text = "Run" }
	buttonRun.borderAllSides = 0
	buttonRun.borderBottom = 8
	buttonRun.absolutePosAlignX = 1.0
	buttonRun:register("mouseClick", run)

	local scrollEditor = editor:createVerticalScrollPane{ id = this.id_code_editor_scroll }
end

local function toggleCode()
	local menu = tes3ui.findMenu(this.id_code)
	if not menu then
		createCode()
	else
		this.selectedFile = nil
		this.previousSelectedFile = nil
		menu:destroy()
	end
end

event.register("UIEXP:consoleCommand", function(e)
	if e.context ~= "lua" then return end
	local command = e.command ---@type string
	if not command then return end
	local fn, _ = getArgs(command)
	if fn ~= "code" then return end
	toggleCode()
	e.block = true
end)

local function init()
	this.id_pane = tes3ui.registerID("PartScrollPane_pane")
	this.id_code = tes3ui.registerID("Code")
	this.id_code_files = tes3ui.registerID("Code:Files")
	this.id_code_files_buttons = tes3ui.registerID("Code:FilesButtons")
	this.id_code_files_button_delete = tes3ui.registerID("Code:FilesButton_Run")
	this.id_code_files_scroll = tes3ui.registerID("Code:FilesScroll")
	this.id_code_editor = tes3ui.registerID("Code:Editor")
	this.id_code_editor_buttons = tes3ui.registerID("Code:EditorButtons")
	this.id_code_editor_button_run = tes3ui.registerID("Code:EditorButton_Run")
	this.id_code_editor_scroll = tes3ui.registerID("Code:EditorScroll")

	if not lfs.directoryexists(dir) then lfs.mkdir(dir) end
end
event.register("initialized", init)
