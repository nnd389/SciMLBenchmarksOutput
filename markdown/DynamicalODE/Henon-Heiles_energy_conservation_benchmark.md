---
author: "Sebastian Micluța-Câmpeanu, Chris Rackauckas"
title: "Hénon-Heiles Energy Conservation"
---


In this notebook we will study the energy conservation properties of several high-order methods
for the [Hénon-Heiles system](https://en.wikipedia.org/wiki/H%C3%A9non%E2%80%93Heiles_system).
We will se how the energy error behaves at very thight tolerances and how different techniques,
such as using symplectic solvers or manifold projections, benchmark against each other.
The Hamiltonian for this system is given by:

$$\mathcal{H}=\frac{1}{2}(p_1^2 + p_2^2) + \frac{1}{2}\left(q_1^2 + q_2^2 + 2q_1^2 q_2 - \frac{2}{3}q_2^3\right)$$

We will also compare the in place apporach with the out of place approach by using `Array`s
(for the in place version) and `StaticArrays` (for out of place versions).
In order to separate these two, we will use `iip` for the in-place names and `oop` for out of place ones.

```julia
using OrdinaryDiffEq, Plots, DiffEqCallbacks
using SciMLBenchmarks
using TaylorIntegration, LinearAlgebra, StaticArrays
gr(fmt=:png)
default(fmt=:png)

T(p) = 1//2 * norm(p)^2
V(q) = 1//2 * (q[1]^2 + q[2]^2 + 2q[1]^2 * q[2]- 2//3 * q[2]^3)
H(p,q, params) = T(p) + V(q)

function iip_dq(dq,p,q,params,t)
    dq[1] = p[1]
    dq[2] = p[2]
end

function iip_dp(dp,p,q,params,t)
    dp[1] = -q[1] * (1 + 2q[2])
    dp[2] = -q[2] - (q[1]^2 - q[2]^2)
end

const iip_q0 = [0.1, 0.]
const iip_p0 = [0., 0.5]

function oop_dq(p, q, params, t)
    p
end

function oop_dp(p, q, params, t)
    dp1 = -q[1] * (1 + 2q[2])
    dp2 = -q[2] - (q[1]^2 - q[2]^2)
    @SVector [dp1, dp2]
end

const oop_q0 = @SVector [0.1, 0.]
const oop_p0 = @SVector [0., 0.5]

function hamilton(du,u,p,t)
    dq, q = @views u[3:4], du[3:4]
    dp, p = @views u[1:2], du[1:2]

    dp[1] = -q[1] * (1 + 2q[2])
    dp[2] = -q[2] - (q[1]^2 - q[2]^2)
    dq .= p

    return nothing
end

function g(resid, u, p)
    resid[1] = H([u[1],u[2]], [u[3],u[4]], nothing) - E
    resid[2:4] .= 0
end

const cb = ManifoldProjection(g, nlopts=Dict(:ftol=>1e-13))

const E = H(iip_p0, iip_q0, nothing)
```

```
0.13
```





For the comparison we will use the following function

```julia
energy_err(sol) = map(i->H([sol[1,i], sol[2,i]], [sol[3,i], sol[4,i]], nothing)-E, 1:length(sol.u))
abs_energy_err(sol) = [abs.(H([sol[1,j], sol[2,j]], [sol[3,j], sol[4,j]], nothing) - E) for j=1:length(sol.u)]

function compare(mode=:inplace, all=true, plt=nothing; tmax=1e2)
    if mode == :inplace
        prob = DynamicalODEProblem(iip_dp, iip_dq, iip_p0, iip_q0, (0., tmax))
    else
        prob = DynamicalODEProblem(oop_dp, oop_dq, oop_p0, oop_q0, (0., tmax))
    end
    prob_linear = ODEProblem(hamilton, vcat(iip_p0, iip_q0), (0., tmax))

    GC.gc()
    (mode == :inplace && all) && @time sol1 = solve(prob, Vern9(), callback=cb, abstol=1e-14, reltol=1e-14)
    GC.gc()
    @time sol2 = solve(prob, KahanLi8(), dt=1e-2, maxiters=1e10)
    GC.gc()
    @time sol3 = solve(prob, SofSpa10(), dt=1e-2, maxiters=1e8)
    GC.gc()
    @time sol4 = solve(prob, Vern9(), abstol=1e-14, reltol=1e-14)
    GC.gc()
    @time sol5 = solve(prob, DPRKN12(), abstol=1e-14, reltol=1e-14)
    GC.gc()
    (mode == :inplace && all) && @time sol6 = solve(prob_linear, TaylorMethod(50), abstol=1e-20)

    (mode == :inplace && all) && println("Vern9 + ManifoldProjection max energy error:\t"*
        "$(maximum(abs_energy_err(sol1)))\tin\t$(length(sol1.u))\tsteps.")
    println("KahanLi8 max energy error:\t\t\t$(maximum(abs_energy_err(sol2)))\tin\t$(length(sol2.u))\tsteps.")
    println("SofSpa10 max energy error:\t\t\t$(maximum(abs_energy_err(sol3)))\tin\t$(length(sol3.u))\tsteps.")
    println("Vern9 max energy error:\t\t\t\t$(maximum(abs_energy_err(sol4)))\tin\t$(length(sol4.u))\tsteps.")
    println("DPRKN12 max energy error:\t\t\t$(maximum(abs_energy_err(sol5)))\tin\t$(length(sol5.u))\tsteps.")
    (mode == :inplace && all) && println("TaylorMethod max energy error:\t\t\t$(maximum(abs_energy_err(sol6)))"*
        "\tin\t$(length(sol6.u))\tsteps.")

    if plt === nothing
        plt = plot(xlabel="t", ylabel="Energy error")
    end
    (mode == :inplace && all) && plot!(sol1.t, energy_err(sol1), label="Vern9 + ManifoldProjection")
    plot!(sol2.t, energy_err(sol2), label="KahanLi8", ls=mode==:inplace ? :solid : :dash)
    plot!(sol3.t, energy_err(sol3), label="SofSpa10", ls=mode==:inplace ? :solid : :dash)
    plot!(sol4.t, energy_err(sol4), label="Vern9", ls=mode==:inplace ? :solid : :dash)
    plot!(sol5.t, energy_err(sol5), label="DPRKN12", ls=mode==:inplace ? :solid : :dash)
    (mode == :inplace && all) && plot!(sol6.t, energy_err(sol6), label="TaylorMethod")

    return plt
end
```

```
compare (generic function with 4 methods)
```





The `mode` argument choses between the in place approach
and the out of place one. The `all` parameter is used to compare only the integrators that support both
the in place and the out of place versions (we reffer here only to the 6 high order methods chosen bellow).
The `plt` argument can be used to overlay the results over a previous plot and the `tmax` keyword determines
the simulation time.

Note:
1. The `Vern9` method is used with `ODEProblem` because of performance issues with `ArrayPartition` indexing which manifest for `DynamicalODEProblem`.
2. The `NLsolve` call used by `ManifoldProjection` was modified to use `ftol=1e-13` in order to obtain a very low energy error.

Here are the results of the comparisons between the in place methods:

```julia
compare(tmax=1e2)
```

```
271.699670 seconds (212.71 M allocations: 10.770 GiB, 1.44% gc time, 99.99%
 compilation time)
  4.036090 seconds (14.93 M allocations: 744.111 MiB, 3.35% gc time, 99.82%
 compilation time)
  3.229579 seconds (7.91 M allocations: 411.130 MiB, 2.04% gc time, 99.68% 
compilation time)
175.349204 seconds (19.33 M allocations: 772.018 MiB, 0.15% gc time, 100.00
% compilation time)
  5.191661 seconds (8.42 M allocations: 452.258 MiB, 0.84% gc time, 99.97% 
compilation time)
  2.498380 seconds (5.79 M allocations: 398.278 MiB, 2.19% gc time, 99.97% 
compilation time)
Vern9 + ManifoldProjection max energy error:	3.0531133177191805e-16	in	1881
	steps.
KahanLi8 max energy error:			4.9404924595819466e-15	in	10001	steps.
SofSpa10 max energy error:			5.440092820663267e-15	in	10001	steps.
Vern9 max energy error:				3.0531133177191805e-16	in	941	steps.
DPRKN12 max energy error:			1.942890293094024e-16	in	385	steps.
TaylorMethod max energy error:			0.0	in	2	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_3_1.png)

```julia
compare(tmax=1e3)
```

```
0.108232 seconds (1.02 M allocations: 69.054 MiB)
  0.076456 seconds (700.10 k allocations: 61.899 MiB)
  0.108398 seconds (700.10 k allocations: 61.901 MiB)
  0.053855 seconds (326.73 k allocations: 20.282 MiB)
  0.005685 seconds (72.14 k allocations: 3.121 MiB)
  0.000586 seconds (2.11 k allocations: 785.609 KiB)
Vern9 + ManifoldProjection max energy error:	4.274358644806853e-15	in	18659
	steps.
KahanLi8 max energy error:			1.815214645262131e-14	in	100002	steps.
SofSpa10 max energy error:			2.8033131371785203e-14	in	100002	steps.
Vern9 max energy error:				4.274358644806853e-15	in	9330	steps.
DPRKN12 max energy error:			8.604228440844963e-16	in	3787	steps.
TaylorMethod max energy error:			0.0	in	2	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_4_1.png)

