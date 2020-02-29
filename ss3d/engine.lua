-- Super Simple 3D Engine v2.0
-- groverburger 2019
-- EngineerSmith 2020

local PATH = (...):match("(.-)[^%.]+$")
local ObjReader = require(PATH.."reader")
local cpml = require(PATH.."cpml")
local mat4 = cpml.mat4
local vec3 = cpml.vec3

local floor, rad, max, min, sqrt, pi = math.floor, math.rad, math.max, math.min, math.sqrt, math.pi
local halfPi = pi/2
local insert, remove = table.insert, table.remove

local lg = love.graphics

local function TransposeMatrix(mat)
	return mat4.transpose(mat4.new(), mat)
end
local function InvertMatrix(mat)
	return mat4.invert(mat4.new(), mat)
end
local function CrossProduct(x1,y1,z1 ,x2,y2,z2)
    local x, y, z
    x = y1 * z2 - z1 * y2
    y = z1 * x2 - x1 * z2
    z = x1 * y2 - y1 * x2
    return x, y, z
end
local function VectorLengthSqrt(x,y,z)
    return sqrt(x*x+y*y+z*z)
end

local engine = {}

engine.defaultTexture = lg.newCanvas(1,1)
lg.setCanvas(engine.defaultTexture)
lg.clear(1,0,1,1)
lg.setCanvas()

