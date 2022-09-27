module PmaHosp
    using Base:@kwdef
    export vx, sm, ptp

    @doc """Vieux Habitants PMA queues""" ->
    @kwdef mutable struct vx
        pre_stabilize_q::Vector{Int} = Int[]
        in_stabilize_q::Vector{Tuple{Int,Int}} = Vector{Tuple{Int,Int}}([])
        post_stabilize_q::Vector{Int} = Int[]
    end

    @doc """Sainte Marie PMA queues"""->
    @kwdef mutable struct sm
        pre_stabilize_q::Vector{Int} = Int[]
        in_stabilize_q::Vector{Tuple{Int,Int}} = Vector{Tuple{Int,Int}}([])
        post_stabilize_q::Vector{Int} = Int[]
    end

    @doc """Point Pitre Hospital queues"""
    @kwdef mutable struct ptp
        pre_treatment_q::Vector{Int} = Int[]
        in_burn_beds::Vector{Int} = Int[]
        in_non_burn_beds::Vector{Int} = Int[]
    end
end