local BASE = (...) .. '.'
local ss3d = {
	engine = require(BASE.."engine"),
	objReader = require(BASE.."reader"),
	cpml = require(BASE.."cpml"),
}
return ss3d