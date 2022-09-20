module Utils 

    using Agents: ABM, Schedulers, add_agent!, nextid
    using ..CrttAgents: Cas, Resc
    export initialise

    @doc """Initilaise ABM with Casualties, Rescuers, Pma and Hospitals"""
    function initialise(num_cas::Int64,num_resc::Int64,properties::Dict)
        model = ABM(
            Union{Cas,Resc},
            scheduler = Schedulers.ByType((Resc, Cas), true),
            properties = properties
        )

        # Add casualties
        for i = 1:num_cas
            cas = Cas(nextid(model),rand([1,2,3]))
            add_agent!(cas, model)
        end

        # Add Rescuers 
        for i =  1:num_resc
            resc = Resc(nextid(model))
            add_agent!(resc, model)
        end

        # # Add PMA 
        # vx = Pma(nextid(model),name = "VX")
        # sm = Pma(nextid(model),name = "SM")

        # add_agent!(vx, model)
        # add_agent!(sm, model)

        # # Add Hospital
        # hosp = Hosp(nextid(model))
        # add_agent!(hosp, model)

        return model
    end

end