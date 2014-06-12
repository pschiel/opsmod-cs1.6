#include <amxmod>
#include <superheromod>

// cvars:
// ops_level 0
// ops_health 1000
// ops_healthregen 50
// ops_armor 1000
// ops_cooldown 1
// ops grenadetimer 1
// ops_powerusage 100
// ops_distance 150
// ops_medipackhp 1000
// ops_powermult 20.0
// ops_speed 350

#define AMMOX_FLASHBANG 11
#define AMMOX_HEGRENADE 12
#define AMMOX_SMOKEGRENADE 13

new gHeroName[]="ops"
new bool:gHasOPSPower[SH_MAXSLOTS+1]
new gOPSUsage[SH_MAXSLOTS+1]
new gOPSPowerSound[] = "player/sprayer.wav"
new Float:gOPSPowerVolume = 0.7
new gPlayerMaxHealth[SH_MAXSLOTS+1]

public plugin_init()
{
	register_plugin("SUPERHERO ops", "1.0", "ops")
	shCreateHero(gHeroName, "ops", "+Power key to use MEDIPACK", true, "ops_level")
	register_srvcmd("ops_init", "ops_init")
	shRegHeroInit(gHeroName, "ops_init")

	// register cvars
	register_cvar("ops_level", "0")
	register_cvar("ops_health", "1000")
	register_cvar("ops_healthregen", "50")
	register_cvar("ops_armor", "1000")
	register_cvar("ops_powerusage", "100")
	register_cvar("ops_cooldown", "1")
	register_cvar("ops_distance", "150")
	register_cvar("ops_medipackhp", "1000")
	register_cvar("ops_powermult", "20.0")
	register_cvar("ops_speed", "250")

	// collect max healths
	register_srvcmd("ops_maxhealth", "ops_maxhealth")
	shRegMaxHealth(gHeroName, "ops_maxhealth")
	shSetMaxSpeed(gHeroName, "ops_speed", "[0]")

	// set values
	shSetMaxHealth(gHeroName, "ops_health")
	shSetMaxArmor(gHeroName, "ops_armor")
	shSetShieldRestrict(gHeroName)

	// register events
	register_event("ResetHUD", "event_spawn","b")
	register_event("CurWeapon", "event_weapon","be","1=1")
	register_event("Damage", "event_damage", "b")
	register_event("AmmoX", "event_ammox", "b")
	register_srvcmd("ops_kd", "ops_kd")
	shRegKeyDown(gHeroName, "ops_kd")

	// loop function
	set_task(1.0, "ops_loop", 0, "", 0, "b")
}

public ops_maxhealth(id)
{
	new id[6]
	new health[9]

	read_argv(1, id, 5)
	read_argv(2, health, 8)

	gPlayerMaxHealth[str_to_num(id)] = str_to_num(health)
}

public ops_loop()
{
	if(shModActive())
		for(new id = 1; id <= SH_MAXSLOTS; id++)
			if(gHasOPSPower[id] && is_user_alive(id))
				shAddHPs(id, get_cvar_num("ops_healthregen"), gPlayerMaxHealth[id])
}

public gunner_grenades(id)
{
	if(shModActive() && gHasOPSPower[id] && is_user_alive(id))
	{
		shGiveWeapon(id, "weapon_hegrenade")
		shGiveWeapon(id, "weapon_smokegrenade")
		shGiveWeapon(id, "weapon_flashbang")
	}
}

public ops_weapons(id)
{
}

public ops_reset(id)
{
	remove_task(id)
	gPlayerUltimateUsed[id] = false
	gOPSUsage[id] = get_cvar_num("ops_powerusage")
	set_user_footsteps(id, 1)
}

public ops_end(id)
{
	ops_reset(id)
	shRemHealthPower(id)
	shRemArmorPower(id)
	shRemSpeedPower(id)
	set_user_footsteps(id, 0)
}

public ops_init()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)
	read_argv(2,temp,5)
	new hasPower = str_to_num(temp)
	if(!is_user_connected(id))
		return
	gHasOPSPower[id] = (hasPower != 0)
	gPlayerMaxHealth[id] = get_cvar_num("ops_health")
	shResetShield(id)
	if(hasPower)
	{
		ops_reset(id)
		ops_weapons(id)
	}
	else if(is_user_connected(id))
		ops_end(id)
}

