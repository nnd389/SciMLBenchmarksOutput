---
author: "Torkel Loman"
title: "Fceri_gamma2 Work-Precision Diagrams"
---


The following benchmark is of 356 ODEs with 3749 terms that describe a stiff
chemical reaction network. This fceri_gamma2 model was used as a benchmark model in [Gupta et
al.](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6013266/). It describes high-affinity human IgE receptor signalling [Faeder et
al.](https://www.jimmunol.org/content/170/7/3769.long). We use
[`ReactionNetworkImporters`](https://github.com/isaacsas/ReactionNetworkImporters.jl)
to load the BioNetGen model files as a
[Catalyst](https://github.com/SciML/Catalyst.jl) model, and then use
[ModelingToolkit](https://github.com/SciML/ModelingToolkit.jl) to convert the
Catalyst network model to ODEs.

```julia
using DiffEqBase, OrdinaryDiffEq, Catalyst, ReactionNetworkImporters,
    Sundials, Plots, DiffEqDevTools, ODEInterface, ODEInterfaceDiffEq,
    LSODA, TimerOutputs, LinearAlgebra, ModelingToolkit, BenchmarkTools,
    LinearSolve

gr()
const to = TimerOutput()
tf       = 150.0

# generate ModelingToolkit ODEs
@timeit to "Parse Network" prnbng = loadrxnetwork(BNGNetwork(), joinpath(@__DIR__, "Models/fceri_gamma2.net"))
show(to)
rn    = prnbng.rn
obs = [eq.lhs for eq in observed(rn)]

@timeit to "Create ODESys" osys = convert(ODESystem, rn)
show(to)

tspan = (0.,tf)
@timeit to "ODEProb SparseJac" sparsejacprob = ODEProblem{true, SciMLBase.FullSpecialize}(osys, Float64[], tspan, Float64[], jac=true, sparse=true)
show(to)
@timeit to "ODEProb No Jac" oprob = ODEProblem{true, SciMLBase.FullSpecialize}(osys, Float64[], tspan, Float64[])
show(to)
oprob_sparse = ODEProblem{true, SciMLBase.FullSpecialize}(osys, Float64[], tspan, Float64[]; sparse=true);
```

```
Parsing parameters...done
Creating parameters...done
Parsing species...done
Creating species...done
Creating species and parameters for evaluating expressions...done
Parsing and adding reactions...done
Parsing groups...done
 ──────────────────────────────────────────────────────────────────────────
                                  Time                    Allocations      
                         ───────────────────────   ────────────────────────
    Tot / % measured:         3.97s / 100.0%           1.67GiB / 100.0%    

 Section         ncalls     time    %tot     avg     alloc    %tot      avg
 ──────────────────────────────────────────────────────────────────────────
 Parse Network        1    3.97s  100.0%   3.97s   1.67GiB  100.0%  1.67GiB
 ──────────────────────────────────────────────────────────────────────────
 ──────────────────────────────────────────────────────────────────────────
                                  Time                    Allocations      
                         ───────────────────────   ────────────────────────
    Tot / % measured:         14.7s /  99.6%           7.35GiB / 100.0%    

 Section         ncalls     time    %tot     avg     alloc    %tot      avg
 ──────────────────────────────────────────────────────────────────────────
 Create ODESys        1    10.7s   72.9%   10.7s   5.68GiB   77.3%  5.68GiB
 Parse Network        1    3.97s   27.1%   3.97s   1.67GiB   22.7%  1.67GiB
 ──────────────────────────────────────────────────────────────────────────
 ──────────────────────────────────────────────────────────────────────────
────
                                      Time                    Allocations  
    
                             ───────────────────────   ────────────────────
────
      Tot / % measured:           1.86h / 100.0%           10.0TiB / 100.0%
    

 Section             ncalls     time    %tot     avg     alloc    %tot     
 avg
 ──────────────────────────────────────────────────────────────────────────
────
 ODEProb SparseJac        1    1.85h   99.8%   1.85h   10.0TiB   99.9%  10.
0TiB
 Create ODESys            1    10.7s    0.2%   10.7s   5.68GiB    0.1%  5.6
8GiB
 Parse Network            1    3.97s    0.1%   3.97s   1.67GiB    0.0%  1.6
7GiB
 ──────────────────────────────────────────────────────────────────────────
──── ──────────────────────────────────────────────────────────────────────
────────
                                      Time                    Allocations  
    
                             ───────────────────────   ────────────────────
────
      Tot / % measured:           1.86h / 100.0%           10.0TiB / 100.0%
    

 Section             ncalls     time    %tot     avg     alloc    %tot     
 avg
 ──────────────────────────────────────────────────────────────────────────
────
 ODEProb SparseJac        1    1.85h   99.6%   1.85h   10.0TiB   99.9%  10.
0TiB
 Create ODESys            1    10.7s    0.2%   10.7s   5.68GiB    0.1%  5.6
8GiB
 ODEProb No Jac           1    9.00s    0.1%   9.00s   2.50GiB    0.0%  2.5
0GiB
 Parse Network            1    3.97s    0.1%   3.97s   1.67GiB    0.0%  1.6
7GiB
 ──────────────────────────────────────────────────────────────────────────
────
```



```julia
@show numspecies(rn) # Number of ODEs
@show numreactions(rn) # Apprx. number of terms in the ODE
@show length(parameters(rn)); # Number of Parameters
```

```
numspecies(rn) = 3744
numreactions(rn) = 58276
length(parameters(rn)) = 26
```





## Time ODE derivative function compilation
As compiling the ODE derivative functions has in the past taken longer than
running a simulation, we first force compilation by evaluating these functions
one time.
```julia
u  = ModelingToolkit.varmap_to_vars(nothing, species(rn); defaults=ModelingToolkit.defaults(rn))
du = copy(u)
p  = ModelingToolkit.varmap_to_vars(nothing, parameters(rn); defaults=ModelingToolkit.defaults(rn))
@timeit to "ODE rhs Eval1" sparsejacprob.f(du,u,p,0.)
sparsejacprob.f(du,u,p,0.)
```




We also time the ODE rhs function with BenchmarkTools as it is more accurate
given how fast evaluating `f` is:
```julia
@btime sparsejacprob.f($du,$u,$p,0.)
```

```
83.100 μs (3 allocations: 1.25 KiB)
```





## Picture of the solution

```julia
sol = solve(oprob, CVODE_BDF(), saveat=tf/1000., reltol=1e-5, abstol=1e-5)
plot(sol; idxs=obs, legend=false, fmt=:png)
```

![](figures/fceri_gamma2_5_1.png)



For these benchmarks we will be using the time-series error with these saving
points.

## Generate Test Solution

```julia
@time sol = solve(sparsejacprob, CVODE_BDF(linear_solver=:GMRES), reltol=1e-15, abstol=1e-15)
test_sol  = TestSolution(sol);
```

```
25.510179 seconds (11.19 M allocations: 1.243 GiB, 74.75% compilation time
)
```





## Setups

#### Sets plotting defaults

```julia
default(legendfontsize=7,framestyle=:box,gridalpha=0.3,gridlinewidth=2.5)
```




#### Declares a plotting helper function

```julia
function plot_settings(wp)
    times = vcat(map(wp -> wp.times, wp.wps)...)
    errors = vcat(map(wp -> wp.errors, wp.wps)...)
    xlimit = 10 .^ (floor(log10(minimum(errors))), ceil(log10(maximum(errors))))
    ylimit = 10 .^ (floor(log10(minimum(times))), ceil(log10(maximum(times))))
    return xlimit,ylimit
end
```

```
plot_settings (generic function with 1 method)
```





#### Declare pre-conditioners
```julia
using IncompleteLU, LinearAlgebra

jaccache = sparsejacprob.f.jac(oprob.u0,oprob.p,0.0)
W = I - 1.0*jaccache
prectmp = ilu(W, τ = 50.0)
preccache = Ref(prectmp)

const τ1 = 5
function psetupilu(p, t, u, du, jok, jcurPtr, gamma)
    if !jok
        sparsejacprob.f.jac(jaccache,u,p,t)
        jcurPtr[] = true

        # W = I - gamma*J
        @. W = -gamma*jaccache
        idxs = diagind(W)
        @. @view(W[idxs]) = @view(W[idxs]) + 1

        # Build preconditioner on W
        preccache[] = ilu(W, τ = τ1)
    end
end
function precilu(z,r,p,t,y,fy,gamma,delta,lr)
    ldiv!(z,preccache[],r)
end

const τ2 = 5
function incompletelu(W,du,u,p,t,newW,Plprev,Prprev,solverdata)
    if newW === nothing || newW
        Pl = ilu(convert(AbstractMatrix,W), τ = τ2)
    else
        Pl = Plprev
    end
    Pl,nothing
end;
```




#### Sets tolerances

```julia
abstols = 1.0 ./ 10.0 .^ (5:8)
reltols = 1.0 ./ 10.0 .^ (5:8);
```




## Work-Precision Diagrams (CVODE and lsoda solvers)

#### Declare solvers.

```julia
setups = [
        Dict(:alg=>lsoda(), :prob_choice => 1),
        Dict(:alg=>CVODE_BDF(), :prob_choice => 1),
        Dict(:alg=>CVODE_BDF(linear_solver=:LapackDense), :prob_choice => 1),
        Dict(:alg=>CVODE_BDF(linear_solver=:GMRES), :prob_choice => 1),
        Dict(:alg=>CVODE_BDF(linear_solver=:GMRES,prec=precilu,psetup=psetupilu,prec_side=1), :prob_choice => 2),
        Dict(:alg=>CVODE_BDF(linear_solver=:KLU), :prob_choice => 3)
        ];
```




#### Plot Work-Precision Diagram.

```julia
wp = WorkPrecisionSet([oprob,oprob_sparse,sparsejacprob],abstols,reltols,setups;error_estimate=:l2,
                    saveat=tf/10000.,appxsol=[test_sol,test_sol,test_sol],maxiters=Int(1e9),numruns=10)

names = ["lsoda" "CVODE_BDF" "CVODE_BDF (LapackDense)" "CVODE_BDF (GMRES)" "CVODE_BDF (GMRES, iLU)" "CVODE_BDF (KLU, sparse jac)"]
xlimit,ylimit = plot_settings(wp)
plot(wp;label=names,xlimit=xlimit,ylimit=ylimit)
```

![](figures/fceri_gamma2_12_1.png)



## Work-Precision Diagrams (various Julia solvers)

#### Declare solvers (using default linear solver).

```julia
setups = [
        Dict(:alg=>TRBDF2(autodiff=false)),
        Dict(:alg=>QNDF(autodiff=false)),
        Dict(:alg=>FBDF(autodiff=false)),
        Dict(:alg=>KenCarp4(autodiff=false))
        ];
```




#### Plot Work-Precision Diagram (using default linear solver).

```julia
wp = WorkPrecisionSet(oprob,abstols,reltols,setups;error_estimate=:l2,
                    saveat=tf/10000.,appxsol=test_sol,maxiters=Int(1e12),dtmin=1e-18,numruns=10)

names = ["TRBDF2" "QNDF" "FBDF" "KenCarp4"]
xlimit,ylimit = plot_settings(wp)
plot(wp;label=names,xlimit=xlimit,ylimit=ylimit)
```

![](figures/fceri_gamma2_14_1.png)



#### Declare solvers (using GMRES linear solver).

```julia
setups = [
        Dict(:alg=>TRBDF2(linsolve=KrylovJL_GMRES(),autodiff=false)),
        Dict(:alg=>QNDF(linsolve=KrylovJL_GMRES(),autodiff=false)),
        Dict(:alg=>FBDF(linsolve=KrylovJL_GMRES(),autodiff=false)),
        Dict(:alg=>KenCarp4(linsolve=KrylovJL_GMRES(),autodiff=false))
        ];
```




#### Plot Work-Precision Diagram (using GMRES linear solver).

```julia
wp = WorkPrecisionSet(oprob,abstols,reltols,setups;error_estimate=:l2,
                    saveat=tf/10000.,appxsol=test_sol,maxiters=Int(1e12),dtmin=1e-18,numruns=10)

names = ["TRBDF2 (GMRES)" "QNDF (GMRES)" "FBDF (GMRES)" "KenCarp4 (GMRES)"]
xlimit,ylimit = plot_settings(wp)
plot(wp;label=names,xlimit=xlimit,ylimit=ylimit)
```

![](figures/fceri_gamma2_16_1.png)



#### Declare solvers (using GMRES linear solver, with pre-conditioner).

```julia
setups = [
        Dict(:alg=>TRBDF2(linsolve=KrylovJL_GMRES(),autodiff=false,precs=incompletelu,concrete_jac=true)),
        Dict(:alg=>QNDF(linsolve=KrylovJL_GMRES(),autodiff=false,precs=incompletelu,concrete_jac=true)),
        Dict(:alg=>FBDF(linsolve=KrylovJL_GMRES(),autodiff=false,precs=incompletelu,concrete_jac=true)),
        Dict(:alg=>KenCarp4(linsolve=KrylovJL_GMRES(),autodiff=false,precs=incompletelu,concrete_jac=true))
        ];
```




#### Plot Work-Precision Diagram (using GMRES linear solver, with pre-conditioner).

```julia
wp = WorkPrecisionSet(sparsejacprob,abstols,reltols,setups;error_estimate=:l2,
                    saveat=tf/10000.,appxsol=test_sol,maxiters=Int(1e12),dtmin=1e-18,numruns=10)

names = ["TRBDF2 (GMRES, iLU)" "QNDF (GMRES, iLU)" "FBDF (GMRES, iLU)" "KenCarp4 (GMRES, iLU)"]
xlimit,ylimit = plot_settings(wp)
plot(wp;label=names,xlimit=xlimit,ylimit=ylimit)
```

![](figures/fceri_gamma2_18_1.png)



#### Declare solvers (using sparse jacobian)

We designate the solvers we wish to use.
```julia
setups = [
        Dict(:alg=>TRBDF2(linsolve=KLUFactorization(),autodiff=false)),
        Dict(:alg=>QNDF(linsolve=KLUFactorization(),autodiff=false)),
        Dict(:alg=>FBDF(linsolve=KLUFactorization(),autodiff=false)),
        Dict(:alg=>KenCarp4(linsolve=KLUFactorization(),autodiff=false))
        ];
```





#### Plot Work-Precision Diagram (using sparse jacobian)

Finally, we generate a work-precision diagram for the selection of solvers.
```julia
wp = WorkPrecisionSet(sparsejacprob,abstols,reltols,setups;error_estimate=:l2,
                    saveat=tf/10000.,appxsol=test_sol,maxiters=Int(1e12),dtmin=1e-18,numruns=10)

names = ["TRBDF2 (KLU, sparse jac)" "QNDF (KLU, sparse jac)" "FBDF (KLU, sparse jac)" "KenCarp4 (KLU, sparse jac)"]
xlimit,ylimit = plot_settings(wp)
plot(wp;label=names,xlimit=xlimit,ylimit=ylimit)
```

![](figures/fceri_gamma2_20_1.png)



## Explicit Work-Precision Diagram

Benchmarks for explicit solvers.

#### Declare solvers

We designate the solvers we wish to use, this also includes lsoda and CVODE.
```julia
setups = [
        Dict(:alg=>CVODE_Adams()),
        Dict(:alg=>Tsit5()),
        Dict(:alg=>BS5()),
        Dict(:alg=>VCABM()),
        Dict(:alg=>Vern6()),
        Dict(:alg=>Vern7()),
        Dict(:alg=>Vern8()),
        Dict(:alg=>Vern9())
        ];
```




#### Plot Work-Precision Diagram

```julia
wp = WorkPrecisionSet(oprob,abstols,reltols,setups;error_estimate=:l2,
                    saveat=tf/10000.,appxsol=test_sol,maxiters=Int(1e9),numruns=10)

names = ["CVODE_Adams" "Tsit5" "BS5" "Vern6" "Vern7" "Vern8" "Vern9"]
xlimit,ylimit = plot_settings(wp)
plot(wp;label=names,xlimit=xlimit,ylimit=ylimit)
```

![](figures/fceri_gamma2_22_1.png)



## Summary of results
Finally, we compute a single diagram comparing the various solvers used.

#### Declare solvers
We designate the solvers we wish to compare.
```julia
setups = [
        Dict(:alg=>CVODE_BDF(linear_solver=:GMRES), :prob_choice => 1),
        Dict(:alg=>CVODE_BDF(linear_solver=:GMRES,prec=precilu,psetup=psetupilu,prec_side=1), :prob_choice => 2),
        Dict(:alg=>QNDF(linsolve=KrylovJL_GMRES(),autodiff=false,precs=incompletelu,concrete_jac=true), :prob_choice => 3),
        Dict(:alg=>FBDF(linsolve=KrylovJL_GMRES(),autodiff=false,precs=incompletelu,concrete_jac=true), :prob_choice => 3),
        Dict(:alg=>Tsit5())
        ];
```




#### Plot Work-Precision Diagram

For these, we generate a work-precision diagram for the selection of solvers.
```julia
wp = WorkPrecisionSet([oprob,oprob_sparse,sparsejacprob],abstols,reltols,setups;error_estimate=:l2,
                      saveat=tf/10000.,appxsol=[test_sol,test_sol,test_sol],maxiters=Int(1e9),numruns=200)

names = ["CVODE_BDF (GMRES)" "CVODE_BDF (GMRES, iLU)" "QNDF (GMRES, iLU)" "FBDF (GMRES, iLU)" "Tsit5"]
colors = [:darkgreen :green :deepskyblue1 :dodgerblue2 :orchid2]
markershapes = [:rect :octagon :hexagon :rtriangle :ltriangle]
xlimit,ylimit = plot_settings(wp)
xlimit = xlimit .* [0.95,1/0.95]; ylimit = ylimit .* [0.95,1/0.95]; 
plot(wp;label=names,left_margin=10Plots.mm,right_margin=10Plots.mm,xlimit=xlimit,ylimit=ylimit,xticks=[1e-9,1e-8,1e-7,1e-6,1e-5,1e-4,1e-3,1e-2,1e-1],yticks=[1e-1,1e0,1e1,1e2],color=colors,markershape=markershapes,legendfontsize=15,tickfontsize=15,guidefontsize=15, legend=:topright, lw=20, la=0.8, markersize=20,markerstrokealpha=1.0, markerstrokewidth=1.5, gridalpha=0.3, gridlinewidth=7.5,size=(1100,1000))
```

![](figures/fceri_gamma2_24_1.png)

```julia
echo = false
using SciMLBenchmarks
SciMLBenchmarks.bench_footer(WEAVE_ARGS[:folder],WEAVE_ARGS[:file])
```


## Appendix

These benchmarks are a part of the SciMLBenchmarks.jl repository, found at: [https://github.com/SciML/SciMLBenchmarks.jl](https://github.com/SciML/SciMLBenchmarks.jl). For more information on high-performance scientific machine learning, check out the SciML Open Source Software Organization [https://sciml.ai](https://sciml.ai).

To locally run this benchmark, do the following commands:

```
using SciMLBenchmarks
SciMLBenchmarks.weave_file("benchmarks/Bio","fceri_gamma2.jmd")
```

Computer Information:

```
Julia Version 1.8.5
Commit 17cfb8e65ea (2023-01-08 06:45 UTC)
Platform Info:
  OS: Linux (x86_64-linux-gnu)
  CPU: 128 × AMD EPYC 7502 32-Core Processor
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-13.0.1 (ORCJIT, znver2)
  Threads: 128 on 128 virtual cores
Environment:
  JULIA_CPU_THREADS = 128
  JULIA_DEPOT_PATH = /cache/julia-buildkite-plugin/depots/5b300254-1738-4989-ae0a-f4d2d937f953

```

Package Information:

```
Status `/cache/build/exclusive-amdci3-0/julialang/scimlbenchmarks-dot-jl/benchmarks/Bio/Project.toml`
  [6e4b80f9] BenchmarkTools v1.3.2
⌅ [479239e8] Catalyst v12.3.1
⌃ [2b5f629d] DiffEqBase v6.114.0
  [f3b72e0c] DiffEqDevTools v2.35.0
  [40713840] IncompleteLU v0.2.1
⌃ [033835bb] JLD2 v0.4.29
  [7f56f5a3] LSODA v0.7.3
⌃ [7ed4a6bd] LinearSolve v1.33.0
⌃ [961ee093] ModelingToolkit v8.41.0
  [54ca160b] ODEInterface v0.5.0
  [09606e27] ODEInterfaceDiffEq v3.12.0
⌃ [1dea7af3] OrdinaryDiffEq v6.38.0
  [91a5bcdd] Plots v1.38.7
⌅ [b4db0fb7] ReactionNetworkImporters v0.13.5
  [31c91b34] SciMLBenchmarks v0.1.1
⌃ [c3572dad] Sundials v4.12.0
  [a759f4b9] TimerOutputs v0.5.22
Info Packages marked with ⌃ and ⌅ have new versions available, but those with ⌅ are restricted by compatibility constraints from upgrading. To see why use `status --outdated`
```

And the full manifest:

```
Status `/cache/build/exclusive-amdci3-0/julialang/scimlbenchmarks-dot-jl/benchmarks/Bio/Manifest.toml`
⌅ [c3fe647b] AbstractAlgebra v0.27.10
  [1520ce14] AbstractTrees v0.4.4
  [79e6a3ab] Adapt v3.6.1
  [dce04be8] ArgCheck v2.3.0
  [ec485272] ArnoldiMethod v0.2.0
⌅ [4fba245c] ArrayInterface v6.0.25
  [30b0a656] ArrayInterfaceCore v0.1.29
  [6ba088a2] ArrayInterfaceGPUArrays v0.2.2
  [015c0d05] ArrayInterfaceOffsetArrays v0.1.7
  [b0d46f97] ArrayInterfaceStaticArrays v0.1.5
  [dd5226c6] ArrayInterfaceStaticArraysCore v0.1.4
  [15f4f7f2] AutoHashEquals v0.2.0
  [198e06fe] BangBang v0.3.37
  [9718e550] Baselet v0.1.1
  [6e4b80f9] BenchmarkTools v1.3.2
  [e2ed5e7c] Bijections v0.1.4
  [d1d4a3ce] BitFlags v0.1.7
  [62783981] BitTwiddlingConvenienceFunctions v0.1.5
  [fa961155] CEnum v0.4.2
  [2a0fbf3d] CPUSummary v0.2.2
  [00ebfdb7] CSTParser v3.3.6
  [49dc2e85] Calculus v0.5.1
⌅ [479239e8] Catalyst v12.3.1
  [d360d2e6] ChainRulesCore v1.15.7
  [9e997f8a] ChangesOfVariables v0.1.6
⌃ [fb6a15b2] CloseOpenIntervals v0.1.11
  [944b1d66] CodecZlib v0.7.1
  [35d6a980] ColorSchemes v3.20.0
  [3da002f7] ColorTypes v0.11.4
  [c3611d14] ColorVectorSpace v0.9.10
  [5ae59095] Colors v0.12.10
  [861a8166] Combinatorics v1.0.2
  [a80b9123] CommonMark v0.8.10
  [38540f10] CommonSolve v0.2.3
  [bbf7d656] CommonSubexpressions v0.3.0
  [34da2185] Compat v4.6.1
  [b152e2b5] CompositeTypes v0.1.3
  [a33af91c] CompositionsBase v0.1.1
  [8f4d0f93] Conda v1.8.0
  [187b0558] ConstructionBase v1.5.1
  [d38c429a] Contour v0.6.2
  [adafc99b] CpuId v0.3.1
  [a8cc5b0e] Crayons v4.1.1
  [9a962f9c] DataAPI v1.14.0
  [864edb3b] DataStructures v0.18.13
  [e2d170a0] DataValueInterfaces v1.0.0
  [244e2a9f] DefineSingletons v0.1.2
  [b429d917] DensityInterface v0.4.0
⌃ [2b5f629d] DiffEqBase v6.114.0
  [459566f4] DiffEqCallbacks v2.26.0
  [f3b72e0c] DiffEqDevTools v2.35.0
  [77a26b50] DiffEqNoiseProcess v5.16.0
  [163ba53b] DiffResults v1.1.0
  [b552c78f] DiffRules v1.13.0
  [b4f34e82] Distances v0.10.8
  [31c24e10] Distributions v0.25.86
  [ffbed154] DocStringExtensions v0.9.3
⌅ [5b8099bc] DomainSets v0.5.15
  [fa6b7ba4] DualNumbers v0.6.8
  [7c1d4256] DynamicPolynomials v0.4.6
  [4e289a0a] EnumX v1.0.4
⌃ [d4d017d3] ExponentialUtilities v1.23.0
  [e2ba6199] ExprTools v0.1.9
  [c87230d0] FFMPEG v0.4.1
⌃ [7034ab61] FastBroadcast v0.2.4
  [9aa1b823] FastClosures v0.3.2
  [29a986be] FastLapackInterface v1.2.9
  [5789e2e9] FileIO v1.16.0
  [1a297f60] FillArrays v0.13.7
⌃ [6a86dc24] FiniteDiff v2.17.0
  [53c48c17] FixedPointNumbers v0.8.4
  [59287772] Formatting v0.4.2
  [f6369f11] ForwardDiff v0.10.35
  [069b7b12] FunctionWrappers v1.1.3
  [77dc65aa] FunctionWrappersWrappers v0.1.3
  [46192b85] GPUArraysCore v0.1.4
  [28b8d3ca] GR v0.71.7
  [c145ed77] GenericSchur v0.5.3
  [d7ba0133] Git v1.3.0
  [c27321d9] Glob v1.3.0
  [86223c79] Graphs v1.8.0
  [42e2da0e] Grisu v1.0.2
⌅ [0b43b601] Groebner v0.2.11
  [d5909c97] GroupsCore v0.4.0
  [cd3eb016] HTTP v1.7.4
  [eafb193a] Highlights v0.5.2
  [3e5b6fbb] HostCPUFeatures v0.1.14
  [34004b35] HypergeometricFunctions v0.3.11
  [7073ff75] IJulia v1.24.0
  [615f187c] IfElse v0.1.1
  [40713840] IncompleteLU v0.2.1
  [d25df0c9] Inflate v0.1.3
  [83e8ac13] IniFile v0.5.1
  [22cec73e] InitialValues v0.3.1
  [18e54dd8] IntegerMathUtils v0.1.0
⌅ [8197267c] IntervalSets v0.7.3
  [3587e190] InverseFunctions v0.1.8
  [92d709cd] IrrationalConstants v0.2.2
  [42fd0dbc] IterativeSolvers v0.9.2
  [82899510] IteratorInterfaceExtensions v1.0.0
⌃ [033835bb] JLD2 v0.4.29
  [1019f520] JLFzf v0.1.5
  [692b3bcd] JLLWrappers v1.4.1
  [682c06a0] JSON v0.21.3
  [98e50ef6] JuliaFormatter v1.0.24
  [ccbc3e58] JumpProcesses v9.5.1
  [ef3ab10e] KLU v0.4.0
  [ba0b0d4f] Krylov v0.9.0
  [0b1a1467] KrylovKit v0.6.0
  [7f56f5a3] LSODA v0.7.3
  [b964fa9f] LaTeXStrings v1.3.0
⌃ [2ee39098] LabelledArrays v1.13.0
  [984bce1d] LambertW v0.4.6
  [23fbe1c1] Latexify v0.15.18
⌃ [10f19ff3] LayoutPointers v0.1.13
  [50d2b5c4] Lazy v0.15.1
  [d3d80556] LineSearches v7.2.0
⌃ [7ed4a6bd] LinearSolve v1.33.0
  [2ab3a3ac] LogExpFunctions v0.3.23
  [e6f89c97] LoggingExtras v1.0.0
⌃ [bdcacae8] LoopVectorization v0.12.150
  [1914dd2f] MacroTools v0.5.10
  [d125e4d3] ManualMemory v0.1.8
  [739be429] MbedTLS v1.1.7
  [442fdcdd] Measures v0.3.2
⌅ [e9d8d322] Metatheory v1.3.5
  [128add7d] MicroCollections v0.1.3
  [e1d29d7a] Missings v1.1.0
⌃ [961ee093] ModelingToolkit v8.41.0
  [46d2c3a1] MuladdMacro v0.2.4
  [102ac46a] MultivariatePolynomials v0.4.7
  [ffc61752] Mustache v1.0.14
  [d8a4904e] MutableArithmetics v1.2.3
  [d41bc354] NLSolversBase v7.8.3
  [2774e3e8] NLsolve v4.5.1
  [77ba4419] NaNMath v1.0.2
  [8913a72c] NonlinearSolve v1.5.0
  [54ca160b] ODEInterface v0.5.0
  [09606e27] ODEInterfaceDiffEq v3.12.0
  [6fe1bfb0] OffsetArrays v1.12.9
  [4d8831e6] OpenSSL v1.3.3
  [429524aa] Optim v1.7.4
  [bac558e1] OrderedCollections v1.4.1
⌃ [1dea7af3] OrdinaryDiffEq v6.38.0
  [90014a1f] PDMats v0.11.17
  [d96e819e] Parameters v0.12.3
  [69de0a69] Parsers v2.5.8
  [b98c9c47] Pipe v1.3.0
  [ccf2f8ad] PlotThemes v3.1.0
  [995b91a9] PlotUtils v1.3.4
  [91a5bcdd] Plots v1.38.7
  [e409e4f3] PoissonRandom v0.4.3
⌃ [f517fe37] Polyester v0.7.2
  [1d0040c9] PolyesterWeave v0.2.1
  [85a6dd25] PositiveFactorizations v0.2.4
⌃ [d236fae5] PreallocationTools v0.4.11
  [21216c6a] Preferences v1.3.0
  [27ebfcd6] Primes v0.5.3
  [1fd47b50] QuadGK v2.8.1
  [74087812] Random123 v1.6.0
  [fb686558] RandomExtensions v0.4.3
  [e6cf234a] RandomNumbers v1.5.3
⌅ [b4db0fb7] ReactionNetworkImporters v0.13.5
  [3cdcf5f2] RecipesBase v1.3.3
  [01d81517] RecipesPipeline v0.6.11
⌃ [731186ca] RecursiveArrayTools v2.37.0
  [f2c3362d] RecursiveFactorization v0.2.18
  [189a3867] Reexport v1.2.2
  [42d2dcc6] Referenceables v0.1.2
  [05181044] RelocatableFolders v1.0.0
  [ae029012] Requires v1.3.0
  [ae5879a3] ResettableStacks v1.1.1
  [79098fc4] Rmath v0.7.1
  [47965b36] RootedTrees v2.18.0
  [7e49a35a] RuntimeGeneratedFunctions v0.5.5
  [94e857df] SIMDTypes v0.1.0
  [476501e8] SLEEFPirates v0.6.38
  [0bca4576] SciMLBase v1.89.0
  [31c91b34] SciMLBenchmarks v0.1.1
  [e9a6253c] SciMLNLSolve v0.1.3
⌃ [c0aeaf25] SciMLOperators v0.1.21
  [6c6a2e73] Scratch v1.2.0
  [efcf1570] Setfield v1.1.1
  [992d4aef] Showoff v1.0.3
  [777ac1f9] SimpleBufferStream v1.1.0
⌃ [727e6d20] SimpleNonlinearSolve v0.1.12
  [699a6c99] SimpleTraits v0.9.4
  [66db9d55] SnoopPrecompile v1.0.3
  [b85f4697] SoftGlobalScope v1.1.0
  [a2af1166] SortingAlgorithms v1.1.0
⌃ [47a9eef4] SparseDiffTools v1.30.0
  [e56a9233] Sparspak v0.3.9
  [276daf66] SpecialFunctions v2.2.0
  [171d559e] SplittablesBase v0.1.15
  [aedffcd0] Static v0.8.4
  [90137ffa] StaticArrays v1.5.16
  [1e83bf80] StaticArraysCore v1.4.0
  [82ae8749] StatsAPI v1.5.0
  [2913bbd2] StatsBase v0.33.21
  [4c63d2b9] StatsFuns v1.3.0
⌃ [7792a7ef] StrideArraysCore v0.4.7
  [69024149] StringEncodings v0.3.6
⌃ [c3572dad] Sundials v4.12.0
  [2efcf032] SymbolicIndexingInterface v0.2.2
⌅ [d1185830] SymbolicUtils v0.19.11
⌅ [0c5d862f] Symbolics v4.14.0
  [3783bdb8] TableTraits v1.0.1
  [bd369af6] Tables v1.10.0
  [62fd8b95] TensorCore v0.1.1
⌅ [8ea1fca8] TermInterface v0.2.3
  [8290d209] ThreadingUtilities v0.5.1
  [ac1d9e8a] ThreadsX v0.1.11
  [a759f4b9] TimerOutputs v0.5.22
  [0796e94c] Tokenize v0.5.25
  [3bb67fe8] TranscodingStreams v0.9.11
  [28d57a85] Transducers v0.4.75
  [a2a6695c] TreeViews v0.3.0
  [d5829a12] TriangularSolve v0.1.19
  [410a4b4d] Tricks v0.1.6
  [781d530d] TruncatedStacktraces v1.1.0
  [5c2747f8] URIs v1.4.2
  [3a884ed6] UnPack v1.0.2
  [1cfade01] UnicodeFun v0.4.1
  [1986cc42] Unitful v1.12.4
  [41fe7b60] Unzip v0.2.0
⌃ [3d5dd08c] VectorizationBase v0.21.58
  [81def892] VersionParsing v1.3.0
  [19fa3120] VertexSafeGraphs v0.2.0
  [44d3d7a6] Weave v0.10.12
  [ddb6d928] YAML v0.4.8
  [c2297ded] ZMQ v1.2.2
  [700de1a5] ZygoteRules v0.2.2
  [6e34b625] Bzip2_jll v1.0.8+0
  [83423d85] Cairo_jll v1.16.1+1
  [2e619515] Expat_jll v2.4.8+0
  [b22a6f82] FFMPEG_jll v4.4.2+2
  [a3f928ae] Fontconfig_jll v2.13.93+0
  [d7e528f0] FreeType2_jll v2.10.4+0
  [559328eb] FriBidi_jll v1.0.10+0
  [0656b61e] GLFW_jll v3.3.8+0
  [d2c73de3] GR_jll v0.71.7+0
  [78b55507] Gettext_jll v0.21.0+0
  [f8c6e375] Git_jll v2.36.1+2
  [7746bdde] Glib_jll v2.74.0+2
  [3b182d85] Graphite2_jll v1.3.14+0
  [2e76f6c2] HarfBuzz_jll v2.8.1+1
  [aacddb02] JpegTurbo_jll v2.1.91+0
  [c1c5ebd0] LAME_jll v3.100.1+0
  [88015f11] LERC_jll v3.0.0+1
  [aae0fff6] LSODA_jll v0.1.1+0
  [dd4b983a] LZO_jll v2.10.1+0
⌅ [e9f186c6] Libffi_jll v3.2.2+1
  [d4300ac3] Libgcrypt_jll v1.8.7+0
  [7e76a0d4] Libglvnd_jll v1.6.0+0
  [7add5ba3] Libgpg_error_jll v1.42.0+0
  [94ce4f54] Libiconv_jll v1.16.1+2
  [4b2f31a3] Libmount_jll v2.35.0+0
  [89763e89] Libtiff_jll v4.4.0+0
  [38a345b3] Libuuid_jll v2.36.0+0
  [c771fb93] ODEInterface_jll v0.0.1+0
  [e7412a2a] Ogg_jll v1.3.5+1
  [458c3c95] OpenSSL_jll v1.1.20+0
  [efe28fd5] OpenSpecFun_jll v0.5.5+0
  [91d4177d] Opus_jll v1.3.2+0
  [30392449] Pixman_jll v0.40.1+0
  [ea2cea3b] Qt5Base_jll v5.15.3+2
  [f50d1b31] Rmath_jll v0.4.0+0
  [fb77eaff] Sundials_jll v5.2.1+0
  [a2964d1f] Wayland_jll v1.21.0+0
  [2381bf8a] Wayland_protocols_jll v1.25.0+0
  [02c8fc9c] XML2_jll v2.10.3+0
  [aed1982a] XSLT_jll v1.1.34+0
  [4f6342f7] Xorg_libX11_jll v1.6.9+4
  [0c0b7dd1] Xorg_libXau_jll v1.0.9+4
  [935fb764] Xorg_libXcursor_jll v1.2.0+4
  [a3789734] Xorg_libXdmcp_jll v1.1.3+4
  [1082639a] Xorg_libXext_jll v1.3.4+4
  [d091e8ba] Xorg_libXfixes_jll v5.0.3+4
  [a51aa0fd] Xorg_libXi_jll v1.7.10+4
  [d1454406] Xorg_libXinerama_jll v1.1.4+4
  [ec84b674] Xorg_libXrandr_jll v1.5.2+4
  [ea2f1a96] Xorg_libXrender_jll v0.9.10+4
  [14d82f49] Xorg_libpthread_stubs_jll v0.1.0+3
  [c7cfdc94] Xorg_libxcb_jll v1.13.0+3
  [cc61e674] Xorg_libxkbfile_jll v1.1.0+4
  [12413925] Xorg_xcb_util_image_jll v0.4.0+1
  [2def613f] Xorg_xcb_util_jll v0.4.0+1
  [975044d2] Xorg_xcb_util_keysyms_jll v0.4.0+1
  [0d47668e] Xorg_xcb_util_renderutil_jll v0.3.9+1
  [c22f9ab0] Xorg_xcb_util_wm_jll v0.4.1+1
  [35661453] Xorg_xkbcomp_jll v1.4.2+4
  [33bec58e] Xorg_xkeyboard_config_jll v2.27.0+4
  [c5fb5394] Xorg_xtrans_jll v1.4.0+3
  [8f1865be] ZeroMQ_jll v4.3.4+0
  [3161d3a3] Zstd_jll v1.5.4+0
⌅ [214eeab7] fzf_jll v0.29.0+0
  [a4ae2306] libaom_jll v3.4.0+0
  [0ac62f75] libass_jll v0.15.1+0
  [f638f0a6] libfdk_aac_jll v2.0.2+0
  [b53b4c65] libpng_jll v1.6.38+0
  [a9144af2] libsodium_jll v1.0.20+0
  [f27f6e37] libvorbis_jll v1.3.7+1
  [1270edf5] x264_jll v2021.5.5+0
  [dfaa095f] x265_jll v3.5.0+0
  [d8fb68d0] xkbcommon_jll v1.4.1+0
  [0dad84c5] ArgTools v1.1.1
  [56f22d72] Artifacts
  [2a0f44e3] Base64
  [ade2ca70] Dates
  [8bb1440f] DelimitedFiles
  [8ba89e20] Distributed
  [f43a241f] Downloads v1.6.0
  [7b1f6079] FileWatching
  [9fa8497b] Future
  [b77e0a4c] InteractiveUtils
  [b27032c2] LibCURL v0.6.3
  [76f85450] LibGit2
  [8f399da3] Libdl
  [37e2e46d] LinearAlgebra
  [56ddb016] Logging
  [d6f4376e] Markdown
  [a63ad114] Mmap
  [ca575930] NetworkOptions v1.2.0
  [44cfe95a] Pkg v1.8.0
  [de0858da] Printf
  [9abbd945] Profile
  [3fa0cd96] REPL
  [9a3f8284] Random
  [ea8e919c] SHA v0.7.0
  [9e88b42a] Serialization
  [1a1011a3] SharedArrays
  [6462fe0b] Sockets
  [2f01184e] SparseArrays
  [10745b16] Statistics
  [4607b0f0] SuiteSparse
  [fa267f1f] TOML v1.0.0
  [a4e569a6] Tar v1.10.1
  [8dfed614] Test
  [cf7118a7] UUIDs
  [4ec0a83e] Unicode
  [e66e0078] CompilerSupportLibraries_jll v1.0.1+0
  [deac9b47] LibCURL_jll v7.84.0+0
  [29816b5a] LibSSH2_jll v1.10.2+0
  [c8ffd9c3] MbedTLS_jll v2.28.0+0
  [14a3606d] MozillaCACerts_jll v2022.2.1
  [4536629a] OpenBLAS_jll v0.3.20+0
  [05823500] OpenLibm_jll v0.8.1+0
  [efcefdf7] PCRE2_jll v10.40.0+0
  [bea87d4a] SuiteSparse_jll v5.10.1+0
  [83775a58] Zlib_jll v1.2.12+3
  [8e850b90] libblastrampoline_jll v5.1.1+0
  [8e850ede] nghttp2_jll v1.48.0+0
  [3f19e933] p7zip_jll v17.4.0+0
Info Packages marked with ⌃ and ⌅ have new versions available, but those with ⌅ are restricted by compatibility constraints from upgrading. To see why use `status --outdated -m`
```