function engine.loadObj(objPath)
    local obj = ObjReader.load(objPath)
	
	for _, object in ipairs(obj.objects) do
		object.indices, object.vertices = {}, {}
		local verticesIDs = {}
		for _, triangle in ipairs(object.triangles) do
			for i=1, 3 do
				if not verticesIDs[triangle[i]] then
					object.vertices[#object.vertices+1] = object.points[triangle[i]]
					verticesIDs[triangle[i]] = #object.vertices
				end
				object.indices[#object.indices+1] = verticesIDs[triangle[i]]
			end
		end
	end
	
	obj.newModels = function(self, texture)
		local models = {}
		for _, object in ipairs(self.objects) do
			models[#models+1] = engine.newModel(object.vertices, object.indices, texture)
		end
		return models
	end
	
	return obj
end

function engine.newModel(vertices, indices, texture, normal, specular)
    local m = {}

    local fmt = {
        {"VertexPosition",  "float", 3},
        {"VertexTexCoord",  "float", 2},
        {"VertexNormal",    "float", 3}, 
		{"VertexTangent",   "float", 3},
		{"VertexBiTangent", "float", 3},
    }

    assert(vertices ~= nil, "NewModel require verts")
	m.texture = texture or engine.defaultTexture or error("NewModel requires a texture")
	m.normalMap = normal
	m.specularMap = specular
	
	-- Calculate Tangents
	for i=1, #indices, 3 do
		local v1 = vertices[indices[i]]
		local v2 = vertices[indices[i+1]]
		local v3 = vertices[indices[i+2]]
		
		assert(#v1 == 14 or #v2 == 14 or #v3 == 14, "Vertex requires 14 elements: v1#"..#v1.." v2#"..#v2.." v3#"..#v3)
		
		local edge1X = v2[1] - v1[1]
		local edge1Y = v2[2] - v1[2]
		local edge1Z = v2[3] - v1[3]
		
		local edge2X = v3[1] - v1[1]
		local edge2Y = v3[2] - v1[2]
		local edge2Z = v3[3] - v1[3]
		
		local edge1uvX = v2[4] - v1[4]
		local edge1uvY = v2[5] - v1[5]
		
		local edge2uvX = v3[4] - v1[4]
		local edge2uvY = v3[5] - v1[5]
		
		local r = edge1uvX * edge2uvY - edge1uvY * edge2uvX
		
		if r ~= 0 then -- Edge case
			r = r / 1.0
			local tangentX = (edge1X * edge2uvY - edge2X * edge1uvY) * r
			local tangentY = (edge1Y * edge2uvY - edge2Y * edge1uvY) * r
			local tangentZ = (edge1Z * edge2uvY - edge2Z * edge1uvY) * r
			local bitangentX = (edge2X * edge1uvX - edge1X * edge2uvX) * r
			local bitangentY = (edge2Y * edge1uvX - edge1Y * edge2uvX) * r
			local bitangentZ = (edge2Z * edge1uvX - edge1Z * edge2uvX) * r
			
			v1[9]  = v1[9]  + tangentX
			v1[10] = v1[10] + tangentY
			v1[11] = v1[11] + tangentZ
			v1[12] = v1[12] + bitangentX
			v1[13] = v1[13] + bitangentY
			v1[14] = v1[14] + bitangentZ
			
			v2[9]  = v2[9]  + tangentX
			v2[10] = v2[10] + tangentY
			v2[11] = v2[11] + tangentZ
			v2[12] = v2[12] + bitangentX
			v2[13] = v2[13] + bitangentY
			v2[14] = v2[14] + bitangentZ
			
			v3[9]  = v3[9]  + tangentX
			v3[10] = v3[10] + tangentY
			v3[11] = v3[11] + tangentZ
			v3[12] = v3[12] + bitangentX
			v3[13] = v3[13] + bitangentY
			v3[14] = v3[14] + bitangentZ
		end
	end

	for _, vertex in ipairs(vertices) do
		-- Normalize
		local length = VectorLengthSqrt(vertex[9], vertex[10], vertex[11])
		vertex[9] = vertex[9] / length
		vertex[10] = vertex[10] / length
		vertex[11] = vertex[11] / length
		
		length = VectorLengthSqrt(vertex[12], vertex[13], vertex[14])
		vertex[12] = vertex[12] / length
		vertex[13] = vertex[13] / length
		vertex[14] = vertex[14] / length
		-- Smooth
		local dot = vertex[9] * vertex[6] + vertex[10] * vertex[7] + vertex[11] * vertex[8]
		vertex[9] = vertex[9] - vertex[6] * dot
		vertex[10] = vertex[10] - vertex[7] * dot
		vertex[11] = vertex[11] - vertex[8] * dot
		
		local length = VectorLengthSqrt(vertex[9], vertex[10], vertex[11])
		vertex[9] = vertex[9] / length
		vertex[10] = vertex[10] / length
		vertex[11] = vertex[11] / length
		
		-- Invert if facing wrong direction
		local x,y,z = CrossProduct(vertex[6],vertex[7],vertex[8], vertex[9],vertex[10],vertex[11])
		dot = x * vertex[12] + y * vertex[13] + z * vertex[14]
		if dot < 0.0 then
			vertex[9] = vertex[9] * -1.0
			vertex[10] = vertex[10] * -1.0
			vertex[11] = vertex[11] * -1.0
		end
	end

    -- define the Model object's properties
    m.mesh = nil
    if #vertices > 0 then
        m.mesh = lg.newMesh(fmt, vertices, "triangles")
		m.mesh:setVertexMap(indices)
        m.mesh:setTexture(m.texture)
    end
    m.format = fmt
    m.verts = vertices
	m.indices = indices
    m.transform = TransposeMatrix(mat4.identity())
    m.visible = true
    m.wireframe = false
    m.culling = false

    m.setMesh = function (self, vertices, indices)
        if vertices and #vertices > 0 then
            self.mesh = lg.newMesh(self.format, vertices, "triangles")
			self.mesh:setVertexMap(indices)
            self.mesh:setTexture(self.texture)
		else
			self.mesh = nil
        end
        self.verts = vertices
		self.indices = indices
    end

    -- translate and rotate the Model
    m.setTransform = function (self, coords, rotations)
        self.transform = mat4.identity()
        self.transform:translate(self.transform, vec3(coords))
        if rotations ~= nil then
            for i=1, #rotations, 2 do
                self.transform:rotate(self.transform, rotations[i],rotations[i+1]) -- radians, unit vector
            end
        end
        self.transform = TransposeMatrix(self.transform)
    end

    -- returns a copy of the verts this Model contains
    m.getVerts = function (self)
        local ret = {}
        for i=1, #self.verts do
            ret[#ret+1] = {self.verts[i][1], self.verts[i][2], self.verts[i][3]}
        end

        return ret
    end

    -- prints a list of the verts this Model contains
    m.printVerts = function (self)
        local verts = self:getVerts()
        for i=1, #verts do
            print(verts[i][1], verts[i][2], verts[i][3])
            if i%3 == 0 then
                print("---")
            end
        end
    end

    -- set a texture to this Model
    m.setTexture = function (self, tex)
        self.mesh:setTexture(tex)
    end

    return m
end

-- create a new Scene object with given canvas output size
function engine.newScene(renderWidth,renderHeight)
	lg.setDepthMode("lequal", true)
    local scene = {}

    -- define the shaders used in rendering the scene
    scene.threeShader = lg.newShader[[
        uniform mat4 view;
        uniform mat4 model_matrix;
        uniform mat4 model_matrix_inverse;
        uniform float ambientLight;
        uniform vec3 ambientVector;
		uniform vec3 eye;
		
		uniform Image normalMap;
		uniform Image specularMap;

        varying mat4 modelView;
        varying mat4 modelViewProjection;
		varying mat3 TBN;
        varying vec3 normal;
        varying vec3 vposition;

        #ifdef VERTEX
            attribute vec4 VertexNormal;
			attribute vec4 VertexTangent; 
			attribute vec4 VertexBiTangent;
			
            vec4 position(mat4 transform_projection, vec4 vertex_position) {
                modelView = view * model_matrix;
                modelViewProjection = view * model_matrix * transform_projection;

                normal = vec3(model_matrix_inverse * vec4(VertexNormal));
				
				vec3 tangent = vec3(model_matrix_inverse * vec4(VertexTangent));
				vec3 bitangent = vec3(model_matrix_inverse * vec4(VertexBiTangent));
				
				TBN = mat3(tangent, bitangent, normal);
				
                vposition = vec3(model_matrix * vertex_position);

                return view * model_matrix * vertex_position;
            }
        #endif

        #ifdef PIXEL		
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
			vec4 texturecolor = Texel(texture, texture_coords);
	
			// if the alpha here is zero just don't draw anything here
			// otherwise alpha values of zero will render as black pixels
			if (texturecolor.a == 0.0)
			{
				discard;
			}
			
			vec4 c = texturecolor * color;

			vec3 n = TBN * normalize(Texel(normalMap, texture_coords).rgb - 0.5);

			float light = max(dot(normalize(ambientVector), n), 0);
			ambientLight;
			//texturecolor.rgb *= max(light, ambientLight);
	
	
			// Diffuse
			vec3 lightDir = normalize(ambientVector);
			float diffuseFactor = clamp(dot(n, lightDir), 0.0f, 1.0f);
			vec3 diffuse = diffuseFactor * vec3(0.6);
	
			// Specular
			vec3 e = normalize(vposition - eye);
			float specularFactor = pow(max(dot(reflect(-lightDir, n), e), 0.0f), 3.0f);
			vec3 specular = clamp(specularFactor * (vec3(0.8) * Texel(specularMap, texture_coords).rgb), 0.0f, 1.0f);
			
			return vec4((diffuse + vec3(0.3f)) * c.rgb + specular, c.a);
		}
        #endif
    ]]


    scene.renderWidth = renderWidth
    scene.renderHeight = renderHeight

    -- create a canvas that will store the rendered 3d scene
    scene.threeCanvas = lg.newCanvas(renderWidth, renderHeight)

    -- a list of all models in the scene
    scene.modelList = {}

    scene.fov = 70
    scene.nearClip = 0.001
    scene.farClip = 10000
    scene.camera = {
        pos = vec3(0,0,0),
        angle = vec3(0,0,0),
        perspective = TransposeMatrix(mat4.from_perspective(scene.fov, renderWidth/renderHeight, scene.nearClip, scene.farClip)),
    }

    scene.ambientLight = 0.25
    scene.ambientVector = {0,1,0}

    -- returns a reference to the model
    scene.addModel = function (self, model)
        insert(self.modelList, model)
        return model
    end

    -- finds and removes model, returns boolean if successful
    scene.removeModel = function (self, model)
		for i=1, #self.modelList do
			if self.modelList[i] == model then
				remove(self.modelList, i)
				return true
			end
		end
        return false
    end

    scene.changeCamera = function (self, fov, near, far)
        self.fov = fov
        self.nearClip = near
        self.farClip = far
        self.camera.perspective = TransposeMatrix(mat4.from_perspective(self.fov, self.renderWidth/self.renderHeight, self.nearClip, self.farClip))
    end

    -- resize output canvas to given dimensions
    scene.resize = function (self, renderWidth, renderHeight)
        self.renderWidth = renderWidth
        self.renderHeight = renderHeight
        self.threeCanvas = lg.newCanvas(renderWidth, renderHeight)
        self.camera.perspective = TransposeMatrix(mat4.from_perspective(self.fov, renderWidth/renderHeight, self.nearClip, self.farClip))
    end

    -- renders the models in the scene to the threeCanvas
    -- will draw threeCanvas if drawArg is not given or is true (use if you want to scale the game canvas to window)
    scene.render = function (self, drawArg)
        lg.setColor(1,1,1)
        lg.setCanvas({self.threeCanvas, depth=true})
        lg.clear(0,0,0,0)
        lg.setShader(self.threeShader)

        -- compile camera data into usable view to send to threeShader
        local Camera = self.camera
        local camTransform = mat4()
        camTransform:rotate(camTransform, Camera.angle.y, vec3.unit_x)
        camTransform:rotate(camTransform, Camera.angle.x, vec3.unit_y)
        camTransform:rotate(camTransform, Camera.angle.z, vec3.unit_z)
        camTransform:translate(camTransform, Camera.pos*-1)
        self.threeShader:send("view", Camera.perspective * TransposeMatrix(camTransform))
		self.threeShader:send("eye", {Camera.pos.x, Camera.pos.y, Camera.pos.z})
        self.threeShader:send("ambientLight", self.ambientLight)
        self.threeShader:send("ambientVector", self.ambientVector)

        -- go through all models in modelList and draw them
        for i=1, #self.modelList do
            local model = self.modelList[i]
            if model ~= nil and model.visible and #model.verts > 0 then
                self.threeShader:send("model_matrix", model.transform)
                self.threeShader:send("model_matrix_inverse", TransposeMatrix(InvertMatrix(model.transform)))

				self.threeShader:send("normalMap", model.normalMap)
				self.threeShader:send("specularMap", model.specularMap)
				
                lg.setWireframe(model.wireframe)
                if model.culling then
                    lg.setMeshCullMode("back")
                end

                lg.draw(model.mesh, -self.renderWidth/2, -self.renderHeight/2)

                lg.setMeshCullMode("none") -- TODO
                lg.setWireframe(false)
            end
        end

        lg.setShader()
        lg.setCanvas()

        --lg.setColor(1,1,1) -- Already set to white
        if drawArg == nil or drawArg == true then
            lg.draw(self.threeCanvas, self.renderWidth/2,self.renderHeight/2, 0, 1,-1, self.renderWidth/2, self.renderHeight/2)
        end
    end

    -- useful if mouse relativeMode is enabled
    -- useful to call from love.mousemoved
    -- a simple first person mouse look function
    scene.mouseLook = function (self, x, y, dx, dy)
        local Camera = self.camera
        Camera.angle.x = Camera.angle.x + rad(dx * 0.5)
        Camera.angle.y = max(min(Camera.angle.y + rad(dy * 0.5), halfPi), -halfPi)
    end

    return scene
end

-- useful functions
function engine.scaleVerts(verts, sx,sy,sz)
    if sy == nil then
        sy = sx
        sz = sx
    end

    for i=1, #verts do
        local vert = verts[i]
        vert[1] = vert[1]*sx
        vert[2] = vert[2]*sy
        vert[3] = vert[3]*sz
    end

    return verts
end
function engine.moveVerts(verts, sx,sy,sz)
    if sy == nil then
        sy = sx
        sz = sx
    end

    for i=1, #verts do
        local vert = verts[i]
        vert[1] = vert[1]+sx
        vert[2] = vert[2]+sy
        vert[3] = vert[3]+sz
    end

    return verts
end

return engine
