---
author: "Aayush Sabharwal, Polic Marko"
title: "Transistor Amplifier, DAE format"
---
```julia
using DiffEqDevTools, Sundials, ODEInterfaceDiffEq,
      Plots, DASSL, DASKR
using ModelingToolkit, OrdinaryDiffEq
using ModelingToolkit: t_nounits as t, D_nounits as D
using LinearAlgebra

@parameters begin
      Ub=6.0
      UF=0.026
      α=0.99
      β=1e-6
      R₀=1e3
      R₁=9e3
      R₂=9e3
      R₃=9e3
      R₄=9e3
      R₅=9e3
      R₆=9e3
      R₇=9e3
      R₈=9e3
      R₉=9e3
      C₁=1e-6
      C₂=2e-6
      C₃=3e-6
      C₄=4e-6
      C₅=5e-6
end

@variables begin
      y₁(t)  = 0.0
      y₂(t)  = 3.0 # Ub/(R₂/R₁ + 1)
      y₃(t)  = 3.0
      y₄(t)  = 6.0
      y₅(t)  = 3.0 # Ub/(R₆/R₅ + 1)
      y₆(t)  = 3.0
      y₇(t)  = 6.0
      y₈(t)  = 0.0
      tmp1(t) = 0.0
      tmp2(t) = 0.0
      tmp3(t) = 0.0
      tmp4(t) = 0.0
      tmp5(t) = 0.0
      tmp6(t) = 0.0
end

Uₑ = 0.1sin(200π * t)
g(x) = β * (exp(x / UF) - 1)

eqs = [
     tmp1 ~ (-Uₑ / R₀ + y₁ / R₀) / C₁
     tmp2 ~ (-Ub / R₂ + y₂ * (1 / R₁ + 1 / R₂) - (α - 1) * g(y₂ - y₃))/C₁
     D(y₂) - D(y₁) ~ tmp1
     D(y₁) - D(y₂) ~ tmp2
     -C₂ * D(y₃)                ~ -g(y₂ - y₃) + y₃/R₃
     tmp5 ~ (-Ub / R₄ + y₄ / R₄ + α * g(y₂ - y₃))/C₃
     tmp6 ~ (-Ub / R₆ + y₅ * (1 / R₅ + 1 / R₆) - (α - 1) * g(y₅ - y₆))/C₃
     D(y₅) - D(y₄)   ~ tmp5
     -D(y₅) + D(y₄)   ~ tmp6
     -C₄ * D(y₆)                ~ -g(y₅ - y₆) + y₆ / R₇
     tmp3 ~ (-Ub / R₈ + y₇ / R₈ + α * g(y₅ - y₆) )/C₅
     tmp4 ~ (y₈ / R₉) / C₅
     -D(y₇) + D(y₈)   ~ tmp3
     D(y₇) - D(y₈)   ~ tmp4
]

u0 = [y₁  => 0.0
      y₂  => 3.0
      y₃  => 3.0
      y₄  => 6.0
      y₅  => 3.0
      y₆  => 3.0
      y₇  => 6.0
      y₈  => 0.0
]

@mtkbuild sys = ODESystem(eqs, t)
tspan = (0.0, 0.2)
mtkprob   = ODEProblem(sys, u0, tspan)
ref_sol = solve(mtkprob, Rodas5P(), abstol = 1e-10, reltol = 1e-14)

du = mtkprob.f(mtkprob.u0, mtkprob.p, 0.0)
du0 = D.(unknowns(sys)) .=> du
daeprob = DAEProblem(sys, du0, [], tspan)
dae_ref_sol = solve(daeprob, IDA(), abstol = 1/10^8, reltol = 1/10^8)

function transamp(du, u, p, t)
    y₁, y₂, y₃, y₄, y₅, y₆, y₇, y₈ = u
    Uₑ = 0.1sin(200π * t)
    Ub=6.0
    UF=0.026
    α=0.99
    β=1e-6
    R₀=1e3
    R₁=9e3
    R₂=9e3
    R₃=9e3
    R₄=9e3
    R₅=9e3
    R₆=9e3
    R₇=9e3
    R₈=9e3
    R₉=9e3
    C₁=1e-6
    C₂=2e-6
    C₃=3e-6
    C₄=4e-6
    C₅=5e-6
    g(x) = β * (exp(x / UF) - 1)

    du[1] = -Uₑ / R₀ + y₁ / R₀
    du[2] = -Ub / R₂ + y₂ * (1 / R₁ + 1 / R₂) - (α - 1) * g(y₂ - y₃)
    du[3] = -g(y₂ - y₃) + y₃/R₃
    du[4] = -Ub / R₄ + y₄ / R₄ + α * g(y₂ - y₃)
    du[5] = -Ub / R₆ + y₅ * (1 / R₅ + 1 / R₆) - (α - 1) * g(y₅ - y₆)
    du[6] = -g(y₅ - y₆) + y₆ / R₇
    du[7] = -Ub / R₈ + y₇ / R₈ + α * g(y₅ - y₆)
    du[8] = y₈ / R₉
    nothing
end

dirMassMatrix =
    Float64.(ModelingToolkit.unwrap.(substitute.(
                [-C₁  C₁  0   0   0   0   0   0
                  C₁ -C₁  0   0   0   0   0   0
                  0   0  -C₂  0   0   0   0   0
                  0   0   0  -C₃  C₃  0   0   0
                  0   0   0   C₃ -C₃  0   0   0
                  0   0   0   0   0 -C₄   0   0
                  0   0   0   0   0   0  -C₅  C₅
                  0   0   0   0   0   0   C₅ -C₅],
                 (parameters(sys) .=> ModelingToolkit.getdefault.(parameters(sys)),))))
mmf = ODEFunction(transamp, mass_matrix = dirMassMatrix)
mmprob = ODEProblem(mmf, [0.0,3.0,3.0,6.0,3.0,3.0,6.0,0.0], tspan)
mm_refsol = solve(mmprob, Rodas5(), reltol = 1e-12, abstol = 1e-12)

probs = [mtkprob,daeprob,mmprob]
refs = [ref_sol,ref_sol,mm_refsol];
```

