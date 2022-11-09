--Laser Gun example mod

function init()
	--Register tool and enable it
	RegisterTool("supercutter", "Precise Cutter", "MOD/vox/cuttergun.vox")
	SetBool("game.tool.supercutter.enabled", true)

	--Laser gun has 60 seconds of ammo. 
	--If played in sandbox mode, the sandbox script will make it infinite automatically
	SetFloat("game.tool.supercutter.ammo", 20)

	fireTime = 0

	enableFire = true
	
	openSnd = LoadSound("MOD/snd/open.ogg")
	closeSnd = LoadSound("MOD/snd/close.ogg")
	laserSnd = LoadLoop("MOD/snd/laser.ogg")
	hitSnd = LoadLoop("MOD/snd/hit.ogg")

	prev_circle = LoadSprite("MOD/preview_circle.png")
	openMenu = false
	inputAllowed = true
	sliderList = {
		Height=33.33,
		Depth=8,
		Radius=30,
		Speed=15
	}
	buttonList = {}
	autoStopToggle = true
	autoStop = true
	startMenu = true
	clearAll = false
	showPreview = true
end

--Return a random vector of desired length
function rndVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function makeSlider(x,y,min,max,name,format,multiplier)
	UiPush()
	UiTranslate(x+104,y+14)
	UiColor(0.15,0.15,0.15,0.75)
	UiRect(max-min,4)
	UiPop()

	UiPush()
	UiTranslate(x+90,y)
	sliderList[name] = UiSlider("slider.png", "x", sliderList[name], min, max)
	UiPop()

	UiPush()
	UiTranslate(x,y+16)
	UiColor(1,1,1)
	UiFont("bold.ttf", 20)
	UiText(name.."\n"..string.format(format,sliderList[name]*multiplier))
	UiPop()
	return sliderList[name]*multiplier
end
function makeTextButton(x,y,w,h,name,stat)
	UiPush()
	UiTranslate(x,y)
	UiColor(1,1,1)
	UiFont("bold.ttf", 20)
	if stat ~= nil then
		buttonList[name] = UiTextButton(name.." : "..stat,w,h)
	else
		buttonList[name] = UiTextButton(name)
	end
	UiPop()

	return buttonList[name]
end
function draw(dt)
	if openMenu or startMenu then
		mw = UiCenter()
		mh = UiMiddle()
		UiBlur(0.05)
		UiMakeInteractive()
		UiPush()
		UiTranslate(mw-150,mh-100)
		UiColor(0.3,0.3,0.3,0.5)
		UiRect(300,300)
		UiPop()

		height = makeSlider(mw-140,mh-90,0,100,"Height","%.1f",0.15)
		depth = makeSlider(mw-140,mh-53,0,100,"Depth","%.1f",0.8)
		radius = makeSlider(mw-140,mh-16,0,100,"Radius","%.1f",0.5)
		speed = makeSlider(mw-140,mh+21,0,100,"Speed","%.1f",0.1)

		if makeTextButton(mw-140,mh+80,10,60,"Auto-Stop",tostring(autoStop)) then
			if autoStopToggle then
				autoStop = not autoStop
				autoStopToggle = false
			end
		else
			autoStopToggle = true
		end
		
		if makeTextButton(mw-140,mh+110,10,60,"Default",nil) then
			openMenu = false
			sliderList = {
				Height=33.33,
				Depth=8,
				Radius=30,
				Speed=15
			}
			autoStop = true
			startMenu = true
		end
		
		if startMenu then
			startMenu = false
		end
		clearAll = makeTextButton(mw-140,mh+140,10,60,"Clear All",nil)

		if makeTextButton(mw-140,mh+170,10,60,"Preview",tostring(showPreview)) then
			if showPreviewToggle then
				showPreview = not showPreview
				showPreviewToggle = false
			end
		else
			showPreviewToggle = true
		end
	end
end

