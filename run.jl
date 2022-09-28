begin
    using Pkg 
    Pkg.activate("envs/crtt")
end

begin
    include("agent_types_abm.jl")
    include("cas_funcs.jl")
    include("pma_hosp_funcs.jl")
    include("resc_funcs.jl")
    include("utils.jl")
end

begin
    using .AgentTypes: Cas, Resc
    using .PmaHosp: vx, sm, ptp, update_pma_q!
    (using .RescFuncs: 
        update_resc_at_pma!, 
        update_resc_at_iz!, 
        update_resc_searching_cas!, 
        update_resc_load_cas_at_iz!,
        travel_to_loc
    )
    #using .CasFuncs: update_cas_status! #required for pma_hosp_funcs
    using .Utils:plot_resc_traject
end

using Distributions: Normal
(using Agents:
    ABM, Schedulers, add_agent!, nextid
)


using DrWatson:@dict
# ------------------------------------------------------------------------------
# To be move to utils
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# Initialise
# ------------------------------------------------------------------------------
@doc """Initilise ABM with Casualties and Rescuers"""
function initalise(num_cas::Int64,num_resc::Int64,properties::Dict)
    # Define a model
    model = ABM(
        Union{Cas, Resc},
        scheduler = Schedulers.ByType((Resc,Cas), true),
        properties = properties
    )
    # Add Casualties
    map(_ -> Cas(nextid(model),rand([1,2,3])) 
            |> cas -> add_agent!(cas,model), 
            1:num_cas
    ) 
    # Add Rescuers 
    map(_ -> Resc(nextid(model))
            |> resc -> add_agent!(resc, model),
            1:num_resc
    )
    return model
end

properties = Dict(
    :ticks => 0,
    :dist_vx_iz => 15000, #15 km
    :dist_sm_iz => 32000, #32 km
    :dist_vx_hosp => 57000, #57 km
    :dist_sm_hosp => 27000, #27 km
    :dist_per_step => 30000 / 60, # 30km/h = 500m/min
    :stab_opening_ticks => 180, #no of ticks when the stabilization opens up
    :stab_cap => 3, #no of casualties that can be stabalized 
    :stab_time_ticks => 20, #time taken for stabilization
    :resc_cap => 2,
    :hosp_transfer_cap => 3, #to be taken to hosp if above this value
    :burn_bed_cap => 5,
    :non_burn_bed_cap => 10,
    :vx => vx(), #pre_stabilize_q, in_stabilize_q, post_stabilize_q
    :sm => sm(), 
    :ptp => ptp(),
    :search_time => Normal(10,10)
)


# ==============================================================================
#  Main Run
# ==============================================================================
model = initalise(10,2,properties)

for i = 1:1000
    update_pma_q!(model)
    update_resc_at_pma!(model)
    update_resc_at_iz!(model)
    update_resc_searching_cas!(model)
    update_resc_load_cas_at_iz!(model)
    travel_to_loc(model)

    model.ticks += 1
end

