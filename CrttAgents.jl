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

    function Cas(id, ts; dist_from_vx, dist_from_sm, dist_from_hosp, rescued_by, at_pma, awaiting_rescue = true, in_rescue = false, in_pma_queue = false, in_stabilisation = false, in_burn_beds = false, in_non_burn_beds = false)
        new(id, ts, dist_from_vx, dist_from_sm, dist_from_hosp, rescued_by, at_pma, awaiting_rescue, in_rescue, in_pma_queue, in_stabilisation, in_burn_beds, in_non_burn_beds)
    end
end

mutable struct Resc <: AbstractAgent
    id::Int
    to_impact_zone::Bool # Boolean value to be switched on while travelling to a casualty
    to_medical::Bool # Boolean to be switched on while travelling to pma/hospital
    at_pma::Bool # Decision point, travel to impact-zone/hospital while run != 1
    decisions::Vector{String} #Decision choices
    dist_to_loc::Float64 #Countdown till you arrive at location

    function Resc(id;to_impact_zone=true,to_medical=false,at_pma=true,decision=["to_iz","to_pma","to_hosp"], dist_to_loc = 999)
        new(id,to_impact_zone,to_medical,to_pma,at_pma,decision,dist_to_loc)
    end
end