```
Error: UndefVarError: `tmp3ˍt(t)` not defined
```



```julia
plot(ref_sol, idxs = [y₁,y₂,y₃,y₄,y₅,y₆,y₇,y₈])
```

```
Error: UndefVarError: `ref_sol` not defined
```



```julia
plot(mm_refsol)
```

```
Error: UndefVarError: `mm_refsol` not defined
```





## Omissions

`DASSL.dassl())` is omitted because it throws a singularity error.
`rodas()` is too slow at low tolerances.

## High Tolerances

```julia
abstols = 1.0 ./ 10.0 .^ (5:8)
reltols = 1.0 ./ 10.0 .^ (1:4);
setups = [Dict(:prob_choice => 1, :alg=>Rodas4()),
          Dict(:prob_choice => 1, :alg=>FBDF()),
          Dict(:prob_choice => 1, :alg=>QNDF()),
          Dict(:prob_choice => 1, :alg=>rodas()),
          Dict(:prob_choice => 1, :alg=>radau()),
          Dict(:prob_choice => 1, :alg=>RadauIIA5()),
          Dict(:prob_choice => 2, :alg=>DFBDF()),
          Dict(:prob_choice => 2, :alg=>IDA()),
]

wp = WorkPrecisionSet(probs,abstols,reltols,setups;
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)
```

```
Error: UndefVarError: `refs` not defined
```



```julia
abstols = 1.0 ./ 10.0 .^ (6:8)
reltols = 1.0 ./ 10.0 .^ (2:4);
setups = [Dict(:prob_choice => 1, :alg=>Rosenbrock23()),
          Dict(:prob_choice => 1, :alg=>Rodas4()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 3, :alg=>Rodas5P()),
          Dict(:prob_choice => 3, :alg=>Rodas4()),
          Dict(:prob_choice => 3, :alg=>FBDF()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 2, :alg=>DASKR.daskr()),
          ]
wp = WorkPrecisionSet(probs,abstols,reltols,setups;
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)
```

```
Error: UndefVarError: `refs` not defined
```





### Timeseries Errors

