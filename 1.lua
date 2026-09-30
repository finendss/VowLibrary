local function string_find(s, pattern)
	return string.find(s, pattern, nil, true)
end

local function ArrayToDictionary(t, hydridMode, valueOverride, typeStrict)
	local tmp = {}

	if hydridMode then
		for some1, some2 in next, t do
			if type(some1) == "number" then
				tmp[some2] = valueOverride or true
			elseif type(some2) == "table" then
				tmp[some1] = ArrayToDictionary(some2, hydridMode) -- some1 是类，some2 是名称
			else
				tmp[some1] = some2
			end
		end
	else
		for _, key in next, t do
			if not typeStrict or typeStrict and type(key) == typeStrict then
				tmp[key] = true
			end
		end
	end

	return tmp
end

local ESCAPES_PATTERN = "[&<>\"'\0\1-\9\11-\12\14-\31\127-\255]" -- * 安全的方式是在文本中转义全部五个字符。不过，在文本中不需要转义 " ' 和 > 这三个字符
-- %z（也就是 \0，即 NULL）可能并不需要，因为 Roblox 似乎会自动在各地把它转换成空格
-- 字符来源：https://create.roblox.com/docs/en-us/ui/rich-text#escape-forms
-- * 为了速度，EscapesPattern 应按从最常见到最不常见的字符排序
-- * 也许应该使用它们的数字编码而不是命名编码来减小文件大小（可以做成一个选项）
-- TODO 也许我们应该反转模式，只允许特定字符（面向未来）
local ESCAPES = {
	["&"] = "&amp;", -- 38
	["<"] = "&lt;", -- 60
	[">"] = "&gt;", -- 62
	['"'] = "&#34;", --  quot
	["'"] = "&#39;", -- apos
	["\0"] = "",
}

for rangeStart, rangeEnd in string.gmatch(ESCAPES_PATTERN, "(.)%-(.)") do
	for charCode = string.byte(rangeStart), string.byte(rangeEnd) do
		ESCAPES[string.char(charCode)] = "&#" .. charCode .. ";"
	end
end

local global_container
do
	local filename = "UniversalMethodFinder"

	local finder
	finder, global_container = loadstring(
		game:HttpGet("https://raw.githubusercontent.com/luau/SomeHub/main/" .. filename .. ".luau", true),
		filename
	)()

	finder({
		-- readbinarystring = 'string.find(...,"bin",nil,true)', -- ! 可能会匹配到一些不想要的东西（getbinaryindex）
		-- request = 'string.find(...,"request",nil,true) and not string.find(...,"internal",nil,true)',
		base64encode = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"encode")and(c(b,"base64")or c(string.lower(tostring(a[2])),"base64"))',
		-- cloneref = 'string.find(...,"clone",nil,true) and string.find(...,"ref",nil,true)',
		-- decompile = '(string.find(...,"decomp",nil,true) and string.sub(...,#...) ~= "s")',
		gethiddenproperty = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"prop",nil,true) and string.sub(...,#...) ~= "s"',
		gethui = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"ui",nil,true)',
		getnilinstances = 'string.find(...,"nil",nil,true) and string.find(...,"get",nil,true) and string.sub(...,#...) == "s"', -- ! 可能会匹配到一些不想要的东西
		getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"bytecode",nil,true)', --  或者 string.find(...,"dump",nil,true) and string.find(...,"string",nil,true)，因为 Fluxus（dumpstring 返回一个函数）
		hash = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"hash")and c(string.lower(tostring(a[2])),"crypt")',
		protectgui = 'string.find(...,"protect",nil,true) and string.find(...,"ui",nil,true) and not string.find(...,"un",nil,true)',
		setthreadidentity = 'string.find(...,"identity",nil,true) and string.find(...,"set",nil,true)',
	}, true, 10)
end

local identify_executor = identifyexecutor or getexecutorname or whatexecutor

local EXECUTOR_NAME = identify_executor and identify_executor() or ""

-- local cloneref = global_container.cloneref
local gethiddenproperty = global_container.gethiddenproperty

-- 这些应该足够通用
local appendfile = appendfile
local readfile = readfile
local writefile = writefile

local getscriptbytecode = global_container.getscriptbytecode -- * 很多假设都是基于这个函数是否已定义来做的。所以在某些边缘情况下，比如执行器定义了 "decompile" 或 "getscripthash" 函数但没有定义这个函数时，saveinstance 的功能可能会有所损失。不过这种情况非常罕见也很奇怪
local base64encode = global_container.base64encode
local sha384

local service = setmetatable({}, {
	__index = function(self, serviceName)
		local o, s = pcall(Instance.new, serviceName)
		local Service = o and s
			or game:GetService(serviceName)
			or settings():GetService(serviceName)
			or UserSettings():GetService(serviceName)

		-- if cloneref then
		-- 	Service = cloneref(Service)
		-- end

		self[serviceName] = Service
		return Service
	end,
})

local gethiddenproperty_fallback
do -- * 加载 Déjà Vu 区域
	local UGCValidationService = service.UGCValidationService

	gethiddenproperty_fallback = function(instance, propertyName)
		return UGCValidationService:GetPropertyValue(instance, propertyName) -- TODO 遗憾的是，没有办法判断返回的值到底是 nil 还是函数只是读取不到
	end
	if gethiddenproperty then
		local o, r = pcall(gethiddenproperty, workspace, "StreamOutBehavior")
		if not o or r ~= nil and typeof(r) ~= "EnumItem" then -- * 测试 gethiddenproperty 是否损坏
			gethiddenproperty = nil
		else
			o, r = pcall(gethiddenproperty, Instance.new("AnimationRigData", Instance.new("Folder")), "parent") -- * 测试它如何处理属性重叠（遮蔽），因为 AnimationRigData.parent；预期是 BinaryString

			if o and r ~= nil and type(r) ~= "string" then
				gethiddenproperty = nil
			end
		end
	end
	local function benchmark(f1, f2, ...)
		local ranking = table.create(2)
		for i, f in next, { f1, f2 } do
			local start = os.clock()
			for _ = 1, 50 do
				f(...)
			end
			ranking[i] = { t = os.clock() - start, f = f }
		end
		table.sort(ranking, function(a, b)
			return a.t < b.t
		end)
		return ranking[1].f
	end

	local test_str = string.rep("\1\0\0\0\1\2\3\4\5\6\7", 50)

	do
		if not bit32.byteswap or not pcall(bit32.byteswap, 1) then -- 因为 Fluxus 缺少 byteswap
			bit32 = table.clone(bit32)

			local function tobit(num)
				num = num % (bit32.bxor(num, 32))
				if 0x80000000 < num then
					num = num - bit32.bxor(num, 32)
				end
				return num
			end

			bit32.byteswap = function(num)
				local BYTE_SIZE = 8
				local MAX_BYTE_VALUE = 255

				num = num % bit32.bxor(2, 32)

				local a = bit32.band(num, MAX_BYTE_VALUE)
				num = bit32.rshift(num, BYTE_SIZE)

				local b = bit32.band(num, MAX_BYTE_VALUE)
				num = bit32.rshift(num, BYTE_SIZE)

				local c = bit32.band(num, MAX_BYTE_VALUE)
				num = bit32.rshift(num, BYTE_SIZE)

				local d = bit32.band(num, MAX_BYTE_VALUE)
				num = tobit(bit32.lshift(bit32.lshift(bit32.lshift(a, BYTE_SIZE) + b, BYTE_SIZE) + c, BYTE_SIZE) + d)
				return num
			end

			table.freeze(bit32)
		end

		-- TODO 以后再删
		if EXECUTOR_NAME == "Delta" then
			base64encode = nil
		end

		-- 致谢 @Reselim
		local reselim_base64encode
		pcall(function()
			local b64_enc_buf = loadstring(
				game:HttpGet("https://raw.githubusercontent.com/Reselim/Base64/master/Base64.lua", true),
				"Base64"
			)().encode
			reselim_base64encode = function(raw)
				return raw == "" and raw or buffer.tostring(b64_enc_buf(buffer.fromstring(raw)))
			end
		end)

		-- * 测试 base64encode 是否存在且正常工作，然后对它进行基准测试
		if base64encode and base64encode("\1\0\0\0\1") == "AQAAAAE=" then
			if reselim_base64encode then
				base64encode = benchmark(base64encode, reselim_base64encode, test_str)
			end
		else
			base64encode = reselim_base64encode
		end

		assert(base64encode, "未找到 base64encode")
	end

	do
		local hash = global_container.hash

		if hash then
			sha384 = function(data)
				return hash(data, "sha384")
			end
		end

		local filename = "RequireOnlineModule"

		-- 致谢 @boatbomber
		local hashlib_sha384
		pcall(function()
			hashlib_sha384 = loadstring(
				game:HttpGet("https://raw.githubusercontent.com/luau/SomeHub/main/" .. filename .. ".luau", true),
				filename
			)()(4544052033).sha384
		end)

		-- * 测试 sha384 是否存在，然后对它进行基准测试
		if hashlib_sha384 then
			if sha384 then
				sha384 = benchmark(sha384, hashlib_sha384, test_str)
			else
				sha384 = hashlib_sha384
			end
		end

		assert(sha384, "未找到 sha384 哈希函数")
	end
end

local custom_decompiler

-- if getscriptbytecode then
-- end

local SharedStrings = {}
local SharedString_identifiers = setmetatable({
	identifier = 1e15, -- 1 千万亿，理论上最多到 9.(9) 千万亿，理论上这应该永远不会耗尽，并且足够用于所有能想象到的 sharedstrings
	-- TODO：最坏情况下，在数字用完后再添加随机字符串的回退方案 : )
}, {
	__index = function(self, str)
		local identifier = self.identifier
		local Identifier = base64encode(tostring(identifier)) -- 只有内置 base64encode 才需要 tostring，Reselim 的版本不需要，因为 buffer 会自动转换
		self.identifier = identifier + 1

		self[str] = Identifier -- ? md5 属性的值是 Base64 编码的键。<SharedString> 类型元素使用这个键来引用字符串的值。值是文本内容，经过 Base64 编码。历史上，键是字符串值的 MD5 哈希。然而，这并不是必需的；键可以是任何能唯一标识共享字符串的值。Roblox 目前使用截断为 16 字节的 BLAKE2b。
		return Identifier
	end,
})