function tick(dt)
	--Check if laser gun is selected
	if GetString("game.player.tool") == "supercutter" then
		if InputDown("g") or (InputDown("esc") and openMenu) then
			if inputAllowed then
				openMenu = not openMenu
				-- DebugPrint(openMenu)
				inputAllowed = false
			end
		else
			inputAllowed = true
		end

		--Draws the Preview Lines
		local camera_transform = GetCameraTransform()
		local camera_forward = TransformToParentVec(camera_transform, Vec(0, 0, -1))
		local prev_hit, prev_dist, prev_normal, prev_shape = QueryRaycast(camera_transform.pos, camera_forward, 5)

		local prev_rot = QuatLookAt({0,0,0},prev_normal)
		local prev_quat = QuatEuler(-90, 0, 0)
		local prev_rot_final = QuatRotateQuat(prev_rot,prev_quat)

		if prev_hit then
			local prev_hitpoint = VecAdd(camera_transform.pos, VecScale(camera_forward, prev_dist))
			local prev_hitpoint_zfix = VecAdd(prev_hitpoint, QuatRotateVec(prev_rot_final,{0,0.01,0}))

			DrawSprite(prev_circle, Transform(prev_hitpoint_zfix,QuatRotateQuat(prev_rot_final,QuatEuler(90,0,0))), (radius/10-0.1)*2, (radius/10-0.1)*2,0,1,0.1,0.1,true,true)
			DrawSprite(prev_circle, Transform(prev_hitpoint,QuatRotateQuat(prev_rot_final,QuatEuler(90,0,0))), (radius/10-0.1)*2, (radius/10-0.1)*2,0,1,0.1,0.01,false,true)

			prev_point_up = VecAdd(prev_hitpoint,QuatRotateVec(prev_rot_final,{0,0,(radius/10-0.1)}))
			prev_point_down = VecAdd(prev_hitpoint,QuatRotateVec(prev_rot_final,{0,0,(radius/10-0.1)*-1}))
			prev_point_right = VecAdd(prev_hitpoint,QuatRotateVec(prev_rot_final,{(radius/10-0.1),0,0}))
			prev_point_left = VecAdd(prev_hitpoint,QuatRotateVec(prev_rot_final,{(radius/10-0.1)*-1,0,0}))

			prev_point_height_up = VecAdd(prev_point_up,QuatRotateVec(prev_rot_final,{0,height/10,0}))
			prev_point_height_down = VecAdd(prev_point_down,QuatRotateVec(prev_rot_final,{0,height/10,0}))
			prev_point_height_right = VecAdd(prev_point_right,QuatRotateVec(prev_rot_final,{0,height/10,0}))
			prev_point_height_left = VecAdd(prev_point_left,QuatRotateVec(prev_rot_final,{0,height/10,0}))

			prev_point_depth_up = VecAdd(prev_point_height_up,QuatRotateVec(prev_rot_final,{0,-(depth/10),0}))
			prev_point_depth_down = VecAdd(prev_point_height_down,QuatRotateVec(prev_rot_final,{0,-(depth/10),0}))
			prev_point_depth_right = VecAdd(prev_point_height_right,QuatRotateVec(prev_rot_final,{0,-(depth/10),0}))
			prev_point_depth_left = VecAdd(prev_point_height_left,QuatRotateVec(prev_rot_final,{0,-(depth/10),0}))

			DrawLine(prev_hitpoint,prev_point_up,1,0,0) --Up
			DebugLine(prev_hitpoint,prev_point_up,1,0,0,0.35) --Up (transparent)

			DrawLine(prev_point_height_up,prev_point_depth_up,1,0,0) --Up (depth+height)
			DebugLine(prev_point_height_up,prev_point_depth_up,1,0,0,0.35) --Up (depth+height, transparent)


			DrawLine(prev_hitpoint,prev_point_down,1,0,0) --Down
			DebugLine(prev_hitpoint,prev_point_down,1,0,0,0.35) --Down (transparent)

			DrawLine(prev_point_height_down,prev_point_depth_down,1,0,0) --Down (depth+height)
			DebugLine(prev_point_height_down,prev_point_depth_down,1,0,0,0.35) --Down (depth+height, transparent)


			DrawLine(prev_hitpoint,prev_point_right,1,0,0.2) --Right
			DebugLine(prev_hitpoint,prev_point_right,1,0,0.2,0.35) --Right (transparent)

			DrawLine(prev_point_height_right,prev_point_depth_right,1,0,1) --Right (depth+height)
			DebugLine(prev_point_height_right,prev_point_depth_right,1,0,1,0.35) --Right (depth+height, transparent)


			DrawLine(prev_hitpoint,prev_point_left,1,0,0.2) --Left
			DebugLine(prev_hitpoint,prev_point_left,1,0,0.2,0.35) --Left (transparent)

			DrawLine(prev_point_height_left,prev_point_depth_left,1,0,0.2) --Left (depth+height)
			DebugLine(prev_point_height_left,prev_point_depth_left,1,0,0.2,0.35) --Left (depth+height, transparent)

		end

		--Check if tool is firing
		if GetBool("game.player.canusetool") and InputDown("usetool") and GetFloat("game.tool.supercutter.ammo") > 0 and #FindShapes("cutterboxVox",true) == 0 then
			if enableFire then
				local offset = Vec(-0.025,-0.60,0)
				SetToolTransform(Transform(offset))

				PlayLoop(laserSnd)
				local t = GetCameraTransform()
				local fwd = TransformToParentVec(t, Vec(0, 0, -1))
				local maxDist = 5
				local hit, dist, normal, shape = QueryRaycast(t.pos, fwd, maxDist)
				if not hit then
					dist = maxDist
				end

				local s = VecAdd(VecAdd(t.pos, Vec(0, -0.5, 0)),VecScale(fwd, 1.5))
				local e = VecAdd(t.pos, VecScale(fwd, dist))

				if hit then
					local cutterBoxRot = QuatLookAt({0,0,0},normal)
					local cutterBoxQuat = QuatEuler(-90, 0, 0)
					local cutterBoxRot = QuatRotateQuat(cutterBoxRot,cutterBoxQuat)
					local cutterBoxPos = e
					PlayLoop(hitSnd, e)

					ParticleType("smoke")
					ParticleColor(0.5,1,1, 0,0.2,1)
					ParticleGravity(0.1)
					ParticleEmissive(1, 0)
					ParticleAlpha(0.75, 0.0)
					ParticleRadius(0.2, 0.6)

					SpawnParticle(e, rndVec(0.5), 0.5, 2)
					cutterBoxEnts = Spawn("MOD/prefab/cutterbox.xml", Transform(cutterBoxPos,cutterBoxRot), false, true)
					SetFloat("game.tool.lasergunv2.ammo", math.max(0, GetFloat("game.tool.lasergunv2.ammo")-1))
					enableFire = false
				end
			else
				local offset = Vec(0.6,-0.90,0)
				SetToolTransform(Transform(offset))
			end
			fireTime = fireTime + dt
		else
			fireTime = 0
			enableFire = true
			local offset = Vec(0.6,-0.90,0)
			SetToolTransform(Transform(offset))
		end
	end
	local shapeList = FindShapes("cutterboxVox",true)
	local bodyList = {}
	for k,v in pairs(shapeList) do
		bodyList[v] = GetShapeBody(v)
	end
	if bodyList then
		for shape,body in pairs(bodyList) do
			local cutterJoint = FindJoint("cutterboxJoint")
			if HasTag(shape,"isCutting") then
				local scale = math.sin(GetTime()*5)*0.5 + 0.5
				SetShapeEmissiveScale(shape, scale)
			else
				SetShapeEmissiveScale(shape, 0)
			end
			if HasTag(shape,"isNew") then
				RemoveTag(shape,"isNew")
				SetTag(shape,"isCutting")
				SetTag(shape,"lifetime","0")
			elseif (tonumber(GetTagValue(shape, "lifetime")) > 120*(3/speed) and autoStop and GetJointMovement(cutterJoint) > 0) or (GetString("game.player.tool") == "supercutter" and InputDown("grab") and not autoStop) or clearAll then
			  	Delete(cutterJoint)
			  	Delete(shape)
			  	RemoveTag(shape,"isCutting")
			else
				local lifetime = tonumber(GetTagValue(shape, "lifetime"))
				SetTag(shape,"lifetime",tostring(lifetime+1))
			end
			if HasTag(shape,"isCutting") then
				SetJointMotor(cutterJoint,speed)
				SetJointMotorTarget(cutterJoint,360,speed)

				
				local cutterjoint = cutterJoint
				local cutterbox = body
				local bodyTransform = GetBodyTransform(cutterbox)
				local shapeTransform = GetShapeWorldTransform(shape)

				-- DebugCross(poofpoint)

				ParticleType("smoke")

				ParticleColor(1,1,1, 1,0.1,0.1)
				ParticleGravity(0.1)
				ParticleEmissive(1, 0)
				ParticleAlpha(0.75, 0.0)
				ParticleRadius(0.2, 0.6)

				local cuttingpoint = TransformToParentPoint(shapeTransform,Vec(0.2,radius/10, height/10))
				local cuttingrot = TransformToParentVec(shapeTransform, Vec(0, 0, -1))

				local fixed_shape_pos = VecAdd(shapeTransform.pos,QuatRotateVec(shapeTransform.rot,{0.2,0.2,0.1}))

				-- DebugLine(shapeTransform.pos, TransformToParentPoint(shapeTransform, Vec(0,0,-1)), 0, 0, 1)
				-- DebugLine(shapeTransform.pos, TransformToParentPoint(shapeTransform, Vec(0,1,0)), 0, 1, 0)

				-- DebugCross(cuttingpoint)
				-- DebugPrint(table.concat(cuttingpoint," "))

				local hit, dist, normal, shape = QueryRaycast(cuttingpoint,cuttingrot,depth/10)
				
				local hitpoint = VecAdd(cuttingpoint, VecScale(cuttingrot, dist+0.1))

				DrawLine(fixed_shape_pos,cuttingpoint,1,0,0.3)

				if hit then
					DrawLine(cuttingpoint,hitpoint,1,0.2,0.2)
					-- DebugPrint("Hit!")
					-- DebugPrint(dist)
					-- DebugCross(hitpoint)
					-- DebugLine(cuttingpoint,hitpoint)
					MakeHole(hitpoint, 0.2, 0.2, 0.2, true)
					MakeHole(hitpoint, 0.3, 0.3, 0.3, true)
					SpawnParticle(hitpoint, rndVec(0.5), 0.5, 2)
				end
			end
		end
	end
end

