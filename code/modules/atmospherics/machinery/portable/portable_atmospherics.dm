#define PORTABLE_ATMOS_IGNORE_ATMOS_LIMIT 0

/obj/machinery/portable_atmospherics
	name = "portable_atmospherics"
	icon = 'icons/obj/atmospherics/atmos.dmi'
	use_power = NO_POWER_USE
	max_integrity = 250
	armor_type = /datum/armor/machinery_portable_atmospherics
	anchored = FALSE
	layer = ABOVE_OBJ_LAYER

	///Stores the gas mixture of the portable component. Don't access this directly, use return_air() so you support the temporary processing it provides
	var/datum/gas_mixture/air_contents
	///Stores the reference of the connecting port
	var/obj/machinery/atmospherics/components/unary/portables_connector/connected_port
	///Stores the reference of the tank the machine is holding
	var/obj/item/tank/holding
	///Volume (in L) of the inside of the machine
	var/volume = 0
	///Used to track if anything of note has happen while running process_atmos().
	///Treat it as a process_atmos() scope var, we just declare it here to pass it between parent calls.
	///Should be false on start of every process_atmos() proc, since true means we'll process again next tick.
	var/excited = FALSE

	/// Max amount of heat allowed inside the machine before it starts to melt. [PORTABLE_ATMOS_IGNORE_ATMOS_LIMIT] is special value meaning we are immune.
	var/temp_limit = 10000
	/// Max amount of pressure allowed inside of the canister before it starts to break. [PORTABLE_ATMOS_IGNORE_ATMOS_LIMIT] is special value meaning we are immune.
	var/pressure_limit = 500000

	/// Should reactions inside the object be suppressed
	var/suppress_reactions = FALSE
	/// Is there a hypernoblium crystal inserted into this
	var/nob_crystal_inserted = FALSE
	var/insert_sound = 'sound/effects/compressed_air/tank_insert_clunky.ogg'
	var/remove_sound = 'sound/effects/compressed_air/tank_remove_thunk.ogg'
	var/sound_vol = 50

/datum/armor/machinery_portable_atmospherics
	energy = 100
	fire = 60
	acid = 30

/obj/machinery/portable_atmospherics/Initialize(mapload)
	. = ..()
	air_contents = new
	air_contents.volume = volume
	air_contents.temperature = T20C
	SSair.start_processing_machine(src)
	AddElement(/datum/element/climbable, climb_time = 3 SECONDS, climb_stun = 3 SECONDS)
	AddElement(/datum/element/elevation, pixel_shift = 8)
	register_context()

/obj/machinery/portable_atmospherics/on_construction(mob/user)
	. = ..()
	set_anchored(FALSE)

/obj/machinery/portable_atmospherics/Destroy()
	disconnect()
	air_contents = null
	SSair.stop_processing_machine(src)

	if(nob_crystal_inserted)
		new /obj/item/hypernoblium_crystal(src)

	return ..()

/obj/machinery/portable_atmospherics/examine(mob/user)
	. = ..()
	if(nob_crystal_inserted)
		. += "There is a hypernoblium crystal inside it that allows for reactions inside to be suppressed."
	if(suppress_reactions)
		. += "The hypernoblium crystal inside is glowing with a faint blue colour, indicating reactions inside are currently being suppressed."

/obj/machinery/portable_atmospherics/ex_act(severity, target)
	if(resistance_flags & INDESTRUCTIBLE)
		return FALSE //Indestructible cans shouldn't release air

	if(severity == EXPLODE_DEVASTATE || target == src)
		//This explosion will destroy the can, release its air.
		var/turf/local_turf = get_turf(src)
		local_turf.assume_air(air_contents)

	return ..()

/obj/machinery/portable_atmospherics/process_atmos()
	if(!suppress_reactions)
		if(air_contents.react(src))
			excited = TRUE
	if(!excited)
		return PROCESS_KILL
	excited = FALSE