```julia
compare(tmax=1e4)
```

```
1.453077 seconds (10.16 M allocations: 685.649 MiB, 19.38% gc time)
  0.969164 seconds (7.00 M allocations: 579.841 MiB, 21.58% gc time)
  1.062469 seconds (7.00 M allocations: 579.844 MiB)
  0.532087 seconds (3.26 M allocations: 203.204 MiB)
  0.054207 seconds (718.64 k allocations: 32.470 MiB)
  0.000576 seconds (2.11 k allocations: 785.609 KiB)
Vern9 + ManifoldProjection max energy error:	4.593547764386585e-14	in	18642
9	steps.
KahanLi8 max energy error:			3.161360062620133e-14	in	1000001	steps.
SofSpa10 max energy error:			1.136590821460004e-13	in	1000001	steps.
Vern9 max energy error:				4.593547764386585e-14	in	93215	steps.
DPRKN12 max energy error:			8.465450562766819e-15	in	37813	steps.
TaylorMethod max energy error:			0.0	in	2	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_5_1.png)

```julia
compare(tmax=5e4)
```

```
7.725003 seconds (51.14 M allocations: 3.347 GiB, 21.51% gc time, 1.61% c
ompilation time)
  6.333915 seconds (35.00 M allocations: 2.831 GiB, 39.27% gc time)
 10.674456 seconds (35.00 M allocations: 2.831 GiB, 50.43% gc time)
  2.671526 seconds (16.31 M allocations: 1001.925 MiB)
  4.839273 seconds (3.59 M allocations: 155.672 MiB, 94.27% gc time)
  0.000634 seconds (2.11 k allocations: 785.609 KiB)
