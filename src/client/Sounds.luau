--!strict
-- 効果音（Roblox に最初から入っている rbxasset の音を使う。読み込めなくてもゲームは止まらない）

local SoundService = game:GetService("SoundService")

local Sounds = {}

local DEFINITIONS = {
	click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.35, speed = 1.1 },
	sale = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 1.2 },
	reward = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, speed = 0.9 },
}

local cache: { [string]: Sound } = {}

local function get(name: string): Sound?
	if cache[name] then
		return cache[name]
	end
	local def = DEFINITIONS[name]
	if not def then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "SFX_" .. name
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.speed
	sound.Parent = SoundService
	cache[name] = sound
	return sound
end

function Sounds.Play(name: string)
	local sound = get(name)
	if sound then
		pcall(function()
			SoundService:PlayLocalSound(sound)
		end)
	end
end

return Sounds
