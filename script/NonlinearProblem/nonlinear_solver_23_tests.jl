
using NonlinearSolve, NonlinearSolveMINPACK, SciMLNLSolve, SimpleNonlinearSolve, StaticArrays, Sundials
using BenchmarkTools, DiffEqDevTools, NonlinearProblemLibrary, Plots


solvers = [ Dict(:alg=>NewtonRaphson()),
            Dict(:alg=>TrustRegion()),
            Dict(:alg=>LevenbergMarquardt()),
            Dict(:alg=>CMINPACK(method=:hybr)),
            Dict(:alg=>CMINPACK(method=:lm)),
            Dict(:alg=>NLSolveJL()),
            Dict(:alg=>KINSOL())]
solvernames =  ["Newton Raphson"; 
                "Newton Trust Region"; 
                "Levenberg-Marquardt"; 
                "Modified Powell (CMINPACK)"; 
                "Levenberg-Marquardt (CMINPACK)"; 
                "Newton Trust Region (NLSolveJL)"; 
                "KINSOL (Sundials)"];


abstols = 1.0 ./ 10.0 .^ (4:12)
reltols = 1.0 ./ 10.0 .^ (4:12);


default(framestyle=:box,legend=:topleft,gridwidth=2, guidefontsize=12, legendfontsize=9, lw=2)
colors = [1 2 3 4 5 6 7]
markershapes = [:circle :rect :heptagon :cross :xcross :utriangle :star5];


# Finds good x and y limits.
function xy_limits(wp)
    times = vcat(map(wp -> wp.times, wp.wps)...)
    errors = vcat(map(wp -> wp.errors, wp.wps)...)
    xlimit = 10 .^ (floor(log10(minimum(errors))), ceil(log10(maximum(errors))))
    ylimit = 10 .^ (floor(log10(minimum(times))), ceil(log10(maximum(times))))
    return xlimit, ylimit
end

# Find good x and y ticks.
function arithmetic_sequences(v1, v2)
    sequences = []
    for n in 2:(v2-v1+1)
        d = (v2 - v1) / (n - 1)
        if d == floor(d)  
            sequence = [v1 + (j-1)*d for j in 1:n]
            push!(sequences, sequence)
        end
    end
    return sequences
end
function get_ticks(limit)
    (limit[1]==-Inf) && return 10.0 .^[limit[1], limit[2]]
    sequences = arithmetic_sequences(limit...)
    selected_seq = findlast(length.(sequences) .< 5)
    if length(sequences[selected_seq]) < 4
        step = (limit[2] - limit[1]) / 6.0
        ticks = [round(Int, limit[1] + i*step) for i in 1:5]
        return 10 .^[limit[1];ticks;limit[2]]
    end
    return 10 .^sequences[selected_seq]
end

# Plots a wrok-precision diagram.
function plot_wp(wp, selected_solvers; colors=permutedims(getindex(colors,selected_solvers)[:,:]), markershapes=permutedims(getindex(markershapes,selected_solvers)[:,:]), kwargs...)
    xlimit, ylimit = xy_limits(wp)
    xticks = get_ticks(log10.(xlimit))
    yticks = get_ticks(log10.(ylimit))
    plot(wp; xlimit=xlimit, ylimit=ylimit, xticks=xticks, yticks=yticks, color=colors, markershape=markershapes, kwargs...)
end;


prob_1 = nlprob_23_testcases["Generalized Rosenbrock function"]
selected_solvers_1 = [2,3,4,5,6]
wp_1 = WorkPrecisionSet(prob_1.prob, abstols, reltols, getindex(solvers,selected_solvers_1); names=getindex(solvernames,selected_solvers_1), numruns=100, appxsol=prob_1.true_sol, error_estimate=:l2)
plot_wp(wp_1, selected_solvers_1; legend=:bottomright)


prob_2 = nlprob_23_testcases["Powell singular function"]
selected_solvers_2 = [1,2,3,4,5,6,7]
wp_2 = WorkPrecisionSet(prob_2.prob, abstols, reltols, getindex(solvers,selected_solvers_2); names=getindex(solvernames,selected_solvers_2), numruns=100, appxsol=prob_2.true_sol, error_estimate=:l2)
plot_wp(wp_2, selected_solvers_2)


prob_3 = nlprob_23_testcases["Powell badly scaled function"]
selected_solvers_3 = [1,2,3,4,5,6,7]
wp_3 = WorkPrecisionSet(prob_3.prob, abstols, reltols, getindex(solvers,selected_solvers_3); names=getindex(solvernames,selected_solvers_3), numruns=100, appxsol=prob_3.true_sol, error_estimate=:l2)
plot_wp(wp_3, selected_solvers_3)


prob_4 = nlprob_23_testcases["Wood function"]
selected_solvers_4 = [1,2,3,4,5,6]
wp_4 = WorkPrecisionSet(prob_4.prob, abstols, reltols, getindex(solvers,selected_solvers_4); names=getindex(solvernames,selected_solvers_4), numruns=100, appxsol=prob_4.true_sol, error_estimate=:l2)
plot_wp(wp_4, selected_solvers_4; legend=:topright)


