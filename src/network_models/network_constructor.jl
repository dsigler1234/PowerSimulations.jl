function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{CopperPlatePowerModel},
    template::OperationsProblemTemplate,
)
    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, CopperPlatePowerModel)
    end
    copper_plate(optimization_container, :nodal_balance_active, bus_count)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{AreaBalancePowerModel},
    template::OperationsProblemTemplate,
)
    area_mapping = PSY.get_aggregation_topology_mapping(PSY.Area, sys)
    branches = get_available_components(PSY.Branch, sys)
    if get_balance_slack_variables(optimization_container.settings)
        throw(
            IS.ConflictingInputsError(
                "Slack Variables are not compatible with AreaBalancePowerModel",
            ),
        )
    end

    area_balance(optimization_container, :nodal_balance_active, area_mapping, branches)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{StandardPTDFModel},
    template::OperationsProblemTemplate,
)
    buses = PSY.get_components(PSY.Bus, sys)
    ptdf = get_PTDF(optimization_container)

    if ptdf === nothing
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, StandardPTDFModel)
    end

    copper_plate(optimization_container, :nodal_balance_active, length(buses))
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate,
) where {T <: PTDFPowerModel}
    construct_network!(
        optimization_container,
        sys,
        T,
        template;
        instantiate_model = instantiate_nip_ptdf_expr_model,
    )

    add_pm_expr_refs!(optimization_container, T, sys)
    copper_plate(
        optimization_container,
        :nodal_balance_active,
        length(PSY.get_components(PSY.Bus, sys)),
    )

    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate;
    instantiate_model = instantiate_nip_expr_model,
) where {T <: PM.AbstractPowerModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, T)
    end

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(optimization_container, T, sys, template, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)

    return
end

################# my code #################################
function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate,
    partition_number::Int;
    instantiate_model = instantiate_nip_expr_model,
) where {T <: PM.AbstractPowerModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, T)
    end

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(optimization_container, T, sys, template, partition_number, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)
    # have a function that goes in and deletes the nodal balance constraints 
    for gb in get_ghost_buses(PSY.Bus, sys,partition_number)
        name = PSY.get_name(gb)
        JuMP.delete.(optimization_container.JuMPmodel,optimization_container.constraints[:nodal_balance_active__Bus][name,:])
    end

    return
end
###########################################################

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate;
    instantiate_model = instantiate_bfp_expr_model,
) where {T <: PM.AbstractBFModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    get_balance_slack_variables(optimization_container.settings) &&
        add_slacks!(optimization_container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(optimization_container, T, sys, template, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate;
    instantiate_model = instantiate_vip_expr_model,
) where {T <: PM.AbstractIVRModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, T)
    end

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(optimization_container, T, sys, template, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)
    return
end
