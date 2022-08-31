module CrttAgents
    using Agents: AbstractAgent
    
    export Cas, Resc

    mutable struct Cas <: AbstractAgent
        const id::Int
        const ts::Int 
        dist_from_iz::Float64
        rescued_by::Int
        tans_to_hosp_by::Int
        at_pma::Int
        awaiting_rescue::Bool 
        in_rescue::Bool
        in_pma_queue::Bool
        in_stabilization::Bool
        on_way_to_hosp::Bool
        in_hosp_queue::Bool
        in_burn_beds::Bool
        in_non_burn_beds::Bool

        function Cas(id,ts;dist_from_iz = rand(1:1000),rescued_by=999,trans_to_hosp_by=999,at_pma=999,awaiting_rescue=true,in_rescue=false,in_pma_queue=false,in_stabilization=false,on_way_to_hosp=false,in_hosp_queue=false,in_burn_beds=false,in_non_burn_beds=false)
            new(id, ts, dist_from_iz, rescued_by, trans_to_hosp_by, at_pma, awaiting_rescue,in_rescue,in_pma_queue,in_stabilization,on_way_to_hosp,in_hosp_queue,in_burn_beds,in_non_burn_beds)

        end
    end

    mutable struct Resc <: AbstractAgent
        const id::Int
        action::DataType
        rescued::Vector{Int}
        dist_to_iz::Float64
        dist_to_vx::Float64
        dist_to_sm::Float64
        dist_to_hosp::Float64
        at_iz::Bool
        on_way_to_iz::Bool
        at_pma::Bool
        on_way_to_pma::Bool
        at_hosp::Bool
        on_way_to_hosp::Bool

        function Resc(id;action=IZ,rescued = Int[],dist_to_iz=999,dist_to_vx=999,dist_to_sm=999,dist_to_hosp=999,at_iz = false, on_way_to_iz = false, at_pma = true, on_way_to_pma = false, at_hosp = false, on_way_to_hosp=false)
            new(id,action,rescued,dist_to_iz,dist_to_vx,dist_to_sm,dist_to_hosp,at_iz,on_way_to_iz,at_pma,on_way_to_pma,at_hosp,on_way_to_hosp)
        end
    end

    mutable struct PMA <: AbstractAgent
        const id::Int
        name::String
        pre_stabilize_queue::Vector{Int} 
        in_stabilization::Vector{Tuple{Int,Int}} #[(Cas_id, ticks), ...]
        post_stabilize_queue::Vector{Int}

        function PMA(id;name="VX", pre_stabilize_queue=[],in_stabilization=[],post_stabilize_queue=[])
            new(id,name,pre_stabilize_queue,in_stabilization,post_stabilize_queue)
        end
    end

    mutable struct Hosp <: AbstractAgent
        const id::Int 
        pre_treatment_queue::Vector{Int}
        burn_beds::Vector{Int}
        non_burn_beds::Vector{Int}

        function Hosp(id;pre_treatment_queue=[],burn_beds=[],non_burn_beds=[])
            new(id,pre_treatment_queue,burn_beds,non_burn_beds)
        end
    end
end