prob_5 = nlprob_23_testcases["Helical valley function"]
selected_solvers_5 = [1,2,3,4,5,6]
wp_5 = WorkPrecisionSet(prob_5.prob, abstols, reltols, getindex(solvers,selected_solvers_5); names=getindex(solvernames,selected_solvers_5), numruns=100, appxsol=prob_5.true_sol, error_estimate=:l2)
plot_wp(wp_5, selected_solvers_5)


prob_6 = nlprob_23_testcases["Watson function"]
selected_solvers_6 = [4,5,6]
true_sol_6 = solve(prob_6.prob, NLSolveJL(); abstol=1e-18, reltol=1e-18)
wp_6 = WorkPrecisionSet(prob_6.prob, abstols, reltols, getindex(solvers,selected_solvers_6); names=getindex(solvernames,selected_solvers_6), numruns=100, appxsol=true_sol_6, error_estimate=:l2)
plot_wp(wp_6, selected_solvers_6; legend=:topright)


prob_7 = nlprob_23_testcases["Chebyquad function"]
selected_solvers_7 = [1,2,3,4,5,6,7]
wp_7 = WorkPrecisionSet(prob_7.prob, abstols, reltols, getindex(solvers,selected_solvers_7); names=getindex(solvernames,selected_solvers_7), numruns=100, appxsol=prob_7.true_sol, error_estimate=:l2)
plot_wp(wp_7, selected_solvers_7; legend=:bottomright)


prob_8 = nlprob_23_testcases["Brown almost linear function"]
selected_solvers_8 = [1,2,3,4,5,6]
wp_8 = WorkPrecisionSet(prob_8.prob, abstols, reltols, getindex(solvers,selected_solvers_8); names=getindex(solvernames,selected_solvers_8), numruns=100, appxsol=prob_8.true_sol, error_estimate=:l2)
plot_wp(wp_8, selected_solvers_8)


prob_9 = nlprob_23_testcases["Discrete boundary value function"]
selected_solvers_9 = [1,2,3,4,5,6,7]
true_sol_9 = solve(prob_9.prob, NLSolveJL(); abstol=1e-18, reltol=1e-18)
wp_9 = WorkPrecisionSet(prob_9.prob, abstols, reltols, getindex(solvers,selected_solvers_9); names=getindex(solvernames,selected_solvers_9), numruns=100, appxsol=true_sol_9, error_estimate=:l2)
plot_wp(wp_9, selected_solvers_9)


prob_10 = nlprob_23_testcases["Discrete integral equation function"]
selected_solvers_10 = [1,2,3,4,5,6,7]
true_sol_10 = solve(prob_10.prob, NLSolveJL(); abstol=1e-18, reltol=1e-18)
wp_10 = WorkPrecisionSet(prob_10.prob, abstols, reltols, getindex(solvers,selected_solvers_10); names=getindex(solvernames,selected_solvers_10), numruns=100, appxsol=true_sol_10, error_estimate=:l2)
plot_wp(wp_10, selected_solvers_10; legend=:bottomleft)


prob_11 = nlprob_23_testcases["Trigonometric function"]
selected_solvers_11 = [1,2,3,4,5,6]
true_sol_11 = solve(prob_11.prob, NLSolveJL(); abstol=1e-18, reltol=1e-18)
wp_11 = WorkPrecisionSet(prob_11.prob, abstols, reltols, getindex(solvers,selected_solvers_11); names=getindex(solvernames,selected_solvers_11), numruns=100, appxsol=true_sol_11, error_estimate=:l2)
plot_wp(wp_11, selected_solvers_11)


prob_12 = nlprob_23_testcases["Variably dimensioned function"]
selected_solvers_12 = [1,2,3,4,5,6,7]
wp_12 = WorkPrecisionSet(prob_12.prob, abstols, reltols, getindex(solvers,selected_solvers_12); names=getindex(solvernames,selected_solvers_12), numruns=100, appxsol=prob_12.true_sol, error_estimate=:l2)
plot_wp(wp_12, selected_solvers_12; legend=:bottomright)


prob_13 = nlprob_23_testcases["Broyden tridiagonal function"]
selected_solvers_13 = [1,2,3,4,5,6,7]
true_sol_13 = solve(prob_13.prob, NLSolveJL(); abstol=1e-18, reltol=1e-18)
wp_13 = WorkPrecisionSet(prob_13.prob, abstols, reltols, getindex(solvers,selected_solvers_13); names=getindex(solvernames,selected_solvers_13), numruns=100, appxsol=true_sol_13, error_estimate=:l2)
plot_wp(wp_13, selected_solvers_13; legend=:topleft, legendfontsize=6)


