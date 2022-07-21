# ==============================================================================
# Activate Environemnt
# ==============================================================================
begin
    using Pkg
    Pkg.activate("envs/abm")
end

# ==============================================================================
# Imports
# ==============================================================================

begin
    include("CRTTAgents.jl")
using .Crtt_Agents: Cas, Resc, Pma
end

using Agents: ABM, Schedulers, add_agent!, nagents
using Distributions:Normal

# ------------------------------------------------------------------------------
# Initialise Model
# ------------------------------------------------------------------------------
@doc """
    Notes
    - The pma which is added first is considered to be Vieux Habitants
    - As there are no geospatial elements, distance of casualties from agents are initialised at some distance + random distance following a normal distribution
    - Vieux Habitants Pma is give id 9998, Sainte Marie Pma is given id 9999
""" ->
function initialise(num_cas::Int64,num_resc::Int64)
    model = ABM(
        Union{Cas,Resc,Pma},
        scheduler = Schedulers.fastest,
        properties = Dict(
            :ticks => 0, 
            :dist_per_step => 50.,
            :dist_from_9998 => 2000.,
            :dist_from_9999 => 2500.,
            :dist_from_hosp => 10000.,
            :μ_dist => 0,
            :σ_dist => 100,
            :decisions => ["to_iz","to_pma","to_hospital"]
        )
    )

    # Add Casualties
    for i = 1:num_cas
        cas = Cas(
            i,
            rand([1,2,3]),
            model.dist_from_9998 + rand(Normal(model.μ_dist, model.σ_dist)), #distance from Vieux Habitants
            model.dist_from_9999 + rand(Normal(model.μ_dist, model.σ_dist)), #distance from Sainte Marie
            model.dist_from_hosp
        )
        add_agent!(cas, model)
    end

    # Add Rescuers 
    for i = nagents(model) + 1:nagents(model) + num_resc
        resc = Resc(
            i;
            which_pma = rand([9998,9999])
        )
        add_agent!(resc,model)
    end

    # Add Pma
    add_agent!(Pma(9998), model)
    add_agent!(Pma(9999), model)

    return model
end

# ------------------------------------------------------------------------------
# Filter  Rescuers / Casualties
# ------------------------------------------------------------------------------

@doc"""
Filters 
    - Rescuers
    - target_id == nothing
""" ->
filter_inactive_rescuers(model::ABM) = filter(
        r -> (isa(model[r], Resc) && isnothing(model[r].target_id)), 
        model.agents |> keys
    ) 

@doc"""
Filters
    - Casualties 
    - awaiting_rescue == true
"""
filter_awaiting_rescue_casualties(model::ABM) = filter(
    c-> (isa(model[c], Cas) && model[c].awaiting_rescue == true), 
    model.agents |> keys 
)

# ------------------------------------------------------------------------------
# Find Closest Agent
# ------------------------------------------------------------------------------
@doc"""
Note this method doesnt account for the best combination of rescuer to casualties like munkres algorithm.
However as 
""" ->
function find_closest_cas!(model)
    for r in filter_inactive_rescuers(model)
        closest_dist = Inf
        closest_casid = nothing
        for c in filter_awaiting_rescue_casualties(model)
            if model[r].which_pma == 9998
                dist_to_cas = model[c].dist_from_vx
                if dist_to_cas < closest_dist
                    closest_dist = dist_to_cas
                    closest_casid = c
                else
                    #Dont do anything
                end 
            else
                dist_to_cas = model[c].dist_from_sm 
                if dist_to_cas < closest_dist
                    closest_dist = dist_to_cas 
                    closest_casid = c 
                else
                    # Dont do anything
                end
            end
        end
        # Update Agent Attributes
        model[r].dist_to_loc = closest_dist 
        model[r].to_iz = true
        model[r].target_id = closest_casid
        model[closest_casid].awaiting_rescue = false 
        model[closest_casid].rescued_by = r
    end
end


# ------------------------------------------------------------------------------
# Travel to IZ
# ------------------------------------------------------------------------------
@doc"""
Should work when agents are at PMA
"""
function travel_to_iz(model)
    find_closest_cas!(model)

end

# ==============================================================================
# Main
# ==============================================================================

#= Rescuer Params
    id::Int
    target_id::Union{Int,Nothing} #id of rescue casualty, pma or hospital
    to_iz::Bool # Boolean value to be switched on while travelling to a Impact Zone (where casualties are)
    to_pma::Bool # Boolean to be switched on if travelling to PMA 
    to_hosp::Bool # Boolean to be switched on if travelling to Hospital
    at_iz::Bool #Boolean to be switched on once in impact zone
    at_pma::Bool #! Decision point, travel to impact-zone/hospital while not considering first run (has to be Impact Zone)
    at_hosp::Bool #Boolean to be switched on once at hospital
    which_pma::Union{Int,Nothing} #Stores in which PMA you are located
    rescued::Vector{Int} # Rescued agents
    dist_to_loc::Union{Float64,Nothing} #Stores distance from where ever you are to

    id::Int 
    ts::Int 
    dist_from_vx::Float64 
    dist_from_sm::Float64
    dist_from_hosp::Float64
    rescued_by::Int
    at_pma::Int #which pma - sm or vx
    awaiting_rescue::Bool 
    in_rescue::Bool 
    in_pma_queue::Bool
    in_stabilisation::Bool 
    in_burn_beds::Bool 
    in_non_burn_beds::Bool
=#

# Initialise Model
model = initialise(20,5)
# Filter inactive rescuers
find_closest_cas(model)