local Type_IDs = {
	string = 0x02,
	boolean = 0x03,
	-- int32 = 0x04,
	-- float = 0x05,
	number = 0x06,
	UDim = 0x09,
	UDim2 = 0x0A,
	BrickColor = 0x0E,
	Color3 = 0x0F,
	Vector2 = 0x10,
	Vector3 = 0x11,
	CFrame = 0x14,
	EnumItem = 0x15,
	NumberSequence = 0x17,
	ColorSequence = 0x19,
	NumberRange = 0x1B,
	Rect = 0x1C,
	Font = 0x21,
}
local CFrame_Rotation_IDs = {
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x02,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x03,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x05,
	["\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x06,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x07,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x09,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x0a,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x0c,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0d,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0e,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x10,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128"] = 0x11,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x14,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128"] = 0x15,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x17,
	["\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128"] = 0x18,
	["\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x19,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x1b,
	["\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x1c,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x1e,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x1f,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x20,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x22,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128"] = 0x23,
}
local Binary_Descriptors
Binary_Descriptors = {
	__SEQUENCE = function(raw, valueFormatter, keypointSize, Envelope)
		local Keypoints = raw.Keypoints
		local Keypoints_n = #Keypoints

		local len = 4 + (keypointSize or 12) * Keypoints_n
		local b = buffer.create(len)
		local offset = 0

		buffer.writeu32(b, offset, Keypoints_n)
		offset = offset + 4

		for _, keypoint in next, Keypoints do
			buffer.writef32(b, offset, Envelope or keypoint.Envelope)
			offset = offset + 4
			buffer.writef32(b, offset, keypoint.Time)
			offset = offset + 4

			local Value = keypoint.Value
			if valueFormatter then
				offset = offset + valueFormatter(Value, b, offset)
			else
				buffer.writef32(b, offset, Value)
				offset = offset + 4
			end
		end

		return b, len
	end,
	--------------------------------------------------------------
	--------------------------------------------------------------
	--------------------------------------------------------------
	["string"] = function(raw)
		local raw_len = #raw
		local len = 4 + raw_len

		local b = buffer.create(len)

		buffer.writeu32(b, 0, raw_len)
		buffer.writestring(b, 4, raw)

		return b, len
	end,
	["boolean"] = function(raw)
		local b = buffer.create(1)

		buffer.writeu8(b, 0, raw and 1 or 0)

		return b, 1
	end,
	["number"] = function(raw) -- double
		local b = buffer.create(8)

		buffer.writef64(b, 0, raw)

		return b, 8
	end,
	["UDim"] = function(raw)
		local b = buffer.create(8)

		buffer.writef32(b, 0, raw.Scale)
		buffer.writei32(b, 4, raw.Offset)

		return b, 8
	end,
	["UDim2"] = function(raw)
		local b = buffer.create(16)

		local Descriptors_UDim = Binary_Descriptors.UDim
		local X = Descriptors_UDim(raw.X)
		buffer.copy(b, 0, X)
		local Y = Descriptors_UDim(raw.Y)
		buffer.copy(b, 8, Y)

		return b, 16
	end,
	["BrickColor"] = function(raw)
		local b = buffer.create(4)

		buffer.writeu32(b, 0, raw.Number)

		return b, 4
	end,
	["Color3"] = function(raw)
		local b = buffer.create(12)

		buffer.writef32(b, 0, raw.R)
		buffer.writef32(b, 4, raw.G)
		buffer.writef32(b, 8, raw.B)

		return b, 12
	end,
	["Vector2"] = function(raw)
		local b = buffer.create(8)

		buffer.writef32(b, 0, raw.X)
		buffer.writef32(b, 4, raw.Y)

		return b, 8
	end,
	["Vector3"] = function(raw)
		local b = buffer.create(12)

		buffer.writef32(b, 0, raw.X)
		buffer.writef32(b, 4, raw.Y)
		buffer.writef32(b, 8, raw.Z)

		return b, 12
	end,
	["CFrame"] = function(raw)
		local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = raw:GetComponents()

		local rotation_ID = CFrame_Rotation_IDs[string.pack("<fffffffff", R00, R01, R02, R10, R11, R12, R20, R21, R22)]

		local len = rotation_ID and 13 or 49
		local b = buffer.create(len)

		-- ? TODO 更简洁但更慢？
		-- local write_vector3 = Descriptors.Vector3
		-- local pos = write_vector3(raw.Position)
		-- buffer.copy(b, 0, pos)

		buffer.writef32(b, 0, X)
		buffer.writef32(b, 4, Y)
		buffer.writef32(b, 8, Z)

		if rotation_ID then
			buffer.writeu8(b, 12, rotation_ID)
		else
			buffer.writeu8(b, 12, 0x0)

			-- ? TODO 更简洁但更慢？
			-- buffer.copy(b, 13, write_vector3(raw.XVector)) -- R00, R10, R20
			-- buffer.copy(b, 13 + 12, write_vector3(raw.YVector)) -- R01, R11, R21
			-- buffer.copy(b, 13 + 24, write_vector3(raw.ZVector)) -- R02, R12, R22

			buffer.writef32(b, 13, R00)
			buffer.writef32(b, 17, R01)
			buffer.writef32(b, 21, R02)

			buffer.writef32(b, 25, R10)
			buffer.writef32(b, 29, R11)
			buffer.writef32(b, 33, R12)

			buffer.writef32(b, 37, R20)
			buffer.writef32(b, 41, R21)
			buffer.writef32(b, 45, R22)
		end

		return b, len
	end,
	["EnumItem"] = function(raw)
		local b_Name, Name_size = Binary_Descriptors.string(tostring(raw.EnumType))

		local len = Name_size + 4
		local b = buffer.create(len)

		buffer.copy(b, 0, b_Name)
		buffer.writeu32(b, Name_size, raw.Value)

		return b, len
	end,
	["NumberSequence"] = nil,

	["ColorSequence"] = function(raw)
		return Binary_Descriptors.__SEQUENCE(raw, function(color3, b, offset)
			buffer.copy(b, offset, Binary_Descriptors.Color3(color3))
			return 12
		end, 20, 0)
	end,
	["NumberRange"] = function(raw)
		local b = buffer.create(8)

		buffer.writef32(b, 0, raw.Min)
		buffer.writef32(b, 4, raw.Max)

		return b, 8
	end,
	["Rect"] = function(raw)
		local b = buffer.create(16)

		local Descriptors_Vector2 = Binary_Descriptors.Vector2
		local Min = Descriptors_Vector2(raw.Min)
		buffer.copy(b, 0, Min)
		local Max = Descriptors_Vector2(raw.Max)
		buffer.copy(b, 8, Max)

		return b, 16
	end,
	["Font"] = function(raw)
		local Descriptors_string = Binary_Descriptors.string

		local b_Family, Family_size = Descriptors_string(raw.Family)
		local b_CachedFaceId, CachedFaceId_size = Descriptors_string("")

		local len = 3 + Family_size + CachedFaceId_size
		local b = buffer.create(len)

		buffer.writeu16(b, 0, raw.Weight.Value)
		buffer.writeu8(b, 2, raw.Style.Value)

		buffer.copy(b, 3, b_Family)
		buffer.copy(b, 3 + Family_size, b_CachedFaceId)

		return b, len
	end,
}
do
	Binary_Descriptors.NumberSequence = Binary_Descriptors.__SEQUENCE
end

local XML_Descriptors
XML_Descriptors = {
	__BIT = function(...) -- * 致谢 Friend（你自己知道你指的是谁）
		local Value = 0

		for i, bit in next, { ... } do
			if bit then
				Value = Value + 2 ^ (i - 1)
			end
		end

		return Value
	end,
	__CDATA = function(raw) -- ? 通常 Roblox 只有在字符串包含换行符（\n）时才使用 CDATA；为了速度，我们干脆对所有内容都使用 CDATA
		return "<![CDATA[" .. raw .. "]]>"
	end,
	__ENUM = function(raw)
		return raw.Value, "token"
	end,
	__EXTREME = function(raw)
		if raw ~= raw then
			return "NAN"
		elseif raw == math.huge then
			return "INF"
		elseif raw == -math.huge then
			return "-INF"
		end

		return raw
	end,
	__EXTREME_RANGE = function(raw)
		return raw ~= raw and "0" or raw -- 通常我们应该返回 "-nan(ind)" 而不是 "0"，但这样兼容性更好
	end,
	__MINMAX = function(min, max, descriptor)
		return "<min>" .. descriptor(min) .. "</min><max>" .. descriptor(max) .. "</max>"
	end,
	__PROTECTEDSTRING = function(raw) -- ? 其目的是在处理过程中“保护”数据，使其不被当作普通字符数据处理；
		return string_find(raw, "]]>") and string.gsub(raw, ESCAPES_PATTERN, ESCAPES) or XML_Descriptors.__CDATA(raw)
	end,
	__SEQUENCE = function(raw, valueFormatter)
		-- 值是文本内容，格式为以空格分隔的浮点数列表。
		-- tostring(raw) 也可以（但目前慢得多）
		local __EXTREME_RANGE = XML_Descriptors.__EXTREME_RANGE

		local Converted = ""

		for _, keypoint in next, raw.Keypoints do
			local Value = keypoint.Value

			Converted = Converted
				.. keypoint.Time
				.. " "
				.. (
					valueFormatter and valueFormatter(Value)
					or __EXTREME_RANGE(Value) .. " " .. __EXTREME_RANGE(keypoint.Envelope) .. " "
				) -- ? 尾随空格只是为了兼容 lune
		end

		return Converted
	end,
	__VECTOR = function(X, Y, Z) -- 每个元素都是一个 <float>
		local Value = "<X>" .. X .. "</X><Y>" .. Y .. "</Y>" -- 不存在只有不到两个坐标的 Vector（Vector1 至少在 Roblox 上不存在）

		if Z then
			Value = Value .. "<Z>" .. Z .. "</Z>"
		end

		return Value
	end,
	--------------------------------------------------------------
	--------------------------------------------------------------
	--------------------------------------------------------------
	Axes = function(raw)
		-- 此元素的文本格式为 0 到 7 之间的整数

		return "<axes>" .. XML_Descriptors.__BIT(raw.X, raw.Y, raw.Z) .. "</axes>"
	end,

	-- ? Roblox 只对这些使用 CDATA（试着证明这是错的）：CollisionGroupData, SmoothGrid, MaterialColors, PhysicsGrid
	-- ! 假设所有 base64 编码的字符串都不含换行符

	-- ! 2024/7/7
	-- ! Electron v3 修复
	-- ! Electron v3 的 'gethiddenproperty' 会自动对 BinaryString 值进行 base64 编码

	BinaryString = EXECUTOR_NAME == "Electron" and function(raw)
		return raw
	end or base64encode, -- TODO 如果 NotScriptableFix 或 gethiddenproperty_fallback 能在 Electron 上读取 gethiddenproperty 无法读取的 BinaryString，可能会出现问题

	BrickColor = function(raw)
		return raw.Number -- * Roblox 将标签编码为 "int"，但 Roblox 正确解码该类型并不要求如此。为了更好的兼容性，第三方实现最好编码和解码 "BrickColor" 标签。也可以使用 "int" 或 "Color3uint8"
	end,
	CFrame = function(raw)
		local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = raw:GetComponents()
		return XML_Descriptors.__VECTOR(X, Y, Z)
			.. "<R00>"
			.. R00
			.. "</R00><R01>"
			.. R01
			.. "</R01><R02>"
			.. R02
			.. "</R02><R10>"
			.. R10
			.. "</R10><R11>"
			.. R11
			.. "</R11><R12>"
			.. R12
			.. "</R12><R20>"
			.. R20
			.. "</R20><R21>"
			.. R21
			.. "</R21><R22>"
			.. R22
			.. "</R22>",
			"CoordinateFrame"
	end,
	Color3 = function(raw) -- 每个元素都是一个 <float>
		return "<R>" .. raw.R .. "</R><G>" .. raw.G .. "</G><B>" .. raw.B .. "</B>" -- ? 建议使用元素而不是文本来编码 Color3。
	end,
	Color3uint8 = function(raw)
		-- https://github.com/rojo-rbx/rbx-dom/blob/master/docs/xml.md#color3uint8

		return 0xFF000000
			+ (math.floor(raw.R * 255) * 0x10000)
			+ (math.floor(raw.G * 255) * 0x100)
			+ math.floor(raw.B * 255) -- ? 建议使用文本而不是元素来编码 Color3uint8。

		-- return bit32.bor(
		-- 	bit32.bor(bit32.bor(bit32.lshift(0xFF, 24), bit32.lshift(0xFF * raw.R, 16)), bit32.lshift(0xFF * raw.G, 8)),
		-- 	0xFF * raw.B
		-- )

		-- return tonumber(string.format("0xFF%02X%02X%02X",raw.R*255,raw.G*255,raw.B*255))
	end,
	ColorSequence = function(raw)
		-- 值是文本内容，格式为以空格分隔的 FLOAT 浮点数列表。

		return XML_Descriptors.__SEQUENCE(raw, function(color3)
			local __EXTREME_RANGE = XML_Descriptors.__EXTREME_RANGE

			return __EXTREME_RANGE(color3.R)
				.. " "
				.. __EXTREME_RANGE(color3.G)
				.. " "
				.. __EXTREME_RANGE(color3.B)
				.. " 0 "
		end)
	end,
	ContentId = function(raw)
		return raw == "" and "<null></null>" or "<url>" .. XML_Descriptors.string(raw) .. "</url>", "Content"
	end,
	CoordinateFrame = function(raw)
		return "<CFrame>" .. XML_Descriptors.CFrame(raw) .. "</CFrame>"
	end,
	-- DateTime = function(raw) return raw.UnixTimestampMillis end, -- TODO
	Faces = function(raw)
		-- 此元素的文本格式为 0 到 63 之间的整数
		return "<faces>"
			.. XML_Descriptors.__BIT(raw.Right, raw.Top, raw.Back, raw.Left, raw.Bottom, raw.Front)
			.. "</faces>"
	end,
	Font = function(raw)
		local FontString = tostring(raw) -- TODO：临时修复

		local EmptyWeight = string_find(FontString, "Weight = ,")
		local EmptyStyle = string_find(FontString, "Style =  }")

		return "<Family>"
			.. XML_Descriptors.ContentId(raw.Family)
			.. "</Family><Weight>"
			.. (EmptyWeight and "" or XML_Descriptors.__ENUM(raw.Weight))
			.. "</Weight><Style>"
			.. (EmptyStyle and "" or raw.Style.Name) -- 很奇怪，但这个字段接受的是枚举的 .Name
			.. "</Style>" --TODO（可选元素）：弄清楚如何确定 (ContentId) <CachedFaceId><url>rbxasset://fonts/GothamSSm-Medium.otf</url></CachedFaceId>
	end,
	NumberRange = function(raw) -- tostring(raw) 也可以
		-- 值是文本内容，格式为以空格分隔的浮点数列表。
		local __EXTREME_RANGE = XML_Descriptors.__EXTREME_RANGE

		return __EXTREME_RANGE(raw.Min) .. " " .. __EXTREME_RANGE(raw.Max) --[[.. " "]] -- ! 这可能是绕过检测所必需的，因为这就是通常的格式；这里其实不需要 __EXTREME_RANGE，但它修复了 "nan 10" 值会重置为 "0 0" 的问题
	end,
	NumberSequence = nil,
	-- NumberSequence = Descriptors.__SEQUENCE,
	PhysicalProperties = function(raw)
		--[[
			包含至少一个 CustomPhysics 元素，它会按照 bool 类型进行解释。如果此值为 true，则该标签还包含 PhysicalProperties 每个组成部分的一个元素：

			Density
			Friction
			Elasticity
			FrictionWeight
			ElasticityWeight

			每个组成部分的值由格式化为 32 位浮点数（参见 float）的文本内容表示
		]]

		local CustomPhysics
		if raw then
			CustomPhysics = true
		else
			CustomPhysics = false
		end
		CustomPhysics = "<CustomPhysics>" .. XML_Descriptors.bool(CustomPhysics) .. "</CustomPhysics>"

		return raw
				and CustomPhysics .. "<Density>" .. raw.Density .. "</Density><Friction>" .. raw.Friction .. "</Friction><Elasticity>" .. raw.Elasticity .. "</Elasticity><FrictionWeight>" .. raw.FrictionWeight .. "</FrictionWeight><ElasticityWeight>" .. raw.ElasticityWeight .. "</ElasticityWeight>"
			or CustomPhysics
	end,
	-- ProtectedString = function(raw) return tostring(raw), "ProtectedString" end,
	Ray = function(raw)
		local vector3 = XML_Descriptors.Vector3

		return "<origin>" .. vector3(raw.Origin) .. "</origin><direction>" .. vector3(raw.Direction) .. "</direction>"
	end,
	Rect = function(raw)
		return XML_Descriptors.__MINMAX(raw.Min, raw.Max, XML_Descriptors.Vector2), "Rect2D"
	end,
	Region3 = function(raw) --? 还不确定（https://github.com/ui0ppk/roblox-master/blob/main/Network/Replicator.cpp#L1306）
		local Translation = raw.CFrame.Position
		local HalfSize = raw.Size * 0.5

		return XML_Descriptors.__MINMAX(
			Translation - HalfSize, -- https://github.com/ui0ppk/roblox-master/blob/main/App/util/Region3.cpp#L38
			Translation + HalfSize, -- https://github.com/ui0ppk/roblox-master/blob/main/App/util/Region3.cpp#L42
			XML_Descriptors.Vector3
		)
	end,
	Region3int16 = function(raw) --? 还不确定（https://github.com/ui0ppk/roblox-master/blob/main/App/v8tree/EnumProperty.cpp#L346）
		return XML_Descriptors.__MINMAX(raw.Min, raw.Max, XML_Descriptors.Vector3int16)
	end,
	SharedString = function(raw)
		raw = base64encode(raw)

		local Identifier = SharedString_identifiers[raw]

		if SharedStrings[Identifier] == nil then
			SharedStrings[Identifier] = raw
		end

		return Identifier
	end,
	SecurityCapabilities = tostring, -- TODO：寻找更快的解决方案
	-- SystemAddress = function(raw) return raw end,
	UDim = function(raw)
		--[[
			S：表示 Scale 组成部分。按 <float> 解释。
			O：表示 Offset 组成部分。按 <int> 解释。
		]]

		return "<S>" .. raw.Scale .. "</S><O>" .. raw.Offset .. "</O>"
	end,
	UDim2 = function(raw)
		--[[
			XS：表示 X.Scale 组成部分。按 <float> 解释。
			XO：表示 X.Offset 组成部分。按 <int> 解释。
			YS：表示 Y.Scale 组成部分。按 <float> 解释。
			YO：表示 Y.Offset 组成部分。按 <int> 解释。
		]]

		local X, Y = raw.X, raw.Y

		return "<XS>"
			.. X.Scale
			.. "</XS><XO>"
			.. X.Offset
			.. "</XO><YS>"
			.. Y.Scale
			.. "</YS><YO>"
			.. Y.Offset
			.. "</YO>"
	end,

	-- UniqueId = function(raw)
	-- 	--[[
	-- 		UniqueId 属性每次 Studio 保存 place 文件时可能都是随机的，
	-- 		而且目前在 packages 之外没有用处，而 SSI 本来也不处理 packages。
	-- 		它们会产生 diff 噪音，所以在必须处理之前我们不应该序列化它们。
	-- 	]]
	-- 	-- https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/LuaPackages/Packages/_Index/ApolloClientTesting/ApolloClientTesting/utilities/common/makeUniqueId.lua#L62
	-- 	return "" -- ? 不知道这个是否甚至需要一个 Descriptor
	-- end,

	Vector2 = function(raw)
		--[[
			X：表示 X 组成部分。按 <float> 解释。
			Y：表示 Y 组成部分。按 <float> 解释。
		]]
		return XML_Descriptors.__VECTOR(raw.X, raw.Y)
	end,
	Vector2int16 = nil,
	-- Vector2int16 = Descriptors.Vector2, -- 只是按 <int> 处理
	Vector3 = function(raw)
		--[[
			X：表示 X 组成部分。按 <float> 解释。
			Y：表示 Y 组成部分。按 <float> 解释。
			Z：表示 Z 组成部分。按 <float> 解释。
		]]
		return XML_Descriptors.__VECTOR(raw.X, raw.Y, raw.Z)
	end,
	Vector3int16 = nil,
	-- Vector3int16 = Descriptors.Vector3, -- 只是按 <int> 处理
	bool = function(raw)
		return raw and "true" or "false"
	end,
	double = nil, -- Float64
	float = nil, -- Float32
	int = nil, -- Int32
	int64 = nil, -- Int64（long）
	string = function(raw)
		return (raw == nil or raw == "") and ""
			or string_find(raw, "]]>") and string.gsub(raw, ESCAPES_PATTERN, ESCAPES)
			or XML_Descriptors.__CDATA(string.gsub(raw, "\0", ""))
	end,
}
for descriptorName, redirectName in
	next,
	{
		Content = "ContentId", -- 为了兼容旧客户端
		NumberSequence = "__SEQUENCE",
		Vector2int16 = "Vector2",
		Vector3int16 = "Vector3",
		double = "__EXTREME",
		float = "__EXTREME",
		int = "__EXTREME",
		int64 = "__EXTREME",
	}
do
	XML_Descriptors[descriptorName] = XML_Descriptors[redirectName]
end

local ClassList

do
	local ClassPropertyExceptions = {
		Whitelist = { TriangleMeshPart = ArrayToDictionary({ "CollisionFidelity" }) },
		Blacklist = {
			LuaSourceContainer = ArrayToDictionary({ "ScriptGuid" }),
			Instance = ArrayToDictionary({ "UniqueId", "HistoryId", "Capabilities" }),
		},
	}

	local NotScriptableFixes =
		{ 
			Instance = {
				AttributesSerialize = function(instance)
					-- * 属性名称有一定的限制
					-- https://create.roblox.com/docs/reference/engine/classes/Instance#SetAttribute
					-- 但即使存在这些限制，Studio 仍然可以正常打开文件
					-- 所以目前不需要检查它们

					-- TODO：尽可能合并 sequence Descriptors 和其他一些 descriptors（检查 xml descriptors）
					-- ? 对空标签提前返回（在使用 counter/next 时，这被证明同样快）

					local attrs = instance:GetAttributes()

					if not next(attrs) then
						return ""
					end

					local attrs_n = 0
					local buffer_size = 4
					local attrs_sorted = {}
					local attrs_formatted = table.clone(attrs)
					for attr, val in next, attrs do
						attrs_n = attrs_n + 1
						attrs_sorted[attrs_n] = attr

						local Type = typeof(val)

						local Descriptor = Binary_Descriptors[Type]
						local attr_size

						attrs_formatted[attr], attr_size = Descriptor(val)

						buffer_size = buffer_size + 5 + #attr + attr_size
					end

					table.sort(attrs_sorted)

					local b = buffer.create(buffer_size)

					local offset = 0

					buffer.writeu32(b, offset, attrs_n)
					offset = offset + 4

					local Descriptors_string = Binary_Descriptors.string
					for _, attr in next, attrs_sorted do
						local b_Name, Name_size = Descriptors_string(attr)

						buffer.copy(b, offset, b_Name)
						offset = offset + Name_size

						buffer.writeu8(b, offset, Type_IDs[typeof(attrs[attr])])
						offset = offset + 1

						local bb = attrs_formatted[attr]

						buffer.copy(b, offset, bb)
						offset = offset + buffer.len(bb)
					end

					return buffer.tostring(b)
				end,
				Tags = function(instance)
					-- https://github.com/RobloxAPI/spec/blob/master/properties/Tags.md

					local tags = instance:GetTags()

					if #tags == 0 then
						return ""
					end

					return table.concat(tags, "\0")
				end,
			},

			-- DebuggerBreakpoint = {line="Line"}, -- ? 这不应该出现在实时游戏中（试着证明这是错的）
			BallSocketConstraint = { MaxFrictionTorqueXml = "MaxFrictionTorque" },
			BasePart = {
				Color3uint8 = "Color",
				MaterialVariantSerialized = "MaterialVariant",
				size = "Size",
			},
			-- CustomEvent = {PersistedCurrentValue=function(instance) -- * 该类已弃用，而且 :SetValue 似乎不再影响 GetCurrentValue
			-- 	local Receiver  = instance:GetAttachedReceivers()[1]
			-- 	if Receiver then
			-- 		return Receiver:GetCurrentValue()
			-- 	else
			-- 		error("No Receiver", 2)
			-- 	end
			-- end},
			Terrain = {
				AcquisitionMethod = "LastUsedModificationMethod", -- ? 不确定
				MaterialColors = function(instance) -- https://github.com/RobloxAPI/spec/blob/master/properties/MaterialColors.md
					local TERRAIN_MATERIAL_COLORS =
						{ --https://github.com/rojo-rbx/rbx-dom/blob/master/rbx_dom_lua/src/customProperties.lua#L5
							Enum.Material.Grass,
							Enum.Material.Slate,
							Enum.Material.Concrete,
							Enum.Material.Brick,
							Enum.Material.Sand,
							Enum.Material.WoodPlanks,
							Enum.Material.Rock,
							Enum.Material.Glacier,
							Enum.Material.Snow,
							Enum.Material.Sandstone,
							Enum.Material.Mud,
							Enum.Material.Basalt,
							Enum.Material.Ground,
							Enum.Material.CrackedLava,
							Enum.Material.Asphalt,
							Enum.Material.Cobblestone,
							Enum.Material.Ice,
							Enum.Material.LeafyGrass,
							Enum.Material.Salt,
							Enum.Material.Limestone,
							Enum.Material.Pavement,
						}

					local b = buffer.create(69) -- 69 字节：6 个保留字节 + 63 个颜色字节（21 种材质 * 3 个分量）
					local offset = 6 -- 6 个保留字节

					local RGB_components = { "R", "G", "B" }

					for _, material in next, TERRAIN_MATERIAL_COLORS do
						local color = instance:GetMaterialColor(material)
						for _, component in next, RGB_components do
							buffer.writeu8(b, offset, math.floor(color[component] * 255)) -- ? math.floor 看起来不需要，但它让它更快
							offset = offset + 1
						end
					end

					return buffer.tostring(b)
				end,
			},
			TriangleMeshPart = {
				FluidFidelityInternal = "FluidFidelity",
			},
			MeshPart = { InitialSize = "MeshSize" },
			PartOperation = { InitialSize = "MeshSize" },
			Part = { shape = "Shape" },
			TrussPart = { style = "Style" },
			FormFactorPart = {
				formFactorRaw = "FormFactor",
			},
			DoubleConstrainedValue = { value = "Value" },
			IntConstrainedValue = { value = "Value" },
			Fire = { heat_xml = "Heat", size_xml = "Size" },

			Humanoid = { Health_XML = "Health" },
			LocalizationTable = {
				Contents = function(instance)
					return instance:GetContents() --service.HttpService:JSONEncode(instance:GetEntries())
				end,
			},
			MaterialService = { Use2022MaterialsXml = "Use2022Materials" },

			Model = {
				ScaleFactor = function(instance)
					return instance:GetScale()
				end,
				WorldPivotData = "WorldPivot", -- TODO 这并不能准确表示可选类型属性是否存在（它永远不会是 nil），最好使用 gethiddenproperty 或 gethiddenproperty_fallback
				-- ModelMeshCFrame = "Pivot Offset",  -- * 两者都是 NotScriptable
			},
			PackageLink = { PackageIdSerialize = "PackageId", VersionIdSerialize = "VersionNumber" },
			Players = { MaxPlayersInternal = "MaxPlayers", PreferredPlayersInternal = "PreferredPlayers" }, -- ? 只有缺少 LocalUserSecurity（级别 2、5、9）的执行器才需要，即便如此，这也是一个相当无用的信息，因为它可以在其他地方查看

			StarterPlayer = { AvatarJointUpgrade_Serialized = "AvatarJointUpgrade" },
			Smoke = { size_xml = "Size", opacity_xml = "Opacity", riseVelocity_xml = "RiseVelocity" },
			Sound = {
				xmlRead_MaxDistance_3 = "RollOffMaxDistance", -- * 也就是 MaxDistance
			},
			-- ViewportFrame = { -- * 无意义，因为这些反映的是 CurrentCamera 的属性
			-- 	CameraCFrame = function(instance) -- *
			-- 		local CurrentCamera = instance.CurrentCamera
			-- 		if CurrentCamera then
			-- 			return CurrentCamera.CFrame
			-- 		else
			-- 			error("No CurrentCamera", 2)
			-- 		end
			-- 	end,
			-- 	-- CameraFieldOfView =
			-- },
			WeldConstraint = {
				Part0Internal = "Part0",
				Part1Internal = "Part1",
				-- State = function(instance)
				-- 	-- 如果未被修改，则默认状态为 3（默认 true）
				-- 	return instance.Enabled and 1 or 0
				-- end,
			},
			Workspace = {
				-- SignalBehavior2 = "SignalBehavior", -- * 两者都是 NotScriptable，所以保留它没有意义
				CollisionGroupData = function()
					local collision_groups = game:GetService("PhysicsService"):GetRegisteredCollisionGroups()

					local col_groups_n = #collision_groups

					if col_groups_n == 0 then
						return "\1\0"
					end

					local buffer_size = 3 -- 初始大小

					for _, group in next, collision_groups do
						buffer_size = buffer_size + 7 + #group.name
					end

					buffer_size = buffer_size - 1 -- 除了 Default 组

					local b = buffer.create(buffer_size)

					local offset = 0

					buffer.writeu8(b, offset, 1) -- ? [常量] 版本字节（可能）
					offset = offset + 1
					buffer.writeu16(b, offset, col_groups_n * 10) -- 组数量（不确定是否为 u16）
					offset = offset + 2

					for i, group in next, collision_groups do
						local name, id, mask = group.name, i - 1, group.mask
						local name_len = #name

						if id ~= 0 then
							buffer.writeu8(b, offset, id) -- ID
							offset = offset + 1
						end

						buffer.writeu8(b, offset, 4) -- ? [常量] 不确定这是什么（也不确定是否为 u8，可能是 i8）
						offset = offset + 1

						buffer.writei32(b, offset, mask) -- Mask 值作为有符号 32 位整数
						offset = offset + 4

						buffer.writeu8(b, offset, name_len) -- 名称长度
						offset = offset + 1
						buffer.writestring(b, offset, name) -- 名称
						offset = offset + name_len
					end

					return buffer.tostring(b)
				end,
			},
		}

	local function FetchAPI()
		-- 致谢 @MaximumADHD

		local API_Dump

		local CLIENT_VERSION = string.split(version(), ".")[2]

		local ok, err = pcall(function()
			local ok, result = pcall(readfile, CLIENT_VERSION)
			if ok and result and result ~= "" then
				API_Dump = result
				return
			end

			local DeployHistory = game:HttpGet("https://setup.rbxcdn.com/DeployHistory.txt", true)
			-- * https://setup.rbxcdn.com/versionQTStudio 似乎比 DeployHistory.txt 稍微滞后一些

			local matching_versions, is_matched = {}

			local lines = string.split(DeployHistory, "\n")
			for i = #lines, 1, -1 do
				local line = lines[i]

				local file_version = string.match(line, "file version: ([%d, ]+)")
				if file_version then
					if string.split(file_version, ", ")[2] == CLIENT_VERSION then
						is_matched = true

						local version_hash = string.match(line, "(version%-[^%s]+)")
						if version_hash then
							matching_versions[version_hash] = true
						end
					elseif is_matched then
						break
					end
				end
			end

			for version_hash in next, matching_versions do
				ok, result = pcall(
					game.HttpGet,
					game,
					"https://setup.rbxcdn.com/" .. version_hash .. "-Full-API-Dump.json",
					true
				)
				if ok then
					local o, r = pcall(service.HttpService.JSONDecode, service.HttpService, result)
					if o then
						API_Dump = service.HttpService:JSONEncode(r.Classes) -- 压缩它
						break
					end
				end
			end

			writefile(CLIENT_VERSION, API_Dump)
		end)

		if not ok or not API_Dump then
			warn("[DEBUG] 获取 " .. version() .. " API Dump 失败，尝试获取最新版..")
			warn("[DEBUG]", err)
			API_Dump = service.HttpService:JSONEncode(
				service.HttpService:JSONDecode(
					game:HttpGet(
						"https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Mini-API-Dump.json",
						true
					)
				).Classes
			)
		end

		local classList = {}

		local ClassesWhitelist, ClassesBlacklist = ClassPropertyExceptions.Whitelist, ClassPropertyExceptions.Blacklist
		CLIENT_VERSION = tonumber(CLIENT_VERSION)
		for _, API_Class in next, service.HttpService:JSONDecode(API_Dump) do
			local ClassProperties, ClassProperties_size = {}, 1
			local Class = {
				Properties = ClassProperties,
				Superclass = API_Class.Superclass,
			}

			local ClassTags = API_Class.Tags
			local ClassName = API_Class.Name

			if ClassTags then
				Class.Tags = ArrayToDictionary(ClassTags, nil, nil, "string") -- 或 {}
			end

			local NotScriptableFixClass = NotScriptableFixes[ClassName]

			-- ? 检查 96ea8b2a755e55a78aedb55a7de7e83980e11077 提交 - 如果需要依赖另一个 NotScriptable 属性的 NotScriptableFix（这本身其实就不太合理）

			local ClassWhitelist, ClassBlacklist = ClassesWhitelist[ClassName], ClassesBlacklist[ClassName]

			for _, Member in next, API_Class.Members do
				if Member.MemberType == "Property" then
					local Serialization = Member.Serialization

					if Serialization.CanLoad then -- 如果 Roblox 不保存它，我们为什么要保存；如果 Roblox 不加载它，我们就不需要保存它
						--[[
							-- ! CanSave 取代了 "Tags.Deprecated" 检查，因为有一些旧的已弃用属性仍然有 CanSave。
							例如：Humanoid.Health 的 CanSave 为 false，因为 Humanoid.Health_XML 的 CanSave 为 true（基本上就是过时属性）- 在这种情况下它们都会 Load。（也就是 PropertyPatches）
							CanSave 与 CanLoad 处于同一级别也修复了 BasePart 的 Color、Color3 和 Color3uint8 等重叠属性的潜在问题，其中只有 Color3uint8 应该被保存
							这也自动修复了 IgnoreClassProperties 中的所有问题，无需硬编码 :)
							这是一个非常简单的修复，解决了许多 saveinstance 脚本会遇到的问题！
						--]]
						local PropertyName = Member.Name
						if
							(Serialization.CanSave or ClassWhitelist and ClassWhitelist[PropertyName])
							and not (ClassBlacklist and ClassBlacklist[PropertyName])
						then
							local MemberTags = Member.Tags

							local ValueType = Member.ValueType
							local ValueType_Name = ValueType.Name

							if 649 <= CLIENT_VERSION and ValueType_Name == "Content" then -- TODO：在 Roblox 为其添加 descriptor 后移除
								continue
							end

							local Special

							if MemberTags then
								MemberTags = ArrayToDictionary(MemberTags, nil, nil, "string")

								Special = MemberTags.NotScriptable
							end

							-- if not Special then
							local Property = {
								Name = PropertyName,
								Category = ValueType.Category,
								-- Default = Member.Default,
								-- Tags = MemberTags,
								ValueType = ValueType_Name,

								Special = Special,

								CanRead = nil,
							}

							if string.sub(ValueType_Name, 1, 8) == "Optional" then
								-- 提取 "Optional" 之后的字符串
								Property.Optional = string.sub(ValueType_Name, 9)
							end

							if NotScriptableFixClass then
								local NotScriptableFix = NotScriptableFixClass[PropertyName]
								if NotScriptableFix then
									Property.Fallback = type(NotScriptableFix) == "function" and NotScriptableFix
										or function(instance)
											return instance[NotScriptableFix]
										end
								end
							end
							ClassProperties[ClassProperties_size] = Property
							ClassProperties_size = ClassProperties_size + 1

							-- end
						end
					end
				end
			end

			classList[ClassName] = Class
		end

		-- classList.Instance.Properties.Parent = nil -- ? 不确定这是否比过滤属性以移除它更好

		return classList
	end

	local ok, result = pcall(FetchAPI)
	if ok then
		ClassList = result
	else
		warn("加载 API Dump 失败")
		warn(result)
		return
	end
