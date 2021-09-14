const PARTITION_ZONE_TO_BUS_NUMBER = Dict{Int, Vector{Int}}

function read_partition_mapping(filename::AbstractString)
    data = open(filename) do io
        JSON.parse(io)
    end

    return PARTITION_ZONE_TO_BUS_NUMBER(parse(Int, k) => v for (k, v) in data)
end

"""
Record partition zones in system components per the mapping in filename.
"""
function partition_system!(sys::PSY.System, filename::AbstractString)
    partition_system!(sys, read_partition_mapping(filename))
    @info "Partitioned system with" filename
end

function partition_system!(sys::PSY.System, bus_mapping::PARTITION_ZONE_TO_BUS_NUMBER)
    bus_number_to_bus = Dict(PSY.get_number(x) => x for x in PSY.get_components(PSY.Bus, sys))

    for (partition_zone, bus_numbers) in bus_mapping
        for bus_number in bus_numbers
            bus = bus_number_to_bus[bus_number]
            set_partition_zone!(bus, partition_zone)
        end
    end

    for branch in PSY.get_components(PSY.Branch, sys)
        arc = PSY.get_arc(branch)
        from_bus = PSY.get_from(arc)
        from_partition_zone = get_partition_zone(from_bus)
        to_bus = PSY.get_to(arc)
        to_partition_zone = get_partition_zone(to_bus)
        if from_partition_zone != to_partition_zone
            _set_spanned_info!(from_bus, PSY.get_name(to_bus), PSY.get_name(branch))
            _set_spanned_info!(to_bus, PSY.get_name(from_bus), PSY.get_name(branch))
        end
    end
end

"""
Set the partition zone containing the bus.
"""
function set_partition_zone!(bus::PSY.Bus, partition_zone::Int)
    ext = PSY.get_ext(bus)
    ext["partition_zone"] = partition_zone
    @debug "Set bus partition zone" PSY.get_number(bus) partition_zone
end

# function _set_spanned_info!(bus::PSY.Bus, connected_bus::AbstractString, branch::AbstractString)
#     ext = PSY.get_ext(bus)
#     ext["connected_spanned_bus"] = connected_bus
#     ext["spanned_branch"] = branch
#     @debug "Found spanned branch" PSY.get_name(bus) connected_bus branch
# end
function _set_spanned_info!(bus::PSY.Bus, connected_bus::AbstractString, branch::AbstractString)
    ext = PSY.get_ext(bus)

    if !haskey(ext, "connected_spanned_buses")
        ext["connected_spanned_buses"] = Vector()
    end
    push!(ext["connected_spanned_buses"],connected_bus)

    if !haskey(ext, "spanned_branches")
        ext["spanned_branches"] = Vector()
    end
    push!(ext["spanned_branches"],branch)
end


"""
Return the partition zone in which component resides.
"""
get_partition_zone(component::T) where {T <: PSY.Component} = error("not implemented for $T")
get_partition_zone(bus::PSY.Bus) = PSY.get_ext(bus)["partition_zone"]
get_partition_zone(device::PSY.StaticInjection) = get_partition_zone(PSY.get_bus(device))

# get_connected_spanned_bus_name(bus::PSY.Bus) = _get_ext_field(bus, "connected_spanned_bus")
# get_spanned_branch_name(bus::PSY.Bus) = _get_ext_field(bus, "spanned_branch")
get_connected_spanned_bus_names(bus::PSY.Bus) = _get_ext_field(bus, "connected_spanned_buses")
get_spanned_branch_names(bus::PSY.Bus) = _get_ext_field(bus, "spanned_branches")+

"""
Return the connected bus if that bus is in a different partition zone.
Otherwise, return nothing.
"""
# function get_connected_spanned_bus(sys::PSY.System, bus::PSY.Bus) 
#     name = get_connected_spanned_bus_name(bus)
#     isnothing(name) && return nothing
#     return PSY.get_component(PSY.Bus, sys, name)
# end

function get_connected_spanned_buses(sys::PSY.System, bus::PSY.Bus) 
    names = get_connected_spanned_bus_names(bus)
    if isnothing(names) 
        return nothing
    else
        comps = Vector()
        for name in names 
            comp = PSY.get_component(PSY.Bus, sys, name)
            push!(comps,comp)
        end
        return comps
    end
end

"""
Return a branch if the bus is connected a bus in a different partition zone.
Otherwise, return nothing.
"""
# function get_spanned_branch(sys::PSY.System, bus::PSY.Bus) 
#     name = get_spanned_branch_name(bus)
#     isnothing(name) && return nothing
#     return PSY.get_component(PSY.Branch, sys, name)
# end

function get_spanned_branches(sys::PSY.System, bus::PSY.Bus) 
    names = get_spanned_branch_names(bus)
    if isnothing(names) 
        return nothing
    else
        comps = Vector()
        for name in names 
            comp = PSY.get_component(PSY.Branch, sys, name)
            push!(comps,comp)
        end
        return comps
    end
end

