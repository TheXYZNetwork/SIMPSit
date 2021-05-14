hook.Add("PlayerButtonDown", "SIMPSit:KeyPress", function(ply, button)
	if (not game.SinglePlayer()) and (not IsFirstTimePredicted()) then return end
	-- They're already in some kind of vehicle.
	if IsValid(LocalPlayer():GetVehicle()) then return end
	-- Check the button they're pressing is atleast 1 of the buttons we're looking for
	if not table.HasValue(SIMPSit.Config.ButtonsToSit, button) then return end

	-- Confirm they're pressing all the buttons we're looking for
	-- Because this is client side we could in theory allow it to be user configured? Maybe something for future me to do.
	for k, v in ipairs(SIMPSit.Config.ButtonsToSit) do
		if not input.IsButtonDown(v) then return end

		if SIMPSit.Config.Debug then
			print("[SIMPSIT]", v, "is currently pressed")
		end
	end

	-- Tell the server we want to sit
	RunConsoleCommand("sit")
end)