pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- main functions
function _init()
	-- init music
	music(0)
end

function _update()
	if game_over then
		return 0	
	end
	--time 
	clock_update()
	-- update objects
	player_update()
	bullet_update()
	enemy_update()
	power_up_update()
	shake_update()
	emitters_update()
	bomb_update()
	-- process collisions
	bullet_cull()
	enemy_coll_backs()
	power_up_collbacks()
end

function _draw()
	if game_over then
		cls(2)
		print(
			"game over",
			-- note this is not centered lmao
			player.pos.x-(8),
			player.pos.y+(8)
		)
		return null
	end
	-- cls
	cls(0)
	-- draw map
	map()
	camera(
		player.pos.x-64+8+shake_offs.x,
		player.pos.y-64+8+shake_offs.y
	)
	-- draw game objects
	bomb_draw()
	player_draw()
	bullet_draw()
	enemies_draw()
	power_up_draw()
	emitters_draw()
	--ui
	ui_player_health()
	ui_player_bomb()
	dr_score()
	-- logging
	log_draw()
	--arc(player.pos.x,player.pos.y,8,0,0.5,7)
end


------- game states
game_over = false











----------collision-------
function collide(o, flag)
	local x1=o.pos.x/8
	local y1=o.pos.y/8
	local x2=(o.pos.x+7)/8
	local y2=(o.pos.y+7)/8
	
	local a = fget(mget(x1,y1),flag)
	local b = fget(mget(x1,y2),flag)
	local c = fget(mget(x2,y2),flag)
	local d = fget(mget(x2,y1),flag)
	
	if a or b or c or d then
		return true
	else
		return false
	end
end


function obj_collide(obj, other)
 if
  other.pos.x + 8 + 8 > obj.pos.x+8 and 
  other.pos.y +8 + 8 > obj.pos.y+8 and
  other.pos.x +8 < obj.pos.x+8+8 and
  other.pos.y +8 < obj.pos.y+8+8 
 then
  return true
 end
end







--------- clock stuff
clock={
	delta=0,
	prev_time=0
}
function clock_update()
	-- calculate delta time
	clock.delta = time() - clock.prev_time
	-- log current time
	clock.prev_time=time()
end









