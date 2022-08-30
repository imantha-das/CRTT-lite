module Crtt_Agents

using Agents:AbstractAgent
export Cas, Resc, Pma

mutable struct Cas <: AbstractAgent
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

    function Cas(id, ts, dist_from_vx, dist_from_sm, dist_from_hosp; rescued_by = 999, at_pma = 999, awaiting_rescue = true, in_rescue = false, in_pma_queue = false, in_stabilisation = false, in_burn_beds = false, in_non_burn_beds = false)
        new(id, ts, dist_from_vx, dist_from_sm, dist_from_hosp, rescued_by, at_pma, awaiting_rescue, in_rescue, in_pma_queue, in_stabilisation, in_burn_beds, in_non_burn_beds)
    end
end

mutable struct Resc <: AbstractAgent
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

    function Resc(id;target_id = nothing, to_iz=true,to_pma=false,to_hosp=false,at_iz = false, at_pma=true, at_hosp = false, which_pma = nothing,rescued = [], dist_to_loc = nothing)
        new(id,target_id,to_iz,to_pma, to_hosp,at_iz,at_pma,at_hosp,which_pma,rescued,dist_to_loc)
    end
end

mutable struct Pma <: AbstractAgent
    id::Int
    waiting_queue::Vector{Int64}
    stabilisation_queue::Vector{Int64}
    post_stabilisation_queue::Vector{Int64}
    function Pma(id;waiting_queue=[],stabilisation_queue=[], post_stabilisation_queue=[])
        new(id,waiting_queue,stabilisation_queue,post_stabilisation_queue)
    end
end
end