public ops_kd()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)
	new idteam = get_user_team(id)

	if(!is_user_alive(id) || !gHasOPSPower[id] || !hasRoundStarted())
		return PLUGIN_HANDLED

	if(gOPSUsage[id] == 0)
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use MEDIPACK only %ix per round!", get_cvar_num("ops_powerusage"))
		return PLUGIN_HANDLED
	}
	if(gPlayerUltimateUsed[id])
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use MEDIPACK only every %isec!", get_cvar_num("ops_cooldown"))
		return PLUGIN_HANDLED
	}

	new maxtoheal = 0
	new usertoheal = 0

	new selfheal = true

	for(new i = 1; i <= SH_MAXSLOTS; i++)
	{
		new vec1[3]
		new vec2[3]
		get_user_origin(id, vec1)
		if((i != id || selfheal) && is_user_alive(id) && idteam == get_user_team(i))
		{
			get_user_origin(i, vec2)
			new dist = get_distance(vec1, vec2)
			new toheal = gPlayerMaxHealth[i] - get_user_health(i)
			if(dist <= get_cvar_num("ops_distance") && toheal > 0 && toheal > maxtoheal)
			{
				maxtoheal = toheal
				usertoheal = i
			}
		}
	}

	maxtoheal = min(maxtoheal, get_cvar_num("ops_medipackhp"))

	if(maxtoheal > 0)
	{
		gOPSUsage[id]--
		if(get_cvar_float("ops_cooldown") > 0.0)
			ultimateTimer(id, get_cvar_float("ops_cooldown"))

		shAddHPs(usertoheal, maxtoheal, gPlayerMaxHealth[usertoheal])
		emit_sound(id, CHAN_STATIC, gOPSPowerSound, gOPSPowerVolume, ATTN_NORM, 0, PITCH_NORM)
		emit_sound(usertoheal, CHAN_STATIC, gOPSPowerSound, gOPSPowerVolume, ATTN_NORM, 0, PITCH_NORM)

		new opsname[32]
		new username[32]
		get_user_name(id, opsname, 31)
		get_user_name(usertoheal, username, 31)
		if(usertoheal == id)
			client_print(id, print_chat, "Used MEDIPACK, %i left", gOPSUsage[id])
		else
			client_print(id, print_chat, "Used MEDIPACK on %s, %i left (restored %i HP)", username, gOPSUsage[id], maxtoheal)	
	}
	else
	{
		client_print(id, print_chat, "No injured team member nearby!")
		playSoundDenySelect(id)
	}

	return PLUGIN_HANDLED
}

public event_spawn(id)
{
	if(gHasOPSPower[id] && is_user_alive(id) && shModActive())
	{
		ops_reset(id)
		set_task(0.1, "ops_weapons", id)
	}
}

public event_weapon(id)
{
	if(gHasOPSPower[id] && is_user_alive(id) && shModActive())
	{
		new clip = read_data(3)
		if(clip == 0)
			shReloadAmmo(id)
	}
}

public event_damage(id)
{
	if(!shModActive() || !is_user_alive(id))
		return PLUGIN_CONTINUE

	new damage = read_data(2)
	new weapon, bodypart, attacker = get_user_attacker(id, weapon, bodypart)
	new headshot = bodypart == 1 ? 1 : 0
	if(attacker <= 0 || attacker > SH_MAXSLOTS)
		return PLUGIN_CONTINUE
	if(gHasOPSPower[attacker] && is_user_alive(id))
	{
		new extradmg = floatround(damage * get_cvar_float("ops_powermult") - damage)
		if(extradmg > 0)
			shExtraDamage(id, attacker, extradmg, "ops powermult", headshot)
	}

	return PLUGIN_HANDLED
}

public event_ammox(id)
{
	if(!shModActive() || !is_user_alive(id))
		return

	new ammotype = read_data(1)
	new ammocount = read_data(2)
	if(gHasOPSPower[id] && (ammotype == AMMOX_HEGRENADE || ammotype == AMMOX_SMOKEGRENADE || ammotype == AMMOX_FLASHBANG))
	{
		if(ammocount == 0)
			set_task(get_cvar_float("ops_grenadetimer"), "ops_grenades", id)
	}
}

