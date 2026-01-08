# Error Handling Guide

## Overview
The software stack provides two levels of error handling:
1. **Software errors**: Function return codes
2. **Hardware errors**: Detected by the Wishbone interconnect

## Error Codes

### Software Error Codes (`system_error_t`)
| Code                          | Value | Description                                   |
|-------------------------------|-------|-----------------------------------------------|
| SYSTEM_SUCCESS                | 0     | Operation successful                          |
| SYSTEM_ERROR_INVALID_PARAM    | -1    | Invalid parameter                             |
| SYSTEM_ERROR_INVALID_ADDRESS  | -7    | Invalid memory address (maps to 0xDEAD_BEEF)  |
| SYSTEM_ERROR_INVALID_SLAVE    | -8    | Invalid peripheral access (maps to 0xBADADD01)|

### Hardware Error Patterns
| Pattern                       | Value         | Meaning                   |
|-------------------------------|---------------|---------------------------|
| HARDWARE_ERROR_INVALID_ADDR   | 0xDEADBEEF    | Access to unmapped memory |
| HARDWARE_ERROR_INVALID_SLAVE  | 0xBADADD01    | Invalid slave selection   |

## Usage Examples

### Basic Error Checking
```c
system_error_t err = gpio_init(&gpio0, GPIO_BASE_ADDRESS);
if (IS_ERROR(err)) {
    // Handle error
    return err;
}
```


### Hardware Error Detection
```c
uint32_t value;
system_error_t err = system_read_word_safe(0x50000000, &value);
if (err == SYSTEM_ERROR_INVALID_ADDRESS) {
    // Hardware returned 0xDEAD_BEEF
    print_string("Error: Invalid memory address\n");
}
```

### Best Practices

1. Always check return values of functions that can fail
2. Use `IS_ERROR()` macro for quick error detection
3. Log hardware errors for debugging
4. Implement graceful degradation when errors occur 