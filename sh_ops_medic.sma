#include <amxmod>
#include <superheromod>

// cvars:
// medic_level 0
// medic_health 150
// medic_healthregen 2
// medic_armor 150
// medic_cooldown 3
// medic_powerusage 8
// medic_distance 150
// medic_medipackhp 100

new gHeroName[]="Medic"
new bool:gHasMedicPower[SH_MAXSLOTS+1]
new gMedicUsage[SH_MAXSLOTS+1]
new gMedicPowerSound[] = "player/sprayer.wav"
new Float:gMedicPowerVolume = 0.7
new gPlayerMaxHealth[SH_MAXSLOTS+1]

public plugin_init()
{
	register_plugin("SUPERHERO Medic", "1.0", "ops")
	shCreateHero(gHeroName, "Regeneration, MP & MEDIPACK", "+Power key to use MEDIPACK on nearby team member", true, "medic_level")
	register_srvcmd("medic_init", "medic_init")
	shRegHeroInit(gHeroName, "medic_init")

	// register cvars
	register_cvar("medic_level", "0")
	register_cvar("medic_health", "150")
	register_cvar("medic_armor", "150")
	register_cvar("medic_powerusage", "8")
	register_cvar("medic_cooldown", "3")
	register_cvar("medic_distance", "150")
	register_cvar("medic_medipackhp", "100")
	register_cvar("medic_healthregen", "2")

	// collect max healths
	register_srvcmd("medic_maxhealth", "medic_maxhealth")
	shRegMaxHealth(gHeroName, "medic_maxhealth")

	// set values
	shSetMaxHealth(gHeroName, "medic_health")
	shSetMaxArmor(gHeroName, "medic_armor")
	shSetShieldRestrict(gHeroName)

	// register events
	register_event("ResetHUD", "event_spawn","b")
	register_event("CurWeapon", "event_weapon","be","1=1")
	register_srvcmd("medic_kd", "medic_kd")
	shRegKeyDown(gHeroName, "medic_kd")

	// loop function
	set_task(1.0, "medic_loop", 0, "", 0, "b")
}

public medic_maxhealth(id)
{
	new id[6]
	new health[9]

	read_argv(1, id, 5)
	read_argv(2, health, 8)

	gPlayerMaxHealth[str_to_num(id)] = str_to_num(health)
}

public medic_loop()
{
	if(shModActive())
		for(new id = 1; id <= SH_MAXSLOTS; id++)
			if(gHasMedicPower[id] && is_user_alive(id))
				shAddHPs(id, get_cvar_num("medic_healthregen"), gPlayerMaxHealth[id])
}

public medic_weapons(id)
{
	if(is_user_alive(id) && shModActive())
		shGiveWeapon(id ,"weapon_mp5navy")
}

public medic_reset(id)
{
	remove_task(id)
	gPlayerUltimateUsed[id] = false
	gMedicUsage[id] = get_cvar_num("medic_powerusage")
}

public medic_end(id)
{
	medic_reset(id)
	shRemHealthPower(id)
	shRemArmorPower(id)

	engclient_cmd(id, "drop", "weapon_mp5navy")
}

public medic_init()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)
	read_argv(2,temp,5)
	new hasPower = str_to_num(temp)
	if(!is_user_connected(id))
		return
	gHasMedicPower[id] = (hasPower != 0)
	gPlayerMaxHealth[id] = get_cvar_num("medic_health")
	shResetShield(id)
	if(hasPower)
	{
		medic_reset(id)
		medic_weapons(id)
	}
	else if(is_user_connected(id))
		medic_end(id)
}

public medic_kd()
{
	new temp[6]
	read_argv(1, temp, 5)
	new id = str_to_num(temp)
	new idteam = get_user_team(id)

	if(!is_user_alive(id) || !gHasMedicPower[id] || !hasRoundStarted())
		return PLUGIN_HANDLED

	if(gMedicUsage[id] == 0)
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use MEDIPACK only %ix per round!", get_cvar_num("medic_powerusage"))
		return PLUGIN_HANDLED
	}
	if(gPlayerUltimateUsed[id])
	{
		playSoundDenySelect(id)
		client_print(id, print_chat, "You can use MEDIPACK only every %isec!", get_cvar_num("medic_cooldown"))
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
			if(dist <= get_cvar_num("medic_distance") && toheal > 0 && toheal > maxtoheal)
			{
				maxtoheal = toheal
				usertoheal = i
			}
		}
	}

	maxtoheal = min(maxtoheal, get_cvar_num("medic_medipackhp"))

	if(maxtoheal > 0)
	{
		gMedicUsage[id]--
		if(get_cvar_float("medic_cooldown") > 0.0)
			ultimateTimer(id, get_cvar_float("medic_cooldown"))

		shAddHPs(usertoheal, maxtoheal, gPlayerMaxHealth[usertoheal])
		emit_sound(id, CHAN_STATIC, gMedicPowerSound, gMedicPowerVolume, ATTN_NORM, 0, PITCH_NORM)
		emit_sound(usertoheal, CHAN_STATIC, gMedicPowerSound, gMedicPowerVolume, ATTN_NORM, 0, PITCH_NORM)

		new medicname[32]
		new username[32]
		get_user_name(id, medicname, 31)
		get_user_name(usertoheal, username, 31)
		if(usertoheal == id)
			client_print(id, print_chat, "Used MEDIPACK, %i left", gMedicUsage[id])
		else
			client_print(id, print_chat, "Used MEDIPACK on %s, %i left (restored %i HP)", username, gMedicUsage[id], maxtoheal)	
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
	if(gHasMedicPower[id] && is_user_alive(id) && shModActive())
	{
		medic_reset(id)
		set_task(0.1, "medic_weapons", id)
	}
}

public event_weapon(id)
{
	if(gHasMedicPower[id] && is_user_alive(id) && shModActive())
	{
		new weapon = read_data(2)
		new clip = read_data(3)
		if(clip == 0 && weapon == CSW_MP5NAVY)
			shReloadAmmo(id)
	}
}

