# These 3 methods are defined on concrete formulations of the branches to avoid ambiguity
construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranch},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchBounds},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.DCBranch, <:AbstractDCLineFormulation},
    ::Union{Type{CopperPlatePowerModel}, Type{AreaBalancePowerModel}},
) = nothing

construct_device!(
    ::OptimizationContainer,
    ::PSY.System,
    ::DeviceModel{<:PSY.ACBranch, StaticBranchUnbounded},
    ::Type{<:PM.AbstractPowerModel},
) = nothing

# For DC Power only. Implements constraints
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end
################### my code ###################
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
    partition_number,
) where {B <: PSY.ACBranch, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(B, sys, partition_number)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end
################################################

# For DC Power only
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(optimization_container, S, devices, StaticBranch())
    branch_flow_values!(optimization_container, devices, model, S)
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranchBounds},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(optimization_container, S, devices, StaticBranchBounds())
    branch_flow_values!(optimization_container, devices, model, S)
    branch_rate_bounds!(optimization_container, devices, model, S)
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranchUnbounded},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: StandardPTDFModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(optimization_container, S, devices, StaticBranchUnbounded())
    branch_flow_values!(optimization_container, devices, model, S)
    return
end

# For AC Power only. Implements Bounds on the active power and rating constraints on the aparent power
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranch},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_bounds!(optimization_container, devices, model, S)
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, StaticBranchBounds},
    ::Type{S},
) where {B <: PSY.ACBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_bounds!(optimization_container, devices, model, S)
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, <:AbstractDCLineFormulation},
    ::Type{S},
) where {B <: PSY.DCBranch, S <: PM.AbstractPowerModel}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, U},
    ::Type{S},
) where {
    B <: PSY.DCBranch,
    U <: Union{HVDCLossless, HVDCUnbounded},
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(optimization_container, FlowActivePowerVariable, devices, U())
    add_variable_to_expression!(optimization_container, devices, model, S)
    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{B, U},
    ::Type{S},
) where {
    B <: PSY.DCBranch,
    U <: AbstractDCLineFormulation,
    S <: Union{StandardPTDFModel, PTDFPowerModel},
}
    devices = get_available_components(B, sys)
    if !validate_available_devices(B, devices)
        return
    end

    add_variables!(optimization_container, FlowActivePowerVariable, devices, U())

    branch_rate_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    return
end
