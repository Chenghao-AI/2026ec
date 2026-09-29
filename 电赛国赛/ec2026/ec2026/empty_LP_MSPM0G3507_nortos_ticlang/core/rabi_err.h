/* Rabi 核心模块：公共错误码。 */
#pragma once

#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif

typedef int32_t rabi_err_t;

#define RABI_ERR_OK 0
#define RABI_ERR_FAIL -1

#define RABI_ERR_NO_MEMORY -2
#define RABI_ERR_NO_RESOURCES -3
#define RABI_ERR_INVALID_ARG -4
#define RABI_ERR_INVALID_SIZE -5

#define RABI_ERR_INVALID_STATE -6
#define RABI_ERR_NOT_FOUND -7
#define RABI_ERR_NOT_SUPPORTED -8

#define RABI_ERR_BUSY -9
#define RABI_ERR_TIMEOUT -10

#if defined(__cplusplus)
}
#endif
