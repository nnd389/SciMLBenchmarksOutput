---
author: "Sebastian Micluța-Câmpeanu, Chris Rackauckas"
title: "Quadruple Boson Energy Conservation"
---


In this notebook we will study the energy conservation properties of several high-order methods for a system with the following Hamiltonian:

$$\mathcal{H}\left(q_0,q_2,p_0,p_2\right) = \frac{A}{2} \left(p_0^2 + p_2^2 + q_0^2 + q_2^2\right) + \frac{B}{\sqrt{2}} q_0 \left(3q_2^2 - q_0^2\right) + \frac{D}{4} \left(q_0^2+q_2^2\right)^2$$

This Hamiltonian resembles the Hénon-Heiles one, but it has an additional fourth order term.
The aim of this benchmark is to see what happens with the energy error when highly accurate solutions are needed and how the results compare with the Hénon-Heiles case.

```julia
using OrdinaryDiffEq, Plots, DiffEqCallbacks, LinearAlgebra
using TaylorIntegration
using ParameterizedFunctions
using StaticArrays
gr()
default(fmt=:png)

T(p) = A / 2 * norm(p)^2
V(q) = A / 2 * (q[1]^2 + q[2]^2) + B / sqrt(2) * q[1] * (3 * q[2]^2 - q[1]^2) + D / 4 * (q[1]^2 + q[2]^2)^2
H(p, q, params) = T(p) + V(q)

const A, B, D = 1., 0.55, 0.4

function iip_dq(dq, p, q, params, t)
    dq[1] = A * p[1]
    dq[2] = A * p[2]
end

function iip_dp(dp, p, q, params, t)
    dp[1] = -A * q[1] - 3 * B / sqrt(2) * (q[2]^2 - q[1]^2) - D * q[1] * (q[1]^2 + q[2]^2)
    dp[2] = -q[2] * (A + 3 * sqrt(2) * B * q[1] + D * (q[1]^2 + q[2]^2))
end

const iip_q0 = [4.919080920016389, 2.836942666663649]
const iip_p0 = [0., 0.]
const iip_u0 = vcat(iip_p0,iip_q0)

function oop_dq(p, q, params, t)
    p
end

function oop_dp(p, q, params, t)
    dp1 = -A * q[1] - 3 * B / sqrt(2) * (q[2]^2 - q[1]^2) - D * q[1] * (q[1]^2 + q[2]^2)
    dp2 = -q[2] * (A + 3 * sqrt(2) * B * q[1] + D * (q[1]^2 + q[2]^2))
    @SVector [dp1, dp2]
end

const oop_q0 = @SVector [4.919080920016389, 2.836942666663649]
const oop_p0 = @SVector [0., 0.]
const oop_u0 = vcat(oop_p0,oop_q0)

function hamilton(z, params, t)
    SVector(
    -A * z[3] - 3 * B / sqrt(2) * (z[4]^2 - z[3]^2) - D * z[3] * (z[3]^2 + z[4]^2),
    -z[4] * (A + 3 * sqrt(2) * B * z[3] + D * (z[3]^2 + z[4]^2)),
    z[1],
    z[2]
    )
end

function g(resid, u, p)
    resid[1] = H([u[1],u[2]],[u[3],u[4]],nothing) - E
    resid[2:4] .= 0
end

const E = H(iip_p0, iip_q0, nothing)
const cb = ManifoldProjection(g, nlopts=Dict(:ftol=>1e-13));
```




For the comparison we will use the following function

```julia
energy_err(sol) = map(i->H([sol[1,i], sol[2,i]], [sol[3,i], sol[4,i]],nothing)-E, 1:length(sol.u))
abs_energy_err(sol) = [abs.(H([sol[1,j], sol[2,j]], [sol[3,j], sol[4,j]],nothing) - E) for j=1:length(sol.u)]

function compare(mode=:inplace, all=true, plt=nothing; tmax=1e2)
    if mode == :inplace
        prob = DynamicalODEProblem(iip_dp, iip_dq, iip_p0, iip_q0, (0., tmax))
    else
        prob = DynamicalODEProblem(oop_dp, oop_dq, oop_p0, oop_q0, (0., tmax))
    end
    prob_linear = ODEProblem(hamilton, vcat(iip_p0, iip_q0), (0., tmax))

    GC.gc()
    (mode == :inplace  && all) && @time sol1 = solve(prob, Vern9(), callback=cb, abstol=1e-14, reltol=1e-14)
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

    if plt == nothing
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
and the out of place one. The `all` parameter is used to compare only the integrators that support both the in place and the out of place versions (we reffer here only to the 6 high order methods chosen bellow).
The `plt` argument can be used to overlay the results over a previous plot and the `tmax` keyword determines the simulation time.

Note:
1. The `Vern9` method is used with `ODEProblem` because of performance issues with `ArrayPartition` indexing which manifest for `DynamicalODEProblem`.
2. The `NLsolve` call used by `ManifoldProjection` was modified to use `ftol=1e-13` in order to obtain a very low energy error.

Here are the results of the comparisons between the in place methods:

```julia
compare(tmax=1e2)
```

```
55.418628 seconds (147.98 M allocations: 8.593 GiB, 8.62% gc time, 99.90% 
compilation time)
  1.929203 seconds (2.86 M allocations: 187.161 MiB, 99.59% compilation tim
e)
  1.845445 seconds (2.45 M allocations: 158.350 MiB, 99.40% compilation tim
e)
 29.321404 seconds (91.76 M allocations: 5.512 GiB, 12.45% gc time, 99.94% 
compilation time)
  2.826935 seconds (2.58 M allocations: 166.261 MiB, 99.86% compilation tim
e)
  1.885734 seconds (3.23 M allocations: 367.836 MiB, 90.47% compilation tim
e)
Vern9 + ManifoldProjection max energy error:	1.8474111129762605e-13	in	9731
	steps.
