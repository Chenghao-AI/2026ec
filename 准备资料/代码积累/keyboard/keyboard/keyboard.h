#ifndef KEYBOARD_KEYBOARD_H_
#define KEYBOARD_KEYBOARD_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Returned when no single, stable key is detected. */
#define KEYBOARD_NO_KEY ((uint8_t) 0U)

/**
 * Scan the 4x4 matrix keyboard once and debounce the detected key.
 *
 * @return 1..16 for one stable key, or KEYBOARD_NO_KEY when no key is
 *         pressed, the input is bouncing, or more than one key is detected.
 *
 * SYSCFG_DL_init() must be called once before this function is used.
 */
uint8_t keyboard_get_key(void);

#ifdef __cplusplus
}
#endif

#endif /* KEYBOARD_KEYBOARD_H_ */