------ logging
logging = true
logging_size = 8
log_msgs={}
function log(msg) 
	log_msgs[#log_msgs+1] = msg
end
function log_draw()
	if logging == true then;
		if #log_msgs > 0 then
			for i=1, #log_msgs do
				print(
				log_msgs[#log_msgs-(i-1)],
				player.pos.x-64+8,
				(player.pos.y+64+3)-(8*logging_size)+(i*8)
				)
			end
		end
	end
end









------ math utilities
pi = 22/7

function rot_vec(vec, ang)
	local x=vec.x
	local y=vec.y
	local sina = sin(ang)
	local cosa = cos(ang)
	return {
		x=(x*cosa)-(y*sina),
		y=(x*sina)+(y*cosa)
	}
end

function deg2rad(deg)
	return deg * (pi/180)
end

function rad2deg(rad)
	return rad * (180/pi)
end

function norm_vec(vector)
 local length = sqrt(vector.x^2 + vector.y^2)
 local res = {x=0, y=0}
 if length > 0 then
  res.x = vector.x / length
  res.y = vector.y / length
 end
 return res
end

function lerp(a, b, t)
 return a + (b - a) * t
end


--------------
-->8
-- player stuff
-- player var
player={
	-- vars
	speed=2,
	sprite=71,
	-- states
	pos={x=64,y=64},
	health=3,
	dir=0,
	is_hit=false,
	sht_fwd=true,
	sht_dir={},
	bombs=2
}

function player_update()
	-- movement and reticle
	local o_pos = {x=player.pos.x, y=player.pos.y}
	if btn(0) then
		player.pos.x -= player.speed
		player.dir = 0
	elseif btn(1) then
		player.pos.x += player.speed
		player.dir = 1
	end
	if btn(2) then
		player.pos.y -= player.speed
		player.dir = 2
	elseif btn(3) then
		player.pos.y += player.speed
		player.dir = 3
	end
	-- collision env
	if collide(player, 0) then
		player.pos = o_pos
	end
	-- collision enemy
	for i=1, #enemies do
		if obj_collide(player, enemies[i]) then
			player_damage()
		end
	end
	-- shooting
	if btn(4) then
		if b_down_time < 0 then
			-- handle bullet down time
			b_down_time = b_rate
			-- calc bullet directions
			local b_dir = rot_vec(player.sht_dir, curr_ret_ang)
			local b_dir_a = rot_vec(b_dir, deg2rad(2))
			local b_dir_b = rot_vec(b_dir, deg2rad(-2))
			-- create the bullets
			create_bullet(player.pos.x, player.pos.y, b_dir)
			create_bullet(player.pos.x, player.pos.y, b_dir_a)
			create_bullet(player.pos.x, player.pos.y, b_dir_b)
			end
	end
	-- switch shooting direction
	if btnp(5) then
		if player.sht_fwd then
			player.sht_fwd = false
			ret_ang = 0.5
		else
			player.sht_fwd = true
			ret_ang = 0
		end
	end
	-- bomb use
	if(btnp(4) and btnp(5)) then
		create_bomb(player.pos.x, player.pos.y)
	end
	-- player invul
	player_invul_time -= clock.delta
end

function player_draw()
	-- draw player
	if player_invul_time > 0 then
		spr(player.sprite-1, player.pos.x, player.pos.y)
	else
		spr(player.sprite, player.pos.x, player.pos.y)
	end
	-- draw reticle
	dr_ret()
end
-- draw reticle
curr_ret_ang = 0
ret_ang = 0
function dr_ret()
	-- get correct perpendicular angle
	player.sht_dir = {x=0,y=0}
	if (player.dir == 0) then
		player.sht_dir.x = -1
	elseif player.dir == 1 then
		player.sht_dir.x = 1
	elseif player.dir == 2 then
		player.sht_dir.y = -1
	else 
		player.sht_dir.y = 1
	end
	-- lerp ret_ang
	curr_ret_ang = lerp(curr_ret_ang, ret_ang, 0.6)
	-- rotate vec 
	local final_ret_vec = rot_vec(player.sht_dir, curr_ret_ang)
	-- draw reticle
	spr(
		0,
		player.pos.x+(final_ret_vec.x*6),
		player.pos.y+(final_ret_vec.y*6)
	)
end

--------- player damage
player_invul_time = 0
function player_damage()
	if player_invul_time < 0 then
		shake()
		player.health -= 1
		player_invul_time = 3
		if player.health == 0 then
			game_over = true
		end
	end
end


------------- bullet stuff
bullets={}
b_spd = 4
b_down_time = 0
b_rate = 1/8
b_curr_i = 1

-- on start create intial bullets
for i=1, 20 do
	bullets[#bullets+1]={
		pos={x=-9000, y=-9000},
		dir={x=0, y=0},
		active=false
	}
end

function create_bullet(_x, _y, _dir)
	-- get bullet
	local curr_b = bullets[b_curr_i]
	-- set bullet initial vars
	curr_b.active = true
	curr_b.pos = {x=_x, y=_y}
	curr_b.dir = _dir
	-- iterate bullet index
	b_curr_i = b_curr_i + 1
	if b_curr_i > #bullets then
		b_curr_i = 1
	end
end

function bullet_update()
	-- bullet downtime 
	b_down_time -= clock.delta
	-- bullet update
	for i=1, #bullets do
		local b = bullets[i]
		if b.active then
			-- movement
			b.pos.x += b.dir.x * b_spd;
			b.pos.y += b.dir.y * b_spd;
			--collision
			for ei=1, #enemies do
			 local e = enemies[ei]
			 if obj_collide(b, e)  and e.active then
			 	b_cull_i=i
			 end
			end		
		end
	end
end

function bullet_draw()
	for i=1, #bullets do
		local b = bullets[i]
		if b.active then
			spr(93, b.pos.x, b.pos.y)	
		end
	end
end


---- process bullet collision
b_cull_i=-1
function bullet_cull()
	if b_cull_i != -1 then
		bullets[b_cull_i].active = false
		b_cull_i = -1
	end
end

--------------- power ups
power_ups = {}
----- create power ups
for i=1, 5 do
	power_ups[#power_ups+1] = {
		pos={x=0,y=0}, 
		p_type="",
		active=false,
		l_span=0
	}
end

-- power up functions
-- spawning vars
p_spn_rate = 10
p_spn_timer = p_spn_rate
p_spn_dist = 8*7
p_l_span = 13
function spn_p_ups_loop()
	-- iterate timer
	p_spn_timer -= clock.delta
	-- if is time then spawn
	if p_spn_timer < 0 then
		p_spn_timer = p_spn_rate
		for i=1, #power_ups do
			local p = power_ups[i]
			if p.active == false then
				-- create position
				local pos={
					x=(((rnd()*2)-1)*p_spn_dist)+player.pos.x,
					y=(((rnd()*2)-1)*p_spn_dist)+player.pos.y
				}
				-- choose type
				local _type = "health"
				if rnd() > 0.5 then _type ="bomb" end
				-- create power up
				p.pos = pos
				p.active = true
				p.p_type = _type
				p.l_span = p_l_span
				break
			end
		end
	end
end

p_up_colls = {}
function power_up_update()
	-- clear collbacks
	p_up_colls = {}
	-- spn power ups
	spn_p_ups_loop()
	-- main loop
	for i=1, #power_ups do
		local p = power_ups[i]
		if p.active then
			-- check collision
			if obj_collide(player, p) then
				p_up_colls[#p_up_colls+1] = p 
			end
			-- handle lifespan
			p.l_span -= clock.delta
			if p.l_span < 0 then p.active = false end
		end
	end
end


function power_up_draw()
	for i=1, #power_ups do
		local p = power_ups[i]
		if p.active then
			local s = 114 -- change correct sprite
			if p.p_type == "health" then
				s = 115 -- change correct sprite
			end
			spr(s, p.pos.x, p.pos.y)
		end
	end
end

function power_up_collbacks()
	for i=1, #p_up_colls do
		local p = p_up_colls[i]
		log("col")
		-- handle event
		if p.p_type == "health" then
			player.health += 1
			-- prevent too much health
			if player.health > 3 then player.health = 3 end
		else
			player.bombs += 1
			if player.bombs > 2 then player.bombs = 2 end
			log(player.bombs)
		end
		-- deactivate powerup
		p.active = false
	end
end





----------------------------bomb
bomb = { -- only one bomb
 active=false,
 pos={x=0,y=0},
 lifespan=0
}
function create_bomb(_x, _y)
	if bomb.active == false and player.bombs > 0 then
		-- deplete one bomb
		player.bombs-=1
		-- create bomb
		bomb.pos.x = _x
		bomb.pos.y = _y
		bomb.active = true
		bomb.lifespan=1
	end
end
function bomb_update()
	-- just delay lifespan
	if bomb.active then
		bomb.lifespan -= clock.delta
		if bomb.lifespan < 0 then
			-- if lifespan runs out
			-- bomb boom
			bomb.active = false
			bomb_boom()
		end
	end
end
b_flash_colors={
	8,8,8,
	0,0,0,
	9,9,9,
	0,0,0,
	10,10,10,
	0,0,0
} 
curr_flash_index = 0
function bomb_draw()
	if(bomb.active) then
		spr(114, bomb.pos.x, bomb.pos.y)
	end
	if(curr_flash_index > 0) then
		curr_flash_index -= 1
		cls(b_flash_colors[#b_flash_colors-(curr_flash_index-1)])
	end
end
function bomb_boom()
	--set bomb fx
	curr_flash_index = #b_flash_colors
	-- clear all enemies
	for i=1, #enemies do
		local e = enemies[i]
		e.active = false
	end
end



------------------ score
score = 00000

function add_score(_add)
 score+=_add
end

function dr_score()
	local scr_string = pad(tostr(score), 6)
	print(
	 scr_string,
	 player.pos.x - 8*6 - 3, 
	 player.pos.y - 8*6 + 4,
	 8
	)
end

function pad(string,length)
  if (#string==length) return string
  return "0"..pad(string, length-1)
end



-->8
-- enemies
-- enemies has slow-tough and fast-weak types
enemies={}
enemy_spd= 20/100
enemy_spd_fast = enemy_spd*3
-- start enemy pool
for i=1, 5 do
	enemies[#enemies+1]={
		--state
	 pos={x=0,y=0},
	 active=false,
	 health=3,
	 is_hit=false,
	 --props
	 sprite=64,
	 sprite_hit=65,
	 is_fast=false
	}
end

function activate_enemies()
	-- activate one enemy if avail
	for i=1, #enemies do
		local e = enemies[i]
		if e.active != true then
			-- pick enemy type
			local _is_fast = true
			if rnd() > 0.3 then
			 _is_fast = false
			end
			-- create enemy position
			local min_d = 8*2
			local d = 8*4
			local epos = {
				x=(rnd()*2)-1,
				y=(rnd()*2)-1
			}
			local epos_nrm = norm_vec(epos)
			local epos_scl = {
				x=player.pos.x+epos_nrm.x * (rnd(d)+min_d),
				y=player.pos.y+epos_nrm.y * (rnd(d)+min_d)
			}	
			e.pos = epos_scl
			e.active = true
			e.health = 9
			e.sprite = 64
			-- create faster enemies
			if _is_fast then
				e.is_fast = true
				e.health = 3
				e.sprite = 72
			end
			break
		end
	end
end

function enemies_draw()
	for i=1, #enemies do
		local e = enemies[i]
		if e.active then
			local sprite = e.sprite
			if e.is_hit then sprite+=1 end
			spr(
				sprite,
				e.pos.x,
				e.pos.y
			)
		end
	end
end

enemy_spawn_rate=1
enemy_timer=enemy_spawn_rate
function enem_spawn_loop()
	--create enemies
	if enemy_timer < 0 then
		activate_enemies()
		-- reset timer
		enemy_timer = enemy_spawn_rate;
	end
	--iterate timer
	enemy_timer -= clock.delta
end

function enemy_update()
	-- spawn enemies
	enem_spawn_loop()
	-- main update loop for enems
	for i=1, #enemies do
		local e = enemies[i]
		if e.active then
			-- handle speed
			local e_spd = enemy_spd
			if e.is_fast then e_spd = enemy_spd_fast end
			-- reset hit sprite
			e.is_hit = false
			-- get direction
			local dir=norm_vec({
				x=player.pos.x-e.pos.x,
				y=player.pos.y-e.pos.y	
			})
			-- move in direction
			e.pos={
				x=e.pos.x+(dir.x*e_spd),
				y=e.pos.y+(dir.y*e_spd)
			}
			-- flag for collision
			for bi=1, #bullets do
				local b = bullets[bi]
				if b.active then
					if obj_collide(b, e) then
						enemy_colls[#enemy_colls+1] = i
					end
				end
			end
		end
	end
end


enemy_colls={}
function enemy_coll_backs()
	-- for all enemies damage them
	for i=1, #enemy_colls do
		-- if health < 0 then die
		local e = enemies[enemy_colls[i]]
		-- set hit sprite
		e.is_hit = true		
		e.health-=1
		-- emit partices
		emit(e.pos.x, e.pos.y)
		-- handle death
		if e.health < 0 then
			e.active = false
			-- add score
			add_score(200)
		end
	end
	--reset flags
	enemy_colls={}
end

-->8
-- ui
function ui_player_health()
	for i=1, player.health do
		print(
			"♥",
			player.pos.x-(8*8)+4+(8*i),
			player.pos.y-(8*7)+4,
			8
		)
	end
end

function ui_player_bomb()
 for i=1, player.bombs do
		print(
		 "◆",
			player.pos.x+(8*8)+4-(8*i),
			player.pos.y-(8*7)+4,
			12
		)
	end
end

-->8
--fx

----------screen shake
shake_ints=6
curr_shake=0
shake_offs={x=0, y=0}
function shake()
	curr_shake = shake_ints
end

function shake_update()
	--lerp the intensity
	curr_shake = lerp(curr_shake, 0, 0.1)
	--create offset
	shake_offs.x=(rnd()*curr_shake)-2
	shake_offs.y=(rnd()*curr_shake)-2
end


-----------------------particles
emitters={}
curr_em_i = 1
-- create emitters
for i=1, 20 do
	-- create emitter
	local e = {
		pos={x=0,y=0},
		active=false,
		lifespan=0,
		particles={},
		sprite=91
	}
	-- create particles
	for ep=1, 5 do
		local party = {
			pos={x=0, y=0},
			active=false,
			dir={x=0,y=0},
			vel=0
		}
		e.particles[#e.particles+1]=party
	end
	emitters[#emitters+1]=e
end

function emit(_x, _y)
	-- get available emitter
	local e = emitters[curr_em_i]
	-- set emitter position
	e.pos = {x=_x, y=_y}
	-- activate emitter 
	e.active = true
	e.lifespan = 0.2
	-- activate all particles
	for i=1, #e.particles do
		local p = e.particles[i]
		p.active = true
		p.pos = {x=0, y=0}
		p.vel = rnd()*5
		p.dir={
			x=(rnd()*2)-1,
			y=(rnd()*2)-1
		}
	end			
	--iterate emitter index
	curr_em_i += 1
	if curr_em_i > #emitters then curr_em_i = 1 end
end

function emitters_update()
	for i=1, #emitters do
		local e = emitters[i]
		if e.active then
			-- handle lifespan
			e.lifespan -= clock.delta
			if e.lifespan < 0 then e.active = false end
			for ep=1, #e.particles do
				local party = e.particles[ep] 
				-- lerp velocity to zero
				party.vel = lerp(party.vel,0,0.3)
				-- move particle
				party.pos.x += party.dir.x*party.vel
				party.pos.y += party.dir.y*party.vel
			end
		end
	end
end

function emitters_draw()
	for i=1, #emitters do
		local e = emitters[i]
		if e.active then
			for ep=1, #e.particles do
				local party = e.particles[ep]
				if party.active then
					spr(
						e.sprite,
						e.pos.x+party.pos.x,
						e.pos.y+party.pos.y
					)
				end 
			end
		end
	end
end

__gfx__
00000000d66666656665d6650666d660055101500000000005510551010101110550055055000555050000009900099010100000011100000000000000000000
000000006d6dddd56d6566d66d5d6d1556d1056d00ddd0d050105010100010005dd15dd199505999995054502290222901001110100010100060006000d000d0
000000006dddddd5dd556d6d65dddd555dd105d10511110111001100100000005dd15dd199404999994049401290122210101110100010000656065605050505
000700006ddddd55ddd56ddd6ddddd15111101100511111010001000000010000111011144000444040004500000011100000110011101100d1d0d1d00100010
000000006dd5ddd5dd556ddddddddd55050050050511110105110511011101015515550500555000005500142009900001110000000010010000000000000000
0000000066ddddd5ddd566dd6dddd5155dd00550001111105010501010001000dd15dd150599950505995000121119021111101000000110060006000d000d00
000000006dddddd55d556dd561515151561056d1050101001100110000001000dd15dd1509999904099950401011120111111010101100006560656050505050
0000000055555550055055500010101001005dd1001010001000100010000000111011000044400000444000000000000111000000000110d1d0d1d001000100
aaaaaaaaaa9aaaaa49a9a9a94949494994449444010014416666666666666666666665665d5d0500050000000000000000100100010b0010300100b041400441
aaaaaaaaa949aaaa99949aaa999499444444a494144144446666666666666d666666d6d66d6056d050500d000050001000000000003b300110b00b3b19914994
aaaaaaaaaa9aaaa999a9a9a9494494994445994441004444665666666656d5d6656d666d65656d650010d050010100003001001000b3b00040b0034341444994
aaaaaaaaaaaaaaaaaa99949a4499444995594915001104416666666666665656d6d66666d5d56d650000501000000000010101010b3b3b0303b3004004114441
aaaaaaaaaaaaaaaa9a49a9a9499449444444a990014410006666666666666666d6d666560565d5d500d0100d000000000000000013b4b3003b4b300001441444
aaaaaaaaaaaaa9aa9494aa9a9494949944449449144441406666d66666d66666666666d6d66655500d0500050100050010003000014441001444103014994194
aaaaaaaaa9aaaaaa9949aa9949944949444594491444410466666666656566d666d66d6d66d65060500010010000101000101000001410310141013114994149
aaaaaaaaaaaaaaaaa99aa99444994499941945590144104066666666656566666d6d6666d6060656100010500000000001000001100400100040004041441094
bbbbbbbbb3bb03bb03b3000003000b000000030000100000cccccccccc4cccccb44cc4cc4444c444444444444444444405544454000000100000000000000000
bbbbbbbb3bbb3bbb3bb3033003b330000013000000000000ccccccccccc4cccb4444c4c344444444444444444444445454404444010040000000000000000000
bbbbbbbb0bbbbbbb0bbb3bb30b3b00030131000300010010cccccccccccbcccc4444cc4cb4444434444444444444444444445004000000040000000000000000
bb3bbbbbb33bbbb30334bb3003b303000310030000010001cccccccccccbcc4cc44cbccc44444444444444445444444444454445504005010000000000000000
bbbbbbbbbbbbbbbb3bb333b30000000b0000000101000000cccccccc4cccc4ccccc44ccc44444444444444444444444441444444041400000000000000000000
bbbbbbbbbbbbbbbb3bb3bbbbb0303b030010010310000000ccccccccccccc4cc44c4444b444444cc444444444444444454455540000000500000000000000000
bbbbbbbbbb3bbbb33b3b3bb33000b3033000100000000100cccccccccbcccbccc4cc44cc44434444444444444444544444044414005004000000000000000000
bbbb3bbb03bbbb3043033b34030330300303000000000100cccccccccbccccccbcc3ccc444444444444444444444444444444445040100000000000000000000
44445444144444410111111100000000444044401040404011001010001000100000000000000000000000000000000000000000000000000000000000000000
44444444000000000011111100100010444144414140104111011010100010000000000000000000000000000000000000000000000000000000000000000000
44441444444441440000000000000000444144414141404111011010001000100000000000000000000000000000000000000000000000000000000000000000
01110110000000001111101110001000444144414041404111011010100010000000000000000000000000000000000000000000000000000000000000000000
14444444414444441111001100000000444114504041414000011010001000100000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000100010444144414041411011011010100010000000000000000000000000000000000000000000000000000000000000000000
54444444444114441111111100000000444144414140414011011010001000100000000000000000000000000000000000000000000000000000000000000000
01111111000000000000000010001000541144404010404011000010100010000000000000000000000000000000000000000000000000000000000000000000
00066600000000000000000000444000a009d100000a0b00000450000004500000077070000009400099499000000000000000000000000000000000006d5100
0065556000666000000000000409040000a2221000f4b000000f9000000f90000006d060070094000004a4000000000000000000000000000000000007000010
005000500655560000000000049094000f2424219944490000edd20000bdd300006d50600a094400000494500000000000000000000000000000000060000001
0009090005000504000000000090900000909090040904000e8dd2000b3dd300065dd6550900ff100000555d00000000000000000000000000000000d0000005
04666660069096400000000004d4d400a0098900009890004e46665543466655065dd140090022100506dd5d000000000000000000000000000000005000000d
402ddd2042ddd2000000000004656400900d22100b333b0000f8229000f333900455500004f22f210590d5590000000000000000000000000000000010000006
004ddd4000dd6040000000000955590049d29d2009b3b9000020200000b0300000505000040d22d1050060500000000000000000000000000000000001000070
0006060006000000000000000010100040d22d2100404000080020000b003000004040000401222105006060000000000000000000000000000000000015d600
15d561655555555501d15d1007ffff100077710000000000000000000000000000000000000000000000000000000000000000000000000000000000cccccc6c
15d5656566666666156666517f0151f10766651000000000000000000000000000000000000000000000000000000000000000000004400000000000cc77cccc
1565657515555555d655d56d6f5606f57671765100000000000000000000000000000000000000000000000000009000000000000049940000000000c6cc6ccc
15d565656666666666d0056d5f0565f1661516610000000000000000000000000000000000000000000000000099a000000000000497a9400014d9906cccc6cc
15d1656555551555d6500d666f5606f5766d66510000000000000000000000000000000000000000000000000009990000000000049aa940114daa78cc6ccccc
15d57565ddddddd6d65d556d5f0565f1666d66110000000000000000000000000000000000000000000000000009000000000000004994000014d980ccccc77c
15d575655555555515666651fdffffdf7667665100000000000000000000000000000000000000000000000000000000000000000004400000000000c7cc6cc6
01d565651111111001dd6d100111111015555510000000000000000000000000000000000000000000000000000000000000000000000000000000006c6ccccc
a999999a0a997a900a999990949499aa00000a000a00000000999900282828281988889200000000000000000000000000000000000000000000000000000000
94444449a1555519a1555559d545d5d5000009000900000009dddd9099999999d988889800000000000000000000000000000000000000000000000000000000
9494949a9544445a9114a4496545656509444900094449000d555540888888881988889200000000000000000000000000000000000000000000000000000000
5555555549a799a55999ad956545656504555900065554000d54544088888888d988889800000000000000000000000000000000000000000000000000000000
a4444445454545454555915499aa999409445d00065444000d545440888888881988889200000000000000000000000000000000000000000000000000000000
94949494454545455449144545d2d15104dddd000645590006dddd4099999999d988889800000000000000000000000000000000000000000000000000000000
49999994154545411559155145686d5d05666d000ddddd0004500540d1d1d1d11988889200000000000000000000000000000000000000000000000000000000
94444449011111100119111045686d5d06000600060006000600006010101010d988889800000000000000000000000000000000000000000000000000000000
00d0a0d00019910000078000022002200a9999a00a9999a009444440000aa10000000000000000000000000011111111000000000000000000000000aaaacccc
0d00a0000497a940006e280027822e82a444444a494444909dfffff800a99a1000000000000000000000000011111111000000000000000000000000a0aa0c0c
5d09790d197a4a9106ee22802e8888829a9999a949455490466666800a9119a100000000000000000000000011111111000000000000000000000000a0aa0c0c
0509790049a4aa947eee222e18882821a444444a494444904fffff800a91094100000000000000000000000011111111000000000000000000000000aaaacccc
5d00900549a9aa94e888111802828220555555554a9999a04666685000a99a1000000000000000000000000011111111000000000000000000000000b0bb0808
05d020d019aa97910e8811800128221074707447915585104ffff8d0000a910000000000000000000000000011111111000000000000000000000000bb0b8008
005020d0049a794000e8180000122100656665569566e6d09d668d6000a9410000000000000000000000000011111111000000000000000000000000b00b8808
0000200000199100000e2000000110005d4d4dd50944e4900944445000a9400000000000000000000000000011111111000000000000000000000000bbbb8888
000000000000005252c1d1525200000000000073c045c07300000000000073000000000000734573000000705005101030505030101005700000000000d05192
82626272727272829251d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000525200000000000000000073c073000000730000734573000073000073c073000070500505105050505050501005507000000000d05192
828282828282829251d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000330000000000000000000000007345730000c0000073457300000000007050500505305060707060503005055070000000005192
9292929292929251d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000
0000000000000000000000332333000000000000000000000000c000000073000000c0000000000070501515250550533636365360501505055070000000d051
51515151515151d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000003323132333000000000000000000000073000000000000007300000070251515151515256053363636536050050505507000000000d0
d0d0d0d0d0d0d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000033231307132333000000000000d0d0d0000000000000000000000000705005101030505050700000000070603005050550700000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000003323132333000000000000d0c0c0c0d00000000000000000000070500505304050607070000057677070503005055070000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000332333000000000000d0c0515151c0d000000000000000000070500505505060700000000070707030401005507000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000033000000000000d0c0514141415151c0c0d000000000000070500505405053363636537050301010101005700000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000d0c0c0c05141313131414151c0c0c0d0d000000070500505305053363636537030251515151525000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000033000000000000000000d0c051413121212131414151d0d0000000000070500505104050607070706030052515155070000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000331333000000000000d0c0c0514131211101112131414151d0000000000070500505101030506060605010050550507000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000331303133300000000d0c0c05141312111010101112131414151d00000000000705005101010305050503010055070700000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000003313030703133300000000d0c05141312111010101112121314151c0c0d0000000007025151515151515151515257000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000332313031323330000330000c05141312121110111212121314151c0d000000000000000705015151515155070000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000332313233300003313330000c051413121212121212131414151d00000000000000000007050151515507000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000332333000033130713330000c0514131313131313141f151c0000000000000000000000070505050700000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000330000000023132300000000c0514141414141415151c000000000000000000000000000707070000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000002300000000d0d0c0515151515151c0000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0c0c0c0c0c000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000d0d0d0d00000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000001b1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000001b1a1a1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000001b1a19191a1b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000001b1a191919191a1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000001b1a1918171718191a1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000001b1b00000000001b1a19181717171718191a1b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000001b1a1a1b001b1b1b1b1a19181818181818191a1b00000003010101010101010101010101010300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000001b1a19191a1b1b1b1b1b1b1a1919191919191a1b0000000002020202030303030303020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001b1b1a191818191a1b000000001b1a1a1a1a1a1a1b000000000701017005050505050505050570030307000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000001b1a19191a1b00001b1b00001b1b1b1b1b1b00000000070502050507740707660707740705050205070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000001b1a1a0000001b1c1c1b0000000000000000000007050503050700000007680700000007050105050700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000252500001b1b001b1b1c1c1c1c1b1b000000000007070000070550070044000007680700004500075005070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000251c1c25000000000000000000000000000000000705050700000750000000000705680507000000005007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000251c1d1d1c2500000000001a1a1a1a1a00000000070503030507000750070000070505680505070000075000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000251c1c2500000000001a19191919191a000000000705050700000750000000000705680507000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000252525250000000000252500000000001a191818181818191a0000000007070000070550070000000007680700000000075000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000251e1d1e252500000000251c252500001a1918181616161618191a0000000000000705055006070000000068000000000705500d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000251e2222221e1d00002525251c252525251a1918161616161618191a0000000007070705055005060700000068000000070605500d0d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000025251e22212121221e1c252525251c00000000001a191818181818191a0000001c0707070707055070050607000068000007060570500d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001c1c1d1e222121202121221e1c000000251c00000000001a19181818191a000000000707070000000552515151515151515151515151515200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000001c1c1e22212121221e1c00000000251c1c00000000001a1919191a000000000707000000000007050507070700000000000d0d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000001c1e2222221e1c0000000000251c1c0000000000001a1a1a0000001c0707000000000000000000000000000000000d1515150d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000001c1e1d1e1c000000000000251c1c2500000000001b1b00000007070000000000000d0d0d00000000000000000d15292929150d000000000000000d0d0d0d0d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001c1c1c000000000000251c1d1e1c25000000001b1b000000000000000000000d1515150d0000000000000d152928282829150d00000000000d1515151515150d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000002525000000000000251c1e22221d1c251c1b1b1b1b1b1c1c1c1c0000000d0d152c2c2c150d0000000d0d1529282726272829150d0000000d15292929292929150d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000250000000000251c1e222121221d1c0d000000000000001c0d1c000d15152c2b2a2b2c150d0d15150d1529282726272829150d0d0d0d152928282828282829150d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000025250000000000251c1e22221e1c1c00000000000034000000000d152c2c2a2c2a2c2a2c150d0d0d0d0d1529282828291515150d151529282627272726262829150d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000251d1c250000000000251c1e1e1c00000000000000353435000000000d0c152c2b2a2b2c150c00000000000d15292929150d0d0d0d0d152928262626262626262829150d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000251c1e1e1c250000000000001c1c00000000370000363554353600003700000c152c2c2c150c000000070700000d1515150d0000000d15292826266226262626272829150d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000251c1e22221e1c25000000000025000000003754370036013601360037543700000c1515150c0000000705050700000d0d0d000000313131313131313131262626272829150d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000251d1e222222221e1c25000000000000000000000c0000540135015400000c000000000c0c0c00000007055151050700000000000000000d15292827266226262626262829150d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000025251c1e1e1e1e1c25000000000000370c37000037000070000000700000370000000000000000075251515151515151515200000000000015292826262626272726262829150d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010f011f210151f0151f0151f0151f0151e0151c0151a0151901519015190151901519015190151b0151c0151d0151e01520015210152101521015200151e0151d0151c0151c0151c0151e0151f0152101521015
011000001f0552005521055220552305525055280552805526055230552205521055210552105521055200552205523055230552605528055290552b0552a0552a05529055270552605522055220552205522055
0110011e0505505055050550505505055050550505507055090550b0550c0550a0550805507055070550705507055080550b0550c0550a0550805507055070550605506055050550505505055050550505505055
0110011f1475014750147501475217752147501775018750147501775014750177521475214750147501775014750147501475018750147501b750147511b7511475017750147501875014750187501475014750
001001200261003610036100261002610026100361003610026100261002610026100261002610026100261002610036100361003610036100361003610036100361003610046100461004610046100561004610
00040000085531055324553245531f5530c5530155300553006030060300603006030060300603006030060300603016030060301603026030360300003000030000300003000030000300003000030000300003
00040000026100b610196202a630276200d6100461001610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000000042c062330643306733065320043100431004310040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004
0004000024640382511d2411123104211022110010001200002000000000100001000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
02 01020304
00 01020344
00 05064344
00 07424344
00 08424344
00 48424344

