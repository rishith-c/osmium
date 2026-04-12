/* ===========================================================================
 * state_manager.h - OS State Manager
 * ===========================================================================
 * Manages the dual-state system that is the core concept of this OS.
 *
 * The OS operates in one of two modes:
 *
 *   SAFE_MODE    - Restricted, locked-down environment.
 *                  Only pre-approved actions are allowed.
 *                  Designed for security-sensitive operations.
 *
 *   CREATOR_MODE - Full access, unrestricted environment.
 *                  All tools, compilers, and system features available.
 *                  Designed for development and creation.
 *
 * The state manager controls transitions between these modes and will
 * eventually gate access to subsystems based on the current state.
 * =========================================================================== */

#ifndef STATE_MANAGER_H
#define STATE_MANAGER_H

/* The two fundamental operating states */
typedef enum {
    SAFE_MODE    = 0,   /* Restricted, locked-down */
    CREATOR_MODE = 1    /* Full access, unrestricted */
} os_state_t;

/* Initialize the state manager. Sets default state to SAFE_MODE. */
void state_init(void);

/* Toggle between SAFE_MODE and CREATOR_MODE */
void state_toggle(void);

/* Get the current operating state */
os_state_t state_get_current(void);

/* Print the current state to screen */
void state_print_current(void);

/* ===========================================================================
 * FUTURE HOOKS
 * ===========================================================================
 * - state_set(os_state_t state)       : Force-set a specific state
 * - state_register_callback(fn)       : Register listener for state changes
 * - state_check_permission(action_t)  : Gate actions based on current state
 *
 * BEHAVIOR ENGINE INTEGRATION:
 * - The behavior engine will hook into state transitions to enforce
 *   per-mode security policies and resource limits.
 *
 * APP SYSTEM INTEGRATION:
 * - Apps will query state_get_current() to determine available features.
 * - CREATOR_MODE apps won't load in SAFE_MODE.
 *
 * CREATOR MODE TOOLS:
 * - Code editor, compiler access, debugger, and system introspection
 *   tools will only activate when state == CREATOR_MODE.
 * =========================================================================== */

#endif /* STATE_MANAGER_H */
