/* Rabi 备用模块：固定采样周期的轻量 PID 实现。 */
#include <stddef.h>
#include "rabi_pid.h"

static float clamp_value(float value, float minimum, float maximum)
{
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
}

static bool config_is_valid(const rabi_pid_cfg_t *cfg)
{
    if (cfg == NULL || cfg->sample_time_s <= 0.0f ||
        cfg->output_min >= cfg->output_max ||
        cfg->integral_min > cfg->integral_max ||
        cfg->derivative_filter <= 0.0f ||
        cfg->derivative_filter > 1.0f)
    {
        return false;
    }

    /* NaN 是唯一不等于自身的 float；拒绝后可避免比较/限幅全部失效。 */
    return cfg->kp == cfg->kp && cfg->ki == cfg->ki && cfg->kd == cfg->kd &&
        cfg->sample_time_s == cfg->sample_time_s &&
        cfg->output_min == cfg->output_min &&
        cfg->output_max == cfg->output_max &&
        cfg->integral_min == cfg->integral_min &&
        cfg->integral_max == cfg->integral_max &&
        cfg->derivative_filter == cfg->derivative_filter;
}

rabi_err_t rabi_pid_init(
    rabi_pid_t *pid, const rabi_pid_cfg_t *cfg)
{
    if (pid == NULL || !config_is_valid(cfg))
    {
        return RABI_ERR_INVALID_ARG;
    }

    *pid = (rabi_pid_t){
        .cfg = *cfg,
        .integral = 0.0f,
        .previous_measurement = 0.0f,
        .derivative_state = 0.0f,
        .proportional_term = 0.0f,
        .derivative_term = 0.0f,
        .output = clamp_value(0.0f, cfg->output_min, cfg->output_max),
        .has_previous_measurement = false,
        .initialized = true,
    };
    return RABI_ERR_OK;
}

rabi_err_t rabi_pid_reset(
    rabi_pid_t *pid, float measurement, float output_bias)
{
    if (pid == NULL || !pid->initialized ||
        measurement != measurement || output_bias != output_bias)
    {
        return RABI_ERR_INVALID_ARG;
    }

    pid->integral = clamp_value(
        output_bias, pid->cfg.integral_min, pid->cfg.integral_max);
    pid->previous_measurement = measurement;
    pid->derivative_state = 0.0f;
    pid->proportional_term = 0.0f;
    pid->derivative_term = 0.0f;
    pid->output = clamp_value(
        output_bias, pid->cfg.output_min, pid->cfg.output_max);
    pid->has_previous_measurement = true;
    return RABI_ERR_OK;
}

rabi_err_t rabi_pid_set_gains(
    rabi_pid_t *pid, float kp, float ki, float kd)
{
    if (pid == NULL || !pid->initialized ||
        kp != kp || ki != ki || kd != kd)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /* 允许负增益，便于反向作用对象；首次调试仍应先确认反馈极性。 */
    pid->cfg.kp = kp;
    pid->cfg.ki = ki;
    pid->cfg.kd = kd;
    return RABI_ERR_OK;
}

rabi_err_t rabi_pid_set_sample_time(
    rabi_pid_t *pid, float sample_time_s)
{
    if (pid == NULL || !pid->initialized || sample_time_s <= 0.0f ||
        sample_time_s != sample_time_s)
    {
        return RABI_ERR_INVALID_ARG;
    }

    pid->cfg.sample_time_s = sample_time_s;
    return RABI_ERR_OK;
}

rabi_err_t rabi_pid_update(
    rabi_pid_t *pid,
    float setpoint,
    float measurement,
    float *output)
{
    if (pid == NULL || output == NULL || !pid->initialized ||
        setpoint != setpoint || measurement != measurement)
    {
        return RABI_ERR_INVALID_ARG;
    }

    float error = setpoint - measurement;
    float proportional = pid->cfg.kp * error;

    float derivative_raw = 0.0f;
    if (pid->has_previous_measurement)
    {
        derivative_raw = -(
            measurement - pid->previous_measurement) /
            pid->cfg.sample_time_s;
    }
    else
    {
        pid->has_previous_measurement = true;
    }

    pid->derivative_state += pid->cfg.derivative_filter *
        (derivative_raw - pid->derivative_state);
    float derivative = pid->cfg.kd * pid->derivative_state;

    float integral_candidate = clamp_value(
        pid->integral +
            pid->cfg.ki * error * pid->cfg.sample_time_s,
        pid->cfg.integral_min,
        pid->cfg.integral_max);
    float integral_delta = integral_candidate - pid->integral;
    float candidate = proportional + integral_candidate + derivative;

    /*
     * 输出已经会在高端饱和且 error 还想继续推高，或低端饱和且 error 还想继续
     * 拉低时，冻结积分；反向误差仍允许积分，帮助控制器退出饱和。
     */
    bool blocks_integration =
        (candidate > pid->cfg.output_max && integral_delta > 0.0f) ||
        (candidate < pid->cfg.output_min && integral_delta < 0.0f);
    if (!blocks_integration)
    {
        pid->integral = integral_candidate;
    }

    float unconstrained = proportional + pid->integral + derivative;
    pid->output = clamp_value(
        unconstrained, pid->cfg.output_min, pid->cfg.output_max);
    pid->previous_measurement = measurement;
    pid->proportional_term = proportional;
    pid->derivative_term = derivative;

    *output = pid->output;
    return RABI_ERR_OK;
}

float rabi_pid_get_integral(const rabi_pid_t *pid)
{
    return pid != NULL && pid->initialized ? pid->integral : 0.0f;
}

float rabi_pid_get_output(const rabi_pid_t *pid)
{
    return pid != NULL && pid->initialized ? pid->output : 0.0f;
}