```julia
abstols = 1.0 ./ 10.0 .^ (5:8)
reltols = 1.0 ./ 10.0 .^ (1:4);
setups = [Dict(:prob_choice => 1, :alg=>Rosenbrock23()),
          Dict(:prob_choice => 1, :alg=>Rodas4()),
          Dict(:prob_choice => 1, :alg=>FBDF()),
          Dict(:prob_choice => 1, :alg=>QNDF()),
          Dict(:prob_choice => 1, :alg=>rodas()),
          Dict(:prob_choice => 1, :alg=>radau()),
          Dict(:prob_choice => 1, :alg=>RadauIIA5()),
          Dict(:prob_choice => 2, :alg=>DFBDF()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          ]
wp = WorkPrecisionSet(probs,abstols,reltols,setups;error_estimate = :l2,
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)
```

```
Error: UndefVarError: `refs` not defined
```



```julia
abstols = 1.0 ./ 10.0 .^ (6:8)
reltols = 1.0 ./ 10.0 .^ (2:4);
setups = [Dict(:prob_choice => 1, :alg=>Rosenbrock23()),
          Dict(:prob_choice => 1, :alg=>Rodas4()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 3, :alg=>Rodas5P()),
          Dict(:prob_choice => 3, :alg=>Rodas4()),
          Dict(:prob_choice => 3, :alg=>FBDF()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 2, :alg=>DASKR.daskr()),
          ]
wp = WorkPrecisionSet(probs,abstols,reltols,setups;error_estimate = :l2,
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)
```

```
Error: UndefVarError: `refs` not defined
```





### Low Tolerances

This is the speed at lower tolerances, measuring what's good when accuracy is needed.

```julia
abstols = 1.0 ./ 10.0 .^ (7:12)
reltols = 1.0 ./ 10.0 .^ (4:9)

setups = [Dict(:prob_choice => 1, :alg=>Rodas5P()),
          Dict(:prob_choice => 3, :alg=>Rodas5P()),
          Dict(:prob_choice => 1, :alg=>Rodas4()),
          Dict(:prob_choice => 3, :alg=>Rodas4()),
          Dict(:prob_choice => 1, :alg=>FBDF()),
          Dict(:prob_choice => 1, :alg=>QNDF()),
          Dict(:prob_choice => 1, :alg=>radau()),
          Dict(:prob_choice => 1, :alg=>RadauIIA5()),
          Dict(:prob_choice => 2, :alg=>DFBDF()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 2, :alg=>DASKR.daskr()),
          ]

wp = WorkPrecisionSet(probs,abstols,reltols,setups;
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)
```

```
Error: UndefVarError: `refs` not defined
```



```julia
wp = WorkPrecisionSet(probs,abstols,reltols,setups;error_estimate = :l2,
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)
```

```
Error: UndefVarError: `refs` not defined
```





### Conclusion


## Appendix

