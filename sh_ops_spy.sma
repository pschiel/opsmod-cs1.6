#include <amxmod>
#include <superheromod>

// cvars:
// spy_level 0
// spy_health 150
// spy_armor 150
// spy_speed 300
// spy_cooldown 10
// spy_knifemult 40
// spy_uspmult 1.8

new gHeroName[]="Spy"
new bool:gHasSpyPower[SH_MAXSLOTS+1]
new gSpyPowerMode[SH_MAXSLOTS+1]
new gSpyPowerSound[] = "ambience/disgusting.wav"
new Float:gSpyPowerVolume = 0.4
new CTSkins[4][10] = {"sas", "gsg9", "urban", "gign"}
new TSkins[4][10] = {"arctic", "leet", "guerilla", "terror"}
new gMsgSync

public plugin_init()
{
	register_plugin("SUPERHERO Spy", "1.0", "ops")
	shCreateHero(gHeroName, "Silent, USP, Knife & DISGUISE", "+Power key to toggle DISGUISE mode", true, "spy_level")
	register_srvcmd("spy_init", "spy_init")
	shRegHeroInit(gHeroName, "spy_init")

	// register cvars
	register_cvar("spy_level", "0")
	register_cvar("spy_health", "150")
	register_cvar("spy_armor", "150")
	register_cvar("spy_speed", "300")
	register_cvar("spy_cooldown", "10")
	register_cvar("spy_knifemult", "40")
	register_cvar("spy_uspmult", "1.8")

	// set values
	shSetMaxHealth(gHeroName, "spy_health")
	shSetMaxArmor(gHeroName, "spy_armor")
	shSetMaxSpeed(gHeroName, "spy_speed", "[0]")
	shSetShieldRestrict(gHeroName)

	// register events
	register_event("ResetHUD", "event_spawn","b")
	register_event("CurWeapon", "event_weapon","be","1=1")
	register_event("Damage", "event_damage", "b")
	register_srvcmd("spy_kd", "spy_kd")
	shRegKeyDown(gHeroName, "spy_kd")

	// loop function
	set_task(0.1, "spy_loop", 0, "", 0, "b")
	gMsgSync = CreateHudSyncObj()
}

public spy_loop()
{
	if(!shModActive() || !hasRoundStarted())
		return

	for(new id = 1; id <= SH_MAXSLOTS; id++)
		if(gHasSpyPower[id] && is_user_alive(id))
		{
			new closest = 1201
			new vec1[3]
			get_user_origin(id, vec1)
			for(new i = 1; i <= SH_MAXSLOTS; i++)
			{
				new vec2[3]
				get_user_origin(i, vec2)
				if(i != id && is_user_alive(i) && get_user_team(id) != get_user_team(i))
				{
					new dist = get_distance(vec1, vec2)
					if(dist < closest)
						closest = dist
				}
			}

			if(closest == 1201)
				continue

			switch(floatround(closest * 0.0254))
	       		{
				case 0..5:
				{
					set_hudmessage(255, 0, 0, 0.01, 0.27, 1, 6.0, 0.5, 0.1, 0.1, 4)
					ShowSyncHudMsg(id, gMsgSync, "Enemy within 5m")
				}
				case 6..10:
				{
					set_hudmessage(255, 0, 0, 0.01, 0.27, 1, 6.0, 0.5, 0.1, 0.1, 4)
					ShowSyncHudMsg(id, gMsgSync, "Enemy within 10m")
				}
				case 11..15:
				{
					set_hudmessage(255, 155, 0, 0.01, 0.27, 1, 6.0, 0.5, 0.1, 0.1, 4)
					ShowSyncHudMsg(id, gMsgSync, "Enemy within 15m")
				}
				case 16..20:
				{
					set_hudmessage(255, 155, 0, 0.01, 0.27, 1, 6.0, 0.5, 0.1, 0.1, 4)
					ShowSyncHudMsg(id, gMsgSync, "Enemy within 20m")
				}
				case 21..30:
				{
					set_hudmessage(255, 255, 255, 0.01, 0.27, 1, 6.0, 0.5, 0.1, 0.1, 4)
					ShowSyncHudMsg(id, gMsgSync, "Enemy within 30m")
				}
			}
		}
}

public plugin_precache()
{
	precache_sound(gSpyPowerSound)
}