prob_14 = nlprob_23_testcases["Broyden banded function"]
selected_solvers_14 = [1,2,3,4,5,6,7]
true_sol_14 = solve(prob_14.prob, NLSolveJL(); abstol=1e-18, reltol=1e-18)
wp_14 = WorkPrecisionSet(prob_14.prob, abstols, reltols, getindex(solvers,selected_solvers_14); names=getindex(solvernames,selected_solvers_14), numruns=100, appxsol=true_sol_14, error_estimate=:l2)
plot_wp(wp_14, selected_solvers_14)


prob_15 = nlprob_23_testcases["Hammarling 2 by 2 matrix square root problem"]
selected_solvers_15 = [1,2,3,4,5,6,7]
wp_15 = WorkPrecisionSet(prob_15.prob, abstols, reltols, getindex(solvers,selected_solvers_15); names=getindex(solvernames,selected_solvers_15), numruns=100, appxsol=prob_15.true_sol, error_estimate=:l2)
plot_wp(wp_15, selected_solvers_15)


prob_16 = nlprob_23_testcases["Hammarling 3 by 3 matrix square root problem"]
selected_solvers_16 = [1,2,3,4,5,6,7]
wp_16 = WorkPrecisionSet(prob_16.prob, abstols, reltols, getindex(solvers,selected_solvers_16); names=getindex(solvernames,selected_solvers_16), numruns=100, appxsol=prob_16.true_sol, error_estimate=:l2)
plot_wp(wp_16, selected_solvers_16)


prob_17 = nlprob_23_testcases["Dennis and Schnabel 2 by 2 example"]
selected_solvers_17 = [1,2,3,4,5,6,7]
wp_17 = WorkPrecisionSet(prob_17.prob, abstols, reltols, getindex(solvers,selected_solvers_17); names=getindex(solvernames,selected_solvers_17), numruns=100, appxsol=prob_17.true_sol, error_estimate=:l2)
plot_wp(wp_17, selected_solvers_17)


prob_18 = nlprob_23_testcases["Sample problem 18"]
selected_solvers_18 = [1,2,3,4,5,6]
wp_18 = WorkPrecisionSet(prob_18.prob, abstols, reltols, getindex(solvers,selected_solvers_18); names=getindex(solvernames,selected_solvers_18), numruns=100, appxsol=prob_18.true_sol, error_estimate=:l2)
plot_wp(wp_18, selected_solvers_18)


prob_19 = nlprob_23_testcases["Sample problem 19"]
selected_solvers_19 = [1,2,3,4,5,6,7]
wp_19 = WorkPrecisionSet(prob_19.prob, abstols, reltols, getindex(solvers,selected_solvers_19); names=getindex(solvernames,selected_solvers_19), numruns=100, appxsol=prob_19.true_sol, error_estimate=:l2)
plot_wp(wp_19, selected_solvers_19)


prob_20 = nlprob_23_testcases["Scalar problem f(x) = x(x - 5)^2"]
selected_solvers_20 = [1,2,3,4,5,6,7]
wp_20 = WorkPrecisionSet(prob_20.prob, abstols, reltols, getindex(solvers,selected_solvers_20); names=getindex(solvernames,selected_solvers_20), numruns=100, appxsol=prob_20.true_sol, error_estimate=:l2)
plot_wp(wp_20, selected_solvers_20)


prob_21 = nlprob_23_testcases["Freudenstein-Roth function"]
selected_solvers_21 = [1,2,3,4,5,6]
wp_21 = WorkPrecisionSet(prob_21.prob, abstols, reltols, getindex(solvers,selected_solvers_21); names=getindex(solvernames,selected_solvers_21), numruns=100, appxsol=prob_21.true_sol, error_estimate=:l2)
plot_wp(wp_21, selected_solvers_21)


prob_22 = nlprob_23_testcases["Boggs function"]
selected_solvers_22 = [1,2,3,4,5,6,7]
wp_22 = WorkPrecisionSet(prob_22.prob, abstols, reltols, getindex(solvers,selected_solvers_22); names=getindex(solvernames,selected_solvers_22), numruns=100, appxsol=prob_22.true_sol, error_estimate=:l2)
plot_wp(wp_22, selected_solvers_22)


prob_23 = nlprob_23_testcases["Chandrasekhar function"]
selected_solvers_23 = [1,2,3,4,5,6,7]
true_sol_23 = solve(prob_23.prob, NLSolveJL(); abstol=1e-18, reltol=1e-18)
wp_23 = WorkPrecisionSet(prob_23.prob, abstols, reltols, getindex(solvers,selected_solvers_23); names=getindex(solvernames,selected_solvers_23), numruns=100, appxsol=true_sol_23, error_estimate=:l2)
plot_wp(wp_23, selected_solvers_23; legend=:topright, legendfontsize=7)


using SciMLBenchmarks
SciMLBenchmarks.bench_footer(WEAVE_ARGS[:folder],WEAVE_ARGS[:file])
