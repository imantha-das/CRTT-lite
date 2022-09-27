begin
    using Pkg 
    Pkg.activate("envs/crtt")
end

begin
    include("agent_types_abm.jl")
    include("pma_hosp_funcs.jl")
    include("cas_funcs.jl")
    include("resc_funcs.jl")
end

begin
    using .AgentTypes: Cas, Resc
    using .PmaHosp: vx, sm, ptp
    using .RescFuncs: update_rescuers_at_pma!
end


(using Agents:
    ABM, Schedulers, add_agent!, nextid
)


using DrWatson:@dict

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
    :stab_cap => 3, #no of casualties that can be taken into stabilization
    :stab_time_ticks => 20, #time taken for stabilization
    :resc_cap => 2,
    :post_stabilize_cap => 3, #to be taken to hosp if above this value
    :burn_bed_cap => 5,
    :non_burn_bed_cap => 10,
    :vx => vx(), #pre_stabilize_q, in_stabilize_q, post_stabilize_q
    :sm => sm(), 
    :ptp => ptp()
)


# ==============================================================================
#  Main Run
# ==============================================================================
model = initalise(10,2,properties)

for i = 1:500
    update_rescuers_at_pma!(model)
end

