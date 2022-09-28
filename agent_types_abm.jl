module AgentTypes
    using Agents: AbstractAgent
    export Cas, Resc

    mutable struct Cas <: AbstractAgent
        const id::Int
        const ts::Int
        status::Symbol # :awaiting_rescue, :in_rescue, :on_way_to_pma, :in_pre_stabilize_q, :in_stabilize_q, :in_post_stabilize_q, :on_way_to_pma, :in_pre_treatment_q, :in_burn_beds, :in_non_burn_beds, :deceased
        rescued_by::Int
        tans_to_hosp_by::Int
        at_pma::String
        status_traject::Vector{Symbol}
        function Cas(id,ts;status=:awaiting_rescue,rescued_by=999,trans_to_hosp_by=999,at_pma=" ", status_traject=[:awaiting_rescue])
            new(id, ts, status, rescued_by, trans_to_hosp_by, at_pma,status_traject)
        end
    end

    mutable struct Resc <: AbstractAgent
        const id::Int
        status::Symbol # :at_iz, :on_way_to_iz, :search_time, :load_cas_at_iz, :at_pma, :load_cas_at_pma, :on_way_to_pma, :at_hosp, :on_way_to_hosp, rescue_finished
        dist_to_agent::Float64
        rescued::Vector{Int}
        which_pma::String   
        dist_traject::Vector{Float64}
        loc_traject::Vector{String}
        search_time::Int
        function Resc(id;status=:at_pma,dist_to_agent=999,rescued = Int[],which_pma = rand(["VX","SM"]),dist_traject=Float64[],loc_traject=String[],search_time = 999)
            new(id,status,dist_to_agent,rescued,which_pma,dist_traject,loc_traject, search_time)
        end
    end
end