"""
Return partition zones for bus. If the bus is connected to a bus in a different partition
zone, that zone is included.
"""
# function get_partition_zones(sys::PSY.System, bus::PSY.Bus; ghostbuses::Bool)
#     partition_zones = [get_partition_zone(bus)]
#     if ghostbuses == true
#         spanned_bus = get_connected_spanned_bus(sys, bus)
#         if !isnothing(spanned_bus)
#             push!(partition_zones, get_partition_zone(spanned_bus))
#         end
#     end
#     return partition_zones
# end 

function get_partition_zones(sys::PSY.System, bus::PSY.Bus; ghostbuses::Bool)
    partition_zones = [get_partition_zone(bus)]
    if ghostbuses == true
        spanned_buses = get_connected_spanned_buses(sys, bus)
        if !isnothing(spanned_buses)
            for spanned_bus in spanned_buses
                push!(partition_zones, get_partition_zone(spanned_bus))
            end
        end
    end
    return partition_zones
end 
"""
Return partition zones of buses to which branch is connected.
"""
function get_partition_zones(branch::PSY.Branch)
    from_partition_zone, to_partition_zone = _from_to_partition_zones(branch)
    if from_partition_zone == to_partition_zone
        return [from_partition_zone]
    end

    return [from_partition_zone, to_partition_zone]
end

"""
Return StaticInjection devices with buses in partition.
"""
function get_components(::Type{T}, sys::PSY.System, partition::Int) where {T <: PSY.StaticInjection}
    return PSY.get_components(T, sys, x -> get_partition_zone(x) == partition)
end

"""
Return buses in partition. Include buses in a different partition that are connected to a
bus in partition.
"""
function get_components(::Type{PSY.Bus}, sys::PSY.System, partition::Int; ghostbuses::Bool)
    return PSY.get_components(PSY.Bus, sys, x -> partition in Set(get_partition_zones(sys, x, ghostbuses = ghostbuses)))
end

function _get_ext_field(component::PSY.Component, field)
    ext = PSY.get_ext(component)
    return PSY.get(ext, field, nothing)
end

function _from_to_partition_zones(branch::PSY.Branch)
    arc = PSY.get_arc(branch)
    from_bus = PSY.get_from(arc)
    from_partition_zone = get_partition_zone(from_bus)
    to_bus = PSY.get_to(arc)
    to_partition_zone = get_partition_zone(to_bus)
    return from_partition_zone, to_partition_zone
end
  

function create_partitions(sys::PSY.System)
    areas = [PSY.get_name(x) for x in PSY.get_components(Area, sys)]
    partition_to_bus_numbers = PARTITION_ZONE_TO_BUS_NUMBER()
    for bus in PSY.get_components(Bus, sys)
        area = parse(Int, get_name(get_area(bus)))
        if !haskey(partition_to_bus_numbers, area)
            partition_to_bus_numbers[area] = Vector{Int}()
        end
        push!(partition_to_bus_numbers[area], PSY.get_number(bus))
    end

    sort!(collect(keys(partition_to_bus_numbers))) == [1, 2, 3]
    path, io = mktemp()
    try
        text = JSON.json(partition_to_bus_numbers)
        write(io, JSON.json(partition_to_bus_numbers))
    finally
        close(io)
    end

    return path
end

function get_available_components(::Type{T}, sys::PSY.System, partition_number) where {T <: PSY.Component}
    return PSY.get_components(T, sys, x -> (PSY.get_available(x) && (get_partition_zone(x) == partition_number)))
end

# the get components I defined should work because get_available is not a thing with buses
# function get_available_components(::Type{PSY.Bus}, sys::PSY.System, partition::Int; ghostbuses::Bool)
#     return PSY.get_components(PSY.Bus, sys, x -> partition in Set(get_partition_zones(sys, x, ghostbuses = ghostbuses)))
# end

function get_available_components(::Type{T}, sys::PSY.System, partition::Int) where {T <: PSY.ACBranch}
    return PSY.get_components(T, 
    sys,
    x -> ( PSY.get_available(x) && (PSY.get_to(PSY.get_arc(x)) in PSI.get_components(PSY.Bus, sys, partition,ghostbuses=true)) &&  (PSY.get_from(PSY.get_arc(x)) in PSI.get_components(PSY.Bus, sys, partition,ghostbuses=true)) ))
end

function get_available_components(::Type{T}, sys::PSY.System, partition::Int) where {T <: PSY.DCBranch}
    return PSY.get_components(T, 
    sys,
    x -> ( PSY.get_available(x) && (PSY.get_to(PSY.get_arc(x)) in PSI.get_components(PSY.Bus, sys, partition,ghostbuses=true)) &&  (PSY.get_from(PSY.get_arc(x)) in PSI.get_components(PSY.Bus, sys, partition,ghostbuses=true)) ))
end

function get_ghost_buses(::Type{PSY.Bus}, sys::PSY.System, partition::Int)
    return PSY.get_components(PSY.Bus,
     sys, 
     x -> (x in get_components(PSY.Bus, sys,partition,ghostbuses=true)) && !(x in get_components(PSY.Bus, sys,partition,ghostbuses=false)) )
end

