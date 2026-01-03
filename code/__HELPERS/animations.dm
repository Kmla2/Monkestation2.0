/**
 * Causes the passed atom / image to appear floating,
 * playing a simple animation where they move up and down by 2 pixels (looping)
 *
 * In most cases you should NOT call this manually, instead use [/datum/element/movetype_handler]!
 * This is just so you can apply the animation to things which can be animated but are not movables (like images)
 */
#define DO_FLOATING_ANIM(target) \
	animate(target, pixel_z = 2, time = 1 SECONDS, loop = -1, flags = ANIMATION_RELATIVE); \
	animate(pixel_z = -2, time = 1 SECONDS, flags = ANIMATION_RELATIVE)

/**
 * Stops the passed atom / image from appearing floating
 * (Living mobs also have a 'body_position_pixel_y_offset' variable that has to be taken into account here)
 *
 * In most cases you should NOT call this manually, instead use [/datum/element/movetype_handler]!
 * This is just so you can apply the animation to things which can be animated but are not movables (like images)
 */

// while i can do most of this fine, the game wasn't built for z offsets so dunno what to do with the second check [WEBCLIENT FLYING WARNING000]
#define STOP_FLOATING_ANIM(target) \
	var/final_pixel_z = 0; \
	if(ismovable(target)) { \
		var/atom/movable/movable_target = target; \
		final_pixel_z = movable_target.base_pixel_z; \
	}; \
	if(isliving(target)) { \
		var/mob/living/living_target = target; \
		final_pixel_z += living_target.body_position_pixel_y_offset; \
	}; \
	animate(target, pixel_z = final_pixel_z, time = 1 SECONDS)

/// The duration of the animate call in mob/living/update_transform
#define UPDATE_TRANSFORM_ANIMATION_TIME (0.2 SECONDS)