public spy_disguise(id)
{
	new skin[32]
	if(!is_user_alive(id) || gSpyPowerMode[id])
		return

	new num = random_num(0,3)
	if(get_user_team(id) == 1)
		copy(skin, 31, CTSkins[num])
	else
		copy(skin, 31, TSkins[num])

	gSpyPowerMode[id] = true
#if defined AMXX_VERSION
	cs_set_user_model(id, skin)
#else
	CS_SetModel(id, skin)
#endif
	emit_sound(id, CHAN_AUTO, gSpyPowerSound, gSpyPowerVolume, ATTN_NORM, SND_STOP , PITCH_NORM)
	emit_sound(id, CHAN_AUTO, gSpyPowerSound, gSpyPowerVolume, ATTN_NORM, 0, PITCH_NORM)

	set_hudmessage(200, 200, 0, -1.0, 0.45, 2, 0.02, 4.0, 0.01, 0.1, 86)
	show_hudmessage(id, "DISGUISE - active")
}

public spy_undisguise(id)
{
	if(gSpyPowerMode[id])
	{
		set_hudmessage(200, 200, 0, -1.0, 0.45, 2, 0.02, 4.0, 0.01, 0.1, 86)
		show_hudmessage(id, "DISGUISE - inactive")
		remove_task(id)
		cs_reset_user_model(id)
		gSpyPowerMode[id] = false
		emit_sound(id, CHAN_AUTO, gSpyPowerSound, gSpyPowerVolume, ATTN_NORM, SND_STOP , PITCH_NORM)
		emit_sound(id, CHAN_AUTO, gSpyPowerSound, gSpyPowerVolume, ATTN_NORM, 0, PITCH_NORM)
	}
}

public spy_weapons(id)
{
}

public spy_reset(id)
{
	remove_task(id)
	cs_reset_user_model(id)
	gPlayerUltimateUsed[id] = false
	gSpyPowerMode[id] = false
	set_user_footsteps(id, 1)
}

public spy_end(id)
{
	spy_reset(id)
	shRemHealthPower(id)
	shRemArmorPower(id)
	shRemSpeedPower(id)
	set_user_footsteps(id, 0)
}



public spy_init()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)
	read_argv(2,temp,5)
	new hasPower = str_to_num(temp)
	if(!is_user_connected(id))
		return
	gHasSpyPower[id] = (hasPower != 0)
	shResetShield(id)
	if(hasPower)
	{
		spy_reset(id)
		spy_weapons(id)
	}
	else if(is_user_connected(id))
	{
		spy_end(id)
	}
}

public spy_kd()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)

	if(!is_user_alive(id) || !gHasSpyPower[id] || !hasRoundStarted())
		return PLUGIN_HANDLED

	if(gSpyPowerMode[id])
	{
		spy_undisguise(id)
		return PLUGIN_HANDLED
	}

	if(gPlayerUltimateUsed[id])
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use DISGUISE only every %isec!", get_cvar_num("spy_cooldown"))
		return PLUGIN_HANDLED
	}

	if(get_cvar_float("spy_cooldown") > 0.0)
		ultimateTimer(id, get_cvar_float("spy_cooldown"))
	
	spy_disguise(id)

	return PLUGIN_HANDLED
}

public event_spawn(id)
{
	if(gHasSpyPower[id] && is_user_alive(id) && shModActive())
	{
		spy_reset(id)
		set_task(0.1, "spy_weapons", id)
	}
}

public event_weapon(id)
{
	if(gHasSpyPower[id] && is_user_alive(id) && shModActive())
	{
		new weapon = read_data(2)
		new clip = read_data(3)
		if(clip == 0 && weapon == CSW_USP)
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
	if(gHasSpyPower[attacker] && is_user_alive(id) && weapon == CSW_KNIFE)
	{
		new extradmg = floatround(damage * get_cvar_float("spy_knifemult") - damage)
		if(extradmg > 0)
			shExtraDamage(id, attacker, extradmg, "deadly knife attack", headshot)
	}
	if(gHasSpyPower[attacker] && is_user_alive(id) && weapon == CSW_USP)
	{
		new extradmg = floatround(damage * get_cvar_float("spy_uspmult") - damage)
		if(extradmg > 0)
			shExtraDamage(id, attacker, extradmg, "usp power shot", headshot)
	}

	return PLUGIN_HANDLED
}

