local ss3d = require("ss3d")
local engine = ss3d.engine
local cpml = ss3d.cpml

local lg, lw, lm, lk, lt = love.graphics, love.window, love.mouse, love.keyboard, love.timer
local atan2, sin, cos = math.atan2, math.sin, math.cos

lg.setBackgroundColor(0.52,0.57,0.69)

lw.setTitle("ss3d 2.0 demo")
lw.setMode(1024, 1024*9/16, {vsync = false})

local paused = false
local scene = engine.newScene(lg.getDimensions())
scene.camera.pos.x = 0
scene.camera.pos.z = 5

local model

function love.load()
	local obj = engine.loadObj("assets/house.obj")
	lg.setDefaultFilter("nearest", "nearest")
	for _, material in pairs(obj.materials) do
		if material.diffuseMap then
			material.diffuseMap = lg.newImage(material.diffuseMap)
			material.diffuseMap:setWrap("repeat", "repeat")
		end
	end
	for _, object in ipairs(obj.objects) do
		scene:addModel(engine.newModel(object.vertices, object.indices, obj.materials[object.material]))
	end
end

local timer, speed = 0, 1
function love.update(dt)
    lm.setRelativeMode(not paused)
    if paused then
        return
    end

    timer = timer + speed * dt
    --model:setTransform({0,-1.5,0}, {timer, cpml.vec3.unit_y})

    -- simple first-person camera movement
    local mx,my = 0,0
    if lk.isDown("w") then
        my = my - 1
    end
    if lk.isDown("a") then
        mx = mx - 1
    end
    if lk.isDown("s") then
        my = my + 1
    end
    if lk.isDown("d") then
        mx = mx + 1
    end

    if mx ~= 0 or my ~= 0 then
        local angle = scene.camera.angle.x + atan2(my,mx)
        local speed = 0.15
        scene.camera.pos.x = scene.camera.pos.x + cos(angle)*speed*dt*60
        scene.camera.pos.z = scene.camera.pos.z + sin(angle)*speed*dt*60
    end
end

function love.mousemoved(x,y, dx,dy)
    -- basic first person mouselook, built into Scene object
    if not paused then
        scene:mouseLook(x,y, dx,dy)
    end
end

function love.keypressed(k)
    if k == "escape" then
        paused = not paused
	elseif k == "pageup" then
		scene.camera.pos.y = scene.camera.pos.y + 0.5
	elseif k == "pagedown" then
		scene.camera.pos.y = scene.camera.pos.y - 0.5
    end
end

function love.draw()
    -- render all Models in the Scene
    lg.setColor(1,1,1)
    scene:render()

    lg.setColor(0,0,0)
    lg.print("FPS: "..lt.getFPS(),0,0)
	lg.print("Camera Pos "..scene.camera.pos.x..":"..scene.camera.pos.y..":"..scene.camera.pos.z..", Angle "..scene.camera.angle.x..":"..scene.camera.angle.y..":"..scene.camera.angle.z, 0, 16)

    if paused then
        lg.print("PAUSED",0,32)
    end
end