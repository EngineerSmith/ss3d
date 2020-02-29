local ss3d = require("ss3d")
local engine = ss3d.engine
local cpml = ss3d.cpml

function love.load()
    -- make the mouse cursor locked to the screen
    love.mouse.setRelativeMode(true)
    love.window.setTitle("ss3d 1.3 demo")
    love.window.setMode(1024, 1024*9/16, {vsync = false})
    love.graphics.setBackgroundColor(0.52,0.57,0.69)
    Paused = false

    -- create a Scene object which stores and renders Models
    -- arguments refer to the Scene's camera's canvas output size in pixels
    Scene = engine.newScene(love.graphics.getWidth(), love.graphics.getHeight())
	Scene.ambientLight = 1
	Scene.ambientVector = {0,0,1}
    DefaultTexture = love.graphics.newImage("assets/texture.png")
	
	local diffuse = love.graphics.newImage("assets/earth.bmp")
	local normal = love.graphics.newImage("assets/earth_normals.jpg")
	local specular = love.graphics.newImage("assets/earth_specular.jpg")
    Timer = 0

    Scene.camera.pos.x = 0
    Scene.camera.pos.z = 5

    -- turn the vertices into a Model with a texture
	local obj = engine.loadObj("assets/earth.obj")
    AlakazamModel = engine.newModel(obj.objects[1].vertices, obj.objects[1].indices, diffuse)
	AlakazamModel.normalMap = normal
	AlakazamModel.specularMap = specular
    Scene:addModel(AlakazamModel)
end

function love.update(dt)
    love.mouse.setRelativeMode(not Paused)
    if Paused then
        return
    end

    -- make the AlakazamModel go in circles and rotate
    Timer = Timer + dt/2
    AlakazamModel:setTransform({0,-1.5,0}, {Timer, cpml.vec3.unit_y, 0, cpml.vec3.unit_z, 0, cpml.vec3.unit_x})

    -- simple first-person camera movement
    local mx,my = 0,0
    if love.keyboard.isDown("w") then
        my = my - 1
    end
    if love.keyboard.isDown("a") then
        mx = mx - 1
    end
    if love.keyboard.isDown("s") then
        my = my + 1
    end
    if love.keyboard.isDown("d") then
        mx = mx + 1
    end

    if mx ~= 0 or my ~= 0 then
        local angle = math.atan2(my,mx)
        local speed = 0.15
        Scene.camera.pos.x = Scene.camera.pos.x + math.cos(Scene.camera.angle.x + angle)*speed*dt*60
        Scene.camera.pos.z = Scene.camera.pos.z + math.sin(Scene.camera.angle.x + angle)*speed*dt*60
    end
end

function love.mousemoved(x,y, dx,dy)
    -- basic first person mouselook, built into Scene object
    if not Paused then
        Scene:mouseLook(x,y, dx,dy)
    end
end

function love.keypressed(k)
    if k == "escape" then
        Paused = not Paused
    end
end

function love.draw()
    -- render all Models in the Scene
    love.graphics.setColor(1,1,1)
    Scene:render()

    love.graphics.setColor(0,0,0)
    love.graphics.print("groverburger's super simple 3d engine v1.3")
    love.graphics.print("FPS: "..love.timer.getFPS(),0,16)

    if Paused then
        love.graphics.print("PAUSED",0,32)
    end
end
