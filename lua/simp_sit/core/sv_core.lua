local pitchOffset = Angle(270, 0, 0)
local optimalOffset = Vector(0, 0, 5)
local optimalOffsetHeight = Vector(0, 0, -20)

concommand.Add("sit", function(ply)

	if not SIMPSit.Cooldown[ply:SteamID64()] then
		SIMPSit.Cooldown[ply:SteamID64()] = 0
	end

	if SIMPSit.Cooldown[ply:SteamID64()] > CurTime() then return end

	-- We add a minor cooldown as spamming could cause issues, there's a lot of tracing involved.
	SIMPSit.Cooldown[ply:SteamID64()] = CurTime() + 0.5

	local eyeTrace = ply:GetEyeTrace()
	local pos = eyeTrace.HitPos
	local ent = eyeTrace.Entity
	local pitch = (eyeTrace.HitNormal:Angle() - pitchOffset).pitch

	local canSit, optimalRotation = SIMPSit.Core.CanSitHere(ply, pos, pitch, ent)

	if not canSit then
		if SIMPSit.Config.Debug then
			print("[SIMPSIT]", ply, "attempted to sit but could not find a suitable location.")
		end
		return
	end
	SIMPSit.Core.Sit(ply, pos, ent:IsWorld() and NULL or ent, optimalRotation, pitch)
end)

-- Do a spin around the user and find the best angle to sit them at
-- This is some head bashing math that makes me want to kill myself.
function SIMPSit.Core.OptimalRotation(pos)
	-- We don't want them blocking the optimal rotation
	local allPly = player.GetAll()
	local furthest

	for i=0, 360, 45 do
		local rad = math.rad(i)
		local dir = Vector(math.cos(rad), math.sin(rad), 0)
		-- Build a ring of positions around the point of wanting to sit
		local startPos = pos + dir * SIMPSit.Config.CircleBuffer + optimalOffset

		-- Trace those rings down around the position
		local trace = util.QuickTrace(startPos, optimalOffsetHeight, allPly)

		if SIMPSit.Config.Debug then
			if not trace.Hit then
				debugoverlay.Line(startPos, startPos + optimalOffsetHeight, 5, Color(0, 255, 0), true)
			else
				debugoverlay.Line(startPos, startPos + optimalOffsetHeight, 5, Color(255, 0, 0), true)
			end
		end
		-- End of debugging

		-- Skip if it hit something
		if trace.Hit then continue end

		-- Trace backwards to see if it hits anything, and use that to get the furthest position
		local traceToStart = util.QuickTrace(startPos + (-optimalOffset*1.2), (dir * -(SIMPSit.Config.CircleBuffer)), allPly)
		traceToStart.rotation = i
		if SIMPSit.Config.Debug then
			debugoverlay.Line(startPos + (-optimalOffset*1.2), startPos + (-optimalOffset*1.2) + (dir * -(SIMPSit.Config.CircleBuffer)), 5, Color(0, 0, 255), true)
		end

		if not furthest then
			furthest = traceToStart
			continue
		end

		if furthest.HitPos:Distance(furthest.StartPos) < traceToStart.HitPos:Distance(traceToStart.StartPos) then
			furthest = traceToStart
		end
	end

	if not furthest then
		return false
	end
	
	return furthest.rotation
end

function SIMPSit.Core.CanSitHere(ply, pos, pitch, ent)
	print(ply, pos, pitch, ent)
	-- Check how far away they are
	if ply:GetPos():DistToSqr(pos) > SIMPSit.Config.MaxDistance then return false end
	-- No sitting on players anymore :)
	if ent:IsPlayer() then return false end
	-- Pitch, to ensure they don't sit on the side of a wall
	if pitch > SIMPSit.Config.MaxPitch then return false end
	if pitch < -SIMPSit.Config.MaxPitch then return false end

	-- Backwards compatibility with old sit system
	local canSit, sitRotation = hook.Run("ShouldAllowSit", ply, pos, pitch, ent)
	if not (canSit == nil) then
		return canShit, sitRotation or SIMPSit.Core.OptimalRotation(pos) or 0
	end

	local rotation = SIMPSit.Core.OptimalRotation(pos)
	if not rotation then return false end

	return true, rotation
end

-- ply, the player sitting
-- pos, the position they're sitting at
-- ent, the entity they're sitting on (to parent) or NULL
-- rotation, the rotation they're sitting
-- pitch, their pitch.
function SIMPSit.Core.Sit(ply, pos, ent, rotation, pitch)
	local chair = ents.Create("prop_vehicle_prisoner_pod")
	chair.SIMPSit = true

	if IsValid(ent) and (not ent:IsWorld()) then
		chair:SetParent(ent)
	end
	chair:SetModel("models/nova/airboat_seat.mdl")
	chair:SetPos(pos - optimalOffset)
	local ang = Angle(0, rotation - 90, 0)
	ang:RotateAroundAxis(ang:Forward(), pitch)
	chair:SetAngles(ang)
	chair:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
	chair:Spawn()
	chair:Activate()
	chair:SetVehicleClass("Seat_Airboat")
	if not SIMPSit.Config.Debug then
		chair:SetNotSolid(true)
	end

	local phys = chair:GetPhysicsObject()
	if IsValid(phys) then
		phys:Sleep()
		phys:EnableGravity(false)
		phys:EnableMotion(false)
		phys:EnableCollisions(false)
		phys:SetMass(1)
	end
	
	if not SIMPSit.Config.Debug then
		-- The fun stuff
		chair:SetColor(Color(0, 0, 0, 0))
		chair:SetRenderMode(RENDERMODE_TRANSALPHA)
		chair:DrawShadow(false)
	end
	-- Steal this shit from the original addon
	chair.PhysgunDisabled = true
	chair.m_tblToolsAllowed = {}
	chair.customCheck = function() return false end -- DarkRP plz
	chair:SetCollisionGroup(COLLISION_GROUP_WORLD)

	-- Ply info
	ply:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	chair.SIMPIdealLeaveSpace = ply:GetPos()
	ply:EnterVehicle(chair)
end


hook.Add("PlayerLeaveVehicle", "SIMPSit:Remove", function(ply, chair)
	if not IsValid(chair) then return end
	if not chair.SIMPSit then return end

	local idealLeaveSpace = chair.SIMPIdealLeaveSpace

	chair:Remove()

	-- If they're close to their original sit position, we can jus put them back where they started. This prevents some minor alt+e abuse to get pats walls ect.
	if idealLeaveSpace:DistToSqr(chair:GetPos()) < SIMPSit.Config.MaxIdealLeaveDistance then
		ply:SetPos(idealLeaveSpace)
	end
end)

-- Unsure if PlayerLeaveVehicle is called internally when a user leaves, but better safe than sorry?
hook.Add("PlayerDisconnected", "SIMPSit:Remove", function(ply)
	local chair = ply:GetVehicle()

	if not IsValid(chair) then return end
	if not chair.SIMPSit then return end

	chair:Remove()
end)