end

local inherited_properties = {}
local default_instances = {}
local referents, ref_size = {}, 0 -- ? Roblox 用 referent 属性编码所有 <Item> 元素。每个值都以 RBX 前缀开头，后跟一个 UUID 版本 4，去掉 - 字符，并将所有字符转换为大写。

local GLOBAL_ENV = getgenv and getgenv() or _G or shared

--[=[
    @class SynSaveInstance
    表示使用 synsaveinstance 函数以自定义设置保存实例的选项。
]=]

--- @interface CustomOptions table
--- * CustomOptions 主表的结构。
--- * 注意：别名优先于父选项名。
--- @within SynSaveInstance
--- @field __DEBUG_MODE boolean -- 如果你希望帮助我们改进产品并发现其中的错误/问题，建议启用！___默认值：___ false
--- @field ReadMe boolean --___默认值：___ true
--- @field SafeMode boolean -- 在保存前将你踢出，从而防止你在任何游戏中被检测到。___默认值：___ false
--- @field ShutdownWhenDone boolean -- saveinstance 完成后关闭游戏。___默认值：___ false
--- @field AntiIdle boolean -- 防止 20 分钟挂机踢出。___默认值：___ true
--- Anonymous {boolean|table{UserId = string, Name = string}} -- * **有风险：** 清除文件中与你账户相关的任何信息，例如：Name、UserId。这对某些可能将该信息存储在 GUI 或其他 Instance 中的游戏很有用。可能会弄乱包含与你的 Name 匹配的字符或与你的 UserId 匹配的部分数字的字符串部分。也可以是一个包含 UserId 和 Name 键的表。___默认值：___ false
--- @field ShowStatus boolean -- ___默认值：___ true
--- @field Callback boolean -- 如果设置，序列化数据将被发送到回调函数而不是文件。___默认值：___ nil
--- @field mode string -- 如果你只想要 ExtraInstances，请将其改为无效模式，比如 "invalid"。"optimized" 模式**不**支持 *@Object* 选项。___默认值：___ `"optimized"`
--- @field noscripts boolean -- ___别名：___ `Decompile`。___默认值：___ false
--- @field scriptcache boolean -- ___默认值：___ true
--- @field decomptype string -- * "custom" - 使用内置自定义反编译器。___默认值：___ 你执行器的反编译器（如果有）。否则如果没有则使用 "custom"。
--- @field timeout number -- 如果反编译运行时间超过此值，它将被取消。设为 -1 以禁用超时（不可靠）。***别名***：`DecompileTimeout`。___默认值：___ 10
--- @field DecompileJobless boolean -- 包含输出中已经反编译过的代码。不会反编译新脚本。___默认值：___ false
--- @field SaveBytecode boolean -- 在输出中包含字节码。如果你希望以后能够自己反编译它，这会很有用。___默认值：___ false
--- .DecompileIgnore {Instance | Instance.ClassName | [Instance.ClassName] = {Instance.Name}} -- * 默认情况下会忽略匹配项及其后代。若只想忽略实例本身，请将值设为 `= false`。示例："Chat" - 匹配任何 ClassName 为 "Chat" 的实例，Players = {"MyPlayerName"} - 仅匹配 "Players" 类且名称为 "MyPlayerName"，`workspace` - 通过引用匹配 Instance，`[workspace] = false` - 通过引用匹配 Instance，并且只忽略该实例本身而不忽略其后代。___默认值：___ {TextChatService}
--- .IgnoreList {Instance | Instance.ClassName | [Instance.ClassName] = {Instance.Name}} -- 结构与 **@DecompileIgnore** 类似，除了 `= false` 意味着如果你忽略一个实例，它会自动忽略其后代。___默认值：___ {CoreGui, CorePackages}
--- .ExtraInstances {Instance} -- 如果与任何无效模式（如 "invalidmode"）一起使用，则只会保存这些实例。___默认值：___ {}
--- @field IgnoreProperties table -- 按名称忽略属性。___默认值：___ {}
--- @field SaveCacheInterval number -- 值越小保存越频繁，但这意味着由于不断保存而导致性能下降。___默认值：___ 0x1600 * 10
--- @field FilePath string -- 只能包含文件名，不能有文件扩展名。___默认值：___ false
--- @field Object Instance -- * 如果提供，则改为保存为 .rbxmx（Model 文件）。如果 Object 是 game，则保存为 .rbxl 文件。**必须是 INSTANCE 引用，例如 - *game.Workspace***。`"optimized"` 模式**不**支持此选项。如果 IsModel 设为 false，则此处指定的 Object 将保存为 place 文件。只保存实例本身，不保存其后代。如果你也想保存后代，请使用 @ExtraInstances={Object}。___默认值：___ false
--- @field IsModel boolean -- 如果指定了 Object，则自动设为 true，除非你将其设为 false。___默认值：___ false
--- @field NilInstances boolean -- 保存未 Parent（Parent 为 nil）的实例。___默认值：___ false
--- .NilInstancesFixes {[Instance.ClassName] = function} -- * 这可能会导致某些类即使不需要该修复也被修复（不过谨慎一点总比出错好）。例如，Bones 继承自 Attachment，如果我们不在 NilInstancesFixes 中定义它们，那么这仍然会捕获它们。**要避免此行为，请使用此示例：** {ClassName_That_Doesnt_Need_Fix = false}。___默认值：___ {Animator = function, AdPortal = function, BaseWrap = function, Attachment = function}
--- @field IgnoreDefaultProperties boolean -- 在保存期间忽略默认属性。___默认值：___ true
--- @field IgnoreNotArchivable boolean -- 忽略 Archivable 属性并保存 Non-Archivable 实例。___默认值：___ true
--- @field IgnorePropertiesOfNotScriptsOnScriptsMode boolean -- 在 "scripts" 模式下，忽略所有不是脚本的实例的属性。___默认值：___ false
--- @field IgnoreSpecialProperties boolean -- 阻止对 `gethiddenproperty` 的调用，改用回退方法。这也有助于避免崩溃。如果你的文件在保存后损坏，可以尝试打开这个。___默认值：___ false
--- @field IsolateLocalPlayer boolean -- 将 LocalPlayer 的子对象保存为单独文件夹，并防止任何 ClassName 为 Player 且 .Name 与 LocalPlayer.Name 相同的实例被保存。___默认值：___ false
--- @field IsolateStarterPlayer boolean -- 如果启用，StarterPlayer 将被清空，保存的 starter player 将被放入文件夹中。___默认值：___ false
--- @field IsolateLocalPlayerCharacter boolean -- 将 LocalPlayer.Character 的子对象保存为单独文件夹，并防止任何 ClassName 为 Player 且 .Name 与 LocalPlayer.Name 相同的实例被保存。___默认值：___ false
--- @field RemovePlayerCharacters boolean -- 保存时忽略玩家角色。（会自动启用 SaveNonCreatable）。___默认值：___ true
--- @field SaveNonCreatable boolean -- * 将不可序列化实例作为 Folder 对象包含进来（这个名称有误导性，因为它主要是针对某些 NilInstances 的修复，并不总是与 NotCreatable 相关）。___默认值：___ false
--- .NotCreatableFixes table<Instance.ClassName> -- * {"Player"} 等同于 {Player = "Folder"}；像 {SpawnLocation = "Part"} 这样的格式只应在 SpawnLocation 继承自 "Part" 且 "Part" 可创建时使用。___默认值：___ { "Player", "PlayerScripts", "PlayerGui" }
--- @field IsolatePlayers boolean -- * 此选项确实会保存玩家，只是它们不会显示在 Studio 中，只能通过 place 文件代码（在文本编辑器中）查看。更多信息请见 https://github.com/luau/UniversalSynSaveInstance/issues/2。___默认值：___ false
--- @field AlternativeWritefile boolean -- * 将文件内容字符串拆分为多个段，并使用 appendfile 写入。这可能有助于在开始写入文件时避免崩溃。不过在有些执行器上 appendfile 可能工作不正常。___默认值：___ true
--- @field IgnoreDefaultPlayerScripts boolean -- * **有风险：** 忽略默认 PlayerScripts，例如 PlayerModule 和 RbxCharacterSounds。防止某些执行器崩溃。___默认值：___ true
--- @field IgnoreSharedStrings boolean -- * **有风险：修复崩溃（临时，仅在 ROEXEC 上测试过）。你可以随意禁用它来测试是否适用于你**。___默认值：___ true
--- @field SharedStringOverwrite boolean -- * **有风险：** 如果进程未完成，也就是崩溃了，那么所有受影响的值都将不可用。SharedStrings 也可用于不是 `SharedString` 的 ValueTypes，这种行为在任何地方都没有文档记录，但说得通（不过由于潜在的 ValueType 混淆，可能会产生问题，目前只适用于某些类型，而且到目前为止它们都是 base64 编码的）。原因：可能允许更小的文件大小（在某些情况下也可能更大）。___默认值：___ false
--- @field TreatUnionsAsParts boolean -- * **有风险：** 将所有 UnionOperations 转换为 Parts。如果你的执行器无法保存（读取）Unions，这会很有用，因为否则它们将不可见。___默认值：___ false（Solara 除外）

