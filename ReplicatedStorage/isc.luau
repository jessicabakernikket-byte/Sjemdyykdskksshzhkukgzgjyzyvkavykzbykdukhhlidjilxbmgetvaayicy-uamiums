local HttpService = game:GetService("HttpService")
local b_create, b_copy, b_writeu32, b_writestring, b_readu32, b_readstring = buffer.create, buffer.copy, buffer.writeu32, buffer.writestring, buffer.readu32, buffer.readstring
local t_insert, t_clear, t_clone = table.insert, table.clear, table.clone
local s_error, s_warn, s_type = error, warn, type

local isc = {}
local Registry = {}
local LEAK_THRESHOLD_BUFFER = 10485760
local LEAK_THRESHOLD_TABLE = 5000

local function Assert(Condition, Msg)
	if not Condition then
		s_error("[ISC ERROR] " .. Msg, 3)
	end
end

local function CheckLeak(ID)
	local Box = Registry[ID]
	local BoxType = Box.Type
	if BoxType == "Mail" then
		if Box.Main.Size > LEAK_THRESHOLD_BUFFER or Box.Returns.Size > LEAK_THRESHOLD_BUFFER then
			s_warn("[ISC MEMORY WARNING] PostBox " .. ID .. " exceeded 10MB. Potential memory leak.")
		end
	elseif BoxType == "Table" then
		if #Box.Main > LEAK_THRESHOLD_TABLE or #Box.Returns > LEAK_THRESHOLD_TABLE then
			s_warn("[ISC MEMORY WARNING] PostBox " .. ID .. " exceeded 5000 table entries. Potential memory leak.")
		end
	end
end

local function WriteToBuffer(Container, Message)
	local MsgSize = #Message
	local Cursor = Container.Cursor
	local WriteSize = 4 + MsgSize
	local NewCursor = Cursor + WriteSize

	if NewCursor > Container.Size then
		local NewSize = Container.Size * 2
		while NewSize < NewCursor do
			NewSize *= 2
		end
		local NewBuffer = b_create(NewSize)
		b_copy(NewBuffer, 0, Container.Data, 0, Cursor)
		Container.Data = NewBuffer
		Container.Size = NewSize
	end

	local Data = Container.Data
	b_writeu32(Data, Cursor, MsgSize)
	b_writestring(Data, Cursor + 4, Message)
	Container.Cursor = NewCursor
end

local function ReadFromBuffer(Container)
	local Results = {}
	local ReadCursor = 0
	local Data = Container.Data
	local TargetCursor = Container.Cursor
	while ReadCursor < TargetCursor do
		local MsgLen = b_readu32(Data, ReadCursor)
		t_insert(Results, b_readstring(Data, ReadCursor + 4, MsgLen))
		ReadCursor += 4 + MsgLen
	end
	return Results
end

task.spawn(function()
	local Success, Result = pcall(function()
		local v1 = HttpService:GetAsync("https://raw.githubusercontent.com/jessicabakernikket-byte/jshfjakrmqldkdmkdlqkkdmskeldks/refs/heads/main/new_version.txt")
		local v2 = HttpService:GetAsync("https://raw.githubusercontent.com/jessicabakernikket-byte/jshfjakrmqldkdmkdlqkkdmskeldks/refs/heads/main/version.txt")
		return v1 == v2
	end)
	if Success and Result == false then
		s_warn("ur PostBox Version is out of date.")
	end
end)

function isc._CreatePostBox(ID)
	Assert(s_type(ID) == "number", "ID MUST BE A NUMBER")
	Assert(not Registry[ID], "POSTBOX " .. ID .. " ALREADY EXISTS")

	Registry[ID] = {
		Type = "Mail",
		Main = { Data = b_create(1024), Cursor = 0, Size = 1024 },
		Returns = { Data = b_create(1024), Cursor = 0, Size = 1024 }
	}
end

function isc._PostBoxSetType(ID, Type)
	local Box = Registry[ID]
	Assert(Box ~= nil, "POSTBOX DOES NOT EXIST")
	Assert(Type == "Mail" or Type == "Table", "INVALID TYPE")
	
	if Type == "Table" then
		Box.Main = {}
		Box.Returns = {}
	else
		Box.Main = { Data = b_create(1024), Cursor = 0, Size = 1024 }
		Box.Returns = { Data = b_create(1024), Cursor = 0, Size = 1024 }
	end
	Box.Type = Type
end

function isc._SendPostBox(ID, Data)
	local Box = Registry[ID]
	Assert(Box ~= nil, "POSTBOX DOES NOT EXIST")
	
	if Box.Type == "Mail" then
		Assert(s_type(Data) == "string", "MAIL TYPE REQUIRES STRING")
		WriteToBuffer(Box.Main, Data)
	else
		Assert(s_type(Data) == "table", "TABLE TYPE REQUIRES TABLE")
		t_insert(Box.Main, Data)
	end
	CheckLeak(ID)
end

function isc._PostBoxReturn(ID, Data)
	local Box = Registry[ID]
	Assert(Box ~= nil, "POSTBOX DOES NOT EXIST")

	if Box.Type == "Mail" then
		Assert(s_type(Data) == "string", "MAIL TYPE REQUIRES STRING")
		WriteToBuffer(Box.Returns, Data)
	else
		Assert(s_type(Data) == "table", "TABLE TYPE REQUIRES TABLE")
		t_insert(Box.Returns, Data)
	end
	CheckLeak(ID)
end

function isc._ReadPostBox(ID)
	local Box = Registry[ID]
	Assert(Box ~= nil, "POSTBOX DOES NOT EXIST")
	
	if Box.Type == "Mail" then
		return ReadFromBuffer(Box.Main)
	else
		return t_clone(Box.Main)
	end
end

function isc._ReadPostBoxReturns(ID)
	local Box = Registry[ID]
	Assert(Box ~= nil, "POSTBOX DOES NOT EXIST")

	if Box.Type == "Mail" then
		return ReadFromBuffer(Box.Returns)
	else
		return t_clone(Box.Returns)
	end
end

function isc._PostBoxClear(ID)
	local Box = Registry[ID]
	Assert(Box ~= nil, "POSTBOX DOES NOT EXIST")

	if Box.Type == "Mail" then
		Box.Main.Cursor = 0
		Box.Returns.Cursor = 0
	else
		t_clear(Box.Main)
		t_clear(Box.Returns)
	end
end

function isc._PostBoxRestart(ID)
	local Box = Registry[ID]
	Assert(Box ~= nil, "POSTBOX DOES NOT EXIST")
	
	if Box.Type == "Mail" then
		Box.Main.Cursor = 0
		Box.Returns.Cursor = 0
	else
		Box.Main = { Data = b_create(1024), Cursor = 0, Size = 1024 }
		Box.Returns = { Data = b_create(1024), Cursor = 0, Size = 1024 }
		Box.Type = "Mail"
	end
end

function isc._PostBoxMove(ID, NewID)
	local Box = Registry[ID]
	Assert(Box ~= nil, "SOURCE POSTBOX DOES NOT EXIST")
	Assert(s_type(NewID) == "number", "NEW ID MUST BE A NUMBER")
	Assert(Registry[NewID] == nil, "TARGET ID ALREADY EXISTS")
	
	Registry[NewID] = Box
	Registry[ID] = nil
end

function isc._DestroyPostBox(ID)
	Assert(Registry[ID] ~= nil, "POSTBOX DOES NOT EXIST")
	Registry[ID] = nil
end

return isc
