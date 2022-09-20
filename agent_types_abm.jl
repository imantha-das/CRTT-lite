module AgentTypes
    using Agents: AbstractAgent
    export Cas, Resc

    mutable struct Cas <: AbstractAgent
        const id::Int
        const ts::Int
        status::Symbol # :awaiting_rescue, :in_rescue, :on_way_to_pma, :pre_stabilize_q, :in_stabilize_q, :post_stabilize_q, :on_way_to_pma, :pre_treatment_q, :in_burn_beds, :in_non_burn_beds, :deceased
        dist_from_iz::Float64
        rescued_by::Int
        tans_to_hosp_by::Int
        at_pma::String
        status_traject::Vector{Symbol}
        function Cas(id,ts;status=:awaiting_rescue, dist_from_iz = rand(1:1000),rescued_by=999,trans_to_hosp_by=999,at_pma=" ", status_traject=[])
            new(id, ts, status, dist_from_iz, rescued_by, trans_to_hosp_by, at_pma,status_traject)
        end
    end

    mutable struct Resc <: AbstractAgent
        const id::Int
        status::Symbol # :at_iz, :on_way_to_iz, :at_cas, :on_way_to_cas, :at_pma, :on_way_to_pma, :at_hosp, :on_way_to_hosp
        cas_in_rescue::Int
        dist_to_agent::Float64
        rescued::Vector{Int}
        which_pma::String   
        dist_traject::Vector{Float64}
        loc_traject::Vector{String}

        function Resc(id;status=:at_pma,cas_in_rescue=999,dist_to_agent=999,rescued = Int[],which_pma = rand(["VX","SM"]),dist_traject=Float64[],loc_traject=String[])
            new(id,status,cas_in_rescue,dist_to_agent,rescued,which_pma,dist_traject,loc_traject)
        end
    end
end