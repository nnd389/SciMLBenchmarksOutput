
using OrdinaryDiffEq, DiffEqDevTools, Sundials, ModelingToolkit, ODEInterfaceDiffEq,
      Plots, DASSL, DASKR
using LinearAlgebra
using ModelingToolkit: t_nounits as t, D_nounits as D

@variables y₁(t)=1.0 y₂(t)=0.0 y₃(t)=0.0
@parameters k₁=0.04 k₂=3e7 k₃=1e4

eqs = [
  D(y₁) ~ -k₁*y₁ + k₃*y₂*y₃
  D(y₂) ~  k₁*y₁ - k₃*y₂*y₃ - k₂*y₂^2
  0 ~  y₁ + y₂ + y₃ - 1
]
@mtkbuild sys = ODESystem(eqs,t)
mtkprob = ODEProblem(sys,[],(0.0,1e5))
daeprob = DAEProblem(sys,[D(y₁)=>-0.04,
                              D(y₂)=>0.04],[],(0.0,1e5))
odaeprob = ODAEProblem(sys,[],(0.0,1e5))

ref_sol = solve(daeprob,IDA(),abstol=1/10^14,reltol=1/10^14);
ode_ref_sol = solve(odaeprob,CVODE_BDF(),abstol=1/10^14,reltol=1/10^14);

function rober(du, u, p, t)
    y₁, y₂, y₃ = u
    k₁, k₂, k₃ = p
    du[1] = -k₁ * y₁ + k₃ * y₂ * y₃
    du[2] = k₁ * y₁ - k₃ * y₂ * y₃ - k₂ * y₂^2
    du[3] = y₁ + y₂ + y₃ - 1
    nothing
end
M = [1.0 0 0
     0 1.0 0
     0 0 0]
mmf = ODEFunction(rober, mass_matrix = M)
mmprob = ODEProblem(mmf, [1.0, 0.0, 0.0], (0.0, 1e5), (0.04, 3e7, 1e4))
mm_refsol = solve(mmprob, Rodas5(), reltol = 1e-12, abstol = 1e-12)

probs = [mtkprob,daeprob,odaeprob, mmprob]
refs = [ref_sol,ref_sol,ode_ref_sol,mm_refsol];


plot(ode_ref_sol, idxs = [y₁,y₂,y₃])


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

wp = WorkPrecisionSet(probs,abstols,reltols,setups;
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)


abstols = 1.0 ./ 10.0 .^ (6:8)
reltols = 1.0 ./ 10.0 .^ (2:4);
setups = [Dict(:prob_choice => 1, :alg=>Rosenbrock23()),
          Dict(:prob_choice => 1, :alg=>Rodas4()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 3, :alg=>Rosenbrock23()),
          Dict(:prob_choice => 3, :alg=>Rodas4()),
          Dict(:prob_choice => 3, :alg=>CVODE_BDF()),
          Dict(:prob_choice => 3, :alg=>TRBDF2()),
          Dict(:prob_choice => 3, :alg=>KenCarp4()),
          Dict(:prob_choice => 4, :alg=>Rodas4()),
          Dict(:prob_choice => 4, :alg=>Rodas5P()),
          ]
wp = WorkPrecisionSet(probs,abstols,reltols,setups;
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)


abstols = 1.0 ./ 10.0 .^ (6:8)
reltols = 1.0 ./ 10.0 .^ (3:5);
setups = [Dict(:prob_choice => 3, :alg=>Rosenbrock23()),
          Dict(:prob_choice => 3, :alg=>Rodas4()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 2, :alg=>DASSL.dassl()),
          Dict(:prob_choice => 2, :alg=>DASKR.daskr()),
          ]
wp = WorkPrecisionSet(probs,abstols,reltols,setups;
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)


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


abstols = 1.0 ./ 10.0 .^ (6:8)
reltols = 1.0 ./ 10.0 .^ (2:4);
setups = [Dict(:prob_choice => 1, :alg=>Rosenbrock23()),
          Dict(:prob_choice => 1, :alg=>Rodas4()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 3, :alg=>Rosenbrock23()),
          Dict(:prob_choice => 3, :alg=>Rodas4()),
          Dict(:prob_choice => 3, :alg=>CVODE_BDF()),
          Dict(:prob_choice => 3, :alg=>TRBDF2()),
          Dict(:prob_choice => 3, :alg=>KenCarp4()),
          ]
wp = WorkPrecisionSet(probs,abstols,reltols,setups;error_estimate = :l2,
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)


abstols = 1.0 ./ 10.0 .^ (7:12)
reltols = 1.0 ./ 10.0 .^ (4:9)

setups = [Dict(:prob_choice => 1, :alg=>Rodas5()),
          Dict(:prob_choice => 3, :alg=>Rodas5()),
          Dict(:prob_choice => 4, :alg=>Rodas5()),
          Dict(:prob_choice => 1, :alg=>Rodas4()),
          Dict(:prob_choice => 3, :alg=>Rodas4()),
          Dict(:prob_choice => 4, :alg=>Rodas4()),
          Dict(:prob_choice => 1, :alg=>FBDF()),
          Dict(:prob_choice => 1, :alg=>QNDF()),
          Dict(:prob_choice => 1, :alg=>rodas()),
          Dict(:prob_choice => 1, :alg=>radau()),
          Dict(:prob_choice => 1, :alg=>RadauIIA5()),
          Dict(:prob_choice => 2, :alg=>DFBDF()),
          Dict(:prob_choice => 2, :alg=>IDA()),
          Dict(:prob_choice => 2, :alg=>DASKR.daskr()),
          ]

wp = WorkPrecisionSet(probs,abstols,reltols,setups;
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)


wp = WorkPrecisionSet(probs,abstols,reltols,setups;error_estimate = :l2,
                      save_everystep=false,appxsol=refs,maxiters=Int(1e5),numruns=10)
plot(wp)


using SciMLBenchmarks
SciMLBenchmarks.bench_footer(WEAVE_ARGS[:folder],WEAVE_ARGS[:file])

