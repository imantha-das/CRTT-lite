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
        dist_to_iz::Float64
        dist_to_vx::Float64
        dist_to_sm::Float64
        dist_to_hosp::Float64
        rescued::Vector{Int}
        at_iz::Bool
        on_way_to_iz:Bool
        at_pma::Bool
        on_way_to_pma::Bool
        at_hosp::Bool
        on_way_to_hosp::Bool

        function Resc(id;dist_to_iz=999,dist_to_vx=999,dist_to_sm=999,dist_to_hosp=999,rescued = Int[],at_iz = false, on_way_to_iz = false, at_pma = true, on_way_to_pma = false, at_hosp = false, on_way_to_hosp=false)
            new(id, dist_to_iz,dist_to_vx,dist_to_sm,dist_to_hosp,rescued,at_iz,on_way_to_iz,at_pma,on_way_to_pma,at_hosp,on_way_to_hosp)
        end
    end

end