--- @interface OptionsAliases
--- @within SynSaveInstance
--- [SynSaveInstance.CustomOptions 表]的别名。
--- @field FilePath string -- FileName
--- @field IgnoreDefaultProperties string -- IgnoreDefaultProps
--- @field SaveNonCreatable string -- SaveNotCreatable
--- @field IsolatePlayers string -- SavePlayers
--- @field scriptcache string -- DecompileJobless
--- @field timeout string -- DecompileTimeout
--- @field IgnoreNotArchivable string -- IgnoreArchivable
--- @field RemovePlayerCharacters string -- INVERSE SavePlayerCharacters

--[=[
	@function saveinstance
	使用指定选项保存实例。示例：
	```lua
	local Params = {
		RepoURL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/",
		SSI = "saveinstance",
	}

	local synsaveinstance = loadstring(game:HttpGet(Params.RepoURL .. Params.SSI .. ".luau", true), Params.SSI)()

	local CustomOptions = { SafeMode = true, timeout = 15, SaveBytecode = true }
	
	synsaveinstance(CustomOptions)
	```
	@within SynSaveInstance
	@yields
	@param Parameter_1 variant<table, table<Instance>> -- 可以是 [SynSaveInstance.CustomOptions 表]，也可以是填满实例的表（{Instance}），（然后它将被视为具有无效模式的 ExtraInstances，并且 IsModel 为 true）。
	@param Parameter_2 table -- [可选] 如果存在，则 Parameter_2 将被假定为 [SynSaveInstance.CustomOptions 表]。然后如果 Parameter_1 是一个 Instance，则它将被假定为 [SynSaveInstance.CustomOptions 表].Object。如果 Parameter_1 是填满实例的表（{Instance}），则它将被假定为 [SynSaveInstance.CustomOptions 表].ExtraInstances，并且 IsModel 为 true）。这是为了兼容 `saveinstance(game, {})` 而存在的
]=]