These benchmarks are a part of the SciMLBenchmarks.jl repository, found at: [https://github.com/SciML/SciMLBenchmarks.jl](https://github.com/SciML/SciMLBenchmarks.jl). For more information on high-performance scientific machine learning, check out the SciML Open Source Software Organization [https://sciml.ai](https://sciml.ai).

To locally run this benchmark, do the following commands:

```
using SciMLBenchmarks
SciMLBenchmarks.weave_file("benchmarks/DAE","TransistorAmplifier.jmd")
```

Computer Information:

```
Julia Version 1.10.4
Commit 48d4fd48430 (2024-06-04 10:41 UTC)
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
Status `/cache/build/exclusive-amdci1-0/julialang/scimlbenchmarks-dot-jl/benchmarks/DAE/Project.toml`
  [165a45c3] DASKR v2.9.1
  [e993076c] DASSL v2.6.1
  [f3b72e0c] DiffEqDevTools v2.44.4
  [961ee093] ModelingToolkit v9.24.0
  [09606e27] ODEInterfaceDiffEq v3.13.3
  [1dea7af3] OrdinaryDiffEq v6.85.0
  [91a5bcdd] Plots v1.40.5
  [31c91b34] SciMLBenchmarks v0.1.3
  [c3572dad] Sundials v4.24.0
```

And the full manifest:

```
Status `/cache/build/exclusive-amdci1-0/julialang/scimlbenchmarks-dot-jl/benchmarks/DAE/Manifest.toml`
  [47edcb42] ADTypes v1.6.0
  [1520ce14] AbstractTrees v0.4.5
  [7d9f7c33] Accessors v0.1.36
  [79e6a3ab] Adapt v4.0.4
  [66dad0bd] AliasTables v1.1.3
  [ec485272] ArnoldiMethod v0.4.0
  [4fba245c] ArrayInterface v7.12.0
  [4c555306] ArrayLayouts v1.10.2
  [e2ed5e7c] Bijections v0.1.7
  [d1d4a3ce] BitFlags v0.1.9
  [62783981] BitTwiddlingConvenienceFunctions v0.1.6
  [fa961155] CEnum v0.5.0
  [2a0fbf3d] CPUSummary v0.2.6
  [00ebfdb7] CSTParser v3.4.3
  [49dc2e85] Calculus v0.5.1
  [d360d2e6] ChainRulesCore v1.24.0
  [fb6a15b2] CloseOpenIntervals v0.1.13
  [944b1d66] CodecZlib v0.7.5
  [35d6a980] ColorSchemes v3.25.0
  [3da002f7] ColorTypes v0.11.5
  [c3611d14] ColorVectorSpace v0.10.0
  [5ae59095] Colors v0.12.11
  [861a8166] Combinatorics v1.0.2
  [a80b9123] CommonMark v0.8.12
  [38540f10] CommonSolve v0.2.4
  [bbf7d656] CommonSubexpressions v0.3.0
  [f70d9fcc] CommonWorldInvalidations v1.0.0
  [34da2185] Compat v4.15.0
  [b152e2b5] CompositeTypes v0.1.4
  [a33af91c] CompositionsBase v0.1.2
  [2569d6c7] ConcreteStructs v0.2.3
  [f0e56b4a] ConcurrentUtilities v2.4.2
  [8f4d0f93] Conda v1.10.2
  [187b0558] ConstructionBase v1.5.5
  [d38c429a] Contour v0.6.3
  [adafc99b] CpuId v0.3.1
  [a8cc5b0e] Crayons v4.1.1
  [165a45c3] DASKR v2.9.1
  [e993076c] DASSL v2.6.1
  [9a962f9c] DataAPI v1.16.0
  [864edb3b] DataStructures v0.18.20
  [e2d170a0] DataValueInterfaces v1.0.0
  [8bb1440f] DelimitedFiles v1.9.1
  [2b5f629d] DiffEqBase v6.151.5
  [459566f4] DiffEqCallbacks v3.6.2
  [f3b72e0c] DiffEqDevTools v2.44.4
  [77a26b50] DiffEqNoiseProcess v5.22.0
  [163ba53b] DiffResults v1.1.0
  [b552c78f] DiffRules v1.15.1
  [a0c0ee7d] DifferentiationInterface v0.5.9
  [b4f34e82] Distances v0.10.11
  [31c24e10] Distributions v0.25.109
  [ffbed154] DocStringExtensions v0.9.3
  [5b8099bc] DomainSets v0.7.14
  [fa6b7ba4] DualNumbers v0.6.8
⌅ [7c1d4256] DynamicPolynomials v0.5.7
⌅ [06fc5a27] DynamicQuantities v0.13.2
  [4e289a0a] EnumX v1.0.4
  [f151be2c] EnzymeCore v0.7.7
  [460bff9d] ExceptionUnwrapping v0.1.10
  [d4d017d3] ExponentialUtilities v1.26.1
  [e2ba6199] ExprTools v0.1.10
  [c87230d0] FFMPEG v0.4.1
  [7034ab61] FastBroadcast v0.3.4
  [9aa1b823] FastClosures v0.3.2
  [29a986be] FastLapackInterface v2.0.4
  [1a297f60] FillArrays v1.11.0
  [64ca27bc] FindFirstFunctions v1.2.0
  [6a86dc24] FiniteDiff v2.23.1
  [53c48c17] FixedPointNumbers v0.8.5
  [1fa38f19] Format v1.3.7
  [f6369f11] ForwardDiff v0.10.36
  [069b7b12] FunctionWrappers v1.1.3
  [77dc65aa] FunctionWrappersWrappers v0.1.3
  [d9f16b24] Functors v0.4.11
  [46192b85] GPUArraysCore v0.1.6
  [28b8d3ca] GR v0.73.6
  [c145ed77] GenericSchur v0.5.4
  [d7ba0133] Git v1.3.1
  [c27321d9] Glob v1.3.1
  [86223c79] Graphs v1.11.2
  [42e2da0e] Grisu v1.0.2
  [cd3eb016] HTTP v1.10.8
  [eafb193a] Highlights v0.5.3
  [3e5b6fbb] HostCPUFeatures v0.1.17
  [34004b35] HypergeometricFunctions v0.3.23
  [7073ff75] IJulia v1.25.0
  [615f187c] IfElse v0.1.1
  [d25df0c9] Inflate v0.1.5
  [8197267c] IntervalSets v0.7.10
  [3587e190] InverseFunctions v0.1.15
  [92d709cd] IrrationalConstants v0.2.2
  [82899510] IteratorInterfaceExtensions v1.0.0
  [1019f520] JLFzf v0.1.7
  [692b3bcd] JLLWrappers v1.5.0
  [682c06a0] JSON v0.21.4
  [98e50ef6] JuliaFormatter v1.0.57
  [ccbc3e58] JumpProcesses v9.11.1
  [ef3ab10e] KLU v0.6.0
  [ba0b0d4f] Krylov v0.9.6
  [b964fa9f] LaTeXStrings v1.3.1
  [2ee39098] LabelledArrays v1.16.0
  [984bce1d] LambertW v0.4.6
  [23fbe1c1] Latexify v0.16.4
  [10f19ff3] LayoutPointers v0.1.17
  [5078a376] LazyArrays v2.1.9
  [d3d80556] LineSearches v7.2.0
  [7ed4a6bd] LinearSolve v2.30.2
  [2ab3a3ac] LogExpFunctions v0.3.28
  [e6f89c97] LoggingExtras v1.0.3
  [bdcacae8] LoopVectorization v0.12.171
  [d8e11817] MLStyle v0.4.17
  [1914dd2f] MacroTools v0.5.13
  [d125e4d3] ManualMemory v0.1.8
  [bb5d69b7] MaybeInplace v0.1.3
  [739be429] MbedTLS v1.1.9
  [442fdcdd] Measures v0.3.2
  [e1d29d7a] Missings v1.2.0
  [961ee093] ModelingToolkit v9.24.0
  [46d2c3a1] MuladdMacro v0.2.4
  [102ac46a] MultivariatePolynomials v0.5.6
  [ffc61752] Mustache v1.0.19
  [d8a4904e] MutableArithmetics v1.4.5
  [d41bc354] NLSolversBase v7.8.3
  [2774e3e8] NLsolve v4.5.1
  [77ba4419] NaNMath v1.0.2
  [8913a72c] NonlinearSolve v3.13.1
  [54ca160b] ODEInterface v0.5.0
  [09606e27] ODEInterfaceDiffEq v3.13.3
  [6fe1bfb0] OffsetArrays v1.14.1
  [4d8831e6] OpenSSL v1.4.3
  [429524aa] Optim v1.9.4
  [bac558e1] OrderedCollections v1.6.3
  [1dea7af3] OrdinaryDiffEq v6.85.0
  [90014a1f] PDMats v0.11.31
  [65ce6f38] PackageExtensionCompat v1.0.2
  [d96e819e] Parameters v0.12.3
  [69de0a69] Parsers v2.8.1
  [b98c9c47] Pipe v1.3.0
  [ccf2f8ad] PlotThemes v3.2.0
  [995b91a9] PlotUtils v1.4.1
  [91a5bcdd] Plots v1.40.5
  [e409e4f3] PoissonRandom v0.4.4
  [f517fe37] Polyester v0.7.15
  [1d0040c9] PolyesterWeave v0.2.2
  [85a6dd25] PositiveFactorizations v0.2.4
  [d236fae5] PreallocationTools v0.4.22
  [aea7be01] PrecompileTools v1.2.1
  [21216c6a] Preferences v1.4.3
  [43287f4e] PtrArrays v1.2.0
  [1fd47b50] QuadGK v2.9.4
  [74087812] Random123 v1.7.0
  [e6cf234a] RandomNumbers v1.5.3
  [3cdcf5f2] RecipesBase v1.3.4
  [01d81517] RecipesPipeline v0.6.12
  [731186ca] RecursiveArrayTools v3.26.0
  [f2c3362d] RecursiveFactorization v0.2.23
  [189a3867] Reexport v1.2.2
  [05181044] RelocatableFolders v1.0.1
  [ae029012] Requires v1.3.0
  [ae5879a3] ResettableStacks v1.1.1
  [79098fc4] Rmath v0.7.1
  [47965b36] RootedTrees v2.23.0
  [7e49a35a] RuntimeGeneratedFunctions v0.5.13
  [94e857df] SIMDTypes v0.1.0
  [476501e8] SLEEFPirates v0.6.43
  [0bca4576] SciMLBase v2.42.0
  [31c91b34] SciMLBenchmarks v0.1.3
  [c0aeaf25] SciMLOperators v0.3.8
  [53ae85a6] SciMLStructures v1.4.1
  [6c6a2e73] Scratch v1.2.1
  [efcf1570] Setfield v1.1.1
  [992d4aef] Showoff v1.0.3
  [777ac1f9] SimpleBufferStream v1.1.0
  [727e6d20] SimpleNonlinearSolve v1.10.1
  [699a6c99] SimpleTraits v0.9.4
  [ce78b400] SimpleUnPack v1.1.0
  [b85f4697] SoftGlobalScope v1.1.0
  [a2af1166] SortingAlgorithms v1.2.1
  [47a9eef4] SparseDiffTools v2.19.0
  [0a514795] SparseMatrixColorings v0.3.4
  [e56a9233] Sparspak v0.3.9
  [276daf66] SpecialFunctions v2.4.0
  [aedffcd0] Static v1.1.1
  [0d7ed370] StaticArrayInterface v1.5.1
  [90137ffa] StaticArrays v1.9.7
  [1e83bf80] StaticArraysCore v1.4.3
  [82ae8749] StatsAPI v1.7.0
  [2913bbd2] StatsBase v0.34.3
  [4c63d2b9] StatsFuns v1.3.1
  [7792a7ef] StrideArraysCore v0.5.7
  [69024149] StringEncodings v0.3.7
  [09ab397b] StructArrays v0.6.18
  [c3572dad] Sundials v4.24.0
  [2efcf032] SymbolicIndexingInterface v0.3.26
  [19f23fe9] SymbolicLimits v0.2.1
  [d1185830] SymbolicUtils v2.1.1
  [0c5d862f] Symbolics v5.33.0
  [3783bdb8] TableTraits v1.0.1
  [bd369af6] Tables v1.12.0
  [62fd8b95] TensorCore v0.1.1
⌅ [8ea1fca8] TermInterface v0.4.1
  [8290d209] ThreadingUtilities v0.5.2
  [a759f4b9] TimerOutputs v0.5.24
  [0796e94c] Tokenize v0.5.29
  [3bb67fe8] TranscodingStreams v0.11.0
  [d5829a12] TriangularSolve v0.2.1
  [410a4b4d] Tricks v0.1.8
  [781d530d] TruncatedStacktraces v1.4.0
  [5c2747f8] URIs v1.5.1
  [3a884ed6] UnPack v1.0.2
  [1cfade01] UnicodeFun v0.4.1
  [1986cc42] Unitful v1.20.0
  [45397f5d] UnitfulLatexify v1.6.4
  [a7c27f48] Unityper v0.1.6
  [41fe7b60] Unzip v0.2.0
  [3d5dd08c] VectorizationBase v0.21.70
  [81def892] VersionParsing v1.3.0
  [19fa3120] VertexSafeGraphs v0.2.0
  [44d3d7a6] Weave v0.10.12
  [ddb6d928] YAML v0.4.11
  [c2297ded] ZMQ v1.2.6
  [6e34b625] Bzip2_jll v1.0.8+1
  [83423d85] Cairo_jll v1.18.0+2
  [655fdf9c] DASKR_jll v1.0.0+0
  [2702e6a9] EpollShim_jll v0.0.20230411+0
  [2e619515] Expat_jll v2.6.2+0
⌅ [b22a6f82] FFMPEG_jll v4.4.4+1
  [a3f928ae] Fontconfig_jll v2.13.96+0
  [d7e528f0] FreeType2_jll v2.13.2+0
  [559328eb] FriBidi_jll v1.0.14+0
  [0656b61e] GLFW_jll v3.4.0+0
  [d2c73de3] GR_jll v0.73.6+0
  [78b55507] Gettext_jll v0.21.0+0
  [f8c6e375] Git_jll v2.44.0+2
  [7746bdde] Glib_jll v2.80.2+0
  [3b182d85] Graphite2_jll v1.3.14+0
  [2e76f6c2] HarfBuzz_jll v2.8.1+1
  [1d5cc7b8] IntelOpenMP_jll v2024.2.0+0
  [aacddb02] JpegTurbo_jll v3.0.3+0
  [c1c5ebd0] LAME_jll v3.100.2+0
⌅ [88015f11] LERC_jll v3.0.0+1
  [1d63c593] LLVMOpenMP_jll v15.0.7+0
  [dd4b983a] LZO_jll v2.10.2+0
⌅ [e9f186c6] Libffi_jll v3.2.2+1
  [d4300ac3] Libgcrypt_jll v1.8.11+0
  [7e76a0d4] Libglvnd_jll v1.6.0+0
  [7add5ba3] Libgpg_error_jll v1.49.0+0
  [94ce4f54] Libiconv_jll v1.17.0+0
  [4b2f31a3] Libmount_jll v2.40.1+0
⌅ [89763e89] Libtiff_jll v4.5.1+1
  [38a345b3] Libuuid_jll v2.40.1+0
  [856f044c] MKL_jll v2024.2.0+0
  [c771fb93] ODEInterface_jll v0.0.1+0
  [e7412a2a] Ogg_jll v1.3.5+1
  [458c3c95] OpenSSL_jll v3.0.14+0
  [efe28fd5] OpenSpecFun_jll v0.5.5+0
  [91d4177d] Opus_jll v1.3.2+0
  [30392449] Pixman_jll v0.43.4+0
  [c0090381] Qt6Base_jll v6.7.1+1
  [f50d1b31] Rmath_jll v0.4.2+0
⌅ [fb77eaff] Sundials_jll v5.2.2+0
  [a44049a8] Vulkan_Loader_jll v1.3.243+0
  [a2964d1f] Wayland_jll v1.21.0+1
  [2381bf8a] Wayland_protocols_jll v1.31.0+0
  [02c8fc9c] XML2_jll v2.13.1+0
  [aed1982a] XSLT_jll v1.1.41+0
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
  [c7cfdc94] Xorg_libxcb_jll v1.17.0+0
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
  [8f1865be] ZeroMQ_jll v4.3.5+0
  [3161d3a3] Zstd_jll v1.5.6+0
  [35ca27e7] eudev_jll v3.2.9+0
⌅ [214eeab7] fzf_jll v0.43.0+0
  [1a1c6b14] gperf_jll v3.1.1+0
  [a4ae2306] libaom_jll v3.9.0+0
  [0ac62f75] libass_jll v0.15.1+0
  [2db6ffa8] libevdev_jll v1.11.0+0
  [f638f0a6] libfdk_aac_jll v2.0.2+0
  [36db933b] libinput_jll v1.18.0+0
  [b53b4c65] libpng_jll v1.6.43+1
  [a9144af2] libsodium_jll v1.0.20+0
  [f27f6e37] libvorbis_jll v1.3.7+1
  [009596ad] mtdev_jll v1.1.6+0
  [1317d2d5] oneTBB_jll v2021.12.0+0
  [1270edf5] x264_jll v2021.5.5+0
  [dfaa095f] x265_jll v3.5.0+0
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
Info Packages marked with ⌅ have new versions available but compatibility constraints restrict them from upgrading. To see why use `status --outdated -m`
```
