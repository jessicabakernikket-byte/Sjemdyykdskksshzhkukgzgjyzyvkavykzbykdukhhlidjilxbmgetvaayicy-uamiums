local HttpService = game:GetService( "HttpService" )
local b_create, b_copy, b_writeu32, b_writestring, b_readu32, b_readstring, b_len = buffer.create, buffer.copy, buffer.writeu32, buffer.writestring, buffer.readu32, buffer.readstring, buffer.len
local t_insert, t_clear, t_move = table.insert, table.clear, table.move
local s_error, s_warn, s_type, s_pack, s_unpack = error, warn, type, string.pack, string.unpack

local isc = {}
local reg = {}
local INIT_BUF_SZ = 4096
local MAX_BUF_SZ = 16777216
local LEAK_BUF = 10485760
local LEAK_TBL = 5000
local SHRINK_RATIO = 0.25
local LEAK_CHK_INTERVAL = 100
local write_ct = 0

local function assert_fail( msg )
	s_error( "[ISC] " .. msg, 3 )
end

local function write_buf( cont, msg )
	local msg_sz = #msg
	local cur = cont.cur
	local write_sz = 4 + msg_sz
	local new_cur = cur + write_sz
	local buf_sz = cont.sz
	
	if new_cur > buf_sz then
		if new_cur > MAX_BUF_SZ then
			assert_fail( "BUFFER OVERFLOW: MESSAGE TOO LARGE" )
		end
		local new_sz = buf_sz
		while new_sz < new_cur do
			new_sz = new_sz * 2
		end
		if new_sz > MAX_BUF_SZ then
			new_sz = MAX_BUF_SZ
		end
		local new_buf = b_create( new_sz )
		b_copy( new_buf, 0, cont.buf, 0, cur )
		cont.buf = new_buf
		cont.sz = new_sz
	end
	
	local buf = cont.buf
	b_writeu32( buf, cur, msg_sz )
	b_writestring( buf, cur + 4, msg, msg_sz )
	cont.cur = new_cur
end

local function read_buf( cont )
	local res = {}
	local read_cur = 0
	local buf = cont.buf
	local tgt_cur = cont.cur
	local idx = 1
	
	while read_cur < tgt_cur do
		local msg_len = b_readu32( buf, read_cur )
		res[idx] = b_readstring( buf, read_cur + 4, msg_len )
		read_cur = read_cur + 4 + msg_len
		idx = idx + 1
	end
	
	return res
end

local function chk_leak( id )
	local box = reg[id]
	local box_type = box.typ
	
	if box_type == "M" then
		local main_sz = box.main.cur
		local ret_sz = box.ret.cur
		if main_sz > LEAK_BUF or ret_sz > LEAK_BUF then
			s_warn( "[ISC] PostBox " .. id .. " exceeded 10MB" )
		end
	else
		local main_cnt = #box.main
		local ret_cnt = #box.ret
		if main_cnt > LEAK_TBL or ret_cnt > LEAK_TBL then
			s_warn( "[ISC] PostBox " .. id .. " exceeded 5000 entries" )
		end
	end
end

local function shrink_buf( cont )
	local cur = cont.cur
	local sz = cont.sz
	
	if cur < sz * SHRINK_RATIO and sz > INIT_BUF_SZ then
		local new_sz = sz
		while new_sz > INIT_BUF_SZ and cur < new_sz * SHRINK_RATIO do
			new_sz = new_sz / 2
		end
		if new_sz < INIT_BUF_SZ then
			new_sz = INIT_BUF_SZ
		end
		if new_sz < sz then
			local new_buf = b_create( new_sz )
			b_copy( new_buf, 0, cont.buf, 0, cur )
			cont.buf = new_buf
			cont.sz = new_sz
		end
	end
end

task.defer( function()
	local ok, res = pcall( function()
		local v1 = HttpService:GetAsync( "https://raw.githubusercontent.com/jessicabakernikket-byte/jshfjakrmqldkdmkdlqkkdmskeldks/refs/heads/main/new_version.txt", true )
		local v2 = HttpService:GetAsync( "https://raw.githubusercontent.com/jessicabakernikket-byte/jshfjakrmqldkdmkdlqkkdmskeldks/refs/heads/main/version.txt", true )
		return v1 == v2
	end )
	if ok and res == false then
		s_warn( "[ISC] VERSION OUTDATED" )
	end
end )

