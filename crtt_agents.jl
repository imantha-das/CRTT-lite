module CrttAgents
    using Agents: AbstractAgent
    
    export Cas, Resc, Hosp, Pma

    @enum Actions IZ PMA HOSP
    mutable struct Cas <: AbstractAgent
        const id::Int
        const ts::Int 
        dist_from_iz::Float64
        rescued_by::Int
        tans_to_hosp_by::Int
        at_pma::String
        awaiting_rescue::Bool #true when a rescuer has not targeted (not coming to rescue) casualty
        in_rescue::Bool #true when a rescuer is coming to rescue
        on_way_to_pma::Bool
        in_pma_queue::Bool
        in_stabilization::Bool
        on_way_to_hosp::Bool
        in_hosp_queue::Bool
        in_burn_beds::Bool
        in_non_burn_beds::Bool
        is_deceased::Bool

        function Cas(id,ts;dist_from_iz = rand(1:1000),rescued_by=999,trans_to_hosp_by=999,at_pma=" ",awaiting_rescue=true,in_rescue=false,on_way_to_pma = false,in_pma_queue=false,in_stabilization=false,on_way_to_hosp=false,in_hosp_queue=false,in_burn_beds=false,in_non_burn_beds=false,is_deceased = false)
            new(id, ts, dist_from_iz, rescued_by, trans_to_hosp_by, at_pma, awaiting_rescue,in_rescue,on_way_to_pma,in_pma_queue,in_stabilization,on_way_to_hosp,in_hosp_queue,in_burn_beds,in_non_burn_beds, is_deceased)

        end
    end

    mutable struct Resc <: AbstractAgent
        const id::Int
        cas_in_rescue::Int
        dist_to_agent::Float64
        rescued::Vector{Int}
        which_pma::String
        at_iz::Bool
        on_way_to_iz::Bool
        at_cas::Bool 
        on_way_to_cas::Bool
        at_pma::Bool
        on_way_to_pma::Bool
        at_hosp::Bool
        on_way_to_hosp::Bool
        action::Any
        dist_traject::Vector{Float64}
        loc_traject::Vector{String}

        function Resc(id;cas_in_rescue=999,dist_to_agent=999,rescued = Int[],which_pma = rand(["VX","SM"]),at_iz = false, on_way_to_iz = false, at_cas = false, on_way_to_cas = false, at_pma = true, on_way_to_pma = false, at_hosp = false, on_way_to_hosp=false,action=nothing,dist_traject=Float64[],loc_traject=String[])
            new(id,cas_in_rescue,dist_to_agent,rescued,which_pma,at_iz,on_way_to_iz,at_cas,on_way_to_cas,at_pma,on_way_to_pma,at_hosp,on_way_to_hosp,action,dist_traject,loc_traject)
        end
    end

    # mutable struct Pma <: AbstractAgent
    #     const id::Int
    #     name::String
    #     pre_stabilize_queue::Vector{Int} 
    #     in_stabilization::Vector{Tuple{Int,Int}} #[(Cas_id, ticks), ...]
    #     post_stabilize_queue::Vector{Int}

    #     function Pma(id;name="VX", pre_stabilize_queue=[],in_stabilization=[],post_stabilize_queue=[])
    #         new(id,name,pre_stabilize_queue,in_stabilization,post_stabilize_queue)
    #     end
    # end

    # mutable struct Hosp <: AbstractAgent
    #     const id::Int 
    #     pre_treatment_queue::Vector{Int}
    #     burn_beds::Vector{Int}
    #     non_burn_beds::Vector{Int}

    #     function Hosp(id;pre_treatment_queue=[],burn_beds=[],non_burn_beds=[])
    #         new(id,pre_treatment_queue,burn_beds,non_burn_beds)
    #     end
    # end
end