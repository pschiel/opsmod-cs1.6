#include <amxmod>
#include <superheromod>

// cvars:
// infantry_level 0
// infantry_health 150
// infantry_armor 150
// infantry_cooldown 45
// infantry_powerusage 2
// infantry_powermult 1.5
// infantry_powertime 6
// infantry_powerhealth 0
// infantry_powerspeed 350

new gHeroName[]="Infantry"
new bool:gHasInfantryPower[SH_MAXSLOTS+1]
new gInfantryPowerUsage[SH_MAXSLOTS+1]
new gInfantryPowerMode[SH_MAXSLOTS+1]
new gInfantryPowerTimer[SH_MAXSLOTS+1]
new gInfantryPowerSound[] = "player/breathe1.wav"
new Float:gInfantryPowerVolume = 1.0

public plugin_init()
{
	register_plugin("SUPERHERO Infantry", "1.0", "ops")
	shCreateHero(gHeroName, "Big Weapon Arsenal & RAGE", "+Power key for RAGE mode (more speed and damage)", true, "infantry_level")
	register_srvcmd("infantry_init", "infantry_init")
	shRegHeroInit(gHeroName, "infantry_init")

	// register cvars
	register_cvar("infantry_level", "0")
	register_cvar("infantry_health", "150")
	register_cvar("infantry_armor", "150")
	register_cvar("infantry_cooldown", "45")
	register_cvar("infantry_powerusage", "2")
	register_cvar("infantry_powermult", "1.5")
	register_cvar("infantry_powertime", "6")
	register_cvar("infantry_powerhealth", "0")
	register_cvar("infantry_powerspeed", "350")

	// set values
	shSetMaxHealth(gHeroName, "infantry_health")
	shSetMaxArmor(gHeroName, "infantry_armor")
	shSetShieldRestrict(gHeroName)

	// register events
	register_event("ResetHUD", "event_spawn","b")
	register_event("CurWeapon", "event_weapon","be","1=1")
	register_event("Damage", "event_damage", "b")
	register_srvcmd("infantry_kd", "infantry_kd")
	shRegKeyDown(gHeroName, "infantry_kd")

	// loop function
	set_task(1.0, "infantry_loop", 0, "", 0, "b")
}

public plugin_precache()
{
	precache_sound(gInfantryPowerSound)
}

public infantry_loop()
{
	for(new id = 1; id <= SH_MAXSLOTS; id++)
	{
		if(gHasInfantryPower[id] && is_user_alive(id))
		{
			if(gInfantryPowerTimer[id] > 0)
			{
				new message[128]
				format(message, 127, "RAGE - %d second%s", gInfantryPowerTimer[id], gInfantryPowerTimer[id] == 1 ? "" : "s")
				set_hudmessage(50, 50, 255, -1.0, 0.28, 0, 0.0, 1.0, 0.0, 0.0, 54)
				show_hudmessage(id, message)
				gInfantryPowerTimer[id]--
			}
			else if(gInfantryPowerTimer[id] == 0)
			{
				gInfantryPowerTimer[id]--
				gInfantryPowerMode[id] = false
				emit_sound(id, CHAN_STATIC, gInfantryPowerSound, gInfantryPowerVolume, ATTN_NORM, SND_STOP, PITCH_NORM)
			}
		}
	}
}

public infantry_weapons(id)
{
	if(is_user_alive(id) && shModActive())
	{
		new idteam = get_user_team(id)
		shGiveWeapon(id,"weapon_usp") 
		shGiveWeapon(id,"weapon_elite")
		shGiveWeapon(id,"weapon_deagle") 
		shGiveWeapon(id,"weapon_fiveseven")
		shGiveWeapon(id,"weapon_tmp") 
		shGiveWeapon(id,"weapon_xm1014")
		shGiveWeapon(id,"weapon_ak47") 
		shGiveWeapon(id,"weapon_m4a1") 
		shGiveWeapon(id,"weapon_aug") 
		if(idteam == 2)
			shGiveWeapon(id, "item_thighpack")
	}
}

