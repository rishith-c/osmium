/* ===========================================================================
 * state_manager.c - OS State Manager Implementation
 * ===========================================================================
 * Controls the dual-state system. The OS boots into SAFE_MODE by default.
 * State transitions are logged to screen.
 *
 * In future versions, state changes will:
 *   - Trigger the behavior engine to reconfigure permissions
 *   - Notify the app system to load/unload mode-specific apps
 *   - Update the UI to reflect the current mode
 * =========================================================================== */

#include "state_manager.h"
#include "screen.h"

/* Current operating state (module-private) */
static os_state_t current_state;

/* Human-readable state names for display */
static const char *STATE_NAMES[] = {
    "SAFE MODE",
    "CREATOR MODE"
};

/* Color for each state (green for safe, yellow for creator) */
static const unsigned char STATE_COLORS[] = {
    (COLOR_BLACK << 4) | COLOR_GREEN,   /* SAFE_MODE: green text */
    (COLOR_BLACK << 4) | COLOR_YELLOW   /* CREATOR_MODE: yellow text */
};

/* ---------------------------------------------------------------------------
 * state_init - Initialize the state manager
 * ---------------------------------------------------------------------------
 * Sets the default state to SAFE_MODE. This is the most restrictive mode,
 * ensuring the system starts in a secure configuration.
 * --------------------------------------------------------------------------- */
void state_init(void)
{
    current_state = SAFE_MODE;
    print_string("[STATE] State manager initialized.\n");
    print_string("[STATE] Default state: ");
    print_string_color(STATE_NAMES[current_state], STATE_COLORS[current_state]);
    print_string("\n");
}

/* ---------------------------------------------------------------------------
 * state_toggle - Toggle between SAFE_MODE and CREATOR_MODE
 * ---------------------------------------------------------------------------
 * Switches to the opposite state. In future versions this will:
 *   - Require authentication before entering CREATOR_MODE
 *   - Flush caches and reset permissions on transition
 *   - Notify all registered state-change listeners
 * --------------------------------------------------------------------------- */
void state_toggle(void)
{
    os_state_t old_state = current_state;

    if (current_state == SAFE_MODE) {
        current_state = CREATOR_MODE;
    } else {
        current_state = SAFE_MODE;
    }

    /* Log the transition */
    print_string("[STATE] Transition: ");
    print_string_color(STATE_NAMES[old_state], STATE_COLORS[old_state]);
    print_string(" -> ");
    print_string_color(STATE_NAMES[current_state], STATE_COLORS[current_state]);
    print_string("\n");
}

/* ---------------------------------------------------------------------------
 * state_get_current - Return the current operating state
 * --------------------------------------------------------------------------- */
os_state_t state_get_current(void)
{
    return current_state;
}

/* ---------------------------------------------------------------------------
 * state_print_current - Print the current state to screen
 * --------------------------------------------------------------------------- */
void state_print_current(void)
{
    print_string("[STATE] Current state: ");
    print_string_color(STATE_NAMES[current_state], STATE_COLORS[current_state]);
    print_string("\n");
}