function isc._CreatePostBox( id )
	if s_type( id ) ~= "number" then
		assert_fail( "ID MUST BE NUMBER" )
	end
	if reg[id] then
		assert_fail( "POSTBOX EXISTS" )
	end
	
	reg[id] = {
		typ = "M",
		main = { buf = b_create( INIT_BUF_SZ ), cur = 0, sz = INIT_BUF_SZ },
		ret = { buf = b_create( INIT_BUF_SZ ), cur = 0, sz = INIT_BUF_SZ }
	}
end

function isc._PostBoxSetType( id, typ )
	local box = reg[id]
	if not box then
		assert_fail( "POSTBOX NOT FOUND" )
	end
	if typ ~= "M" and typ ~= "T" then
		assert_fail( "INVALID TYPE" )
	end
	
	if typ == "T" then
		box.main = {}
		box.ret = {}
	else
		box.main = { buf = b_create( INIT_BUF_SZ ), cur = 0, sz = INIT_BUF_SZ }
		box.ret = { buf = b_create( INIT_BUF_SZ ), cur = 0, sz = INIT_BUF_SZ }
	end
	box.typ = typ
end

function isc._SendPostBox( id, dat )
	local box = reg[id]
	if not box then
		assert_fail( "POSTBOX NOT FOUND" )
	end
	
	if box.typ == "M" then
		if s_type( dat ) ~= "string" then
			assert_fail( "MAIL REQUIRES STRING" )
		end
		write_buf( box.main, dat )
	else
		if s_type( dat ) ~= "table" then
			assert_fail( "TABLE REQUIRES TABLE" )
		end
		t_insert( box.main, dat )
	end
	
	write_ct = write_ct + 1
	if write_ct >= LEAK_CHK_INTERVAL then
		chk_leak( id )
		write_ct = 0
	end
end

function isc._PostBoxReturn( id, dat )
	local box = reg[id]
	if not box then
		assert_fail( "POSTBOX NOT FOUND" )
	end
	
	if box.typ == "M" then
		if s_type( dat ) ~= "string" then
			assert_fail( "MAIL REQUIRES STRING" )
		end
		write_buf( box.ret, dat )
	else
		if s_type( dat ) ~= "table" then
			assert_fail( "TABLE REQUIRES TABLE" )
		end
		t_insert( box.ret, dat )
	end
	
	write_ct = write_ct + 1
	if write_ct >= LEAK_CHK_INTERVAL then
		chk_leak( id )
		write_ct = 0
	end
end

function isc._ReadPostBox( id )
	local box = reg[id]
	if not box then
		assert_fail( "POSTBOX NOT FOUND" )
	end
	
	if box.typ == "M" then
		return read_buf( box.main )
	else
		local src = box.main
		local res = table.create( #src )
		for i = 1, #src do
			res[i] = src[i]
		end
		return res
	end
end

function isc._ReadPostBoxReturns( id )
	local box = reg[id]
	if not box then
		assert_fail( "POSTBOX NOT FOUND" )
	end
	
	if box.typ == "M" then
		return read_buf( box.ret )
	else
		local src = box.ret
		local res = table.create( #src )
		for i = 1, #src do
			res[i] = src[i]
		end
		return res
	end
end

function isc._PostBoxClear( id )
	local box = reg[id]
	if not box then
		assert_fail( "POSTBOX NOT FOUND" )
	end
	
	if box.typ == "M" then
		box.main.cur = 0
		box.ret.cur = 0
		shrink_buf( box.main )
		shrink_buf( box.ret )
	else
		t_clear( box.main )
		t_clear( box.ret )
	end
end

function isc._PostBoxRestart( id )
	local box = reg[id]
	if not box then
		assert_fail( "POSTBOX NOT FOUND" )
	end
	
	box.main = { buf = b_create( INIT_BUF_SZ ), cur = 0, sz = INIT_BUF_SZ }
	box.ret = { buf = b_create( INIT_BUF_SZ ), cur = 0, sz = INIT_BUF_SZ }
	box.typ = "M"
end

function isc._PostBoxMove( id, new_id )
	local box = reg[id]
	if not box then
		assert_fail( "SOURCE NOT FOUND" )
	end
	if s_type( new_id ) ~= "number" then
		assert_fail( "NEW ID MUST BE NUMBER" )
	end
	if reg[new_id] then
		assert_fail( "TARGET EXISTS" )
	end
	
	reg[new_id] = box
	reg[id] = nil
end

function isc._DestroyPostBox( id )
	if not reg[id] then
		assert_fail( "POSTBOX NOT FOUND" )
	end
	reg[id] = nil
end

return isc
