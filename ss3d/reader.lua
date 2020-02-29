if not love.filesystem then
	love.filesystem = require("love.filesystem")
end

local lf = love.filesystem
local num, strFormat = tonumber, string.format

local loader = {}

local function split(str, sep)
	local sep, fields = sep or ":", { }
	local pattern = strFormat("([^%s]+)", sep)
	str:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

local function exists(file)
	return lf.getInfo(file) ~= nil
end

function loader.load(file)
	assert(exists(file), "File not found: " .. file)
	return loader.parse(file)
end

function loader.parse(file, obj)
	obj =  obj or {}
	obj.objects = obj.objects or {}
	
	local vertices, normals, uvs, o = {}, {}, {}, nil

	for line in lf.lines(file) do
		local l = split(line, " ")
		
		if l[1] == "v" then
			vertices[#vertices+1] = { num(l[2]), num(l[3]), num(l[4]) }
		elseif l[1] == "vn" then
			normals[#normals+1] = { num(l[2]), num(l[3]), num(l[4]) }
		elseif l[1] == "vt" then
			uvs[#uvs+1] = { num(l[2]), 1.0 - num(l[3]) }
		elseif l[1] == "f" then
			for i=1, #l-1 do
				local args = split(l[i+1], "/")
				if not #args == 3 then
					error("Expected OBJ formatted p/t/n")
				end
				
				local dv = vertices[num(args[1])]
				local dn = normals[num(args[3])]
				local uv = uvs[num(args[2])]
				
				o.points[#o.points+1] = {
					dv[1], dv[2], dv[3], -- Pos
					uv[1], uv[2],        -- Uv
					dn[1], dn[2], dn[3], -- Norm
					0.0, 0.0, 0.0,       -- Tan
					0.0, 0.0, 0.0,       -- Bi-Tan
				}
			end
			
			if #l-1 == 3 then -- Triangle
				o.triangles[#o.triangles+1] = {#o.points-2, #o.points-1, #o.points-0}
			elseif #l-1 == 4 then -- Quad
				o.triangles[#o.triangles+1] = {#o.points-3, #o.points-2, #o.points-1}
				o.triangles[#o.triangles+1] = {#o.points-3, #o.points-1, #o.points-0}
			else
				error("Only triangles and quads supported. Got " .. (#l-1) .. " indices for a face")
			end
		elseif l[1] == "o" then
			local name = line:sub(3)
			o = {
				points = {},
				triangles = {},
				name = name,
			}
			
			obj.objects[#obj.objects+1] = o
		end
	end

	return obj
end

return loader