KahanLi8 max energy error:			5.5706550483591855e-12	in	10001	steps.
SofSpa10 max energy error:			3.836930773104541e-12	in	10001	steps.
Vern9 max energy error:				1.6626700016786344e-12	in	4866	steps.
DPRKN12 max energy error:			6.252776074688882e-13	in	2195	steps.
TaylorMethod max energy error:			4.689582056016661e-13	in	509	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_3_1.png)

```julia
compare(tmax=1e3)
```

```
0.493738 seconds (5.39 M allocations: 364.561 MiB)
  0.078345 seconds (700.10 k allocations: 61.899 MiB)
  0.115006 seconds (700.10 k allocations: 61.901 MiB)
  0.174040 seconds (1.75 M allocations: 106.737 MiB)
  0.031977 seconds (437.69 k allocations: 18.586 MiB)
  2.518062 seconds (7.90 M allocations: 1.972 GiB, 35.10% gc time)
Vern9 + ManifoldProjection max energy error:	1.8474111129762605e-13	in	9723
7	steps.
KahanLi8 max energy error:			1.0530243343964685e-11	in	100002	steps.
SofSpa10 max energy error:			1.5077716852829326e-11	in	100002	steps.
Vern9 max energy error:				4.163780431554187e-12	in	48623	steps.
DPRKN12 max energy error:			3.197442310920451e-12	in	21875	steps.
TaylorMethod max energy error:			1.9326762412674725e-12	in	5082	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_4_1.png)

```julia
compare(tmax=1e4)
```

```
12.672131 seconds (53.92 M allocations: 3.529 GiB, 59.61% gc time)
  1.592568 seconds (7.00 M allocations: 579.841 MiB, 45.00% gc time)
  1.615281 seconds (7.00 M allocations: 579.843 MiB, 26.45% gc time)
  7.346917 seconds (17.50 M allocations: 1.027 GiB, 77.15% gc time)
  0.317602 seconds (4.37 M allocations: 181.619 MiB)
 18.395370 seconds (78.97 M allocations: 19.713 GiB, 33.47% gc time)
Vern9 + ManifoldProjection max energy error:	2.1316282072803006e-13	in	9723
79	steps.
KahanLi8 max energy error:			4.3968384488835e-11	in	1000001	steps.
SofSpa10 max energy error:			6.492939519375795e-11	in	1000001	steps.
Vern9 max energy error:				5.356071142159635e-11	in	486191	steps.
DPRKN12 max energy error:			1.496403001510771e-11	in	218676	steps.
TaylorMethod max energy error:			7.702283255639486e-12	in	50814	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_5_1.png)

```julia
compare(tmax=2e4)
```

```
26.845464 seconds (107.82 M allocations: 7.050 GiB, 62.17% gc time)
  5.360580 seconds (14.00 M allocations: 1.171 GiB, 67.68% gc time)
  7.004772 seconds (14.00 M allocations: 1.171 GiB, 65.78% gc time)
 14.562411 seconds (35.01 M allocations: 2.052 GiB, 76.92% gc time)
  0.645335 seconds (8.75 M allocations: 360.885 MiB)
 40.256283 seconds (157.93 M allocations: 39.426 GiB, 39.34% gc time)
Vern9 + ManifoldProjection max energy error:	2.1316282072803006e-13	in	1944
701	steps.
KahanLi8 max energy error:			1.0363976343796821e-10	in	2000002	steps.
SofSpa10 max energy error:			9.750067420100095e-11	in	2000002	steps.
Vern9 max energy error:				1.0747669421107275e-10	in	972377	steps.
DPRKN12 max energy error:			4.125411123823142e-11	in	437335	steps.
TaylorMethod max energy error:			1.3926637620897964e-11	in	101627	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_6_1.png)



As we can see from the above plots, we can achieve a very low energy error for long time simulation by manifold projection and with very high order Taylor methods. In comparison with the Hénon-Heiles system we see that as the Hamiltonian got more complex, the energy error for the other integration methods increased significantly.

We will now compare the in place with the out of place versions. In the plots bellow we will use a dashed line for the out of place versions.

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
  0.713831 seconds (5.39 M allocations: 364.561 MiB, 33.69% gc time)
  0.084598 seconds (700.10 k allocations: 61.899 MiB)
  0.122897 seconds (700.10 k allocations: 61.901 MiB)
  0.175108 seconds (1.75 M allocations: 106.737 MiB)
  0.033766 seconds (437.69 k allocations: 18.586 MiB)
  1.845573 seconds (7.90 M allocations: 1.972 GiB, 9.87% gc time)
Vern9 + ManifoldProjection max energy error:	1.8474111129762605e-13	in	9723
7	steps.
KahanLi8 max energy error:			1.0530243343964685e-11	in	100002	steps.
SofSpa10 max energy error:			1.5077716852829326e-11	in	100002	steps.
Vern9 max energy error:				4.163780431554187e-12	in	48623	steps.
DPRKN12 max energy error:			3.197442310920451e-12	in	21875	steps.
TaylorMethod max energy error:			1.9326762412674725e-12	in	5082	steps.

Out of place versions:
  1.163599 seconds (2.27 M allocations: 167.288 MiB, 97.31% compilation tim
e)
  0.646981 seconds (961.71 k allocations: 75.994 MiB, 93.21% compilation ti
me)
  1.328225 seconds (2.70 M allocations: 161.916 MiB, 97.86% compilation tim
e)
  0.788518 seconds (926.86 k allocations: 61.973 MiB, 98.79% compilation ti
me)
KahanLi8 max energy error:			1.0530243343964685e-11	in	100002	steps.
SofSpa10 max energy error:			1.5077716852829326e-11	in	100002	steps.
Vern9 max energy error:				9.450218385609332e-12	in	48622	steps.
DPRKN12 max energy error:			1.5774048733874224e-12	in	21876	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_8_1.png)



Now we will compare the in place and the out of place versions, but only for the integrators that are compatible with `StaticArrays`

```julia
in_vs_out(tmax=1e2)
```

```
In place versions:
  0.007573 seconds (70.09 k allocations: 5.806 MiB)
  0.010506 seconds (70.09 k allocations: 5.808 MiB)
  0.014321 seconds (175.35 k allocations: 10.932 MiB)
  0.003132 seconds (44.08 k allocations: 1.939 MiB)