Vern9 + ManifoldProjection max energy error:	1.0000333894311098e-13	in	9320
91	steps.
KahanLi8 max energy error:			1.2331802246023926e-13	in	5000001	steps.
SofSpa10 max energy error:			1.5035195310986182e-13	in	5000001	steps.
Vern9 max energy error:				2.2451485115482228e-13	in	466046	steps.
DPRKN12 max energy error:			3.5388358909926865e-14	in	189039	steps.
TaylorMethod max energy error:			0.0	in	2	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_6_1.png)



We can see that as the simulation time increases, the energy error increases. For this particular example
the energy error for all the methods is comparable. For relatively short simulation times,
if a highly accurate solution is required, the symplectic method is not recommended as
its energy error fluctuations are larger than for other methods.
An other thing to notice is the fact that the two versions of `Vern9` behave identically, as expected,
untill the energy error set by `ftol` is reached.

We will now compare the in place with the out of place versions. In the plots bellow we will use
a dashed line for the out of place versions.

```julia
function in_vs_out(;all=false, tmax=1e2)
    println("In place versions:")
    plt = compare(:inplace, all, tmax=tmax)
    println("\nOut of place versions:")
    plt = compare(:oop, false, plt; tmax=tmax)
end
```

```
in_vs_out (generic function with 1 method)
```





First, here is a summary of all the available methods for `tmax = 1e3`:

```julia
in_vs_out(all=true, tmax=1e3)
```

```
In place versions:
  0.108057 seconds (1.02 M allocations: 69.054 MiB)
  0.075184 seconds (700.10 k allocations: 61.899 MiB)
  0.108528 seconds (700.10 k allocations: 61.901 MiB)
  0.054281 seconds (326.73 k allocations: 20.282 MiB)
  0.005650 seconds (72.14 k allocations: 3.121 MiB)
  0.000588 seconds (2.11 k allocations: 785.609 KiB)
Vern9 + ManifoldProjection max energy error:	4.274358644806853e-15	in	18659
	steps.
KahanLi8 max energy error:			1.815214645262131e-14	in	100002	steps.
SofSpa10 max energy error:			2.8033131371785203e-14	in	100002	steps.
Vern9 max energy error:				4.274358644806853e-15	in	9330	steps.
DPRKN12 max energy error:			8.604228440844963e-16	in	3787	steps.
TaylorMethod max energy error:			0.0	in	2	steps.

Out of place versions:
  1.922603 seconds (5.20 M allocations: 303.006 MiB, 3.82% gc time, 98.59% 
compilation time)
  1.107676 seconds (2.23 M allocations: 137.174 MiB, 2.30% gc time, 94.33% 
compilation time)
  5.604480 seconds (6.14 M allocations: 292.238 MiB, 0.63% gc time, 99.89% 
compilation time)
  1.817120 seconds (2.39 M allocations: 127.359 MiB, 99.86% compilation tim
e)
KahanLi8 max energy error:			1.815214645262131e-14	in	100002	steps.
SofSpa10 max energy error:			2.8033131371785203e-14	in	100002	steps.
Vern9 max energy error:				4.496403249731884e-15	in	9330	steps.
DPRKN12 max energy error:			4.440892098500626e-16	in	3787	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_8_1.png)



Now we will compare the in place and the out of place versions, but only for the integrators
that are compatible with `StaticArrays`

```julia
in_vs_out(tmax=1e2)
```

```
In place versions:
  0.007093 seconds (70.09 k allocations: 5.806 MiB)
  0.009447 seconds (70.09 k allocations: 5.808 MiB)
  0.005102 seconds (33.11 k allocations: 2.100 MiB)
  0.000674 seconds (7.50 k allocations: 352.312 KiB)
