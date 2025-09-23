#include "gpio.h"

int main(void)
{
    gpio_t gpio0;

    /* Initialize GPIO */
    gpio_init(&gpio0, GPIO_BASE_ADDRESS);
    
    /* Individual pin operations using pin numbers */
    gpio_set_direction_pin(&gpio0, GPIO_PIN_0, GPIO_DIR_OUTPUT);
    gpio_set_direction_pin(&gpio0, GPIO_PIN_1, GPIO_DIR_OUTPUT);
    
    gpio_write_pin(&gpio0, GPIO_PIN_0, true);  /* Set pin 0 high */
    gpio_toggle_pin(&gpio0, GPIO_PIN_1);       /* Toggle pin 1 */
    
    /* Multiple pin operations using bitmasks */
    gpio_set_outputs(&gpio0, GPIO_PIN_MASK_2 | GPIO_PIN_MASK_3);
    gpio_set_pins(&gpio0, GPIO_PIN_MASK_2 | GPIO_PIN_MASK_3);
    
    /* Read individual pin */
    if (gpio_read_pin(&gpio0, GPIO_PIN_4)) {
        gpio_toggle_pin(&gpio0, GPIO_PIN_0);
    }
    
    return 0;
}