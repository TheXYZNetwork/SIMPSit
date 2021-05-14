-- Enable debug info.
-- This includes a bunch of trace lines when 'developer 1' is enabled, some prints for both server and client, and the seat not getting set invisible.
SIMPSit.Config.Debug = false

-- The max distance someone can be from the point they want to sit
SIMPSit.Config.MaxDistance = 10000

-- The max pitch (slant) angle you can sit on.
SIMPSit.Config.MaxPitch = 10

-- The buffer around the position to build the circle to calculate the facing angle
SIMPSit.Config.CircleBuffer = 15

-- How far away from the ideal leave location before it becomes invalid
SIMPSit.Config.MaxIdealLeaveDistance = 50000

-- The keys that need to be pressed in order to trigger a sit attempt: https://wiki.facepunch.com/gmod/Enums/KEY
SIMPSit.Config.ButtonsToSit = {
	KEY_LALT,
	KEY_E
}