KahanLi8 max energy error:			4.9404924595819466e-15	in	10001	steps.
SofSpa10 max energy error:			5.440092820663267e-15	in	10001	steps.
Vern9 max energy error:				3.0531133177191805e-16	in	941	steps.
DPRKN12 max energy error:			1.942890293094024e-16	in	385	steps.

Out of place versions:
  0.002567 seconds (10.05 k allocations: 1.682 MiB)
  0.003766 seconds (10.05 k allocations: 1.683 MiB)
  0.000658 seconds (14.20 k allocations: 716.672 KiB)
  0.000330 seconds (5.86 k allocations: 184.438 KiB)
KahanLi8 max energy error:			4.9404924595819466e-15	in	10001	steps.
SofSpa10 max energy error:			5.440092820663267e-15	in	10001	steps.
Vern9 max energy error:				3.3306690738754696e-16	in	941	steps.
DPRKN12 max energy error:			2.220446049250313e-16	in	385	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_9_1.png)

```julia
in_vs_out(tmax=1e3)
```

```
In place versions:
  0.066575 seconds (700.10 k allocations: 61.899 MiB)
  0.108494 seconds (700.10 k allocations: 61.901 MiB)
  0.055988 seconds (326.73 k allocations: 20.282 MiB)
  0.005822 seconds (72.14 k allocations: 3.121 MiB)
KahanLi8 max energy error:			1.815214645262131e-14	in	100002	steps.
SofSpa10 max energy error:			2.8033131371785203e-14	in	100002	steps.
Vern9 max energy error:				4.274358644806853e-15	in	9330	steps.
DPRKN12 max energy error:			8.604228440844963e-16	in	3787	steps.

Out of place versions:
  0.027341 seconds (100.05 k allocations: 21.886 MiB)
  0.036937 seconds (100.05 k allocations: 21.887 MiB)
  0.006288 seconds (140.04 k allocations: 6.467 MiB)
  0.002424 seconds (56.89 k allocations: 1.595 MiB)
KahanLi8 max energy error:			1.815214645262131e-14	in	100002	steps.
SofSpa10 max energy error:			2.8033131371785203e-14	in	100002	steps.
Vern9 max energy error:				4.496403249731884e-15	in	9330	steps.
DPRKN12 max energy error:			4.440892098500626e-16	in	3787	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_10_1.png)

```julia
in_vs_out(tmax=1e4)
```

```
In place versions:
  1.094424 seconds (7.00 M allocations: 579.841 MiB, 29.10% gc time)
  1.358227 seconds (7.00 M allocations: 579.844 MiB, 21.46% gc time)
  0.539791 seconds (3.26 M allocations: 203.204 MiB)
  0.054564 seconds (718.64 k allocations: 32.470 MiB)
KahanLi8 max energy error:			3.161360062620133e-14	in	1000001	steps.
SofSpa10 max energy error:			1.136590821460004e-13	in	1000001	steps.
Vern9 max energy error:				4.593547764386585e-14	in	93215	steps.
DPRKN12 max energy error:			8.465450562766819e-15	in	37813	steps.

Out of place versions:
  0.299182 seconds (1.00 M allocations: 167.850 MiB, 7.17% gc time)
  0.361995 seconds (1.00 M allocations: 167.851 MiB)
  0.066102 seconds (1.40 M allocations: 65.297 MiB)
  0.022775 seconds (567.29 k allocations: 18.100 MiB)
KahanLi8 max energy error:			3.161360062620133e-14	in	1000001	steps.
SofSpa10 max energy error:			1.136590821460004e-13	in	1000001	steps.
Vern9 max energy error:				4.4797499043625066e-14	in	93215	steps.
DPRKN12 max energy error:			2.6922908347160046e-15	in	37813	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_11_1.png)

```julia
in_vs_out(tmax=5e4)
```

