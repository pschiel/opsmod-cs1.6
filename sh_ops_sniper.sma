#include <amxmod>
#include <superheromod>

// cvars:
// sniper_level 0
// sniper_health 150
// sniper_armor 150
// sniper_cooldown 45
// sniper_scoutmult 1.7
// sniper_powerusage 2
// sniper_powertime 30
// sniper_powerhealth 0
// sniper_poweralpha 90

new gHeroName[]="Sniper"
new bool:gHasSniperPower[SH_MAXSLOTS+1]
new gSniperPowerUsage[SH_MAXSLOTS+1]
new gSniperPowerMode[SH_MAXSLOTS+1]
new gSniperPowerTimer[SH_MAXSLOTS+1]
new gSniperPowerSound[] = "player/breathe1.wav"
new Float:gSniperPowerVolume = 1.0
new gSniperPowerLoc[SH_MAXSLOTS+1][3]

public plugin_init()
{
	register_plugin("SUPERHERO Sniper", "1.0", "ops")
	shCreateHero(gHeroName, "Power-Scout & HIDING", "+Power key to use HIDING mode (less visible until you move)", true, "sniper_level")
	register_srvcmd("sniper_init", "sniper_init")
	shRegHeroInit(gHeroName, "sniper_init")

	// register cvars
	register_cvar("sniper_level", "0")
	register_cvar("sniper_health", "150")
	register_cvar("sniper_armor", "150")
	register_cvar("sniper_cooldown", "45")
	register_cvar("sniper_scoutmult", "1.7")
	register_cvar("sniper_powerusage", "2")
	register_cvar("sniper_powertime", "30")
	register_cvar("sniper_powerhealth", "0")
	register_cvar("sniper_poweralpha", "90")

	// set values
	shSetMaxHealth(gHeroName, "sniper_health")
	shSetMaxArmor(gHeroName, "sniper_armor")
	shSetShieldRestrict(gHeroName)

	// register events
	register_event("ResetHUD", "event_spawn","b")
	register_event("CurWeapon", "event_weapon","be","1=1")
	register_event("Damage", "event_damage", "b")
	register_srvcmd("sniper_kd", "sniper_kd")
	shRegKeyDown(gHeroName, "sniper_kd")

	// loop function
	set_task(1.0, "sniper_loop", 0, "", 0, "b")
}

public plugin_precache()
{
	precache_sound(gSniperPowerSound)
}

public sniper_loop()
{
	for(new id = 1; id <= SH_MAXSLOTS; id++)
		if(gHasSniperPower[id] && is_user_alive(id))
		{
			if(gSniperPowerTimer[id] > 0)
			{
				new vec[3]
				get_user_origin(id, vec)
				vec[2] = 0
				new dist = get_distance(vec, gSniperPowerLoc[id])
				if(dist == 0)
				{
					new message[128]
					format(message, 127, "HIDING - %i second%s", gSniperPowerTimer[id], gSniperPowerTimer[id] == 1 ? "" : "s")
					set_hudmessage(50, 50, 255, -1.0, 0.28, 0, 0.0, 1.0, 0.0, 0.0, 54)
					show_hudmessage(id, message)
					gSniperPowerTimer[id]--
				}
				else
					gSniperPowerTimer[id] = 0
			}
			if(gSniperPowerTimer[id] == 0)
			{
				gSniperPowerMode[id] = false
				gSniperPowerTimer[id]--
				set_user_rendering(id)
				emit_sound(id, CHAN_STATIC, gSniperPowerSound, 0.0, ATTN_NORM, SND_STOP, PITCH_NORM)
			}
		}
}

public sniper_weapons(id)
{
	if(is_user_alive(id) && shModActive())
		shGiveWeapon(id,"weapon_scout") 
}

public sniper_reset(id)
{
	remove_task(id)
	gPlayerUltimateUsed[id] = false
	gSniperPowerUsage[id] = get_cvar_num("sniper_powerusage")
	gSniperPowerMode[id] = false
	gSniperPowerTimer[id] = -1
	set_user_rendering(id)
	emit_sound(id, CHAN_STATIC, gSniperPowerSound, 0.0, ATTN_NORM, SND_STOP, PITCH_NORM)
}

public sniper_end(id)
{
	sniper_reset(id)
	shRemHealthPower(id)
	shRemArmorPower(id)

	engclient_cmd(id, "drop", "weapon_scout") 
}

public sniper_init()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)
	read_argv(2,temp,5)
	new hasPower = str_to_num(temp)
	if(!is_user_connected(id))
		return
	gHasSniperPower[id] = (hasPower != 0)
	shResetShield(id)
	if(hasPower)
	{
		sniper_reset(id)
		sniper_weapons(id)
	}
	else if(is_user_connected(id))
		sniper_end(id)
}

public sniper_kd()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)

	if(!is_user_alive(id) || !gHasSniperPower[id] || !hasRoundStarted())
		return PLUGIN_HANDLED

	if(gSniperPowerUsage[id] == 0)
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use HIDING only %ix per round!", get_cvar_num("sniper_powerusage"))
		return PLUGIN_HANDLED
	}
	if(gPlayerUltimateUsed[id])
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use HIDING only every %isec!", get_cvar_num("sniper_cooldown"))
		return PLUGIN_HANDLED
	}
	if(get_cvar_float("sniper_cooldown") > 0.0)
		ultimateTimer(id, get_cvar_float("sniper_cooldown"))

	gSniperPowerMode[id] = true
	gSniperPowerUsage[id]--
	gSniperPowerTimer[id] = get_cvar_num("sniper_powertime")
	get_user_origin(id, gSniperPowerLoc[id])
	gSniperPowerLoc[id][2] = 0

	shAddHPs(id, get_cvar_num("sniper_powerhealth"), get_cvar_num("sniper_health"))
	set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, get_cvar_num("sniper_poweralpha"))
	emit_sound(id, CHAN_STATIC, gSniperPowerSound, gSniperPowerVolume, ATTN_NORM, 0, PITCH_NORM)

	new message[128]
	format(message, 127, "HIDING - active")
	set_hudmessage(50, 50, 255, -1.0, 0.28, 0, 0.0, 1.0, 0.0, 0.0, 54)
	show_hudmessage(id, message)
	client_print(id, print_chat, "%i HIDING mode%s left", gSniperPowerUsage[id], gSniperPowerUsage[id] == 1 ? "" : "s")

	return PLUGIN_HANDLED
}

public event_spawn(id)
{
	if(gHasSniperPower[id] && is_user_alive(id) && shModActive())
	{
		sniper_reset(id)
		set_task(0.1, "sniper_weapons", id)
	}
}

public event_weapon(id)
{
	if(gHasSniperPower[id] && is_user_alive(id) && shModActive())
	{
		new weapon = read_data(2)
		new clip = read_data(3)
		if(clip == 0 && weapon == CSW_SCOUT)
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
	if(gHasSniperPower[attacker] && is_user_alive(id) && weapon == CSW_SCOUT)
	{
		new extradmg = floatround(damage * get_cvar_float("sniper_scoutmult") - damage)
		if(extradmg > 0)
			shExtraDamage(id, attacker, extradmg, "sniper power", headshot)
	}

	return PLUGIN_HANDLED
}

