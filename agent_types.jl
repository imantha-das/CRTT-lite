# Casualty 
# ---------------------------------------------------------------------------------------------------
module Agent_Types
using Agents: AbstractAgent

export Casualty, Rescuer, PMA
mutable struct Casualty <: AbstractAgent
    id::Int 
    pos::Tuple{Int,Int,Float64} #(i,j,x) --> position on the road inbetween nodes
    trauma::Int
    awaiting_rescue::Bool
    in_rescue::Bool
    in_pma_queue::Bool
    in_stabilisation::Bool
    in_burn_beds::Bool
    in_non_burn_beds::Bool
    rescued_by::Int
    at_pma::Int
    destination::Tuple{Int,Int,Float64}
    route::Vector{Int}
    function Casualty(
        id::Int, 
        pos::Tuple{Int,Int,Float64};
        trauma::Int,
        awaiting_rescue::Bool=true,
        in_rescue::Bool=false,
        in_pma_queue::Bool=false,
        in_stabilisation::Bool=false,
        in_burn_beds::Bool=false, 
        in_non_burn_beds::Bool=false,
        rescued_by::Int=999,
        at_pma::Int=999,
        destination::Tuple{Int,Int,Float64}=pos,
        route::Vector{Int}=Int[]
        )

        new(
            id,
            pos,
            trauma,
            awaiting_rescue,
            in_rescue,
            in_pma_queue,
            in_stabilisation,
            in_burn_beds,
            in_non_burn_beds,
            rescued_by,
            at_pma,
            destination,
            route
        )
    end
end

# Rescuer
# --------------------------------------------------------------------------------------------------
mutable struct Rescuer <: AbstractAgent
    id::Int 
    pos::Tuple{Int,Int,Float64}
    awaiting_instructions::Bool
    rescuing_in_progress::Bool
    to_medical::Bool
    destination::Tuple{Int,Int,Float64} 
    route::Vector{Int}
    travel_to::Int
    casualties_rescued::Vector{Int}

    function Rescuer(
        id::Int,
        pos::Tuple{Int,Int,Float64};
        awaiting_instructions::Bool=true,
        rescuing_in_progress::Bool=false,
        to_medical::Bool=false,
        destination::Tuple{Int,Int,Float64}=(0,0,0.),
        route::Vector{Int}=Int[],
        travel_to::Int=999,
        casualties_rescued::Vector{Int}=Int[]
    )
        new(
            id,
            pos,
            awaiting_instructions,
            rescuing_in_progress,
            to_medical,destination,
            route,
            travel_to,
            casualties_rescued
        )
    end
end

# PMA
# ---------------------------------------------------------------------------------------------------
mutable struct PMA <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int,Float64}
    queue::Vector{Tuple{Int,Int}}
    stabilisation::Vector{Tuple{Int,Int}}

    function PMA(
        id::Int,
        pos::Tuple{Int,Int,Float64};
        queue::Vector{Tuple{Int,Int}} = Vector{Tuple{Int,Int}}(undef,0),
        stabilisation::Vector{Tuple{Int,Int}} = Vector{Tuple{Int,Int}}(undef,0)
    )
        new(
            id,
            pos,
            queue,
            stabilisation
        )
    end
end
end
 

