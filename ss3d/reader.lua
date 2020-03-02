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

local function getFilePath(path)
	return path:match("(.+[/\\]).+%..+")
end

function loader.load(file, addObjDirToAssets)
	assert(exists(file), "File not found: " .. file)
	return loader.parseOBJ(file, nil, addObjDirToAssets)
end

function loader.parseOBJ(file, obj, addObjDirToAssets)
	obj =  obj or {}
	obj.objects = obj.objects or {}
	addObjDirToAssets = addObjDirToAssets or true
	
	local vertices, normals, uvs, o = {}, {}, {}, nil

	for line in lf.lines(file) do
		local l = split(line, " ")
		if #l < 2 then
			goto continue
		end
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
					error("Expected OBJ formatted v/t/n")
				end
				
				local dv = vertices[num(args[1])]
				local dn = normals[num(args[3])]
				local uv = uvs[num(args[2])]
				
				o.points[#o.points+1] = {
					dv[1], dv[2], dv[3], -- Pos
					uv[1], uv[2],        -- UV
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
		elseif l[1] == "usemtl" then
			o.material = l[2]
		elseif l[1] == "o" then
			local name = line:sub(3)
			o = {
				points = {},
				triangles = {},
				name = name,
			}
			
			obj.objects[#obj.objects+1] = o
		elseif l[1] == "mtllib" then
			obj.materials = obj.materials or {}
			local path = getFilePath(file)
			loader.parseMTL(obj.materials, path..l[2], addObjDirToAssets and path or "")
		end
		::continue::
	end
	
	return obj
end

function loader.parseMTL(materials, file, path)
	local material = nil
	
	for line in lf.lines(file) do
		local l = split(line, " ")
		if #l < 2 then
			goto continue
		end
		-- Base Material
		if l[1] == "Ka" then
			material.ambient = { num(l[2]), num(l[3]), num(l[4]) }
		elseif l[1] == "Kd" then
			material.diffuse = { num(l[2]), num(l[3]), num(l[4]) }
		elseif l[1] == "Ke" then
			material.emissive = { num(l[2]), num(l[3]), num(l[4]) }
		elseif l[1] == "Ks" then
			material.specular = { num(l[2]), num(l[3]), num(l[4]) }
		elseif l[1] == "Ns" then
			material.specularPower = num(l[2])
		elseif l[1] == "Ni" then
			material.refraction = num(l[2])
		--[[elseif l[1] == "d" then -- Removed due to too much effort for number arguments
			material.dissolve = num(l[2])]]
		elseif l[1] == "illum" then
			material.illuminationModel = num(l[2])
		elseif l[1] == "newmtl" then
			material = {}
			materials[l[2]] = material
		-- Mapping, doesn't support arguments, but will skip them
		elseif l[1] == "map_Ka" then
			material.ambientMap = path..l[#l]
		elseif l[1] == "map_Kd" then
			material.diffuseMap = path..l[#l]
		elseif l[1] == "map_Ks" then
			material.specularColorMap = path..l[#l]
		elseif l[1] == "map_Ns" then
			material.specularMap = path..l[#l]
		elseif l[1] == "map_d" then
			material.alphaMap = path..l[#l]
		elseif l[1] == "map_bump" or l[1] == "bump" then
			material.bumpMap = path..l[#l]
		elseif l[1] == "disp" then
			material.displacementMap = path..l[#l]
		elseif l[1] == "decal" then
			material.decalMap = path..l[#l]
		end
		::continue::
	end
	return materials
end

return loader