KahanLi8 max energy error:			5.5706550483591855e-12	in	10001	steps.
SofSpa10 max energy error:			3.836930773104541e-12	in	10001	steps.
Vern9 max energy error:				1.6626700016786344e-12	in	4866	steps.
DPRKN12 max energy error:			6.252776074688882e-13	in	2195	steps.

Out of place versions:
  0.003066 seconds (10.02 k allocations: 1.681 MiB)
  0.004436 seconds (10.02 k allocations: 1.682 MiB)
  0.002462 seconds (4.90 k allocations: 2.760 MiB)
  0.001201 seconds (2.23 k allocations: 604.469 KiB)
KahanLi8 max energy error:			5.5706550483591855e-12	in	10001	steps.
SofSpa10 max energy error:			3.836930773104541e-12	in	10001	steps.
Vern9 max energy error:				5.542233338928781e-13	in	4864	steps.
DPRKN12 max energy error:			9.663381206337363e-13	in	2195	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_9_1.png)

```julia
in_vs_out(tmax=1e3)
```

```
In place versions:
  0.072028 seconds (700.10 k allocations: 61.899 MiB)
  0.103977 seconds (700.10 k allocations: 61.901 MiB)
  0.160354 seconds (1.75 M allocations: 106.737 MiB)
  0.032995 seconds (437.69 k allocations: 18.586 MiB)
KahanLi8 max energy error:			1.0530243343964685e-11	in	100002	steps.
SofSpa10 max energy error:			1.5077716852829326e-11	in	100002	steps.
Vern9 max energy error:				4.163780431554187e-12	in	48623	steps.
DPRKN12 max energy error:			3.197442310920451e-12	in	21875	steps.

Out of place versions:
  0.028097 seconds (100.03 k allocations: 21.886 MiB)
  0.042590 seconds (100.03 k allocations: 21.887 MiB)
  0.022024 seconds (48.66 k allocations: 23.949 MiB)
  0.009618 seconds (21.91 k allocations: 4.990 MiB)
KahanLi8 max energy error:			1.0530243343964685e-11	in	100002	steps.
SofSpa10 max energy error:			1.5077716852829326e-11	in	100002	steps.
Vern9 max energy error:				9.450218385609332e-12	in	48622	steps.
DPRKN12 max energy error:			1.5774048733874224e-12	in	21876	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_10_1.png)

```julia
in_vs_out(tmax=1e4)
```

```
In place versions:
  0.848692 seconds (7.00 M allocations: 579.841 MiB)
  1.201304 seconds (7.00 M allocations: 579.843 MiB)
  3.567749 seconds (17.50 M allocations: 1.027 GiB, 52.32% gc time)
  0.326637 seconds (4.37 M allocations: 181.619 MiB)
KahanLi8 max energy error:			4.3968384488835e-11	in	1000001	steps.
SofSpa10 max energy error:			6.492939519375795e-11	in	1000001	steps.
Vern9 max energy error:				5.356071142159635e-11	in	486191	steps.
DPRKN12 max energy error:			1.496403001510771e-11	in	218676	steps.

Out of place versions:
  0.817350 seconds (1.00 M allocations: 167.849 MiB, 63.28% gc time)
  0.465214 seconds (1.00 M allocations: 167.850 MiB)
  0.285631 seconds (486.25 k allocations: 215.756 MiB)
  0.101026 seconds (218.72 k allocations: 43.323 MiB)
KahanLi8 max energy error:			4.3968384488835e-11	in	1000001	steps.
SofSpa10 max energy error:			6.492939519375795e-11	in	1000001	steps.
Vern9 max energy error:				5.697131655324483e-11	in	486200	steps.
DPRKN12 max energy error:			1.7323031897831243e-11	in	218674	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_11_1.png)