/obj/machinery/portable_atmospherics/welder_act(mob/living/user, obj/item/tool)
	. = ..()
	if((user.istate & ISTATE_HARM))
		return FALSE
	if(atom_integrity >= max_integrity)
		return TRUE
	if(machine_stat & BROKEN)
		return TRUE
	if(!tool.tool_start_check(user, amount=0))
		return TRUE
	to_chat(user, span_notice("You begin repairing cracks in [src]..."))
	while(tool.use_tool(src, user, 2.5 SECONDS, volume=40))
		atom_integrity = min(atom_integrity + 25, max_integrity)
		if(atom_integrity >= max_integrity)
			to_chat(user, span_notice("You've finished repairing [src]."))
			return TRUE
		to_chat(user, span_notice("You repair some of the cracks in [src]..."))
	return TRUE

/obj/machinery/portable_atmospherics/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(!isliving(user) || !Adjacent(user))
		return .
	if(held_item?.tool_behaviour == TOOL_WELDER)
		context[SCREENTIP_CONTEXT_LMB] = "Repair"
		return CONTEXTUAL_SCREENTIP_SET

/// Take damage if a variable is exceeded. Damage is equal to temp/limit * heat/limit.
/// The damage multiplier is treated as 1 if something is being ignored while the other one is exceeded.
/// On most cases only one will be exceeded, so the other one is scaled down.
/obj/machinery/portable_atmospherics/proc/take_atmos_damage()
	var/taking_damage = FALSE

	var/temp_damage = 1
	var/pressure_damage = 1

	if(temp_limit != PORTABLE_ATMOS_IGNORE_ATMOS_LIMIT)
		temp_damage = air_contents.temperature / temp_limit
		taking_damage = temp_damage > 1

	if(pressure_limit != PORTABLE_ATMOS_IGNORE_ATMOS_LIMIT)
		pressure_damage = air_contents.return_pressure() / pressure_limit
		taking_damage = taking_damage || pressure_damage > 1

	if(!taking_damage)
		return FALSE

	take_damage(clamp(temp_damage * pressure_damage, 5, 50), BURN, 0)
	return TRUE

/obj/machinery/portable_atmospherics/return_air()
	SSair.start_processing_machine(src)
	return air_contents

/obj/machinery/portable_atmospherics/return_analyzable_air()
	return air_contents

/**
 * Allow the portable machine to be connected to a connector
 * Arguments:
 * * new_port - the connector that we trying to connect to
 */
/obj/machinery/portable_atmospherics/proc/connect(obj/machinery/atmospherics/components/unary/portables_connector/new_port)
	//Make sure not already connected to something else
	if(connected_port || !new_port || new_port.connected_device)
		return FALSE

	//Make sure are close enough for a valid connection
	if(new_port.loc != get_turf(src))
		return FALSE

	//Perform the connection
	connected_port = new_port
	connected_port.connected_device = src
	var/datum/pipeline/connected_port_parent = connected_port.parents[1]
	connected_port_parent.reconcile_air()

	set_anchored(TRUE) //Prevent movement
	pixel_x = new_port.pixel_x
	pixel_y = new_port.pixel_y

	SSair.start_processing_machine(src)
	update_appearance()
	return TRUE

/obj/machinery/portable_atmospherics/Move()
	. = ..()
	if(.)
		disconnect()

/**
 * Allow the portable machine to be disconnected from the connector
 */
/obj/machinery/portable_atmospherics/proc/disconnect()
	if(!connected_port)
		return FALSE
	set_anchored(FALSE)
	connected_port.connected_device = null
	connected_port = null
	pixel_x = 0
	pixel_y = 0

	SSair.start_processing_machine(src)
	update_appearance()
	return TRUE

/obj/machinery/portable_atmospherics/AltClick(mob/living/user)
	. = ..()
	if(!istype(user) || !user.can_perform_action(src, NEED_DEXTERITY) || !can_interact(user))
		return
	if(!holding)
		return
	replace_tank(user, TRUE)

/obj/machinery/portable_atmospherics/examine(mob/user)
	. = ..()
	if(!holding)
		return
	. += span_notice("\The [src] contains [holding]. Alt-click [src] to remove it.")+\
		span_notice("Click [src] with another gas tank to hot swap [holding].")

/**
 * Allow the player to place a tank inside the machine.
 * Arguments:
 * * User: the player doing the act
 * * close_valve: used in the canister.dm file, check if the valve is open or not
 * * new_tank: the tank we are trying to put in the machine
 */