local function synsaveinstance(CustomOptions, CustomOptions2)
	if GLOBAL_ENV.USSI then
		return
	end
	GLOBAL_ENV.USSI = true
	do
		local setthreadidentity = global_container.setthreadidentity
		if setthreadidentity then
			pcall(setthreadidentity, 8) -- ? Arceus X 修复
		end
	end

	local currentstr, currentsize, totalsize, chunks = "", 0, 0, table.create(1)
	local savebuffer, savebuffer_size = {
		'<roblox version="4">',
	}, 2

	local StatusText

	local OPTIONS = {
		mode = "optimized",
		noscripts = false,
		scriptcache = true,
		decomptype = "",
		timeout = 10,
		--* 新增：
		__DEBUG_MODE = false,

		-- Binary = false, -- 在较新的 syn 版本中为 true（在我们的情况下为 false，因为还不支持二进制），描述：以二进制模式（rbxl/rbxm）保存所有内容。
		Callback = nil,
		--Clipboard/CopyToClipboard = false, -- 描述：如果设为 true，序列化数据将被设置到剪贴板，之后可以轻松粘贴到 studio 中。对保存模型很有用。
		-- MaxThreads = 3 -- 描述：可以同时运行的反编译线程数。线程越多，意味着可以同时反编译更多脚本。
		-- DisableCompression = false, --描述：禁用二进制输出中的压缩

		DecompileJobless = false,
		DecompileIgnore = { -- * 清理这些（合并旧 Syn 和新 Syn）
			-- "Chat",
			"TextChatService",
			ModuleScript = nil,
		},
		IgnoreDefaultPlayerScripts = EXECUTOR_NAME ~= "Wave" and true,
		SaveBytecode = false,

		IgnoreProperties = {},

		IgnoreList = { "CoreGui", "CorePackages" },

		ExtraInstances = {},
		NilInstances = false,
		NilInstancesFixes = {},

		SaveCacheInterval = 0x1600 * 10,
		ShowStatus = true,
		SafeMode = false,
		ShutdownWhenDone = false,
		AntiIdle = true,
		Anonymous = false,
		ReadMe = true,
		FilePath = false,
		Object = false,
		IsModel = false,

		IgnoreDefaultProperties = true,
		IgnoreNotArchivable = true,
		IgnorePropertiesOfNotScriptsOnScriptsMode = false,
		IgnoreSpecialProperties = ArrayToDictionary({ "Fluxus", "Delta", "Solara" })[EXECUTOR_NAME] or false, -- ! 请提交更多在禁用此项时会因 gethiddenproperty 崩溃的执行器

		IsolateLocalPlayer = false, --  #service.StarterGui:GetChildren() == 0
		IsolateLocalPlayerCharacter = false,
		IsolatePlayers = false,
		IsolateStarterPlayer = false,
		RemovePlayerCharacters = true,

		SaveNonCreatable = false,
		NotCreatableFixes = { "Player", "PlayerScripts", "PlayerGui", "TouchTransmitter" },

		-- ! 有风险

		IgnoreSharedStrings = EXECUTOR_NAME ~= "Wave" and true,
		SharedStringOverwrite = false,
		TreatUnionsAsParts = EXECUTOR_NAME == "Solara", -- TODO 临时为 true（一旦移除，也要从文档中移除注释）
		AlternativeWritefile = not ArrayToDictionary({ "WRD", "Xeno", "Zorara" })[EXECUTOR_NAME],

		OptionsAliases = { -- 作为用户你其实不能修改这些
			FilePath = "FileName",
			IgnoreDefaultProperties = "IgnoreDefaultProps",
			SaveNonCreatable = "SaveNotCreatable",
			IsolatePlayers = "SavePlayers",
			scriptcache = "DecompileJobless",
			timeout = "DecompileTimeout",
			IgnoreNotArchivable = "IgnoreArchivable",
		},
	}

	local function GetAlias(searchAlias)
		for option, alias in next, OPTIONS.OptionsAliases do
			if searchAlias == alias then
				return option
			end
		end

		return ""
	end

	do -- * 加载设置
		local function construct_NilinstanceFix(Name, ClassName, Separate)
			return function(instance, instancePropertyOverrides)
				local Exists

				if not Separate then
					Exists = OPTIONS.NilInstancesFixes[Name]
				end

				local Fix

				local DoesntExist = not Exists
				if DoesntExist then
					Fix = Instance.new(ClassName)
					if not Separate then
						OPTIONS.NilInstancesFixes[Name] = Fix
					end
					-- Fix.Name = Name

					instancePropertyOverrides[Fix] =
						{ __SaveSpecific = true, __Children = { instance }, Properties = { Name = Name } }
				else
					Fix = Exists
					table.insert(instancePropertyOverrides[Fix].__Children, instance)
				end

				-- InstancesOverrides[instance].Parent = AnimationController
				if DoesntExist then
					return Fix
				end
			end
		end

		-- TODO：合并 BaseWrap 和 Attachment 和 AdPortal 修复（全部放到 MeshPart 容器下）
		-- TODO?：
		-- DebuggerWatch DebuggerWatch 必须是 ScriptDebugger 的子对象
		-- PluginAction PluginAction 的 Parent 必须是创建它的 Plugin 或 PluginMenu！
		OPTIONS.NilInstancesFixes.Animator = construct_NilinstanceFix(
			"Animator 必须放在 Humanoid 或 AnimationController 下",
			"AnimationController"
		)
		OPTIONS.NilInstancesFixes.AdPortal = construct_NilinstanceFix("AdPortal 必须作为 Part 的父对象", "Part")
		OPTIONS.NilInstancesFixes.Attachment =
			construct_NilinstanceFix("Attachments 必须作为 BasePart 或另一个 Attachment 的父对象", "Part") -- * Bones 继承自 Attachments
		OPTIONS.NilInstancesFixes.BaseWrap =
			construct_NilinstanceFix("BaseWrap 必须作为 MeshPart 的父对象", "MeshPart")
		OPTIONS.NilInstancesFixes.PackageLink =
			construct_NilinstanceFix("Package 已经有 PackageLink", "Folder", true)

		if CustomOptions2 and type(CustomOptions2) == "table" then
			local tmp = CustomOptions
			local Type = typeof(tmp)
			CustomOptions = CustomOptions2
			if Type == "Instance" then
				CustomOptions.Object = tmp
			elseif Type == "table" and typeof(tmp[1]) == "Instance" then
				CustomOptions.ExtraInstances = tmp
				OPTIONS.IsModel = true
			end
		end

		local Type = typeof(CustomOptions)

		if Type == "table" then
			if typeof(CustomOptions[1]) == "Instance" then
				OPTIONS.mode = "invalidmode"
				OPTIONS.ExtraInstances = CustomOptions
				OPTIONS.IsModel = true
				CustomOptions = {}
			else
				for key, value in next, CustomOptions do
					if OPTIONS[key] == nil then
						local Option = GetAlias(key)

						if Option then
							OPTIONS[Option] = value
						end
					else
						OPTIONS[key] = value
					end
				end
				local Decompile = CustomOptions.Decompile
				if Decompile ~= nil then
					OPTIONS.noscripts = not Decompile
				end
				local SavePlayerCharacters = CustomOptions.SavePlayerCharacters
				if SavePlayerCharacters ~= nil then
					OPTIONS.RemovePlayerCharacters = not SavePlayerCharacters
				end
				local RemovePlayers = CustomOptions.RemovePlayers
				if RemovePlayers ~= nil then
					OPTIONS.IsolatePlayers = not RemovePlayers
				end
			end
		elseif Type == "Instance" then
			OPTIONS.mode = "invalidmode"
			OPTIONS.Object = CustomOptions
			CustomOptions = {}
		else
			CustomOptions = {}
		end
	end

	if OPTIONS.IgnoreDefaultPlayerScripts then
		-- TODO 这是一个糟糕的变通方法，找一个更好的自动方式
		local DecompileIgnore = OPTIONS.DecompileIgnore

		local Path = service.StarterPlayer:FindFirstChild("StarterPlayerScripts")
		local Exclude = { ModuleScript = { "PlayerModule" }, LocalScript = { "RbxCharacterSounds" } }
		if Path then
			for _, className in next, Exclude do
				for _, name in next, className do
					local Found = Path:FindFirstChild(name)
					if Found then
						table.insert(DecompileIgnore, Found)
					end
				end
			end
		end
	end

	local InstancesOverrides = {}

	local DecompileIgnore, IgnoreList, IgnoreProperties, NotCreatableFixes =
		ArrayToDictionary(OPTIONS.DecompileIgnore, true),
		ArrayToDictionary(OPTIONS.IgnoreList, true),
		ArrayToDictionary(OPTIONS.IgnoreProperties),
		ArrayToDictionary(OPTIONS.NotCreatableFixes, true, "Folder")

	local __DEBUG_MODE = OPTIONS.__DEBUG_MODE

	if __DEBUG_MODE and type(__DEBUG_MODE) ~= "function" then
		__DEBUG_MODE = warn
	end

	local FilePath = OPTIONS.FilePath
	local SaveCacheInterval = OPTIONS.SaveCacheInterval
	local ToSaveInstance = OPTIONS.Object
	local IsModel = OPTIONS.IsModel

	if ToSaveInstance and CustomOptions.IsModel == nil then
		IsModel = true
	end

	local IgnoreDefaultProperties = OPTIONS.IgnoreDefaultProperties
	local IgnoreNotArchivable = not OPTIONS.IgnoreNotArchivable
	local IgnorePropertiesOfNotScriptsOnScriptsMode = OPTIONS.IgnorePropertiesOfNotScriptsOnScriptsMode

	local old_gethiddenproperty
	if OPTIONS.IgnoreSpecialProperties and gethiddenproperty then
		old_gethiddenproperty = gethiddenproperty
		gethiddenproperty = nil
	end

	local SaveNonCreatable = OPTIONS.SaveNonCreatable
	local TreatUnionsAsParts = OPTIONS.TreatUnionsAsParts

	local DecompileJobless = OPTIONS.DecompileJobless
	local ScriptCache = OPTIONS.scriptcache and getscriptbytecode

	local Timeout = OPTIONS.timeout

	local IgnoreSharedStrings = OPTIONS.IgnoreSharedStrings
	local SharedStringOverwrite = OPTIONS.SharedStringOverwrite

	local ldeccache = GLOBAL_ENV.scriptcache

	local DecompileIgnoring, ToSaveList, ldecompile, placename, elapse_t, SaveNonCreatableWillBeEnabled, RecoveredScripts

	if ScriptCache and not ldeccache then
		ldeccache = {}
		GLOBAL_ENV.scriptcache = ldeccache
	end

	if ToSaveInstance == game then
		OPTIONS.mode = "full"
		ToSaveInstance = nil
		IsModel = nil
	end

	local function isLuaSourceContainer(instance)
		return instance:IsA("LuaSourceContainer")
	end

	do
		local mode = string.lower(OPTIONS.mode)
		local tmp = table.clone(OPTIONS.ExtraInstances)

		local PlaceName = game.PlaceId

		pcall(function()
			PlaceName = PlaceName .. " " .. service.MarketplaceService:GetProductInfo(PlaceName).Name
		end)

		local function sanitizeFileName(str)
			return string.sub(string.gsub(string.gsub(string.gsub(str, "[^%w _]", ""), " +", " "), " +$", ""), 1, 240)
		end

		if ToSaveInstance then
			if mode == "optimized" then -- ! 不支持 Model 文件模式
				mode = "full"
			end

			for _, key in
				next,
				{
					"IsolateLocalPlayer",
					"IsolateLocalPlayerCharacter",
					"IsolatePlayers",
					"IsolateStarterPlayer",
					"NilInstances",
				}
			do
				if CustomOptions[key] == nil and CustomOptions[GetAlias(key)] == nil then
					OPTIONS[key] = false
				end
			end
		end

		if IsModel then
			placename = (
				FilePath
				or sanitizeFileName("model " .. PlaceName .. " " .. (ToSaveInstance or tmp[1] or game):GetFullName())
			) .. ".rbxmx"
		else
			placename = (FilePath or sanitizeFileName("place " .. PlaceName)) .. ".rbxlx"
		end

		if GLOBAL_ENV[placename] then
			-- warn("UniversalSynSaveInstance 已经正在保存到此文件")
			return
		end

		GLOBAL_ENV[placename] = true
		GLOBAL_ENV.USSI = nil
		if mode ~= "scripts" then
			IgnorePropertiesOfNotScriptsOnScriptsMode = nil
		end

		local TempRoot = ToSaveInstance or game

		if mode == "full" then
			if not ToSaveInstance then
				local Children = TempRoot:GetChildren()
				if 0 < #Children then
					local tmp_dict = ArrayToDictionary(tmp)
					for _, child in next, Children do
						if not tmp_dict[child] then
							table.insert(tmp, child)
						end
					end
				end
			end
		elseif mode == "optimized" then -- ! 与 .rbxmx（Model 文件）模式不兼容
			-- if IsolatePlayers then
			-- 	table.insert(_list_0, "Players")
			-- end
			local tmp_dict = ArrayToDictionary(tmp)

			for _, serviceName in
				next,
				{
					"Workspace",
					"Players",
					"Lighting",
					"MaterialService",
					"ReplicatedFirst",
					"ReplicatedStorage",

					"ServerScriptService", -- LoadStringEnabled 属性（不会复制）；以防万一
					"ServerStorage", -- 以防万一

					"StarterGui",
					"StarterPack",
					"StarterPlayer",
					"Teams",
					"SoundService",
					"TextChatService",
					"Chat",

					-- "InsertService",
					"JointsService",

					"LocalizationService", -- 用于 LocalizationTables
					-- "TestService",
					-- "VoiceChatService",
				}
			do
				local _service = game:FindService(serviceName)
				if _service and not tmp_dict[_service] then
					table.insert(tmp, _service)
				end
			end
		elseif mode == "scripts" then
			-- TODO：只保存通往脚本的路径（不保存其他内容）
			-- 目前会连同每棵树的子对象一起保存路径
			local unique = {}
			for _, instance in next, TempRoot:GetDescendants() do
				if isLuaSourceContainer(instance) then
					local Parent = instance.Parent
					while Parent and Parent ~= TempRoot do
						instance = instance.Parent
						Parent = instance.Parent
					end
					if Parent then
						unique[instance] = true
					end
				end
			end
			for instance in next, unique do
				table.insert(tmp, instance)
			end
		end

		ToSaveList = tmp

		if ToSaveInstance then
			table.insert(ToSaveList, 1, ToSaveInstance)
		end
	end

	local IsolateLocalPlayer = OPTIONS.IsolateLocalPlayer
	local IsolateLocalPlayerCharacter = OPTIONS.IsolateLocalPlayerCharacter
	local IsolatePlayers = OPTIONS.IsolatePlayers
	local IsolateStarterPlayer = OPTIONS.IsolateStarterPlayer
	local NilInstances = OPTIONS.NilInstances

	if NilInstances and enablenilinstances then -- ? Solara 修复
		enablenilinstances()
	end
	local function get_size_format()
		local Size

		-- local totalsize = #totalstr

		for i, unit in
			next,
			{
				"B",
				"KB",
				"MB",
				"GB",
				"TB",
			}
		do
			if totalsize < 0x400 ^ i then
				Size = math.floor(totalsize / (0x400 ^ (i - 1)) * 10) / 10 .. " " .. unit
				break
			end
		end

		return Size
	end

	local RunService = service.RunService
	local function wait_for_render()
		RunService.RenderStepped:Wait()
	end

	local Loading
	local function run_with_loading(text, keepStatus, waitForRender, taskFunction, ...)
		local previousStatus

		if StatusText then
			if keepStatus then
				previousStatus = StatusText.Text
			end
			Loading = task.spawn(function()
				local spinner_count = 0
				local chars = { "|", "/", "—", "\\" }
				local chars_size = #chars

				local function getLoadingText()
					spinner_count = spinner_count + 1

					if chars_size < spinner_count then
						spinner_count = 1
					end

					return chars[spinner_count]
				end

				text = text .. " "

				while true do
					StatusText.Text = text .. getLoadingText()
					task.wait(0.25)
				end
			end)
			if waitForRender then
				wait_for_render()
			end
		end

		local result = { taskFunction(...) }

		if Loading then
			task.cancel(Loading)
			Loading = nil
			if previousStatus then
				StatusText.Text = previousStatus
			end
		end

		return unpack(result)
	end

	local function construct_TimeoutHandler(timeout, f, timeout_ret)
		return function(script) -- TODO 理想情况下使用 ...（可变参数）而不是 `script`，以防它被重用于 `decompile` 和 `getscriptbytecode` 以外的东西
			if timeout < 0 then
				return pcall(f, script)
			end

			local thread = coroutine.running()
			local timeoutThread, isCancelled

			timeoutThread = task.delay(timeout, function()
				isCancelled = true -- TODO task.cancel
				coroutine.resume(thread, nil, timeout_ret)
			end)

			task.spawn(function()
				local ok, result = pcall(f, script)

				if isCancelled then
					return
				end

				task.cancel(timeoutThread)

				while coroutine.status(thread) ~= "suspended" do
					task.wait()
				end

				coroutine.resume(thread, ok, result)
			end)

			return coroutine.yield()
		end
	end

	local getbytecode
	if getscriptbytecode then
		getbytecode = construct_TimeoutHandler(3, getscriptbytecode) -- ? Solara 修复
	end

	local SaveBytecode
	if OPTIONS.SaveBytecode and getscriptbytecode then
		SaveBytecode = function(script)
			local s, bytecode = getbytecode(script)

			if s and bytecode and bytecode ~= "" then
				return "-- 字节码（Base64）：\n-- " .. base64encode(bytecode) .. "\n\n"
			end
		end
	end

	do
		local Decompiler = OPTIONS.decomptype == "custom" and custom_decompiler or decompile or custom_decompiler

		-- if Decompiler == custom_decompiler then -- 应对
		-- 	local key = "DecompileTimeout"
		-- 	if CustomOptions[key] == nil then
		-- 		local Option = GetAlias(key)
		-- 		if CustomOptions[Option] == nil then
		-- 			Timeout = 1
		-- 		end
		-- 	end

		-- end

		if OPTIONS.noscripts then
			ldecompile = function()
				return "-- 反编译已禁用"
			end
		elseif Decompiler then
			local decomp = construct_TimeoutHandler(Timeout, Decompiler, "反编译器超时")

			ldecompile = function(script)
				-- local name = scr.ClassName .. scr.Name
				local hashed_bytecode
				if ScriptCache then
					local s, bytecode = getbytecode(script) -- 	TODO 这很糟糕，因为我们已经在我们使用自定义反编译器时在 Custom Decomp 中做过这件事
					local cached

					if s then
						if not bytecode or bytecode == "" then
							return "-- 脚本为空"
						end
						hashed_bytecode = sha384(bytecode)
						cached = ldeccache[hashed_bytecode]
					end

					if cached then
						if __DEBUG_MODE then
							__DEBUG_MODE("在缓存中找到", script:GetFullName())
						end
						return cached
					elseif DecompileJobless then
						return "-- 在已反编译的 ScriptCache 中未找到"
					end
				else
					task.wait() -- TODO 也许移除？
				end

				local ok, result = run_with_loading("正在反编译 " .. script.Name, true, nil, decomp, script)
				if not result then
					ok, result = false, "空输出"
				end

				local output
				if ok then
					result = string.gsub(result, "\0", "\\0") -- ? 一些反编译器不幸会输出 \0，这会阻止文件打开
					output = result
				else
					output = "--[[ 反编译失败。原因：\n" .. (result or "") .. "\n]]"
				end

				if ScriptCache and hashed_bytecode then -- TODO 可能存在一种边缘情况：即使 getscriptbytecode 失败，它也能（用内置反编译器）成功反编译，而输出不会被缓存
					ldeccache[hashed_bytecode] = output -- ? 即使超时了我们也应该缓存吗？
					if __DEBUG_MODE then
						__DEBUG_MODE("已缓存", script:GetFullName())
					end
				end

				return output
			end
		else
			ldecompile = function()
				return "-- 你的执行器没有反编译器"
			end
		end
	end

	local function GetLocalPlayer()
		return service.Players.LocalPlayer
			or service.Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
			or service.Players.LocalPlayer
	end

	local function filterLinkedSource(str)
		local o, r = pcall(service.HttpService.JSONDecode, service.HttpService, str)
		if o and r.errors then
			return
		end
		return true
	end

	local function replaceClassName(instance, InstanceName, ClassName, newClassName)
		local InstanceOverride
		if InstanceName ~= ClassName then -- TODO 与默认实例比较（TouchTransmitter 默认叫 TouchInterest）
			InstanceOverride = InstancesOverrides[instance]
			if not InstanceOverride then
				InstanceOverride = { Properties = { Name = "[" .. ClassName .. "] " .. InstanceName } }
				InstancesOverrides[instance] = InstanceOverride
			end
		end
		return newClassName, InstanceOverride
	end

	local function getsafeproperty(instance, propertyName)
		return instance[propertyName]
	end

	local function filterPropVal(result, propertyName, category) -- ? raw == nil 是因为 SerializedDefaultAttributes；"can't get value" - 因为 WriteOnly 标签；"Invalid value for enum " - "StreamingPauseMode"（旧游戏可能）Roexec
		return result == nil
			or result == "can't get value"
			or type(result) == "string"
				and (category == "Enum" or string_find(result, "Unable to get property " .. propertyName))
	end

	local function unfilterPropVal(category, optional)
		return category ~= "Class" and not optional
	end

	local __BREAK = "__BREAK" .. service.HttpService:GenerateGUID(false)

	local function ReadProperty(instance, property, propertyName, special, category, optional)
		local raw = __BREAK

		local InstanceOverride = InstancesOverrides[instance]
		if InstanceOverride then
			local PropertiesOverride = InstanceOverride.Properties
			if PropertiesOverride then
				local PropertyOverride = PropertiesOverride[propertyName]
				if PropertyOverride ~= nil then
					return PropertyOverride
				end
			end
		end

		local CanRead = property.CanRead

		if CanRead == false then -- * 跳过，因为我们之前已经检查过此属性
			return __BREAK
		end

		if special then
			if gethiddenproperty then
				local ok, result = pcall(gethiddenproperty, instance, propertyName)

				if ok then
					raw = result
				end

				if filterPropVal(raw, propertyName, category) then
					-- * 也许下次我们再遇到这个时也跳过（除非它有可能在其他实例上以某种方式可读）

					if result ~= nil or unfilterPropVal(category, optional) then
						if __DEBUG_MODE then
							__DEBUG_MODE("已过滤", propertyName)
						end
						-- Property.Special = false
						property.CanRead = false
					end

					return __BREAK -- ? 我们跳过它，因为即使使用 ""，在大多数情况下它也只会重置为默认值，除非它是字符串标签之类的（和未定义一样）
				end
			end
		else
			if CanRead then
				raw = instance[propertyName]
			else -- 假设 CanRead == nil（未测试）
				local ok, result = pcall(getsafeproperty, instance, propertyName)

				if ok then
					raw = result
				elseif gethiddenproperty then -- ! 小心这个 'and gethiddenproperty' 逻辑
					ok, result = pcall(gethiddenproperty, instance, propertyName)

					if ok then
						raw = result

						property.Special = true
					end
				end

				property.CanRead = ok

				if not ok or filterPropVal(raw, propertyName, category) then
					return __BREAK
				end
			end
		end

		return raw
	end

	local function ReturnItem(className, instance)
		local ref = referents[instance]
		if not ref then
			ref = ref_size
			referents[instance] = ref
			ref_size = ref_size + 1
		end

		return '<Item class="' .. className .. '" referent="' .. ref .. '"><Properties>' -- TODO：如果 IgnorePropertiesOfNotScriptsOnScriptsMode 已启用，或者如果所有属性都是默认值（可减少至少 1.4% 的文件大小），理想情况下这里不应该返回 <Properties> 以及下面那行来关闭它
	end

	local function ReturnProperty(tag, propertyName, value)
		return "<" .. tag .. ' name="' .. propertyName .. '">' .. value .. "</" .. tag .. ">"
	end

	local function ReturnValueAndTag(raw, valueType, descriptor)
		local value, tag = (descriptor or XML_Descriptors[valueType])(raw)

		return value, tag or valueType
	end

	local function InheritsFix(fixes, className, instance)
		local Fix = fixes[className]
		if Fix then
			return Fix
		elseif Fix == nil then
			for class_name, fix in next, fixes do
				if instance:IsA(class_name) then
					return fix
				end
			end
		end
	end

	local function GetInheritedProps(className)
		local prop_list = {}
		local layer = ClassList[className]
		while layer do
			local layer_props = layer.Properties
			table.move(layer_props, 1, #layer_props, #prop_list + 1, prop_list)

			-- for _, prop in next,layer.Properties do
			-- 	prop_list[prop_count] = prop -- ? 如果 .Default 被修改，则需要 table.clone
			-- 	prop_count = count + 1
			-- end

			layer = ClassList[layer.Superclass]
		end
		inherited_properties[className] = prop_list
		return prop_list
	end

	local CHUNK_LIMIT = 200 * 1024 * 1024 -- 防止字符串长度溢出
	local function save_cache(final)
		local savestr = table.concat(savebuffer)
		currentstr = currentstr .. savestr -- TODO：在某些执行器上会导致 "not enough memory" 错误

		-- writefile(placename, totalstr)
		-- appendfile(placename, savestr) -- * 据说会导致 Tag 数量不均（例如 <Item> 必须用 </Item> 关闭，但有时一个比另一个多）。在负载下，该函数会产生意外输出？
		local savestr_len = #savestr
		totalsize = totalsize + savestr_len
		currentsize = currentsize + savestr_len

		table.clear(savebuffer)
		savebuffer_size = 1

		if CHUNK_LIMIT < currentsize or final then
			table.insert(chunks, { size = currentsize, str = currentstr })
			currentstr, currentsize = "", 0
		end

		if StatusText then
			StatusText.Text = "正在保存.. 大小：" .. get_size_format()
		end
		-- ? 至少需要 1fps（状态文本）
		-- task.wait()
		wait_for_render()
	end

	local function save_specific(className, properties)
		local Ref = Instance.new(className) -- ! 假设这里传入的任何东西都是可创建的
		local Item = ReturnItem(Ref.ClassName, Ref)

		for propertyName, val in next, properties do
			local whitelisted, value, tag

			-- TODO：改进代码中所有类型的覆盖和异常（下面的代码很糟糕）
			if "Source" == propertyName then
				tag = "ProtectedString"
				value = XML_Descriptors.__PROTECTEDSTRING(val)
				whitelisted = true
			elseif "Name" == propertyName then
				whitelisted = true
				value, tag = ReturnValueAndTag(val, "string") -- * 怀疑 ValueType 会改变
			end

			if whitelisted then
				Item = Item .. ReturnProperty(tag, propertyName, value)
			end
		end
		Item = Item .. "</Properties>"
		return Item
	end

	local function save_hierarchy(hierarchy)
		for _, instance in next, hierarchy do
			repeat
				if IgnoreNotArchivable and not instance.Archivable then
					break
				end

				local SkipEntirely = IgnoreList[instance]
				if SkipEntirely then
					break
				end

				local ClassName = instance.ClassName

				local InstanceName = instance.Name

				do
					local OnIgnoredList = IgnoreList[ClassName]
					if OnIgnoredList and (OnIgnoredList == true or OnIgnoredList[InstanceName]) then
						break
					end
				end

				if not DecompileIgnoring then
					DecompileIgnoring = DecompileIgnore[instance]

					if DecompileIgnoring == nil then
						local DecompileIgnored = DecompileIgnore[ClassName]
						if DecompileIgnored then
							DecompileIgnoring = DecompileIgnored == true or DecompileIgnored[InstanceName]
						end
					end

					if DecompileIgnoring then
						DecompileIgnoring = instance
					elseif DecompileIgnoring == false then
						DecompileIgnoring = 1 -- 忽略一个实例
					end
				end

				local InstanceOverride, ClassNameOverride, ClassTagOverride

				do
					local Fix = NotCreatableFixes[ClassName]

					if Fix then
						if SaveNonCreatable then
						ClassName, InstanceOverride = replaceClassName(instance, InstanceName, ClassName, Fix)
						else
							break -- 它们反正也不会显示在 Studio 中（如果你希望绕过这个，请启用 SaveNonCreatable）
						end
					else -- ! 假设任何 PartOperation 或其继承者都不在 NotCreatableFixes 中
						if TreatUnionsAsParts and instance:IsA("PartOperation") then
						ClassName, InstanceOverride = replaceClassName(instance, InstanceName, ClassName, "Part")
							ClassNameOverride = "BasePart" -- * PartOperation 和 Part 的共同父类；仅用于属性
						elseif not ClassList[ClassName] then -- ? API Dump 过时了
							if __DEBUG_MODE then
								__DEBUG_MODE("未找到类", ClassName)
							end

							ClassTagOverride = ClassName -- ? 至少保留 .ClassName，不像其他类特定属性那样
							ClassName = "Folder" -- ? 不需要 replaceClassName，因为有 ClassTagOverride
						end
					end
				end

				if not InstanceOverride then
					InstanceOverride = InstancesOverrides[instance]
				end
				if ClassName == "" then -- * FilteredSelection
					ClassName = "Folder"
				end

				-- ? 我们只保存 .Name（以及 save_specific 中的少数其他属性）的原因是
				-- ? 我们可以确定这是一个自定义容器（例如 NilInstancesFixes）
				-- ? 然而，对于 NotCreatableFixes 的情况，实例可能有 Tags、Attributes 等，这些可能可以被保存（即使它是一个 Folder）
				if InstanceOverride and InstanceOverride.__SaveSpecific then
					savebuffer[savebuffer_size] = save_specific(ClassName, InstanceOverride.Properties) -- ! 假设任何有 __SaveSpecific 的东西都会有 .Properties
					savebuffer_size = savebuffer_size + 1
				else
					-- local Properties =
					savebuffer[savebuffer_size] = ReturnItem(ClassTagOverride or ClassName, instance) -- TODO：如果 IgnorePropertiesOfNotScriptsOnScriptsMode 已启用，理想情况下这里不应该返回 <Properties> 以及下面那行来关闭它
					savebuffer_size = savebuffer_size + 1
					if not (IgnorePropertiesOfNotScriptsOnScriptsMode and not isLuaSourceContainer(instance)) then
						local default_instance, new_def_inst

						if IgnoreDefaultProperties then
							default_instance = default_instances[ClassName]
							if not default_instance then
								local ClassTags = ClassList[ClassName].Tags
								if not (ClassTags and ClassTags.NotCreatable) then -- __api_dump_class_not_creatable__ 也表明了这一点
									new_def_inst = Instance.new(ClassName) -- ! 假设任何没有 NotCreatable 的东西都可以创建（因此不需要 pcall）

									default_instance = {}

									default_instances[ClassName] = default_instance
								elseif __DEBUG_MODE then
									__DEBUG_MODE("无法创建默认 Instance", ClassName)
								end
							end
						end
						local proplist = inherited_properties[ClassNameOverride or ClassName]
						if not proplist then
							proplist = GetInheritedProps(ClassNameOverride or ClassName)
							inherited_properties[ClassNameOverride or ClassName] = proplist
						end
						for _, Property in next, proplist do
							repeat
								local PropertyName = Property.Name

								if IgnoreProperties[PropertyName] then
									break
								end

								local ValueType = Property.ValueType

								if IgnoreSharedStrings and ValueType == "SharedString" then -- ? 更多信息见 Options
									break
								end

								local Category, Optional, Special =
									Property.Category, Property.Optional, Property.Special

								local raw = ReadProperty(instance, Property, PropertyName, Special, Category, Optional)

								if raw == __BREAK then -- ! 假设读取属性失败时总是返回 __BREAK
									local ok, result = pcall(gethiddenproperty_fallback, instance, PropertyName) -- * 这有助于读取：Vector3int16、OptionalCoordinateFrame DataTypes。在 gethiddenproperty 缺失时，它几乎也可以作为其完整回退

							if result == nil and unfilterPropVal(Category, Optional) then
										ok = nil
									end

									if ok then
										raw = result
									else
										local Fallback = Property.Fallback

										if Fallback then
											ok, result = pcall(Fallback, instance)

											if ok then
												raw = result
											else
												if __DEBUG_MODE then
													-- TODO 也许在运行时移除失败的修复以避免重试
													__DEBUG_MODE("修复失败", PropertyName)
												end
												break
											end
										else
											break
										end
									end
								end

								if SharedStringOverwrite and ValueType == "BinaryString" then -- TODO：如果添加更多类型，请将其转换为表
									ValueType = "SharedString"
								end

								-- Special = Property.Special -- ? 阅读下方 TODO（如果之后经常使用它，必须更新）

								if
									default_instance
									and not Property.Special -- TODO：.Special 被检查了不止一次（因为它在 ReadProperty 期间可能会被更新）
									and not (PropertyName == "Source" and isLuaSourceContainer(instance))
								then -- ? 未来可能不只是 "Source"
									if new_def_inst then
										default_instance[PropertyName] = getsafeproperty(new_def_inst, PropertyName)
									end
									if default_instance[PropertyName] == raw then
										break
									end
									-- local ok, IsModified = pcall(IsPropertyModified, instance, PropertyName) -- ? 还没启用 lol（580）
								end

								-- 序列化开始

								local tag, value
								if Category == "Class" then
									tag = "Ref"
									if raw then
										if SaveNonCreatableWillBeEnabled then
											local Fix = NotCreatableFixes[raw.ClassName]
											if
												Fix
												and (
													PropertyName == "PlayerToHideFrom"
													or ValueType ~= "Instance" and ValueType ~= Fix
												)
											then
												-- * 为了避免错误
												break
											end
										end

										value = referents[raw]
										if not value then
											value = ref_size
											referents[raw] = value
											ref_size = ref_size + 1
										end
									else
										value = "null"
									end
								elseif Category == "Enum" then -- ! 我们特意按这个顺序（Enums 在 Descriptors 之前），因为 Font Enum 尽管有 Enum Category，可能会得到一个 Font Descriptor，而不像 Font DataType 那样该 Descriptor 是为此准备的
									value, tag = XML_Descriptors.__ENUM(raw)
								else
									local Descriptor = XML_Descriptors[ValueType]

									if Descriptor then
										value, tag = ReturnValueAndTag(raw, ValueType, Descriptor)
									elseif "ProtectedString" == ValueType then -- TODO：尝试将其放入 Descriptors 中
										tag = ValueType

										if PropertyName == "Source" then
											if DecompileIgnoring then -- ? 如果存在原始源码，这真的应该阻止提取它吗？
												if DecompileIgnoring == 1 then
													DecompileIgnoring = nil
												end
												value = "-- 已忽略"
											else
												local should_decompile = true
												local LinkedSource
												local LinkedSource_Url = instance.LinkedSource -- ! 假设每个有 ProtectedString Source 属性的类也都有 LinkedSource 属性
												local hasLinkedSource = LinkedSource_Url ~= ""
												local LinkedSource_type
												if hasLinkedSource then
													local Path = instance:GetFullName()
													if RecoveredScripts then
														table.insert(RecoveredScripts, Path)
													else
														RecoveredScripts = { Path }
													end

													LinkedSource = string.match(LinkedSource_Url, "%w+$") -- TODO：不确定这个模式是否匹配所有可能情况。示例是：'rbxassetid://0&hash=cd73dd2fe5e5013137231c227da3167e'
													if LinkedSource then
														local cached = ldeccache[LinkedSource]

														if cached then
															value = cached
															should_decompile = nil
														elseif DecompileJobless then
															value = "-- 在已反编译的 ScriptCache 中未找到"
															should_decompile = nil
														end

												LinkedSource_type = string.find(LinkedSource, "%a") and "hash" or "id"

														local asset = LinkedSource_type .. "=" .. LinkedSource

														local source
														local ok = pcall(function()
															-- 致谢 @halffalse
															source = game:HttpGet(
																"https://assetdelivery.roproxy.com/v1/asset/?" .. asset
															)
														end)

												if ok and filterLinkedSource(source) then
															ldeccache[LinkedSource] = source

															value = source

															should_decompile = nil
														end
													else --if __DEBUG_MODE then -- * 无论如何我们都会打印这个，因为非常重要
														warn(
															"提取原始脚本源码失败（请开一个 GitHub issue）：",
															instance:GetFullName(),
															LinkedSource_Url
														)
													end
												end

												if should_decompile then
													local isLocalScript = instance:IsA("LocalScript")
													if
														isLocalScript
															and instance.RunContext == Enum.RunContext.Server
														or not isLocalScript
															and instance:IsA("Script")
															and instance.RunContext ~= Enum.RunContext.Client
													then
														value =
															"-- [FilteringEnabled] 服务器脚本不可能被保存" --TODO：未来可能不只是服务器脚本
													else
														value = ldecompile(instance)
														if SaveBytecode then
															local output = SaveBytecode(instance)
															if output then
																value = output .. value
															end
														end
													end
												end

												value = "-- By FIN\n\n"
													.. (hasLinkedSource and "-- 原始源码：https://assetdelivery.roblox.com/v1/asset/?" .. (LinkedSource_type or "id") .. "=" .. (LinkedSource or LinkedSource_Url) .. "\n\n" or "")
													.. value
											end
										end
										value = XML_Descriptors.__PROTECTEDSTRING(value)
									else
										--OptionalCoordinateFrame 等等，我们让它动态处理

										if Optional then
											Descriptor = XML_Descriptors[Optional]

											if Descriptor then
												if raw == nil then
													-- * 它可以为空，因为它是可选的
													-- ? 不过既然它是可选的，为什么要保存它呢
													break
												-- value, tag = "", ValueType
												else
													value, tag = ReturnValueAndTag(raw, ValueType, Descriptor)
												end
											end
										end
									end
								end

								if tag then
									savebuffer[savebuffer_size] = ReturnProperty(tag, PropertyName, value)
									savebuffer_size = savebuffer_size + 1
								else --if __DEBUG_MODE then -- * 无论如何我们都会打印这个，因为非常重要
									warn("不支持的类型（请开一个 GitHub issue）：", ValueType, ClassName, PropertyName)
								end
							until true
						end
					end
					savebuffer[savebuffer_size] = "</Properties>"
					savebuffer_size = savebuffer_size + 1

					if SaveCacheInterval < savebuffer_size then
						save_cache()
					end
				end

				if SkipEntirely ~= false then -- ? 在这种情况下我们保存实例但不保存其后代（== false）
					local Children = InstanceOverride and InstanceOverride.__Children or instance:GetChildren()

					if #Children ~= 0 then
						save_hierarchy(Children)
					end
				end

				if DecompileIgnoring and DecompileIgnoring == instance then
					DecompileIgnoring = nil
				end

				savebuffer[savebuffer_size] = "</Item>"
				savebuffer_size = savebuffer_size + 1
			until true
		end
	end

	local function save_extra(name, hierarchy, customClassName, source)
		savebuffer[savebuffer_size] = save_specific((customClassName or "Folder"), { Name = name, Source = source })
		savebuffer_size = savebuffer_size + 1
		if hierarchy then
			save_hierarchy(hierarchy)
		end
		savebuffer[savebuffer_size] = "</Item>"
		savebuffer_size = savebuffer_size + 1
	end

	local function save_game()
		writefile(placename, "")

		if IsModel then
			savebuffer[savebuffer_size] = '<Meta name="ExplicitAutoJoints">true</Meta>'
			savebuffer_size = savebuffer_size + 1
		end
		--[[
			-- ? Roblox 还会编码以下附加属性。这些不是必需的。此外，任何已定义的 schema 都会被忽略，并且文件要有效也不需要它们：xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd"  
			另外 http 可以转换为 https，但不确定 Roblox 是否会决定检测这个
			-- ? <External>null</External><External>nil</External>  - <External> 是一个不再使用的旧概念。
		]]

		-- TODO 为此找一个更好的解决方案
		SaveNonCreatableWillBeEnabled = SaveNonCreatable
			or (IsolateLocalPlayer or IsolateLocalPlayerCharacter) and IsolateLocalPlayer
			or IsolatePlayers
			or NilInstances and global_container.getnilinstances -- ! 确保这准确反映下面的所有内容

		save_hierarchy(ToSaveList)

		if IsolateLocalPlayer or IsolateLocalPlayerCharacter then
			local LocalPlayer = service.Players.LocalPlayer
			if LocalPlayer then
				if IsolateLocalPlayer then
					SaveNonCreatable = true
					save_extra("LocalPlayer", LocalPlayer:GetChildren())
				end
				if IsolateLocalPlayerCharacter then
					local LocalPlayerCharacter = LocalPlayer.Character
					if LocalPlayerCharacter then
						save_extra("LocalPlayer Character", LocalPlayerCharacter:GetChildren())
					end
				end
			end
		end

		if IsolateStarterPlayer then
			-- SaveNonCreatable = true -- TODO：如果 StarterPlayerScripts 或 StarterCharacterScripts 不再出现在 Studio 中的隔离文件夹中，请启用
			save_extra("StarterPlayer", service.StarterPlayer:GetChildren())
		end

		if IsolatePlayers then
			SaveNonCreatable = true
			save_extra("Players", service.Players:GetChildren())
		end

		if NilInstances and global_container.getnilinstances then
			local nil_instances, nil_instances_size = {}, 1

			local NilInstancesFixes = OPTIONS.NilInstancesFixes

			for _, instance in next, global_container.getnilinstances() do
				if instance == game then
					instance = nil
					-- break
				else
					local ClassName = instance.ClassName

					local Fix = InheritsFix(NilInstancesFixes, ClassName, instance)

					if Fix then
						instance = Fix(instance, InstancesOverrides)
						-- continue
					end

					local Class = ClassList[ClassName]
					if Class then
						local ClassTags = Class.Tags
						if ClassTags and ClassTags.Service then -- 对于 CSGDictionaryService、NonReplicatedCSGDictionaryService、LogService、ProximityPromptService、TestService 等
							-- instance.Parent = game
							instance = nil
							-- continue
						end
					end
				end
				if instance then
					nil_instances[nil_instances_size] = instance
					nil_instances_size = nil_instances_size + 1
				end
			end
			SaveNonCreatable = true
			save_extra("Nil Instances", nil_instances)
		end

		if OPTIONS.ReadMe then
			save_extra(
				"README",
				nil,
				"Script",
				"--[[\n"
					.. (RecoveredScripts and "\t\t重要：以下脚本的原始源码已被恢复：" .. service.HttpService:JSONEncode(
						RecoveredScripts
					) .. "\n" or "")
					.. [[
		感谢你使用 UniversalSynSaveInstance

		如果你不是以二进制（rbxl）保存的 - 建议你立即保存游戏，以利用二进制格式，并在使用 IgnoreDefaultProperties 设置时保留某些属性的值（因为它们未来可能会改变）。
		你可以通过进入 FILE -> Save to File As -> 确保文件名以 .rbxl 结尾 -> Save 来做到这一点。

		由于 FilteringEnabled，ServerStorage、ServerScriptService 和服务器脚本不可能被保存。

		如果你的玩家无法生成到游戏中，请将 StarterPlayer 中的脚本移到其他地方。然后运行 `game:GetService("Players").CharacterAutoLoads = true`。
		并使用 "Play Here" 来开始游戏，而不是 "Play"，以便在你当前摄像机所在位置生成你的角色。

		如果聊天系统无法工作，请使用资源管理器并删除 TextChatService/Chat 服务中的所有内容。
		或者运行 `game:GetService("Chat"):ClearAllChildren() game:GetService("TextChatService"):ClearAllChildren()`
				
		如果 Union 和 MeshPart 碰撞无法工作，请在 Studio 命令栏中运行下面的脚本：
				
				
		local C = game:GetService("CoreGui")
		local D = Enum.CollisionFidelity.Default
				
		for _, v in game:GetDescendants() do
			if v:IsA("TriangleMeshPart") and not v:IsDescendantOf(C) then
				v.CollisionFidelity = D
			end
		end
		print("完成")
				
		如果你无法移动摄像机，请在 Studio 命令栏中运行此脚本：
			
		workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
		
		或者销毁 Camera。

		此文件是使用以下设置生成的：
				]]
					.. service.HttpService:JSONEncode(OPTIONS)
					.. "\n\n\t\t经过时间："
					.. os.clock() - elapse_t
					.. " PlaceId："
					.. game.PlaceId
					.. " 执行器："
					.. (identify_executor and table.concat({ identify_executor() }, " ") or "未知")
					.. "\n]]"
			)
		end
		do
			local tmp = { "<SharedStrings>" }
			for identifier, value in next, SharedStrings do
				table.insert(tmp, '<SharedString md5="' .. identifier .. '">' .. value .. "</SharedString>")
			end

			if 1 < #tmp then -- TODO：这太糟糕了，因为我们只是尝试迭代表来检查这个（检查上面的内容）
				savebuffer[savebuffer_size] = table.concat(tmp)
				savebuffer_size = savebuffer_size + 1
				savebuffer[savebuffer_size] = "</SharedStrings>"
				savebuffer_size = savebuffer_size + 1
			end
		end

		savebuffer[savebuffer_size] =
             "</roblox><!-- By FIN -->"
		savebuffer_size = savebuffer_size + 1
		save_cache(true)
		do
			-- ! 假设我们只写入文件一次，因此我们只过滤一次
			-- TODO 这在非唯一用户名上可能会导致问题（例如，如果游戏是关于蛋糕的，那么 "Cake" 这个用户名可能会导致所有据称与你名字相关的内容被替换为 "Roblox"）；某些 UserId 也可能影响数字，比如如果你的 UserId 是 2481848，而某个数字是 "1.248184818837"，那么匹配的部分将被替换为 1，可能会使数字变得不正确。
			-- TODO 所以目前最好默认保持这个禁用
			-- TODO 在最后过滤整个文件字符串也不明智，因为这也可能影响反编译脚本内容，而这些内容本来就不可能包含任何用户相关信息。更好的做法是在 string Descriptor 等地方使用 gsub
			if OPTIONS.Anonymous then
				local LocalPlayer = service.Players.LocalPlayer
				if LocalPlayer then
					local function gsubCaseInsensitive(input, search, replacement) -- * 致谢朋友们
						local inputLower = string.lower(input)

						search = string.lower(search)

						local lastFinish = 0
						local subStrings = {}
						local search_len = #search
						local input_len = #input
						while search_len <= input_len - lastFinish do
							local init = lastFinish + 1

							local start, finish = string.find(inputLower, search, init, true)

							if start == nil then
								break
							end

							table.insert(subStrings, string.sub(input, init, start - 1))

							lastFinish = finish
						end

						if lastFinish == 0 then
							return input
						end

						table.insert(subStrings, string.sub(input, lastFinish + 1))

						return table.concat(subStrings, replacement)
					end

					local Anonymous = type(OPTIONS.Anonymous) == "table" and OPTIONS.Anonymous
						or { UserId = "1", Name = "Roblox" }

					for _, chunk in next, chunks do
						chunk.str = gsubCaseInsensitive(
							string.gsub(chunk.str, LocalPlayer.UserId, Anonymous.UserId),
							LocalPlayer.Name,
							Anonymous.Name
						)
					end
				end
			end

			local Callback = OPTIONS.Callback
			if Callback then
				local totalstr = ""
				for _, chunk in next, chunks do
					totalstr = totalstr .. chunk.str
				end
				Callback(totalstr, chunks, totalsize)
			elseif OPTIONS.AlternativeWritefile and appendfile then
				local SEGMENT_SIZE = 4145728 -- Celery 对 savefile/appendfile 有一个约 4MB 的任意大小限制，原因未知。这是将文件分段保存的变通方法。

				local totallen, currentlen = math.ceil(totalsize / SEGMENT_SIZE), 1

				for _, chunk in next, chunks do
					local length = math.ceil(chunk.size / SEGMENT_SIZE)
					for i = 1, length do
						local savestr = string.sub(chunk.str, (i - 1) * SEGMENT_SIZE + 1, i * SEGMENT_SIZE)

						run_with_loading(
							"正在写入文件 " .. math.round(currentlen / totallen * 100) .. "%（取决于执行器）",
							nil,
							true,
							appendfile,
							placename,
							savestr
						)
						currentlen = currentlen + 1

						if i ~= length then
							task.wait()
						end
					end
				end
			else
				local totalstr = ""
				for _, chunk in next, chunks do
					totalstr = totalstr .. chunk.str
				end
				run_with_loading(
					"正在将 " .. get_size_format() .. " 写入文件（取决于执行器）",
					nil,
					true,
					writefile,
					placename,
					totalstr
				)
			end
		end
		table.clear(SharedStrings)
	end

	local Connections
	do
		local Players = service.Players

		if IgnoreList.Model ~= true then
			Connections = {}
			local function ignoreCharacter(player)
				table.insert(
					Connections,
					player.CharacterAdded:Connect(function(character)
						IgnoreList[character] = true
					end)
				)

				local Character = player.Character
				if Character then
					IgnoreList[Character] = true
				end
			end

			if OPTIONS.RemovePlayerCharacters then
				table.insert(
					Connections,
					Players.PlayerAdded:Connect(function(player)
						ignoreCharacter(player)
					end)
				)
				for _, player in next, Players:GetPlayers() do
					ignoreCharacter(player)
				end
			else
				IgnoreNotArchivable = false -- TODO 糟糕的解决方案（Characters 是 NotArchivable）；还要确保下一个解决方案与 IsolateLocalPlayerCharacter 兼容
				if IsolateLocalPlayerCharacter then
					task.spawn(function()
						ignoreCharacter(GetLocalPlayer())
					end)
				end
			end
		end
		if IsolateLocalPlayer and IgnoreList.Player ~= true then
			task.spawn(function()
				IgnoreList[GetLocalPlayer()] = true
			end)
		end
	end

	if IsolateStarterPlayer then
		IgnoreList.StarterPlayer = false
	end

	if IsolatePlayers then
		IgnoreList.Players = false
	end

	if OPTIONS.ShowStatus then
		do
			local Exists = GLOBAL_ENV._statustext
			if Exists then
				Exists:Destroy()
			end
		end

		local StatusGui = Instance.new("ScreenGui")

		GLOBAL_ENV._statustext = StatusGui

		StatusGui.DisplayOrder = 2e9
		pcall(function() -- ? 与级别 2 兼容
			StatusGui.OnTopOfCoreBlur = true
		end)

		StatusText = Instance.new("TextLabel")

		StatusText.Text = "正在保存..."

		StatusText.BackgroundTransparency = 1
		StatusText.Font = Enum.Font.Code
		StatusText.AnchorPoint = Vector2.new(1)
		StatusText.Position = UDim2.new(1)
		StatusText.Size = UDim2.new(0.3, 0, 0, 20)

		StatusText.TextColor3 = Color3.new(1, 1, 1)
		StatusText.TextScaled = true
		StatusText.TextStrokeTransparency = 0.7
		StatusText.TextXAlignment = Enum.TextXAlignment.Right
		StatusText.TextYAlignment = Enum.TextYAlignment.Top

		StatusText.Parent = StatusGui

		local function randomString()
			local length = math.random(10, 20)
			local randomarray = table.create(length)
			for i = 1, length do
				randomarray[i] = string.char(math.random(32, 126))
			end
			return table.concat(randomarray)
		end

		if global_container.gethui then
			StatusGui.Name = randomString()
			StatusGui.Parent = global_container.gethui()
		else
			if global_container.protectgui then
				StatusGui.Name = randomString()
				global_container.protectgui(StatusGui)
				StatusGui.Parent = game:GetService("CoreGui")
			else
				local RobloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
				if RobloxGui then
					StatusGui.Parent = RobloxGui
				else
					StatusGui.Name = randomString()
					StatusGui.Parent = game:GetService("CoreGui")
				end
			end
		end
	end

	do
		local SafeMode = OPTIONS.SafeMode
		if SafeMode then
			task.spawn(function()
				local LocalPlayer = GetLocalPlayer()

				local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
				if PlayerScripts then
					local function construct_InstanceOverride(instance)
						local children = instance:GetChildren()
						InstancesOverrides[instance] = {
							__Children = children,
						}
						for _, child in next, children do
							construct_InstanceOverride(child)
						end
					end
					construct_InstanceOverride(PlayerScripts)

					InstancesOverrides[LocalPlayer] = {
						__Children = LocalPlayer:GetChildren(),
						Properties = { Name = "[" .. LocalPlayer.ClassName .. "] " .. LocalPlayer.Name },
					}
				end

				LocalPlayer:Kick("\n[安全模式] 正在保存..\n请不要离开")
				wait_for_render()
				task.delay(10, service.GuiService.ClearError, service.GuiService)
			end)

			service.RunService:Set3dRenderingEnabled(false)
		end

		local anti_idle
		if OPTIONS.AntiIdle then
			task.spawn(function()
				anti_idle = GetLocalPlayer().Idled:Connect(function()
					service.VirtualInputManager:SendMouseWheelEvent(
						service.UserInputService:GetMouseLocation().X,
						service.UserInputService:GetMouseLocation().Y,
						true,
						game
					)
				end)
			end)
		end

		elapse_t = os.clock()

		local ok, err = xpcall(save_game, function(err)
			return debug.traceback(err)
		end)

		if SafeMode then
			service.GuiService:ClearError()
			service.RunService:Set3dRenderingEnabled(true)
		end

		if old_gethiddenproperty then
			gethiddenproperty = old_gethiddenproperty
		end

		if anti_idle then
			anti_idle:Disconnect()
		end
		if Connections then
			for _, connection in next, Connections do
				connection:Disconnect()
			end
		end
		GLOBAL_ENV[placename] = nil
		if StatusText then
			task.spawn(function()
				elapse_t = os.clock() - elapse_t
				local Log10 = math.log10(elapse_t)
				local ExtraTime = 10
				if ok then
					StatusText.Text = string.format("已保存！耗时 %.3f 秒；大小 %s", elapse_t, get_size_format())
					StatusText.TextColor3 = Color3.new(0, 1)
					task.wait(Log10 * 2 + ExtraTime)
				else
					if Loading then
						task.cancel(Loading)
						Loading = nil
					end
					StatusText.Text = "失败！请查看 F9 控制台获取更多信息"
					StatusText.TextColor3 = Color3.new(1)
					warn("保存时发现错误：")
					warn(err)
					task.wait(Log10 + ExtraTime)
				end
				StatusText:Destroy()
			end)
		end

		if OPTIONS.ShutdownWhenDone and ok then
			game:Shutdown()
		end
	end
end

return synsaveinstance