```julia
in_vs_out(tmax=2e4)
```

```
In place versions:
  2.939754 seconds (14.00 M allocations: 1.171 GiB, 41.69% gc time)
  4.462601 seconds (14.00 M allocations: 1.171 GiB, 46.56% gc time)
  6.311508 seconds (35.01 M allocations: 2.052 GiB, 46.53% gc time)
  0.647759 seconds (8.75 M allocations: 360.885 MiB)
KahanLi8 max energy error:			1.0363976343796821e-10	in	2000002	steps.
SofSpa10 max energy error:			9.750067420100095e-11	in	2000002	steps.
Vern9 max energy error:				1.0747669421107275e-10	in	972377	steps.
DPRKN12 max energy error:			4.125411123823142e-11	in	437335	steps.

Out of place versions:
  1.719847 seconds (2.00 M allocations: 395.140 MiB, 62.44% gc time)
  0.954206 seconds (2.00 M allocations: 395.141 MiB)
  0.555963 seconds (972.44 k allocations: 428.588 MiB)
  0.203934 seconds (437.38 k allocations: 83.674 MiB)
KahanLi8 max energy error:			1.0363976343796821e-10	in	2000002	steps.
SofSpa10 max energy error:			9.750067420100095e-11	in	2000002	steps.
Vern9 max energy error:				1.2643397440115223e-10	in	972386	steps.
DPRKN12 max energy error:			2.3604229681950528e-11	in	437330	steps.
```


![](figures/Quadrupole_boson_Hamiltonian_energy_conservation_benchmark_12_1.png)



As we see from the above comparisons, the `StaticArray` versions are significantly faster and use less memory. The speedup provided for the out of place version is more proeminent at larger values for `tmax`.
We can see again that if the simulation time is increased, the energy error of the symplectic methods is less noticeable compared to the rest of the methods.
In comparison with the Henon-Heiles case, we see that the symplectic methods are more competitive with `DPRKN12`.


## Appendix

