#include <amxmod>
#include <superheromod>

// cvars:
// gunner_level 0
// gunner_health 150
// gunner_armor 150
// gunner_cooldown 45
// gunner grenadetimer 6
// gunner_powerusage 2
// gunner_powermult 1.5
// gunner_powertime 10
// gunner_powerhealth 0

#define AMMOX_FLASHBANG 11
#define AMMOX_HEGRENADE 12
#define AMMOX_SMOKEGRENADE 13

new gHeroName[]="Gunner"
new bool:gHasGunnerPower[SH_MAXSLOTS+1]
new gGunnerPowerUsage[SH_MAXSLOTS+1]
new gGunnerPowerMode[SH_MAXSLOTS+1]
new gGunnerPowerTimer[SH_MAXSLOTS+1]
new gGunnerPowerSound[] = "player/breathe1.wav"
new Float:gGunnerPowerVolume = 1.0

public plugin_init()
{
	register_plugin("SUPERHERO Gunner", "1.0", "ops")
	shCreateHero(gHeroName, "MG, Grenades & RAMPAGE", "+Power key for RAMPAGE mode (more MG damage, unlimited grenades)", true, "gunner_level")
	register_srvcmd("gunner_init", "gunner_init")
	shRegHeroInit(gHeroName, "gunner_init")

	// register cvars
	register_cvar("gunner_level", "0")
	register_cvar("gunner_health", "150")
	register_cvar("gunner_armor", "150")
	register_cvar("gunner_cooldown", "45")
	register_cvar("gunner_grenadetimer", "6")
	register_cvar("gunner_powerusage", "2")
	register_cvar("gunner_powermult", "1.5")
	register_cvar("gunner_powertime", "10")
	register_cvar("gunner_powerhealth", "0")

	// set values
	shSetMaxHealth(gHeroName, "gunner_health")
	shSetMaxArmor(gHeroName, "gunner_armor")
	shSetShieldRestrict(gHeroName)

	// register events
	register_event("ResetHUD", "event_spawn","b")
	register_event("CurWeapon", "event_weapon","be","1=1")
	register_event("Damage", "event_damage", "b")
	register_event("AmmoX", "event_ammox", "b")
	register_srvcmd("gunner_kd", "gunner_kd")
	shRegKeyDown(gHeroName, "gunner_kd")

	// loop function
	set_task(1.0, "gunner_loop", 0, "", 0, "b")
}

public plugin_precache()
{
	precache_sound(gGunnerPowerSound)
}

public gunner_loop()
{
	for(new id = 1; id <= SH_MAXSLOTS; id++)
	{
		if(gHasGunnerPower[id] && is_user_alive(id))
		{
			if(gGunnerPowerTimer[id] > 0)
			{
				new message[128]
				format(message, 127, "RAMPAGE - %d second%s", gGunnerPowerTimer[id], gGunnerPowerTimer[id] == 1 ? "" : "s")
				set_hudmessage(50, 50, 255, -1.0, 0.28, 0, 0.0, 1.0, 0.0, 0.0, 54)
				show_hudmessage(id, message)
				gGunnerPowerTimer[id]--
				remove_task(id)
				set_task(0.5, "gunner_grenades", id)
			}
			else if(gGunnerPowerTimer[id] == 0)
			{
				gGunnerPowerTimer[id]--
				gGunnerPowerMode[id] = false
				emit_sound(id, CHAN_STATIC, gGunnerPowerSound, gGunnerPowerVolume, ATTN_NORM, SND_STOP, PITCH_NORM)
				remove_task(id)
				set_task(get_cvar_float("gunner_grenadetimer"), "gunner_grenades", id)
			}
		}
	}
}

public gunner_grenades(id)
{
	if(shModActive() && gHasGunnerPower[id] && is_user_alive(id))
	{
		shGiveWeapon(id, "weapon_hegrenade")
		shGiveWeapon(id, "weapon_smokegrenade")
		shGiveWeapon(id, "weapon_flashbang")
	}
}

public gunner_weapons(id)
{
	if(is_user_alive(id) && shModActive())
	{
		shGiveWeapon(id,"weapon_m249") 
		gunner_grenades(id)
	}
}