public infantry_reset(id)
{
	remove_task(id)
	gPlayerUltimateUsed[id] = false
	gInfantryPowerUsage[id] = get_cvar_num("infantry_powerusage")
	gInfantryPowerMode[id] = false
	gInfantryPowerTimer[id] = -1
	emit_sound(id, CHAN_STATIC, gInfantryPowerSound, gInfantryPowerVolume, ATTN_NORM, SND_STOP, PITCH_NORM)
}

public infantry_end(id)
{
	infantry_reset(id)
	shRemHealthPower(id)
	shRemArmorPower(id)

	engclient_cmd(id, "drop", "weapon_usp") 
	engclient_cmd(id, "drop", "weapon_elite")
	engclient_cmd(id, "drop", "weapon_deagle") 
	engclient_cmd(id, "drop", "weapon_fiveseven")
	engclient_cmd(id, "drop", "weapon_tmp") 
	engclient_cmd(id, "drop", "weapon_xm1014")
	engclient_cmd(id, "drop", "weapon_ak47") 
	engclient_cmd(id, "drop", "weapon_m4a1") 
	engclient_cmd(id, "drop", "weapon_aug") 
}

public infantry_init()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)
	read_argv(2,temp,5)
	new hasPower = str_to_num(temp)
	if(!is_user_connected(id))
		return
	gHasInfantryPower[id] = (hasPower != 0)
	shResetShield(id)
	if(hasPower)
	{
		infantry_reset(id)
		infantry_weapons(id)
	}
	else if(is_user_connected(id))
		infantry_end(id)
}

public infantry_kd()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)

	if(!is_user_alive(id) || !gHasInfantryPower[id] || !hasRoundStarted())
		return PLUGIN_HANDLED

	if(gInfantryPowerUsage[id] == 0)
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use RAGE only %ix per round!", get_cvar_num("infantry_powerusage"))
		return PLUGIN_HANDLED
	}
	if(gPlayerUltimateUsed[id])
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use RAGE only every %isec!", get_cvar_num("infantry_cooldown"))
		return PLUGIN_HANDLED
	}

	gInfantryPowerMode[id] = true
	gInfantryPowerUsage[id]--
	gInfantryPowerTimer[id] = get_cvar_num("infantry_powertime")
	if(get_cvar_float("infantry_cooldown") > 0.0)
		ultimateTimer(id, get_cvar_float("infantry_cooldown"))

	shAddHPs(id, get_cvar_num("infantry_powerhealth"), get_cvar_num("infantry_health"))
	new Float:powerspeed = get_cvar_float("infantry_powerspeed")
	shStun(id, get_cvar_num("infantry_powertime"))
	set_user_maxspeed(id, powerspeed)
	emit_sound(id, CHAN_STATIC, gInfantryPowerSound, gInfantryPowerVolume, ATTN_NORM, 0, PITCH_NORM)

	new message[128]
	format(message, 127, "Rage - active")
	set_hudmessage(50, 50, 255, -1.0, 0.28, 0, 0.0, 1.0, 0.0, 0.0, 54)
	show_hudmessage(id, message)
	if(gInfantryPowerUsage[id] > 0)
		client_print(id, print_chat, "%i RAGE mode%s left", gInfantryPowerUsage[id], gInfantryPowerUsage[id] == 1 ? "" : "s")

	return PLUGIN_HANDLED
}

public event_spawn(id)
{
	if(gHasInfantryPower[id] && is_user_alive(id) && shModActive())
	{
		infantry_reset(id)
		set_task(0.1, "infantry_weapons", id)
	}
}

public event_weapon(id)
{
	if(gHasInfantryPower[id] && is_user_alive(id) && shModActive())
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
	if(gHasInfantryPower[attacker] && is_user_alive(id) && gInfantryPowerMode[attacker])
	{
		new extradmg = floatround(damage * get_cvar_float("infantry_powermult") - damage)
		if(extradmg > 0)
			shExtraDamage(id, attacker, extradmg, "rage damage", headshot)
	}

	return PLUGIN_HANDLED
}

