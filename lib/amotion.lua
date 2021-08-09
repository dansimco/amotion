--- Amotion.
-- Add ansible/cycles style arc modulation to your scripts
--
-- @classmod Amotion
-- @release v1.0.0
-- @author dansimco (https://github.com/dansimco)
-- Based on Arcify by Mimetaur (https://github.com/mimetaur)

local util = require "util"
local tabutil = require "tabutil"

local Amotion = {}
Amotion.__index = Amotion

local LFO_SR = 3 -- clock speed for calculating position
local FPS = 24

local exclude_list = { -- Don't auto-add these params
	"output_level",
	"input_level",
	"monitor_level",
	"engine_level",
	"softcut_level",
	"tape_level",
	"headphone_gain",
	"rev_eng_input",
	"rev_cut_input",
	"rev_monitor_input",
	"rev_tape_input",
	"rev_return_level",
	"rev_pre_delay",
	"rev_lf_fc",
	"rev_low_time",
	"rev_mid_time",
	"rev_hf_damping",
	"comp_mix",
	"comp_ratio",
	"comp_threshold",
	"comp_attack",
	"comp_release",
	"comp_pre_gain",
	"comp_post_gain",
	"cut_input_adc",
	"cut_input_eng",
	"cut_input_tape",
	"clock_tempo",
	"link_quantum",
	"clock_crow_out_div",
	"clock_crow_in_div"
}

local function redraw_arc (self)
	if self.dirty then
		self.ar:all(0)
		-- Draw Position
		for i = 1, 4 do
			local arc_pos = self.position[i] * 64 + 32
			local led = math.ceil(arc_pos)
			local diff = led - arc_pos
			local side_led = math.ceil(diff * 15)
			self.ar:led(i, led - 1, side_led)
			self.ar:led(i, led, 15)
			self.ar:led(i, led + 1, 15 - side_led)
		end
		self.ar:refresh()
	end
end

local function interpolate (x, wf)
	local y = 0
	if wf == 1 then -- tri
		y = math.abs( ( x * 2 - 0.5 ) % 2 - 1 ) * 2 - 1
	end
	if wf == 2 then -- sin
		y = math.sin( x * 2 * math.pi )
	end
	if wf == 3 then -- ramp
		y = ( 1 - ( x + 0.25 ) % 1 ) * 2 - 1
	end
	return y
end

function Amotion:new (arc_obj)
	local am = {}
	setmetatable(am, Amotion)

	am.ar = arc_obj or arc.connect()

	am.position = { 0.01, 0.01, 0.01, 0.01 }
	am.value = { 1, 1, 1, 1 }
	am.velocity = { 0, 0, 0, 0 }
	am.scale = { 1, 1, 1, 1 }
	am.wave = { 3, 3, 3, 3 }
	am.delta = { 0, 0, 0, 0}
	am.acceleration = 5
	am.fps = FPS
	am.dirty = true

  -- params
  local map_param_ids = {false}
  local map_param_names = {"none"}
  local pl = params.params
	for k,v in pairs(params.params) do
	  local cnt = tabutil.contains(exclude_list, v.id)
	  if cnt ~= true then
	    if (v.id and v.t == 1) or (v.id and v.t == 3) then
	      table.insert(map_param_ids, v.id)
	      table.insert(map_param_names, v.name)
	    end
	  end
  end

  print("Arc mapping available for:")
  tabutil.print(map_param_names)
 
 	for i = 1, 4 do
	 	params:add_option("m_arc" .. i .. "_target", "Arc " .. i .. " target", map_param_names)
	  params:add_number(
	    "m_arc_" .. i .. "_scale", -- id
	    "Arc " .. i .." amount", -- name
	    0, -- min
	    100, -- max
	    0 -- default
	    )
	  params:add_option("m_arc_" .. i .. "_wave", "Arc " .. i .. " wave", {"tri", "sin", "saw" })
 	end


	function redraw_clock_callback ()
		while true do
			redraw_arc(am)
			clock.sleep(1 / am.fps)
		end
	end

	function lfo_clock_callback()
		while true do
			for i = 1, 4 do
				am.position[i] = am.position[i] + am.velocity[i]
				if am.position[i] > 1 then
					local overage = am.position[i] - 1 
					am.position[i] = 0 + overage
				else if am.position[i] < 0 then
						am.position[i] = (1 - am.position[i])
					end
				end
				local long_val = interpolate(am.position[i], params:get("m_arc_" .. i .. "_wave")) * params:get("m_arc_" .. i .. "_scale")
				local new_val = math.ceil(long_val * 1000) / 1000
				am.delta[i] = util.round((new_val - am.value[i])*100) / 100
				am.value[i] = new_val
				local target_param_id = map_param_ids[params:get("m_arc" .. i .. "_target")]
				if target_param_id ~= false then
					params:delta(target_param_id, am.delta[i])
				end

			end
			clock.sleep(LFO_SR / 1000)
		end
	end

	local rcid = clock.run(redraw_clock_callback)
	local lfocid = clock.run(lfo_clock_callback)

  function am.ar.delta(n, delta)
      am:update(n, delta)
  end

	return am
end

function Amotion:update (n, delta)
	self.velocity[n] = self.velocity[n]+delta / (1000000 / self.acceleration)
end

function Amotion:map_param (param, i)

end

return Amotion
