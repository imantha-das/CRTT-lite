module Utils

    import PlotlyJS
    using Agents: ABM
    using ..AgentTypes: Resc

    export plot_resc_traject

    @doc """Plot Rescuer Trajectories"""->
    function plot_resc_traject(model::ABM)
        rescuers = [id for (id,agent) in model.agents if agent isa Resc]
        traces = PlotlyJS.PlotlyBase.GenericTrace[]
        for i in rescuers
            trajectory = model[i].loc_traject
            trace = PlotlyJS.scatter(
                x = 1:length(trajectory),
                y = trajectory,
                mode = "lines",
                line = PlotlyJS.attr(shape = "hv"),
                name = "rescuer $(i)"
            )
            push!(traces,trace)
        end
        layout = PlotlyJS.Layout(title = "Rescuer Trajectory", xaxis_title = "ticks", yaxis_title = "status", width = 900, height = 500, template = "plotly_white")
        return PlotlyJS.plot(traces, layout)
    end

end