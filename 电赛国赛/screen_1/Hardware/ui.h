#ifndef UI_H
#define UI_H

#include <stdint.h>

typedef struct {
    uint16_t background;
    uint16_t header;
    uint16_t panel;
    uint16_t panelAlternate;
    uint16_t primaryText;
    uint16_t secondaryText;
    uint16_t accent;
    uint16_t success;
} UITheme;

extern const UITheme UI_THEME_DARK;

void UI_DrawPageFrame(const char *title, const char *status,
                      const UITheme *theme);
void UI_DrawCard(uint16_t x, uint16_t y, uint16_t width,
                 uint16_t height, const char *label, const char *value,
                 uint16_t accent, const UITheme *theme);

/* Existing demonstration pages. They also serve as examples of the generic
 * Graphics_* and Plot_* APIs. */
void UI_Init(void);
void UI_HandleKey(uint8_t key);
void UI_ShowSpectrum(void);
void UI_ShowPeriodicSignal(void);

#endif
