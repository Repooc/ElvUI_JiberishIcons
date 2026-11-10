local JI = unpack(JiberishIcons)
local media = JI.MediaPath..[[Overwatch\]]
local function Number(v, default, low, high)
	if (issecretvalue and issecretvalue(v)) or type(v) ~= 'number' or v ~= v then return default end
	return math.max(low, math.min(high, v))
end
local function Fit(frame)
	local db = JI.db.portraits[frame.key].model
	local model = frame.modelView.model
	model:SetPortraitZoom(Number(db.zoom, .9, 0, 1))
	model:SetFacing(Number(db.facing, .25, -math.pi, math.pi))
	if model.SetCamDistanceScale then model:SetCamDistanceScale(Number(db.distance, .85, .1, 3)) end
	if model.SetViewTranslation then model:SetViewTranslation(Number(db.viewX, 0, -100, 100), Number(db.viewY, 0, -100, 100)) end
end

function JI:LayoutPortraitModel(frame, db)
	if not frame.modelView and db.mode ~= 'model' then return end
	if not frame.modelView then
		local view = CreateFrame('Frame', nil, frame)
		frame.modelView = view
		view:SetAllPoints(frame); view:EnableMouse(false)
		if frame.SetClipsChildren then frame:SetClipsChildren(false); view:SetClipsChildren(false) end
		view.base = view:CreateTexture(nil, 'BACKGROUND'); view.base:SetAllPoints(view)
		view.rim = view:CreateTexture(nil, 'BORDER'); view.rim:SetAllPoints(view)
		view.model = CreateFrame('PlayerModel', nil, view)
		view.model:EnableMouse(false)
		view.model:SetScript('OnModelLoaded', function() Fit(frame) end)
		view.model:SetScript('OnShow', function() Fit(frame) end)
		view.front = CreateFrame('Frame', nil, view)
		view.front:SetAllPoints(view); view.front:EnableMouse(false)
		view.front.base = view.front:CreateTexture(nil, 'BACKGROUND'); view.front.base:SetAllPoints(view.front)
		view.front.rim = view.front:CreateTexture(nil, 'ARTWORK'); view.front.rim:SetAllPoints(view.front)
		for _, texture in ipairs({view.base, view.rim, view.front.base, view.front.rim}) do
			if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false); texture:SetTexelSnappingBias(0) end
		end
	end
	local view, fit = frame.modelView, db.model
	view:SetFrameLevel(frame:GetFrameLevel() + 1)
	view.model:SetFrameLevel(frame:GetFrameLevel() + 2)
	view.front:SetFrameLevel(frame:GetFrameLevel() + 3)
	local shape = (db.shape == 'shield' or db.shape == 'diamond' or db.shape == 'square') and db.shape or 'circle'
	local stem = shape == 'shield' and 'portrait' or 'portrait-'..shape
	local weight = math.floor(Number(fit.rim, 3, 1, 5) + .5)
	local suffix = weight == 3 and '' or '-'..weight
	view.base:SetTexture(media..stem..'-base.tga', 'CLAMP', 'CLAMP', 'LINEAR')
	view.rim:SetTexture(media..stem..'-rim'..suffix..'.tga', 'CLAMP', 'CLAMP', 'LINEAR')
	view.front.base:SetTexture(media..stem..'-front-base.tga', 'CLAMP', 'CLAMP', 'LINEAR')
	view.front.rim:SetTexture(media..stem..'-front-rim'..suffix..'.tga', 'CLAMP', 'CLAMP', 'LINEAR')
	view.base:SetVertexColor(unpack(db.backgroundColor)); view.front.base:SetVertexColor(unpack(db.backgroundColor))
	view.base:SetShown(db.shape ~= 'none'); view.rim:SetShown(db.shape ~= 'none'); view.front:SetShown(db.shape ~= 'none')
	local scale = Number(db.size, 80, 24, 320) / 100
	-- The model is a tall, independent viewport. Its feet stay below the inset
	-- lip, and its head can render above the rear rim without parent clipping.
	view.model:SetSize(Number(fit.width, 94, 40, 160) * scale, Number(fit.height, 160, 80, 220) * scale)
	view.model:ClearAllPoints()
	view.model:SetPoint('BOTTOM', frame, 'BOTTOM', Number(fit.x, 0, -100, 100) * scale, Number(fit.y, 8, -50, 100) * scale)
	Fit(frame)
end

function JI:PaintPortraitModel(frame, unit, color)
	local view = frame.modelView
	if not view then return end
	view.rim:SetVertexColor(unpack(color)); view.front.rim:SetVertexColor(unpack(color))
	view:Show(); view.model:Show(); view.model:SetUnit(unit); Fit(frame)
end

function JI:ResetPortraitModelFit(key)
	if InCombatLockdown() then return end
	JI.db.portraits[key].model = JI:CopyTable({}, JI.DF.profile.portraits[key].model)
	JI:UpdatePortraits()
end

-- Retire the separate HUD without losing enabled portraits. Never overwrite an
-- existing Portraits entry; remove obsolete dial/action settings after migration.
function JI:MigrateHUDPortraits()
	local old = JI.db.overwatch
	if type(old) ~= 'table' then return end
	if old.enable then
		for _, key in ipairs({'player', 'target', 'focus'}) do
			local source, target = old[key == 'player' and 'left' or key], JI.db.portraits[key]
			if key == 'player' and not source then source = {} end
			local enabled = source and (source.enable == true or (key == 'player' and source.enable ~= false))
			if enabled and not target.enable then
				target.enable, target.mode, target.shape = true, source.portrait == 'portrait' and 'portrait' or 'model', 'shield'
				target.size = 100 * Number(source.scale, 1, .24, 3.2)
				target.anchor = 'elvui'
				target.point, target.relativePoint = source.side == 'RIGHT' and 'LEFT' or 'RIGHT', source.side == 'RIGHT' and 'RIGHT' or 'LEFT'
				target.x, target.y = Number(source.offsetX, -12, -10000, 10000), Number(source.offsetY, 0, -10000, 10000)
				target.classColor = source.classColor ~= false
				if source.color then target.borderColor = JI:CopyTable({}, source.color) end
				target.borderColor[4] = Number(source.borderOpacity, 1, 0, 1)
				if source.backgroundColor then target.backgroundColor = JI:CopyTable({}, source.backgroundColor) end
				-- Start with the new lower shoulder fit rather than importing the
				-- boxed-in viewport. Colors, side, size and placement survive.
				target.model = JI:CopyTable({}, JI.DF.profile.portraits[key].model)
				target.model.rim = Number(source.rimThickness, 3, 1, 5)
			end
		end
	end
	JI.db.overwatch = nil
end