public gunner_reset(id)
{
	remove_task(id)
	gPlayerUltimateUsed[id] = false
	gGunnerPowerUsage[id] = get_cvar_num("gunner_powerusage")
	gGunnerPowerMode[id] = false
	gGunnerPowerTimer[id] = -1
	emit_sound(id, CHAN_STATIC, gGunnerPowerSound, gGunnerPowerVolume, ATTN_NORM, SND_STOP, PITCH_NORM)
}

public gunner_end(id)
{
	gunner_reset(id)
	shRemHealthPower(id)
	shRemArmorPower(id)

	engclient_cmd(id, "drop", "weapon_m249")
	engclient_cmd(id, "drop", "weapon_hegrenade")
	engclient_cmd(id, "drop", "weapon_smokegrenade")
	engclient_cmd(id, "drop", "weapon_flashbang")
}

public gunner_init()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)
	read_argv(2,temp,5)
	new hasPower = str_to_num(temp)
	if(!is_user_connected(id))
		return
	gHasGunnerPower[id] = (hasPower != 0)
	shResetShield(id)
	if(hasPower)
	{
		gunner_weapons(id)
		gunner_reset(id)
	}
	else if(is_user_connected(id))
		gunner_end(id)
}

public gunner_kd()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)

	if(!is_user_alive(id) || !gHasGunnerPower[id] || !hasRoundStarted())
		return PLUGIN_HANDLED

	if(gGunnerPowerUsage[id] == 0)
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use RAMPAGE only %ix per round!", get_cvar_num("gunner_powerusage"))
		return PLUGIN_HANDLED
	}
	if(gPlayerUltimateUsed[id])
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use RAMPAGE only every %isec!)", get_cvar_num("gunner_cooldown"))
		return PLUGIN_HANDLED
	}

	gGunnerPowerMode[id] = true
	gGunnerPowerUsage[id]--
	gGunnerPowerTimer[id] = get_cvar_num("gunner_powertime")
	if(get_cvar_float("gunner_cooldown") > 0.0)
		ultimateTimer(id, get_cvar_float("gunner_cooldown"))

	shAddHPs(id, get_cvar_num("gunner_powerhealth"), get_cvar_num("gunner_health"))
	emit_sound(id, CHAN_STATIC, gGunnerPowerSound, gGunnerPowerVolume, ATTN_NORM, 0, PITCH_NORM)

	new message[128]
	format(message, 127, "Rampage - active")
	set_hudmessage(50, 50, 255, -1.0, 0.28, 0, 0.0, 1.0, 0.0, 0.0, 54)
	show_hudmessage(id, message)
	client_print(id, print_chat, "%i RAMPAGE mode%s left", gGunnerPowerUsage[id], gGunnerPowerUsage[id] == 1 ? "" : "s")

	return PLUGIN_HANDLED
}

public event_spawn(id)
{
	if(gHasGunnerPower[id] && is_user_alive(id) && shModActive())
	{
		gunner_reset(id)
		set_task(0.1, "gunner_weapons", id)
	}
}

public event_weapon(id)
{
	if(gHasGunnerPower[id] && is_user_alive(id) && shModActive())
	{
		new weapon = read_data(2)
		new clip = read_data(3)
		if(clip == 0 && weapon == CSW_M249)
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
	if(gHasGunnerPower[attacker] && is_user_alive(id) && gGunnerPowerMode[attacker] && weapon == CSW_M249)
	{
		new extradmg = floatround(damage * get_cvar_float("gunner_powermult") - damage)
		if(extradmg > 0)
			shExtraDamage(id, attacker, extradmg, "rampage damage", headshot)
	}

	return PLUGIN_HANDLED
}

public event_ammox(id)
{
	if(!shModActive() || !is_user_alive(id))
		return

	new ammotype = read_data(1)
	new ammocount = read_data(2)
	if(gHasGunnerPower[id] && (ammotype == AMMOX_HEGRENADE || ammotype == AMMOX_SMOKEGRENADE || ammotype == AMMOX_FLASHBANG))
	{
		if(ammocount == 0 && !gGunnerPowerMode[id])
			set_task(get_cvar_float("gunner_grenadetimer"), "gunner_grenades", id)
	}
}