```
In place versions:
  5.850563 seconds (35.00 M allocations: 2.831 GiB, 33.95% gc time)
  9.546422 seconds (35.00 M allocations: 2.831 GiB, 44.57% gc time)
  2.665904 seconds (16.31 M allocations: 1001.925 MiB)
  3.930075 seconds (3.59 M allocations: 155.672 MiB, 92.98% gc time)
KahanLi8 max energy error:			1.2331802246023926e-13	in	5000001	steps.
SofSpa10 max energy error:			1.5035195310986182e-13	in	5000001	steps.
Vern9 max energy error:				2.2451485115482228e-13	in	466046	steps.
DPRKN12 max energy error:			3.5388358909926865e-14	in	189039	steps.

Out of place versions:
  1.559227 seconds (5.00 M allocations: 839.237 MiB, 12.25% gc time)
  2.026374 seconds (5.00 M allocations: 839.238 MiB, 10.26% gc time)
  0.322292 seconds (6.99 M allocations: 307.636 MiB)
  0.120090 seconds (2.84 M allocations: 80.089 MiB)
KahanLi8 max energy error:			1.2331802246023926e-13	in	5000001	steps.
SofSpa10 max energy error:			1.5035195310986182e-13	in	5000001	steps.
Vern9 max energy error:				2.246258734572848e-13	in	466047	steps.
DPRKN12 max energy error:			3.4361402612148595e-14	in	189040	steps.
```


![](figures/Henon-Heiles_energy_conservation_benchmark_12_1.png)



As we see from the above comparisons, the `StaticArray` versions are significantly faster and use less memory.
The speedup provided for the out of place version is more proeminent at larger values for `tmax`.
We can see again that if the simulation time is increased, the energy error of the symplectic methods
is less noticeable compared to the rest of the methods.

The benchmarks were performed on a machine with


## Appendix