/obj/machinery/portable_atmospherics/proc/replace_tank(mob/living/user, close_valve, obj/item/tank/new_tank)
	if(machine_stat & BROKEN)
		return FALSE
	if(!user)
		return FALSE
	if(new_tank && !user.transferItemToLoc(new_tank, src))
		return FALSE

	if(holding && new_tank)//for when we are actually switching tanks
		investigate_log("had its internal [holding] swapped with [new_tank] by [key_name(user)].", INVESTIGATE_ATMOS)
		to_chat(user, span_notice("In one smooth motion you pop [holding] out of [src]'s connector and replace it with [new_tank]."))
		user.put_in_hands(holding)
		UnregisterSignal(holding, COMSIG_QDELETING)
		holding = new_tank
		RegisterSignal(holding, COMSIG_QDELETING, PROC_REF(unregister_holding))
		playsound(src, remove_sound, sound_vol)
		playsound(src, insert_sound, sound_vol)
	else if(holding)//we remove a tank
		investigate_log("had its internal [holding] removed by [key_name(user)].", INVESTIGATE_ATMOS)
		to_chat(user, span_notice("You remove [holding] from [src]."))
		if(Adjacent(user))
			user.put_in_hands(holding)
		else
			holding.forceMove(get_turf(src))
		playsound(src, remove_sound, sound_vol)
		UnregisterSignal(holding, COMSIG_QDELETING)
		holding = null
	else if(new_tank)//we insert the tank
		investigate_log("had [new_tank] inserted into it by [key_name(user)].", INVESTIGATE_ATMOS)
		to_chat(user, span_notice("You insert [new_tank] into [src]."))
		holding = new_tank
		playsound(src, insert_sound, sound_vol)
		RegisterSignal(holding, COMSIG_QDELETING, PROC_REF(unregister_holding))

	SSair.start_processing_machine(src)
	update_appearance()
	return TRUE

/obj/machinery/portable_atmospherics/attackby(obj/item/item, mob/user, params)
	if(istype(item, /obj/item/tank))
		return replace_tank(user, FALSE, item)
	return ..()

/obj/machinery/portable_atmospherics/wrench_act(mob/living/user, obj/item/wrench)
	if(machine_stat & BROKEN)
		return FALSE
	if(connected_port)
		investigate_log("was disconnected from [connected_port] by [key_name(user)].", INVESTIGATE_ATMOS)
		disconnect()
		wrench.play_tool_sound(src)
		user.visible_message( \
			"[user] disconnects [src].", \
			span_notice("You unfasten [src] from the port."), \
			span_hear("You hear a ratchet."))
		update_appearance()
		return TRUE
	var/obj/machinery/atmospherics/components/unary/portables_connector/possible_port = locate(/obj/machinery/atmospherics/components/unary/portables_connector) in loc
	if(!possible_port)
		to_chat(user, span_notice("Nothing happens."))
		return FALSE
	if(!connect(possible_port))
		to_chat(user, span_notice("[name] failed to connect to the port."))
		return FALSE
	wrench.play_tool_sound(src)
	user.visible_message( \
		"[user] connects [src].", \
		span_notice("You fasten [src] to the port."), \
		span_hear("You hear a ratchet."))
	update_appearance()
	investigate_log("was connected to [possible_port] by [key_name(user)].", INVESTIGATE_ATMOS)
	return TRUE

/obj/machinery/portable_atmospherics/attacked_by(obj/item/item, mob/user)
	if(item.force < 10 && !(machine_stat & BROKEN))
		take_damage(0)
		return
	investigate_log("was smacked with \a [item] by [key_name(user)].", INVESTIGATE_ATMOS)
	add_fingerprint(user)
	return ..()

/// Holding tanks can get to zero integrity and be destroyed without other warnings due to pressure change.
/// This checks for that case and removes our reference to it.
/obj/machinery/portable_atmospherics/proc/unregister_holding()
	SIGNAL_HANDLER

	UnregisterSignal(holding, COMSIG_QDELETING)
	holding = null

#undef PORTABLE_ATMOS_IGNORE_ATMOS_LIMIT