These benchmarks are a part of the SciMLBenchmarks.jl repository, found at: [https://github.com/SciML/SciMLBenchmarks.jl](https://github.com/SciML/SciMLBenchmarks.jl). For more information on high-performance scientific machine learning, check out the SciML Open Source Software Organization [https://sciml.ai](https://sciml.ai).

To locally run this benchmark, do the following commands:

```
using SciMLBenchmarks
SciMLBenchmarks.weave_file("benchmarks/DynamicalODE","Quadrupole_boson_Hamiltonian_energy_conservation_benchmark.jmd")
```

Computer Information:

```
Julia Version 1.10.5
Commit 6f3fdf7b362 (2024-08-27 14:19 UTC)
Build Info:
  Official https://julialang.org/ release
Platform Info:
  OS: Linux (x86_64-linux-gnu)
  CPU: 128 × AMD EPYC 7502 32-Core Processor
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-15.0.7 (ORCJIT, znver2)
Threads: 1 default, 0 interactive, 1 GC (on 128 virtual cores)
Environment:
  JULIA_CPU_THREADS = 128
  JULIA_DEPOT_PATH = /cache/julia-buildkite-plugin/depots/5b300254-1738-4989-ae0a-f4d2d937f953

```

Package Information:

```
Status `/cache/build/exclusive-amdci1-0/julialang/scimlbenchmarks-dot-jl/benchmarks/DynamicalODE/Project.toml`
⌅ [459566f4] DiffEqCallbacks v2.36.1
⌃ [055956cb] DiffEqPhysics v3.12.0
  [b305315f] Elliptic v1.0.1
⌃ [1dea7af3] OrdinaryDiffEq v6.66.0
⌃ [65888b18] ParameterizedFunctions v5.16.0
⌃ [91a5bcdd] Plots v1.40.4
⌃ [d330b81b] PyPlot v2.11.2
  [31c91b34] SciMLBenchmarks v0.1.3
⌃ [90137ffa] StaticArrays v1.9.5
⌃ [92b13dbe] TaylorIntegration v0.15.2
  [37e2e46d] LinearAlgebra
  [de0858da] Printf
  [10745b16] Statistics v1.10.0
Info Packages marked with ⌃ and ⌅ have new versions available. Those with ⌃ may be upgradable, but those with ⌅ are restricted by compatibility constraints from upgrading. To see why use `status --outdated`
Warning The project dependencies or compat requirements have changed since the manifest was last resolved. It is recommended to `Pkg.resolve()` or consider `Pkg.update()` if necessary.
```

And the full manifest:

```
Status `/cache/build/exclusive-amdci1-0/julialang/scimlbenchmarks-dot-jl/benchmarks/DynamicalODE/Manifest.toml`
⌅ [47edcb42] ADTypes v0.2.7
⌅ [c3fe647b] AbstractAlgebra v0.34.7
  [1520ce14] AbstractTrees v0.4.5
⌃ [7d9f7c33] Accessors v0.1.36
⌅ [79e6a3ab] Adapt v3.7.2
  [66dad0bd] AliasTables v1.1.3
  [ec485272] ArnoldiMethod v0.4.0
⌃ [4fba245c] ArrayInterface v7.7.1
⌃ [4c555306] ArrayLayouts v1.9.4
⌃ [e2ed5e7c] Bijections v0.1.6
⌃ [d1d4a3ce] BitFlags v0.1.8
⌃ [62783981] BitTwiddlingConvenienceFunctions v0.1.5
⌃ [2a0fbf3d] CPUSummary v0.2.5
  [00ebfdb7] CSTParser v3.4.3
⌃ [49dc2e85] Calculus v0.5.1
⌃ [d360d2e6] ChainRulesCore v1.24.0
⌃ [fb6a15b2] CloseOpenIntervals v0.1.12
⌃ [944b1d66] CodecZlib v0.7.4
⌃ [35d6a980] ColorSchemes v3.25.0
⌅ [3da002f7] ColorTypes v0.11.5
  [c3611d14] ColorVectorSpace v0.10.0
  [5ae59095] Colors v0.12.11
  [861a8166] Combinatorics v1.0.2
⌃ [a80b9123] CommonMark v0.8.12
  [38540f10] CommonSolve v0.2.4
⌃ [bbf7d656] CommonSubexpressions v0.3.0
⌃ [34da2185] Compat v4.15.0
  [b152e2b5] CompositeTypes v0.1.4
  [a33af91c] CompositionsBase v0.1.2
  [2569d6c7] ConcreteStructs v0.2.3
⌃ [f0e56b4a] ConcurrentUtilities v2.4.1
⌃ [8f4d0f93] Conda v1.10.0
⌅ [187b0558] ConstructionBase v1.5.5
  [d38c429a] Contour v0.6.3
  [adafc99b] CpuId v0.3.1
  [a8cc5b0e] Crayons v4.1.1
  [9a962f9c] DataAPI v1.16.0
  [864edb3b] DataStructures v0.18.20
  [e2d170a0] DataValueInterfaces v1.0.0
  [8bb1440f] DelimitedFiles v1.9.1
⌃ [2b5f629d] DiffEqBase v6.145.2
⌅ [459566f4] DiffEqCallbacks v2.36.1
⌃ [055956cb] DiffEqPhysics v3.12.0
  [163ba53b] DiffResults v1.1.0
  [b552c78f] DiffRules v1.15.1
  [b4f34e82] Distances v0.10.11
⌃ [31c24e10] Distributions v0.25.109
  [ffbed154] DocStringExtensions v0.9.3
⌅ [5b8099bc] DomainSets v0.6.7
  [fa6b7ba4] DualNumbers v0.6.8
⌅ [7c1d4256] DynamicPolynomials v0.5.7
  [b305315f] Elliptic v1.0.1
  [4e289a0a] EnumX v1.0.4
⌅ [f151be2c] EnzymeCore v0.6.6
⌃ [6912e4f1] Espresso v0.6.1
  [460bff9d] ExceptionUnwrapping v0.1.10
  [d4d017d3] ExponentialUtilities v1.26.1
  [e2ba6199] ExprTools v0.1.10
⌃ [c87230d0] FFMPEG v0.4.1
⌅ [7034ab61] FastBroadcast v0.2.8
  [9aa1b823] FastClosures v0.3.2
  [29a986be] FastLapackInterface v2.0.4
⌃ [1a297f60] FillArrays v1.11.0
⌃ [6a86dc24] FiniteDiff v2.23.1
  [53c48c17] FixedPointNumbers v0.8.5
  [1fa38f19] Format v1.3.7
  [f6369f11] ForwardDiff v0.10.36
  [069b7b12] FunctionWrappers v1.1.3
  [77dc65aa] FunctionWrappersWrappers v0.1.3
⌃ [d9f16b24] Functors v0.4.11
⌅ [46192b85] GPUArraysCore v0.1.5
⌃ [28b8d3ca] GR v0.73.5
  [c145ed77] GenericSchur v0.5.4
  [d7ba0133] Git v1.3.1
  [c27321d9] Glob v1.3.1
⌃ [86223c79] Graphs v1.11.1
  [42e2da0e] Grisu v1.0.2
⌅ [0b43b601] Groebner v0.5.1
⌅ [d5909c97] GroupsCore v0.4.2
  [cd3eb016] HTTP v1.10.8
  [eafb193a] Highlights v0.5.3
⌃ [3e5b6fbb] HostCPUFeatures v0.1.16
⌃ [34004b35] HypergeometricFunctions v0.3.23
⌃ [7073ff75] IJulia v1.24.2
  [615f187c] IfElse v0.1.1
  [d25df0c9] Inflate v0.1.5
  [18e54dd8] IntegerMathUtils v0.1.2
  [8197267c] IntervalSets v0.7.10
⌃ [3587e190] InverseFunctions v0.1.14
  [92d709cd] IrrationalConstants v0.2.2
  [82899510] IteratorInterfaceExtensions v1.0.0
⌃ [1019f520] JLFzf v0.1.7
⌃ [692b3bcd] JLLWrappers v1.5.0
  [682c06a0] JSON v0.21.4
⌃ [98e50ef6] JuliaFormatter v1.0.56
⌃ [ccbc3e58] JumpProcesses v9.10.1
⌅ [ef3ab10e] KLU v0.4.1
⌃ [ba0b0d4f] Krylov v0.9.6
⌃ [b964fa9f] LaTeXStrings v1.3.1
⌃ [2ee39098] LabelledArrays v1.15.1
⌅ [984bce1d] LambertW v0.4.6
⌃ [23fbe1c1] Latexify v0.16.3
  [73f95e8e] LatticeRules v0.0.1
⌃ [10f19ff3] LayoutPointers v0.1.15
⌅ [5078a376] LazyArrays v1.10.0
⌃ [d3d80556] LineSearches v7.2.0
⌃ [7ed4a6bd] LinearSolve v2.22.1
  [2ab3a3ac] LogExpFunctions v0.3.28
  [e6f89c97] LoggingExtras v1.0.3
⌃ [bdcacae8] LoopVectorization v0.12.170
  [d8e11817] MLStyle v0.4.17
  [1914dd2f] MacroTools v0.5.13
  [d125e4d3] ManualMemory v0.1.8
⌅ [a3b82374] MatrixFactorizations v2.2.0
⌃ [bb5d69b7] MaybeInplace v0.1.3
  [739be429] MbedTLS v1.1.9
  [442fdcdd] Measures v0.3.2
  [e1d29d7a] Missings v1.2.0
⌅ [961ee093] ModelingToolkit v8.73.2
  [46d2c3a1] MuladdMacro v0.2.4
⌃ [102ac46a] MultivariatePolynomials v0.5.6
⌃ [ffc61752] Mustache v1.0.19
⌃ [d8a4904e] MutableArithmetics v1.4.5
  [d41bc354] NLSolversBase v7.8.3
  [2774e3e8] NLsolve v4.5.1
  [77ba4419] NaNMath v1.0.2
⌃ [8913a72c] NonlinearSolve v3.1.0
⌃ [6fe1bfb0] OffsetArrays v1.14.0
  [4d8831e6] OpenSSL v1.4.3
  [bac558e1] OrderedCollections v1.6.3
⌃ [1dea7af3] OrdinaryDiffEq v6.66.0
  [90014a1f] PDMats v0.11.31
  [65ce6f38] PackageExtensionCompat v1.0.2
⌃ [65888b18] ParameterizedFunctions v5.16.0
  [d96e819e] Parameters v0.12.3
  [69de0a69] Parsers v2.8.1
  [b98c9c47] Pipe v1.3.0
  [ccf2f8ad] PlotThemes v3.2.0
⌃ [995b91a9] PlotUtils v1.4.1
⌃ [91a5bcdd] Plots v1.40.4
  [e409e4f3] PoissonRandom v0.4.4
⌃ [f517fe37] Polyester v0.7.14
⌃ [1d0040c9] PolyesterWeave v0.2.1
⌃ [d236fae5] PreallocationTools v0.4.22
  [aea7be01] PrecompileTools v1.2.1
  [21216c6a] Preferences v1.4.3
⌃ [08abe8d2] PrettyTables v2.3.2
  [27ebfcd6] Primes v0.5.6
⌃ [43287f4e] PtrArrays v1.2.0
  [438e738f] PyCall v1.96.4
⌃ [d330b81b] PyPlot v2.11.2
⌃ [1fd47b50] QuadGK v2.9.4
  [8a4e6c94] QuasiMonteCarlo v0.3.3
  [fb686558] RandomExtensions v0.4.4
⌃ [e6cf234a] RandomNumbers v1.5.3
  [3cdcf5f2] RecipesBase v1.3.4
  [01d81517] RecipesPipeline v0.6.12
⌅ [731186ca] RecursiveArrayTools v2.38.10
  [f2c3362d] RecursiveFactorization v0.2.23
  [189a3867] Reexport v1.2.2
  [05181044] RelocatableFolders v1.0.1
  [ae029012] Requires v1.3.0
⌅ [79098fc4] Rmath v0.7.1
  [7e49a35a] RuntimeGeneratedFunctions v0.5.13
⌃ [fdea26ae] SIMD v3.5.0
  [94e857df] SIMDTypes v0.1.0
⌃ [476501e8] SLEEFPirates v0.6.42
⌃ [0bca4576] SciMLBase v2.10.0
  [31c91b34] SciMLBenchmarks v0.1.3
⌃ [c0aeaf25] SciMLOperators v0.3.8
  [6c6a2e73] Scratch v1.2.1
  [efcf1570] Setfield v1.1.1
  [992d4aef] Showoff v1.0.3
⌃ [777ac1f9] SimpleBufferStream v1.1.0
⌃ [727e6d20] SimpleNonlinearSolve v1.4.0
  [699a6c99] SimpleTraits v0.9.4
  [ce78b400] SimpleUnPack v1.1.0
  [ed01d8cd] Sobol v1.5.0
  [b85f4697] SoftGlobalScope v1.1.0
  [a2af1166] SortingAlgorithms v1.2.1
⌃ [47a9eef4] SparseDiffTools v2.18.0
  [e56a9233] Sparspak v0.3.9
  [276daf66] SpecialFunctions v2.4.0
⌅ [aedffcd0] Static v0.8.10
⌃ [0d7ed370] StaticArrayInterface v1.5.0
⌃ [90137ffa] StaticArrays v1.9.5
  [1e83bf80] StaticArraysCore v1.4.3
  [82ae8749] StatsAPI v1.7.0
  [2913bbd2] StatsBase v0.34.3
⌃ [4c63d2b9] StatsFuns v1.3.1
⌃ [7792a7ef] StrideArraysCore v0.5.6
  [69024149] StringEncodings v0.3.7
⌅ [892a3eda] StringManipulation v0.3.4
⌅ [2efcf032] SymbolicIndexingInterface v0.2.2
⌅ [d1185830] SymbolicUtils v1.4.0
⌅ [0c5d862f] Symbolics v5.11.0
  [3783bdb8] TableTraits v1.0.1
⌃ [bd369af6] Tables v1.11.1
⌃ [92b13dbe] TaylorIntegration v0.15.2
⌅ [6aa5eb33] TaylorSeries v0.17.7
  [62fd8b95] TensorCore v0.1.1
  [8290d209] ThreadingUtilities v0.5.2
⌃ [a759f4b9] TimerOutputs v0.5.24
  [0796e94c] Tokenize v0.5.29
⌅ [3bb67fe8] TranscodingStreams v0.10.9
⌃ [d5829a12] TriangularSolve v0.2.0
⌃ [410a4b4d] Tricks v0.1.8
  [781d530d] TruncatedStacktraces v1.4.0
  [5c2747f8] URIs v1.5.1
  [3a884ed6] UnPack v1.0.2
  [1cfade01] UnicodeFun v0.4.1
⌃ [1986cc42] Unitful v1.20.0
⌃ [45397f5d] UnitfulLatexify v1.6.3
  [a7c27f48] Unityper v0.1.6
  [41fe7b60] Unzip v0.2.0
⌃ [3d5dd08c] VectorizationBase v0.21.68
  [81def892] VersionParsing v1.3.0
  [19fa3120] VertexSafeGraphs v0.2.0
  [44d3d7a6] Weave v0.10.12
⌃ [ddb6d928] YAML v0.4.11
⌃ [c2297ded] ZMQ v1.2.6
⌃ [6e34b625] Bzip2_jll v1.0.8+1
⌃ [83423d85] Cairo_jll v1.18.0+2
  [2702e6a9] EpollShim_jll v0.0.20230411+0
  [2e619515] Expat_jll v2.6.2+0
⌅ [b22a6f82] FFMPEG_jll v4.4.4+1
  [a3f928ae] Fontconfig_jll v2.13.96+0
  [d7e528f0] FreeType2_jll v2.13.2+0
  [559328eb] FriBidi_jll v1.0.14+0
⌃ [0656b61e] GLFW_jll v3.3.9+0
⌅ [d2c73de3] GR_jll v0.73.5+0
  [78b55507] Gettext_jll v0.21.0+0
⌃ [f8c6e375] Git_jll v2.44.0+2
⌃ [7746bdde] Glib_jll v2.80.2+0
  [3b182d85] Graphite2_jll v1.3.14+0
⌅ [2e76f6c2] HarfBuzz_jll v2.8.1+1
⌃ [1d5cc7b8] IntelOpenMP_jll v2024.1.0+0
⌃ [aacddb02] JpegTurbo_jll v3.0.3+0
  [c1c5ebd0] LAME_jll v3.100.2+0
⌅ [88015f11] LERC_jll v3.0.0+1
⌃ [1d63c593] LLVMOpenMP_jll v15.0.7+0
⌃ [dd4b983a] LZO_jll v2.10.2+0
⌅ [e9f186c6] Libffi_jll v3.2.2+1
  [d4300ac3] Libgcrypt_jll v1.8.11+0
  [7e76a0d4] Libglvnd_jll v1.6.0+0
  [7add5ba3] Libgpg_error_jll v1.49.0+0
  [94ce4f54] Libiconv_jll v1.17.0+0
  [4b2f31a3] Libmount_jll v2.40.1+0
⌅ [89763e89] Libtiff_jll v4.5.1+1
  [38a345b3] Libuuid_jll v2.40.1+0
⌃ [856f044c] MKL_jll v2024.1.0+0
  [e7412a2a] Ogg_jll v1.3.5+1
⌃ [458c3c95] OpenSSL_jll v3.0.14+0
  [efe28fd5] OpenSpecFun_jll v0.5.5+0
⌃ [91d4177d] Opus_jll v1.3.2+0
  [30392449] Pixman_jll v0.43.4+0
⌅ [c0090381] Qt6Base_jll v6.5.3+1
⌅ [f50d1b31] Rmath_jll v0.4.2+0
  [a44049a8] Vulkan_Loader_jll v1.3.243+0
  [a2964d1f] Wayland_jll v1.21.0+1
  [2381bf8a] Wayland_protocols_jll v1.31.0+0
⌃ [02c8fc9c] XML2_jll v2.12.7+0
⌃ [aed1982a] XSLT_jll v1.1.34+0
  [ffd25f8a] XZ_jll v5.4.6+0
  [f67eecfb] Xorg_libICE_jll v1.1.1+0
  [c834827a] Xorg_libSM_jll v1.2.4+0
  [4f6342f7] Xorg_libX11_jll v1.8.6+0
  [0c0b7dd1] Xorg_libXau_jll v1.0.11+0
  [935fb764] Xorg_libXcursor_jll v1.2.0+4
  [a3789734] Xorg_libXdmcp_jll v1.1.4+0
  [1082639a] Xorg_libXext_jll v1.3.6+0
  [d091e8ba] Xorg_libXfixes_jll v5.0.3+4
  [a51aa0fd] Xorg_libXi_jll v1.7.10+4
  [d1454406] Xorg_libXinerama_jll v1.1.4+4
  [ec84b674] Xorg_libXrandr_jll v1.5.2+4
  [ea2f1a96] Xorg_libXrender_jll v0.9.11+0
  [14d82f49] Xorg_libpthread_stubs_jll v0.1.1+0
⌃ [c7cfdc94] Xorg_libxcb_jll v1.15.0+0
  [cc61e674] Xorg_libxkbfile_jll v1.1.2+0
  [e920d4aa] Xorg_xcb_util_cursor_jll v0.1.4+0
  [12413925] Xorg_xcb_util_image_jll v0.4.0+1
  [2def613f] Xorg_xcb_util_jll v0.4.0+1
  [975044d2] Xorg_xcb_util_keysyms_jll v0.4.0+1
  [0d47668e] Xorg_xcb_util_renderutil_jll v0.3.9+1
  [c22f9ab0] Xorg_xcb_util_wm_jll v0.4.1+1
  [35661453] Xorg_xkbcomp_jll v1.4.6+0
  [33bec58e] Xorg_xkeyboard_config_jll v2.39.0+0
  [c5fb5394] Xorg_xtrans_jll v1.5.0+0
⌃ [8f1865be] ZeroMQ_jll v4.3.5+0
⌃ [3161d3a3] Zstd_jll v1.5.6+0
  [35ca27e7] eudev_jll v3.2.9+0
⌅ [214eeab7] fzf_jll v0.43.0+0
  [1a1c6b14] gperf_jll v3.1.1+0
  [a4ae2306] libaom_jll v3.9.0+0
⌃ [0ac62f75] libass_jll v0.15.1+0
  [2db6ffa8] libevdev_jll v1.11.0+0
⌃ [f638f0a6] libfdk_aac_jll v2.0.2+0
  [36db933b] libinput_jll v1.18.0+0
⌃ [b53b4c65] libpng_jll v1.6.43+1
⌃ [a9144af2] libsodium_jll v1.0.20+0
⌃ [f27f6e37] libvorbis_jll v1.3.7+1
  [009596ad] mtdev_jll v1.1.6+0
  [1317d2d5] oneTBB_jll v2021.12.0+0
⌅ [1270edf5] x264_jll v2021.5.5+0
⌅ [dfaa095f] x265_jll v3.5.0+0
  [d8fb68d0] xkbcommon_jll v1.4.1+1
  [0dad84c5] ArgTools v1.1.1
  [56f22d72] Artifacts
  [2a0f44e3] Base64
  [ade2ca70] Dates
  [8ba89e20] Distributed
  [f43a241f] Downloads v1.6.0
  [7b1f6079] FileWatching
  [9fa8497b] Future
  [b77e0a4c] InteractiveUtils
  [4af54fe1] LazyArtifacts
  [b27032c2] LibCURL v0.6.4
  [76f85450] LibGit2
  [8f399da3] Libdl
  [37e2e46d] LinearAlgebra
  [56ddb016] Logging
  [d6f4376e] Markdown
  [a63ad114] Mmap
  [ca575930] NetworkOptions v1.2.0
  [44cfe95a] Pkg v1.10.0
  [de0858da] Printf
  [3fa0cd96] REPL
  [9a3f8284] Random
  [ea8e919c] SHA v0.7.0
  [9e88b42a] Serialization
  [1a1011a3] SharedArrays
  [6462fe0b] Sockets
  [2f01184e] SparseArrays v1.10.0
  [10745b16] Statistics v1.10.0
  [4607b0f0] SuiteSparse
  [fa267f1f] TOML v1.0.3
  [a4e569a6] Tar v1.10.0
  [8dfed614] Test
  [cf7118a7] UUIDs
  [4ec0a83e] Unicode
  [e66e0078] CompilerSupportLibraries_jll v1.1.1+0
  [deac9b47] LibCURL_jll v8.4.0+0
  [e37daf67] LibGit2_jll v1.6.4+0
  [29816b5a] LibSSH2_jll v1.11.0+1
  [c8ffd9c3] MbedTLS_jll v2.28.2+1
  [14a3606d] MozillaCACerts_jll v2023.1.10
  [4536629a] OpenBLAS_jll v0.3.23+4
  [05823500] OpenLibm_jll v0.8.1+2
  [efcefdf7] PCRE2_jll v10.42.0+1
  [bea87d4a] SuiteSparse_jll v7.2.1+1
  [83775a58] Zlib_jll v1.2.13+1
  [8e850b90] libblastrampoline_jll v5.8.0+1
  [8e850ede] nghttp2_jll v1.52.0+1
  [3f19e933] p7zip_jll v17.4.0+2
Info Packages marked with ⌃ and ⌅ have new versions available. Those with ⌃ may be upgradable, but those with ⌅ are restricted by compatibility constraints from upgrading. To see why use `status --outdated -m`
Warning The project dependencies or compat requirements have changed since the manifest was last resolved. It is recommended to `Pkg.resolve()` or consider `Pkg.update()` if necessary.
```