These benchmarks are a part of the SciMLBenchmarks.jl repository, found at: [https://github.com/SciML/SciMLBenchmarks.jl](https://github.com/SciML/SciMLBenchmarks.jl). For more information on high-performance scientific machine learning, check out the SciML Open Source Software Organization [https://sciml.ai](https://sciml.ai).

To locally run this benchmark, do the following commands:

```
using SciMLBenchmarks
SciMLBenchmarks.weave_file("benchmarks/DynamicalODE","Henon-Heiles_energy_conservation_benchmark.jmd")
```

Computer Information:

```
Julia Version 1.7.3
Commit 742b9abb4d (2022-05-06 12:58 UTC)
Platform Info:
  OS: Linux (x86_64-pc-linux-gnu)
  CPU: AMD EPYC 7502 32-Core Processor
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-12.0.1 (ORCJIT, znver2)
Environment:
  JULIA_CPU_THREADS = 128
  BUILDKITE_PLUGIN_JULIA_CACHE_DIR = /cache/julia-buildkite-plugin
  JULIA_DEPOT_PATH = /cache/julia-buildkite-plugin/depots/5b300254-1738-4989-ae0a-f4d2d937f953

```

Package Information:

```
      Status `/cache/build/exclusive-amdci3-0/julialang/scimlbenchmarks-dot-jl/benchmarks/DynamicalODE/Project.toml`
  [459566f4] DiffEqCallbacks v2.23.1
  [055956cb] DiffEqPhysics v3.9.0
  [b305315f] Elliptic v1.0.1
  [1dea7af3] OrdinaryDiffEq v6.19.1
  [65888b18] ParameterizedFunctions v5.13.2
  [91a5bcdd] Plots v1.31.4
  [d330b81b] PyPlot v2.10.0
  [31c91b34] SciMLBenchmarks v0.1.0
  [90137ffa] StaticArrays v1.5.2
  [92b13dbe] TaylorIntegration v0.8.11
  [37e2e46d] LinearAlgebra
  [de0858da] Printf
  [10745b16] Statistics
```

And the full manifest:

```
      Status `/cache/build/exclusive-amdci3-0/julialang/scimlbenchmarks-dot-jl/benchmarks/DynamicalODE/Manifest.toml`
  [c3fe647b] AbstractAlgebra v0.27.0
  [1520ce14] AbstractTrees v0.4.2
  [79e6a3ab] Adapt v3.3.3
  [dce04be8] ArgCheck v2.3.0
  [ec485272] ArnoldiMethod v0.2.0
  [4fba245c] ArrayInterface v6.0.21
  [30b0a656] ArrayInterfaceCore v0.1.15
  [6ba088a2] ArrayInterfaceGPUArrays v0.2.1
  [015c0d05] ArrayInterfaceOffsetArrays v0.1.6
  [b0d46f97] ArrayInterfaceStaticArrays v0.1.4
  [dd5226c6] ArrayInterfaceStaticArraysCore v0.1.0
  [15f4f7f2] AutoHashEquals v0.2.0
  [198e06fe] BangBang v0.3.36
  [9718e550] Baselet v0.1.1
  [e2ed5e7c] Bijections v0.1.4
  [62783981] BitTwiddlingConvenienceFunctions v0.1.4
  [2a0fbf3d] CPUSummary v0.1.25
  [00ebfdb7] CSTParser v3.3.6
  [49dc2e85] Calculus v0.5.1
  [d360d2e6] ChainRulesCore v1.15.3
  [9e997f8a] ChangesOfVariables v0.1.4
  [fb6a15b2] CloseOpenIntervals v0.1.10
  [944b1d66] CodecZlib v0.7.0
  [35d6a980] ColorSchemes v3.19.0
  [3da002f7] ColorTypes v0.11.4
  [c3611d14] ColorVectorSpace v0.9.9
  [5ae59095] Colors v0.12.8
  [861a8166] Combinatorics v1.0.2
  [a80b9123] CommonMark v0.8.6
  [38540f10] CommonSolve v0.2.1
  [bbf7d656] CommonSubexpressions v0.3.0
  [34da2185] Compat v3.45.0
  [b152e2b5] CompositeTypes v0.1.2
  [a33af91c] CompositionsBase v0.1.1
  [8f4d0f93] Conda v1.7.0
  [187b0558] ConstructionBase v1.4.0
  [d38c429a] Contour v0.6.2
  [adafc99b] CpuId v0.3.1
  [a8cc5b0e] Crayons v4.1.1
  [9a962f9c] DataAPI v1.10.0
  [864edb3b] DataStructures v0.18.13
  [e2d170a0] DataValueInterfaces v1.0.0
  [244e2a9f] DefineSingletons v0.1.2
  [b429d917] DensityInterface v0.4.0
  [2b5f629d] DiffEqBase v6.94.4
  [459566f4] DiffEqCallbacks v2.23.1
  [055956cb] DiffEqPhysics v3.9.0
  [163ba53b] DiffResults v1.0.3
  [b552c78f] DiffRules v1.11.0
  [b4f34e82] Distances v0.10.7
  [31c24e10] Distributions v0.25.66
  [ffbed154] DocStringExtensions v0.8.6
  [5b8099bc] DomainSets v0.5.11
  [fa6b7ba4] DualNumbers v0.6.8
  [7c1d4256] DynamicPolynomials v0.4.5
  [b305315f] Elliptic v1.0.1
  [6912e4f1] Espresso v0.6.1
  [d4d017d3] ExponentialUtilities v1.18.0
  [e2ba6199] ExprTools v0.1.8
  [c87230d0] FFMPEG v0.4.1
  [7034ab61] FastBroadcast v0.2.1
  [9aa1b823] FastClosures v0.3.2
  [29a986be] FastLapackInterface v1.1.0
  [1a297f60] FillArrays v0.13.2
  [6a86dc24] FiniteDiff v2.13.1
  [53c48c17] FixedPointNumbers v0.8.4
  [59287772] Formatting v0.4.2
  [f6369f11] ForwardDiff v0.10.30
  [069b7b12] FunctionWrappers v1.1.2
  [46192b85] GPUArraysCore v0.1.1
  [28b8d3ca] GR v0.66.0
  [c145ed77] GenericSchur v0.5.3
  [5c1252a2] GeometryBasics v0.4.2
  [d7ba0133] Git v1.2.1
  [86223c79] Graphs v1.7.1
  [42e2da0e] Grisu v1.0.2
  [0b43b601] Groebner v0.2.8
  [d5909c97] GroupsCore v0.4.0
  [cd3eb016] HTTP v1.2.0
  [eafb193a] Highlights v0.4.5
  [3e5b6fbb] HostCPUFeatures v0.1.8
  [34004b35] HypergeometricFunctions v0.3.11
  [7073ff75] IJulia v1.23.3
  [615f187c] IfElse v0.1.1
  [d25df0c9] Inflate v0.1.2
  [83e8ac13] IniFile v0.5.1
  [22cec73e] InitialValues v0.3.1
  [18e54dd8] IntegerMathUtils v0.1.0
  [8197267c] IntervalSets v0.7.1
  [3587e190] InverseFunctions v0.1.7
  [92d709cd] IrrationalConstants v0.1.1
  [c8e1da08] IterTools v1.4.0
  [42fd0dbc] IterativeSolvers v0.9.2
  [82899510] IteratorInterfaceExtensions v1.0.0
  [692b3bcd] JLLWrappers v1.4.1
  [682c06a0] JSON v0.21.3
  [98e50ef6] JuliaFormatter v1.0.7
  [ccbc3e58] JumpProcesses v9.0.1
  [ef3ab10e] KLU v0.3.0
  [ba0b0d4f] Krylov v0.8.2
  [0b1a1467] KrylovKit v0.5.4
  [b964fa9f] LaTeXStrings v1.3.0
  [2ee39098] LabelledArrays v1.11.1
  [23fbe1c1] Latexify v0.15.16
  [10f19ff3] LayoutPointers v0.1.10
  [d3d80556] LineSearches v7.1.1
  [7ed4a6bd] LinearSolve v1.23.0
  [2ab3a3ac] LogExpFunctions v0.3.16
  [e6f89c97] LoggingExtras v0.4.9
  [bdcacae8] LoopVectorization v0.12.120
  [1914dd2f] MacroTools v0.5.9
  [d125e4d3] ManualMemory v0.1.8
  [739be429] MbedTLS v1.1.1
  [442fdcdd] Measures v0.3.1
  [e9d8d322] Metatheory v1.3.4
  [128add7d] MicroCollections v0.1.2
  [e1d29d7a] Missings v1.0.2
  [961ee093] ModelingToolkit v8.18.0
  [46d2c3a1] MuladdMacro v0.2.2
  [102ac46a] MultivariatePolynomials v0.4.6
  [ffc61752] Mustache v1.0.14
  [d8a4904e] MutableArithmetics v1.0.4
  [d41bc354] NLSolversBase v7.8.2
  [2774e3e8] NLsolve v4.5.1
  [77ba4419] NaNMath v0.3.7
  [8913a72c] NonlinearSolve v0.3.21
  [6fe1bfb0] OffsetArrays v1.12.7
  [bac558e1] OrderedCollections v1.4.1
  [1dea7af3] OrdinaryDiffEq v6.19.1
  [90014a1f] PDMats v0.11.16
  [65888b18] ParameterizedFunctions v5.13.2
  [d96e819e] Parameters v0.12.3
  [69de0a69] Parsers v2.3.2
  [ccf2f8ad] PlotThemes v3.0.0
  [995b91a9] PlotUtils v1.3.0
  [91a5bcdd] Plots v1.31.4
  [e409e4f3] PoissonRandom v0.4.1
  [f517fe37] Polyester v0.6.14
  [1d0040c9] PolyesterWeave v0.1.7
  [d236fae5] PreallocationTools v0.4.0
  [21216c6a] Preferences v1.3.0
  [27ebfcd6] Primes v0.5.3
  [438e738f] PyCall v1.93.1
  [d330b81b] PyPlot v2.10.0
  [1fd47b50] QuadGK v2.4.2
  [fb686558] RandomExtensions v0.4.3
  [e6cf234a] RandomNumbers v1.5.3
  [3cdcf5f2] RecipesBase v1.2.1
  [01d81517] RecipesPipeline v0.6.2
  [731186ca] RecursiveArrayTools v2.31.2
  [f2c3362d] RecursiveFactorization v0.2.11
  [189a3867] Reexport v1.2.2
  [42d2dcc6] Referenceables v0.1.2
  [05181044] RelocatableFolders v0.3.0
  [ae029012] Requires v1.3.0
  [79098fc4] Rmath v0.7.0
  [7e49a35a] RuntimeGeneratedFunctions v0.5.3
  [3cdde19b] SIMDDualNumbers v0.1.1
  [94e857df] SIMDTypes v0.1.0
  [476501e8] SLEEFPirates v0.6.33
  [0bca4576] SciMLBase v1.44.1
  [31c91b34] SciMLBenchmarks v0.1.0
  [6c6a2e73] Scratch v1.1.1
  [efcf1570] Setfield v0.8.2
  [992d4aef] Showoff v1.0.3
  [777ac1f9] SimpleBufferStream v1.1.0
  [699a6c99] SimpleTraits v0.9.4
  [b85f4697] SoftGlobalScope v1.1.0
  [a2af1166] SortingAlgorithms v1.0.1
  [47a9eef4] SparseDiffTools v1.24.0
  [276daf66] SpecialFunctions v2.1.7
  [171d559e] SplittablesBase v0.1.14
  [aedffcd0] Static v0.7.6
  [90137ffa] StaticArrays v1.5.2
  [1e83bf80] StaticArraysCore v1.0.1
  [82ae8749] StatsAPI v1.4.0
  [2913bbd2] StatsBase v0.33.20
  [4c63d2b9] StatsFuns v1.0.1
  [7792a7ef] StrideArraysCore v0.3.15
  [69024149] StringEncodings v0.3.5
  [09ab397b] StructArrays v0.6.11
  [d1185830] SymbolicUtils v0.19.11
  [0c5d862f] Symbolics v4.10.0
  [3783bdb8] TableTraits v1.0.1
  [bd369af6] Tables v1.7.0
  [92b13dbe] TaylorIntegration v0.8.11
  [6aa5eb33] TaylorSeries v0.12.1
  [62fd8b95] TensorCore v0.1.1
  [8ea1fca8] TermInterface v0.2.3
  [8290d209] ThreadingUtilities v0.5.0
  [ac1d9e8a] ThreadsX v0.1.10
  [a759f4b9] TimerOutputs v0.5.20
  [0796e94c] Tokenize v0.5.24
  [3bb67fe8] TranscodingStreams v0.9.6
  [28d57a85] Transducers v0.4.73
  [a2a6695c] TreeViews v0.3.0
  [d5829a12] TriangularSolve v0.1.12
  [5c2747f8] URIs v1.4.0
  [3a884ed6] UnPack v1.0.2
  [1cfade01] UnicodeFun v0.4.1
  [1986cc42] Unitful v1.11.0
  [41fe7b60] Unzip v0.1.2
  [3d5dd08c] VectorizationBase v0.21.43
  [81def892] VersionParsing v1.3.0
  [19fa3120] VertexSafeGraphs v0.2.0
  [44d3d7a6] Weave v0.10.9
  [ddb6d928] YAML v0.4.7
  [c2297ded] ZMQ v1.2.1
  [700de1a5] ZygoteRules v0.2.2
  [6e34b625] Bzip2_jll v1.0.8+0
  [83423d85] Cairo_jll v1.16.1+1
  [5ae413db] EarCut_jll v2.2.3+0
  [2e619515] Expat_jll v2.4.8+0
  [b22a6f82] FFMPEG_jll v4.4.2+0
  [a3f928ae] Fontconfig_jll v2.13.93+0
  [d7e528f0] FreeType2_jll v2.10.4+0
  [559328eb] FriBidi_jll v1.0.10+0
  [0656b61e] GLFW_jll v3.3.6+0
  [d2c73de3] GR_jll v0.66.0+0
  [78b55507] Gettext_jll v0.21.0+0
  [f8c6e375] Git_jll v2.34.1+0
  [7746bdde] Glib_jll v2.68.3+2
  [3b182d85] Graphite2_jll v1.3.14+0
  [2e76f6c2] HarfBuzz_jll v2.8.1+1
  [aacddb02] JpegTurbo_jll v2.1.2+0
  [c1c5ebd0] LAME_jll v3.100.1+0
  [88015f11] LERC_jll v3.0.0+1
  [dd4b983a] LZO_jll v2.10.1+0
  [e9f186c6] Libffi_jll v3.2.2+1
  [d4300ac3] Libgcrypt_jll v1.8.7+0
  [7e76a0d4] Libglvnd_jll v1.3.0+3
  [7add5ba3] Libgpg_error_jll v1.42.0+0
  [94ce4f54] Libiconv_jll v1.16.1+1
  [4b2f31a3] Libmount_jll v2.35.0+0
  [89763e89] Libtiff_jll v4.4.0+0
  [38a345b3] Libuuid_jll v2.36.0+0
  [e7412a2a] Ogg_jll v1.3.5+1
  [458c3c95] OpenSSL_jll v1.1.17+0
  [efe28fd5] OpenSpecFun_jll v0.5.5+0
  [91d4177d] Opus_jll v1.3.2+0
  [2f80f16e] PCRE_jll v8.44.0+0
  [30392449] Pixman_jll v0.40.1+0
  [ea2cea3b] Qt5Base_jll v5.15.3+1
  [f50d1b31] Rmath_jll v0.3.0+0
  [a2964d1f] Wayland_jll v1.19.0+0
  [2381bf8a] Wayland_protocols_jll v1.25.0+0
  [02c8fc9c] XML2_jll v2.9.14+0
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
  [3161d3a3] Zstd_jll v1.5.2+0
  [a4ae2306] libaom_jll v3.4.0+0
  [0ac62f75] libass_jll v0.15.1+0
  [f638f0a6] libfdk_aac_jll v2.0.2+0
  [b53b4c65] libpng_jll v1.6.38+0
  [a9144af2] libsodium_jll v1.0.20+0
  [f27f6e37] libvorbis_jll v1.3.7+1
  [1270edf5] x264_jll v2021.5.5+0
  [dfaa095f] x265_jll v3.5.0+0
  [d8fb68d0] xkbcommon_jll v0.9.1+5
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
  [a4e569a6] Tar v1.10.0
  [8dfed614] Test
  [cf7118a7] UUIDs
  [4ec0a83e] Unicode
  [e66e0078] CompilerSupportLibraries_jll v0.5.2+0
  [deac9b47] LibCURL_jll v7.81.0+0
  [29816b5a] LibSSH2_jll v1.10.2+0
  [c8ffd9c3] MbedTLS_jll v2.28.0+0
  [14a3606d] MozillaCACerts_jll v2022.2.1
  [4536629a] OpenBLAS_jll v0.3.20+0
  [05823500] OpenLibm_jll v0.8.1+0
  [efcefdf7] PCRE2_jll v10.40.0+0
  [bea87d4a] SuiteSparse_jll v5.10.1+0
  [83775a58] Zlib_jll v1.2.12+3
  [8e850b90] libblastrampoline_jll v5.1.0+0
  [8e850ede] nghttp2_jll v1.41.0+1
  [3f19e933] p7zip_jll v17.4.0+0
```
