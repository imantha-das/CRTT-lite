using Base: Bool
using Agents
using GLMakie 
using InteractiveDynamics


mutable struct CasAgent <: AbstractAgent
    id::Int
    pos::Dims{2}
    TS::Int64
    dist_from_iz::Float64
    awaiting_rescue::Bool
    on_route_pma::Bool
    awaiting_stabilisation::Bool
    in_stabilisation::Bool
    awaiting_hospital_transfer::Bool
    on_route_hospital::Bool
    awaiting_treatment::Bool
    in_treatment_NBB::Bool
    in_treatment_BB::Bool
end

mutable struct RescAgent <: AbstractAgent
    id::Int
    pos::Dims{2}
    targeted_agent::Bool
    rescued_cas::Array{CasAgent}
    dist_to_target::Float64
    mode::String
end

function initialize(;num_ts1 = 97, num_ts2 = 97, num_ts3 = 97)
    dims_rqd = sqrt(num_ts1 + num_ts2 + num_ts3) |> ceil
    space = GridSpace((dims_rqd, dims_rqd), periodic = false)
    model = AgentBasedModel(
        Union{CasAgent,RescAgent}, 
        space,
        scheduler = random_activation
    )

end

