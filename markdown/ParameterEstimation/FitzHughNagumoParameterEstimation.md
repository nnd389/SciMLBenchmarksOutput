---
author: "Vaibhav Dixit, Chris Rackauckas"
title: "FitzHugh-Nagumo Parameter Estimation Benchmarks"
---


# Parameter estimation of FitzHugh-Nagumo model using optimisation methods

```julia
using ParameterizedFunctions, OrdinaryDiffEq, DiffEqParamEstim
using BlackBoxOptim, NLopt, Plots,QuadDIRECT
gr(fmt=:png)
```

```
Plots.GRBackend()
```



```julia
loc_bounds = Tuple{Float64,Float64}[(0, 1), (0, 1), (0, 1), (0, 1)]
glo_bounds = Tuple{Float64,Float64}[(0, 5), (0, 5), (0, 5), (0, 5)]
loc_init = [0.5,0.5,0.5,0.5]
glo_init = [2.5,2.5,2.5,2.5]
```

```
4-element Vector{Float64}:
 2.5
 2.5
 2.5
 2.5
```



```julia
fitz = @ode_def FitzhughNagumo begin
  dv = v - v^3/3 -w + l
  dw = τinv*(v +  a - b*w)
end a b τinv l
```

```
(::Main.##WeaveSandBox#291.FitzhughNagumo{Main.##WeaveSandBox#291.var"###Pa
rameterizedDiffEqFunction#303", Main.##WeaveSandBox#291.var"###Parameterize
dTGradFunction#304", Main.##WeaveSandBox#291.var"###ParameterizedJacobianFu
nction#305", Nothing, Nothing, ModelingToolkit.ODESystem}) (generic functio
n with 1 method)
```



```julia
p = [0.7,0.8,0.08,0.5]              # Parameters used to construct the dataset
r0 = [1.0; 1.0]                     # initial value
tspan = (0.0, 30.0)                 # sample of 3000 observations over the (0,30) timespan
prob = ODEProblem(fitz, r0, tspan,p)
tspan2 = (0.0, 3.0)                 # sample of 300 observations with a timestep of 0.01
prob_short = ODEProblem(fitz, r0, tspan2,p)
```

```
ODEProblem with uType Vector{Float64} and tType Float64. In-place: true
timespan: (0.0, 3.0)
u0: 2-element Vector{Float64}:
 1.0
 1.0
```



```julia
dt = 30.0/3000
tf = 30.0
tinterval = 0:dt:tf
t  = collect(tinterval)
```

```
3001-element Vector{Float64}:
  0.0
  0.01
  0.02
  0.03
  0.04
  0.05
  0.06
  0.07
  0.08
  0.09
  ⋮
 29.92
 29.93
 29.94
 29.95
 29.96
 29.97
 29.98
 29.99
 30.0
```



```julia
h = 0.01
M = 300
tstart = 0.0
tstop = tstart + M * h
tinterval_short = 0:h:tstop
t_short = collect(tinterval_short)
```

```
301-element Vector{Float64}:
 0.0
 0.01
 0.02
 0.03
 0.04
 0.05
 0.06
 0.07
 0.08
 0.09
 ⋮
 2.92
 2.93
 2.94
 2.95
 2.96
 2.97
 2.98
 2.99
 3.0
```



```julia
#Generate Data
data_sol_short = solve(prob_short,Vern9(),saveat=t_short,reltol=1e-9,abstol=1e-9)
data_short = convert(Array, data_sol_short) # This operation produces column major dataset obs as columns, equations as rows
data_sol = solve(prob,Vern9(),saveat=t,reltol=1e-9,abstol=1e-9)
data = convert(Array, data_sol)
```

```
2×3001 Matrix{Float64}:
 1.0  1.00166  1.00332  1.00497  1.00661  …  -0.65759   -0.655923  -0.65424
8
 1.0  1.00072  1.00144  1.00216  1.00289     -0.229157  -0.228976  -0.22879
3
```





#### Plot of the solution

##### Short Solution

```julia
plot(data_sol_short)
```

![](figures/FitzHughNagumoParameterEstimation_8_1.png)



##### Longer Solution

```julia
plot(data_sol)
```

![](figures/FitzHughNagumoParameterEstimation_9_1.png)



## Local Solution from the short data set

```julia
obj_short = build_loss_objective(prob_short,Tsit5(),L2Loss(t_short,data_short),tstops=t_short)
res1 = bboptimize(obj_short;SearchRange = glo_bounds, MaxSteps = 7e3)
# Lower tolerance could lead to smaller fitness (more accuracy)
```

```
Starting optimization with optimizer BlackBoxOptim.DiffEvoOpt{BlackBoxOptim
.FitPopulation{Float64}, BlackBoxOptim.RadiusLimitedSelector, BlackBoxOptim
.AdaptiveDiffEvoRandBin{3}, BlackBoxOptim.RandomBound{BlackBoxOptim.Continu
ousRectSearchSpace}}
0.00 secs, 0 evals, 0 steps
0.51 secs, 2854 evals, 2756 steps, improv/step: 0.207 (last = 0.2068), fitn
ess=0.021288687
1.01 secs, 6274 evals, 6177 steps, improv/step: 0.164 (last = 0.1286), fitn
ess=0.001094927

Optimization stopped after 7001 steps and 1.15 seconds
Termination reason: Max number of steps (7000) reached
Steps per second = 6066.34
Function evals per second = 6150.39
Improvements/step = 0.16286
Total function evaluations = 7098


Best candidate found: [0.00232127, 0.696327, 0.212121, 0.4999]

Fitness: 0.000683866

BlackBoxOptim.OptimizationResults("adaptive_de_rand_1_bin_radiuslimited", "
Max number of steps (7000) reached", 7001, 1.660971764169945e9, 1.154073953
62854, BlackBoxOptim.ParamsDictChain[BlackBoxOptim.ParamsDictChain[Dict{Sym
bol, Any}(:RngSeed => 582716, :SearchRange => [(0.0, 5.0), (0.0, 5.0), (0.0
, 5.0), (0.0, 5.0)], :MaxSteps => 7000),Dict{Symbol, Any}()],Dict{Symbol, A
ny}(:CallbackInterval => -1.0, :TargetFitness => nothing, :TraceMode => :co
mpact, :FitnessScheme => BlackBoxOptim.ScalarFitnessScheme{true}(), :MinDel
taFitnessTolerance => 1.0e-50, :NumDimensions => :NotSpecified, :FitnessTol
erance => 1.0e-8, :TraceInterval => 0.5, :MaxStepsWithoutProgress => 10000,
 :MaxSteps => 10000…)], 7098, BlackBoxOptim.ScalarFitnessScheme{true}(), Bl
ackBoxOptim.TopListArchiveOutput{Float64, Vector{Float64}}(0.00068386560737
73598, [0.0023212695892352877, 0.6963274399853913, 0.21212095221290295, 0.4
998995913781066]), BlackBoxOptim.PopulationOptimizerOutput{BlackBoxOptim.Fi
tPopulation{Float64}}(BlackBoxOptim.FitPopulation{Float64}([0.0627012654747
373 0.011085279375595253 … 0.021966270780686456 0.09274796460464396; 0.8325
657181808118 0.7645497637798335 … 0.8006655316475157 0.8422778024470894; 0.
2807460662297616 0.2563479463052259 … 0.2859806061678159 0.259316848316797;
 0.5013787457342593 0.4995301218313842 … 0.499501521485902 0.49939792510114
733], NaN, [0.002413390772410997, 0.0016236381221511253, 0.0028577678349363
945, 0.0026395103167415612, 0.0019738422364445596, 0.0020379386219907987, 0
.004294728998115681, 0.00331346088342354, 0.0032845717066582523, 0.00419667
6193296035  …  0.0010529478322334003, 0.0010209952686373322, 0.002917901158
3626985, 0.0010829521409710552, 0.0022739257616603433, 0.001915757206014057
7, 0.002373391074050583, 0.0031814315456700354, 0.002238571721513025, 0.002
360973038403279], 0, BlackBoxOptim.Candidate{Float64}[BlackBoxOptim.Candida
te{Float64}([0.0272783961213909, 0.7242788351643437, 0.2153115507392777, 0.
5004964307320506], 33, 0.0008216359021075713, BlackBoxOptim.AdaptiveDiffEvo
RandBin{3}(BlackBoxOptim.AdaptiveDiffEvoParameters(BlackBoxOptim.BimodalCau
chy(Distributions.Cauchy{Float64}(μ=0.65, σ=0.1), Distributions.Cauchy{Floa
t64}(μ=1.0, σ=0.1), 0.5, false, true), BlackBoxOptim.BimodalCauchy(Distribu
tions.Cauchy{Float64}(μ=0.1, σ=0.1), Distributions.Cauchy{Float64}(μ=0.95, 
σ=0.1), 0.5, false, true), [0.6743321777586756, 0.8305831739134079, 0.93436
91907129329, 0.7070561258463595, 0.36276883854810754, 1.0, 0.54310237916284
35, 0.601851858201293, 0.4292287430599469, 0.6469900930077187  …  0.5593370
23404433, 0.9225239471528706, 0.8857793482672472, 0.6986338031976579, 0.397
4721130181213, 1.0, 0.5363300800565272, 1.0, 0.6208306952677988, 1.0], [0.1
362824456586581, 1.0, 0.22185588400057926, 0.9480782093010194, 0.9451708565
468645, 0.8011309102689473, 0.5485170956897147, 0.9509932949806846, 0.05375
824811858798, 0.9795257742608778  …  0.7505597898386004, 0.9546828425302832
, 0.880316434078212, 0.057076331752783566, 0.1441443916553598, 1.0, 0.80566
92390293114, 0.07006995659739154, 0.04513265761404339, 0.8441036002358545])
), 0), BlackBoxOptim.Candidate{Float64}([0.04650958169067674, 0.74495552238
78698, 0.21819508242983032, 0.500569756168161], 33, 0.0009657323337676613, 
BlackBoxOptim.AdaptiveDiffEvoRandBin{3}(BlackBoxOptim.AdaptiveDiffEvoParame
ters(BlackBoxOptim.BimodalCauchy(Distributions.Cauchy{Float64}(μ=0.65, σ=0.
1), Distributions.Cauchy{Float64}(μ=1.0, σ=0.1), 0.5, false, true), BlackBo
xOptim.BimodalCauchy(Distributions.Cauchy{Float64}(μ=0.1, σ=0.1), Distribut
ions.Cauchy{Float64}(μ=0.95, σ=0.1), 0.5, false, true), [0.6743321777586756
, 0.8305831739134079, 0.9343691907129329, 0.7070561258463595, 0.36276883854
810754, 1.0, 0.5431023791628435, 0.601851858201293, 0.4292287430599469, 0.6
469900930077187  …  0.559337023404433, 0.9225239471528706, 0.88577934826724
72, 0.6986338031976579, 0.3974721130181213, 1.0, 0.5363300800565272, 1.0, 0
.6208306952677988, 1.0], [0.1362824456586581, 1.0, 0.22185588400057926, 0.9
480782093010194, 0.9451708565468645, 0.8011309102689473, 0.5485170956897147
, 0.9509932949806846, 0.05375824811858798, 0.9795257742608778  …  0.7505597
898386004, 0.9546828425302832, 0.880316434078212, 0.057076331752783566, 0.1
441443916553598, 1.0, 0.8056692390293114, 0.07006995659739154, 0.0451326576
1404339, 0.8441036002358545])), 0)], Base.Threads.SpinLock(0))))
```



```julia
obj_short = build_loss_objective(prob_short,Tsit5(),L2Loss(t_short,data_short),tstops=t_short,reltol=1e-9)
res1 = bboptimize(obj_short;SearchRange = glo_bounds, MaxSteps = 7e3)
# Change in tolerance makes it worse
```

```
Starting optimization with optimizer BlackBoxOptim.DiffEvoOpt{BlackBoxOptim
.FitPopulation{Float64}, BlackBoxOptim.RadiusLimitedSelector, BlackBoxOptim
.AdaptiveDiffEvoRandBin{3}, BlackBoxOptim.RandomBound{BlackBoxOptim.Continu
ousRectSearchSpace}}
0.00 secs, 0 evals, 0 steps
0.50 secs, 3446 evals, 3323 steps, improv/step: 0.181 (last = 0.1815), fitn
ess=0.005165851
1.00 secs, 6964 evals, 6841 steps, improv/step: 0.140 (last = 0.1009), fitn
ess=0.000046288

Optimization stopped after 7001 steps and 1.02 seconds
Termination reason: Max number of steps (7000) reached
Steps per second = 6854.37
Function evals per second = 6974.80
Improvements/step = 0.13914
Total function evaluations = 7124


Best candidate found: [0.673936, 0.827584, 0.0850422, 0.500143]

Fitness: 0.000009952

BlackBoxOptim.OptimizationResults("adaptive_de_rand_1_bin_radiuslimited", "
Max number of steps (7000) reached", 7001, 1.660971769602519e9, 1.021391868
5913086, BlackBoxOptim.ParamsDictChain[BlackBoxOptim.ParamsDictChain[Dict{S
ymbol, Any}(:RngSeed => 140615, :SearchRange => [(0.0, 5.0), (0.0, 5.0), (0
.0, 5.0), (0.0, 5.0)], :MaxSteps => 7000),Dict{Symbol, Any}()],Dict{Symbol,
 Any}(:CallbackInterval => -1.0, :TargetFitness => nothing, :TraceMode => :
compact, :FitnessScheme => BlackBoxOptim.ScalarFitnessScheme{true}(), :MinD
eltaFitnessTolerance => 1.0e-50, :NumDimensions => :NotSpecified, :FitnessT
olerance => 1.0e-8, :TraceInterval => 0.5, :MaxStepsWithoutProgress => 1000
0, :MaxSteps => 10000…)], 7124, BlackBoxOptim.ScalarFitnessScheme{true}(), 
BlackBoxOptim.TopListArchiveOutput{Float64, Vector{Float64}}(9.951897760823
866e-6, [0.6739359929183464, 0.8275835602774839, 0.08504215099669726, 0.500
143204859366]), BlackBoxOptim.PopulationOptimizerOutput{BlackBoxOptim.FitPo
pulation{Float64}}(BlackBoxOptim.FitPopulation{Float64}([0.3198117255864981
 0.13557854347913323 … 0.14057410054616146 0.10203514494611504; 0.851551175
6855335 0.6968660400244377 … 0.6807324015788938 0.586654786414269; 0.149664
29192825859 0.1535792094324625 … 0.14694699625169091 0.1300124430567559; 0.
5000151878968173 0.4992823239542596 … 0.49885389642800027 0.499139169910161
8], NaN, [0.00048660243689970927, 0.0002495532786841738, 0.0004058259409159
254, 0.0002045946839939212, 0.0004430864082842268, 0.00031087375310034915, 
0.0005473959119196582, 0.00022139364572231406, 0.00020702350586165007, 0.00
03710757540336393  …  0.0018897138450370836, 8.676698616994761e-5, 0.000780
6554010016906, 0.0001734239661638512, 0.0003003754873636751, 0.000499612634
8836402, 0.0005711113088222354, 0.0006035142706066041, 0.000353106373306600
7, 0.0005536901050473703], 0, BlackBoxOptim.Candidate{Float64}[BlackBoxOpti
m.Candidate{Float64}([0.09105342285676035, 0.5975102776441285, 0.1353791726
7514266, 0.4984094584115317], 47, 0.0005711113088222354, BlackBoxOptim.Adap
tiveDiffEvoRandBin{3}(BlackBoxOptim.AdaptiveDiffEvoParameters(BlackBoxOptim
.BimodalCauchy(Distributions.Cauchy{Float64}(μ=0.65, σ=0.1), Distributions.
Cauchy{Float64}(μ=1.0, σ=0.1), 0.5, false, true), BlackBoxOptim.BimodalCauc
hy(Distributions.Cauchy{Float64}(μ=0.1, σ=0.1), Distributions.Cauchy{Float6
4}(μ=0.95, σ=0.1), 0.5, false, true), [0.5884164313112579, 1.0, 0.344142951
319354, 0.8064925193975571, 1.0, 0.8953845369755531, 1.0, 0.592026901622909
4, 0.7907107625819267, 0.9184120468389831  …  0.9266554756303359, 0.8608251
363649331, 0.4836190489255109, 0.7183243847370226, 0.5159215826550874, 0.01
9211616272908016, 0.9206035897675227, 1.0, 1.0, 0.7001109639779636], [0.630
4061659014888, 0.8971619108526749, 0.8273414180751423, 1.0, 0.9079597344970
035, 0.07253992496701805, 0.857940004674338, 0.9545709793181447, 1.0, 0.979
2084383545016  …  0.21211267673581713, 0.28249450137488696, 0.0217552192213
8876, 0.05913629417387695, 0.14183368272176802, 1.0, 0.5142121530296264, 0.
8683247522922815, 1.0, 0.8944622911231754])), 0), BlackBoxOptim.Candidate{F
loat64}([0.09105342285676035, 0.5975102776441285, 0.16278037010889523, 0.49
84094584115317], 47, 0.2541624026952121, BlackBoxOptim.AdaptiveDiffEvoRandB
in{3}(BlackBoxOptim.AdaptiveDiffEvoParameters(BlackBoxOptim.BimodalCauchy(D
istributions.Cauchy{Float64}(μ=0.65, σ=0.1), Distributions.Cauchy{Float64}(
μ=1.0, σ=0.1), 0.5, false, true), BlackBoxOptim.BimodalCauchy(Distributions
.Cauchy{Float64}(μ=0.1, σ=0.1), Distributions.Cauchy{Float64}(μ=0.95, σ=0.1
), 0.5, false, true), [0.5884164313112579, 1.0, 0.344142951319354, 0.806492
5193975571, 1.0, 0.8953845369755531, 1.0, 0.5920269016229094, 0.79071076258
19267, 0.9184120468389831  …  0.9266554756303359, 0.8608251363649331, 0.483
6190489255109, 0.7183243847370226, 0.5159215826550874, 0.019211616272908016
, 0.9206035897675227, 1.0, 1.0, 0.7001109639779636], [0.6304061659014888, 0
.8971619108526749, 0.8273414180751423, 1.0, 0.9079597344970035, 0.072539924
96701805, 0.857940004674338, 0.9545709793181447, 1.0, 0.9792084383545016  …
  0.21211267673581713, 0.28249450137488696, 0.02175521922138876, 0.05913629
417387695, 0.14183368272176802, 1.0, 0.5142121530296264, 0.8683247522922815
, 1.0, 0.8944622911231754])), 0)], Base.Threads.SpinLock(0))))
```



```julia
obj_short = build_loss_objective(prob_short,Vern9(),L2Loss(t_short,data_short),tstops=t_short,reltol=1e-9,abstol=1e-9)
res1 = bboptimize(obj_short;SearchRange = glo_bounds, MaxSteps = 7e3)
# using the moe accurate Vern9() reduces the fitness marginally and leads to some increase in time taken
```

```
Starting optimization with optimizer BlackBoxOptim.DiffEvoOpt{BlackBoxOptim
.FitPopulation{Float64}, BlackBoxOptim.RadiusLimitedSelector, BlackBoxOptim
.AdaptiveDiffEvoRandBin{3}, BlackBoxOptim.RandomBound{BlackBoxOptim.Continu
ousRectSearchSpace}}
0.00 secs, 0 evals, 0 steps
0.50 secs, 2308 evals, 2201 steps, improv/step: 0.239 (last = 0.2394), fitn
ess=0.036500396
1.00 secs, 4633 evals, 4527 steps, improv/step: 0.169 (last = 0.1019), fitn
ess=0.002126688

Optimization stopped after 7001 steps and 1.50 seconds
Termination reason: Max number of steps (7000) reached
Steps per second = 4675.29
Function evals per second = 4743.41
Improvements/step = 0.15171
Total function evaluations = 7103


Best candidate found: [0.195562, 0.724088, 0.144954, 0.499627]

Fitness: 0.000155236

BlackBoxOptim.OptimizationResults("adaptive_de_rand_1_bin_radiuslimited", "
Max number of steps (7000) reached", 7001, 1.660971782157683e9, 1.497447013
8549805, BlackBoxOptim.ParamsDictChain[BlackBoxOptim.ParamsDictChain[Dict{S
ymbol, Any}(:RngSeed => 300285, :SearchRange => [(0.0, 5.0), (0.0, 5.0), (0
.0, 5.0), (0.0, 5.0)], :MaxSteps => 7000),Dict{Symbol, Any}()],Dict{Symbol,
 Any}(:CallbackInterval => -1.0, :TargetFitness => nothing, :TraceMode => :
compact, :FitnessScheme => BlackBoxOptim.ScalarFitnessScheme{true}(), :MinD
eltaFitnessTolerance => 1.0e-50, :NumDimensions => :NotSpecified, :FitnessT
olerance => 1.0e-8, :TraceInterval => 0.5, :MaxStepsWithoutProgress => 1000
0, :MaxSteps => 10000…)], 7103, BlackBoxOptim.ScalarFitnessScheme{true}(), 
BlackBoxOptim.TopListArchiveOutput{Float64, Vector{Float64}}(0.000155235926
7385843, [0.1955615022162753, 0.7240878186904538, 0.14495442692245208, 0.49
96273384839812]), BlackBoxOptim.PopulationOptimizerOutput{BlackBoxOptim.Fit
Population{Float64}}(BlackBoxOptim.FitPopulation{Float64}([0.27329168179183
91 0.1822856857892956 … 0.23585769578750843 0.38886463674313165; 0.77507771
54588752 0.7059920185402421 … 0.7434975783837428 0.8773040839349877; 0.1380
192817633523 0.14267413336857301 … 0.13864824068385842 0.13616692266795427;
 0.4988973878924618 0.49894533891714193 … 0.49873135050677536 0.49989572755
674105], NaN, [0.0005324155335059558, 0.00031917153635847883, 0.00133087045
61331205, 0.0018800344366590145, 0.0011356553401604694, 0.00172785245093967
77, 0.0014775840863083883, 0.0013330203472618606, 0.002197844488678738, 0.0
03659495288102745  …  0.0001552359267385843, 0.00016129611543728463, 0.0001
658395581863243, 0.0001693375963426399, 0.00015839490094551908, 0.000164057
6918933331, 0.0002719944104864568, 0.00024414124678833637, 0.00059022873046
65007, 0.0011101817026521934], 0, BlackBoxOptim.Candidate{Float64}[BlackBox
Optim.Candidate{Float64}([0.23585769578750843, 0.7434975783837428, 0.138648
24068385842, 0.49873135050677536], 49, 0.0005902287304665007, BlackBoxOptim
.AdaptiveDiffEvoRandBin{3}(BlackBoxOptim.AdaptiveDiffEvoParameters(BlackBox
Optim.BimodalCauchy(Distributions.Cauchy{Float64}(μ=0.65, σ=0.1), Distribut
ions.Cauchy{Float64}(μ=1.0, σ=0.1), 0.5, false, true), BlackBoxOptim.Bimoda
lCauchy(Distributions.Cauchy{Float64}(μ=0.1, σ=0.1), Distributions.Cauchy{F
loat64}(μ=0.95, σ=0.1), 0.5, false, true), [0.5784719429273577, 1.0, 0.5998
244368010978, 0.8535189379853811, 0.8144159434451181, 0.6208024000509015, 0
.9974794749663692, 0.9159401110787977, 0.5520842851720413, 1.0  …  0.030228
36388887551, 0.7111077874821565, 0.6835573435913228, 1.0, 0.970764560930907
3, 1.0, 0.5463667431401953, 1.0, 1.0, 1.0], [1.0, 0.19923837874022532, 0.86
84066716188921, 0.9839786073173784, 1.0, 0.7521857630685007, 1.0, 1.0, 0.97
43960690876494, 0.32430962475016656  …  0.06733448237605977, 0.923359369346
0845, 0.8832430250944396, 0.7945574142691588, 0.9992511248873074, 0.8799535
389651875, 0.18149115849886308, 1.0, 0.8230703477955342, 0.2368359036095910
3])), 0), BlackBoxOptim.Candidate{Float64}([0.23585769578750843, 0.74349757
83837428, 0.2147574271080187, 0.49873135050677536], 49, 1.6406709341459205,
 BlackBoxOptim.AdaptiveDiffEvoRandBin{3}(BlackBoxOptim.AdaptiveDiffEvoParam
eters(BlackBoxOptim.BimodalCauchy(Distributions.Cauchy{Float64}(μ=0.65, σ=0
.1), Distributions.Cauchy{Float64}(μ=1.0, σ=0.1), 0.5, false, true), BlackB
oxOptim.BimodalCauchy(Distributions.Cauchy{Float64}(μ=0.1, σ=0.1), Distribu
tions.Cauchy{Float64}(μ=0.95, σ=0.1), 0.5, false, true), [0.578471942927357
7, 1.0, 0.5998244368010978, 0.8535189379853811, 0.8144159434451181, 0.62080
24000509015, 0.9974794749663692, 0.9159401110787977, 0.5520842851720413, 1.
0  …  0.03022836388887551, 0.7111077874821565, 0.6835573435913228, 1.0, 0.9
707645609309073, 1.0, 0.5463667431401953, 1.0, 1.0, 1.0], [1.0, 0.199238378
74022532, 0.8684066716188921, 0.9839786073173784, 1.0, 0.7521857630685007, 
1.0, 1.0, 0.9743960690876494, 0.32430962475016656  …  0.06733448237605977, 
0.9233593693460845, 0.8832430250944396, 0.7945574142691588, 0.9992511248873
074, 0.8799535389651875, 0.18149115849886308, 1.0, 0.8230703477955342, 0.23
683590360959103])), 0)], Base.Threads.SpinLock(0))))
```





## Using NLopt

#### Global Optimisation

```julia
obj_short = build_loss_objective(prob_short,Vern9(),L2Loss(t_short,data_short),tstops=t_short,reltol=1e-9,abstol=1e-9)
```

```
(::DiffEqParamEstim.DiffEqObjective{DiffEqParamEstim.var"#37#42"{Nothing, B
ool, Int64, typeof(DiffEqParamEstim.STANDARD_PROB_GENERATOR), Base.Pairs{Sy
mbol, Any, Tuple{Symbol, Symbol, Symbol}, NamedTuple{(:tstops, :reltol, :ab
stol), Tuple{Vector{Float64}, Float64, Float64}}}, SciMLBase.ODEProblem{Vec
tor{Float64}, Tuple{Float64, Float64}, true, Vector{Float64}, Main.##WeaveS
andBox#291.FitzhughNagumo{Main.##WeaveSandBox#291.var"###ParameterizedDiffE
qFunction#303", Main.##WeaveSandBox#291.var"###ParameterizedTGradFunction#3
04", Main.##WeaveSandBox#291.var"###ParameterizedJacobianFunction#305", Not
hing, Nothing, ModelingToolkit.ODESystem}, Base.Pairs{Symbol, Union{}, Tupl
e{}, NamedTuple{(), Tuple{}}}, SciMLBase.StandardODEProblem}, OrdinaryDiffE
q.Vern9, DiffEqParamEstim.L2Loss{Vector{Float64}, Matrix{Float64}, Nothing,
 Nothing, Nothing}, Nothing, Tuple{}}, DiffEqParamEstim.var"#41#47"{DiffEqP
aramEstim.var"#37#42"{Nothing, Bool, Int64, typeof(DiffEqParamEstim.STANDAR
D_PROB_GENERATOR), Base.Pairs{Symbol, Any, Tuple{Symbol, Symbol, Symbol}, N
amedTuple{(:tstops, :reltol, :abstol), Tuple{Vector{Float64}, Float64, Floa
t64}}}, SciMLBase.ODEProblem{Vector{Float64}, Tuple{Float64, Float64}, true
, Vector{Float64}, Main.##WeaveSandBox#291.FitzhughNagumo{Main.##WeaveSandB
ox#291.var"###ParameterizedDiffEqFunction#303", Main.##WeaveSandBox#291.var
"###ParameterizedTGradFunction#304", Main.##WeaveSandBox#291.var"###Paramet
erizedJacobianFunction#305", Nothing, Nothing, ModelingToolkit.ODESystem}, 
Base.Pairs{Symbol, Union{}, Tuple{}, NamedTuple{(), Tuple{}}}, SciMLBase.St
andardODEProblem}, OrdinaryDiffEq.Vern9, DiffEqParamEstim.L2Loss{Vector{Flo
at64}, Matrix{Float64}, Nothing, Nothing, Nothing}, Nothing, Tuple{}}}}) (g
eneric function with 2 methods)
```



```julia
opt = Opt(:GN_ORIG_DIRECT_L, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[5.0,5.0,5.0,5.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,glo_init)
```

```
2.065413 seconds (3.44 M allocations: 531.098 MiB, 4.42% gc time, 1.82% c
ompilation time)
(0.11016600768053639, [0.19204389575055014, 1.1316872427993379, 1.111111111
1140621, 0.509577685189625], :XTOL_REACHED)
```



```julia
opt = Opt(:GN_CRS2_LM, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[5.0,5.0,5.0,5.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,glo_init)
```

```
2.083164 seconds (3.55 M allocations: 549.830 MiB, 3.94% gc time)
(1.6904219109512085e-19, [0.6999999862229306, 0.8000000022492897, 0.0800000
0138449968, 0.5000000000064174], :MAXEVAL_REACHED)
```



```julia
opt = Opt(:GN_ISRES, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[5.0,5.0,5.0,5.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,glo_init)
```

```
2.073695 seconds (3.55 M allocations: 549.775 MiB, 2.92% gc time)
(0.06168462321830632, [3.4617922880525764, 3.230661980261912, 0.06909160198
137998, 0.49218785588342584], :MAXEVAL_REACHED)
```



```julia
opt = Opt(:GN_ESCH, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[5.0,5.0,5.0,5.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,glo_init)
```

```
2.037384 seconds (3.55 M allocations: 549.775 MiB, 1.99% gc time)
(0.08163900021542987, [2.0623124382288602, 2.618555882008759, 0.23575024118
50981, 0.505999467895518], :MAXEVAL_REACHED)
```





Now local optimization algorithms are used to check the global ones, these use the local constraints, different intial values and time step


```julia
opt = Opt(:LN_BOBYQA, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
0.364540 seconds (599.20 k allocations: 92.695 MiB, 5.55% gc time, 1.89% 
compilation time)
(6.061254673501234e-25, [0.7000000000016084, 0.8000000000072433, 0.08000000
00005164, 0.5000000000000376], :SUCCESS)
```



```julia
opt = Opt(:LN_NELDERMEAD, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
0.187196 seconds (330.52 k allocations: 51.184 MiB)
(8.965505337550124e-5, [1.0, 1.0, 0.07355092561816819, 0.5004047023153091],
 :XTOL_REACHED)
```



```julia
opt = Opt(:LD_SLSQP, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
0.374167 seconds (704.77 k allocations: 93.947 MiB, 7.23% gc time, 10.79%
 compilation time)
(3.67912644521962e-14, [0.6999859478529181, 0.7999982042328838, 0.080001028
77405693, 0.49999999706186266], :XTOL_REACHED)
```



```julia
opt = Opt(:LN_COBYLA, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
2.051483 seconds (3.55 M allocations: 549.775 MiB, 2.49% gc time)
(0.0007524728658136584, [0.1885826859994063, 0.837816822842615, 0.193809745
67156425, 0.5003786107932625], :MAXEVAL_REACHED)
```



```julia
opt = Opt(:LN_NEWUOA_BOUND, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
229.573294 seconds (139.88 k allocations: 21.661 MiB)
(0.0004372072514814746, [0.31072806458797847, 0.41451131981170064, 0.077546
14366928633, 0.4991280100743405], :SUCCESS)
```



```julia
opt = Opt(:LN_PRAXIS, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
0.258171 seconds (351.11 k allocations: 54.373 MiB, 24.23% gc time)
(5.583602846656372e-25, [0.7000000000363364, 0.8000000000089904, 0.07999999
999772509, 0.5000000000000423], :SUCCESS)
```



```julia
opt = Opt(:LN_SBPLX, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
2.064439 seconds (3.55 M allocations: 549.775 MiB, 2.94% gc time)
(2.3573179824671637e-14, [0.700008441324718, 0.8000032097693197, 0.07999957
862591811, 0.5000000064581462], :MAXEVAL_REACHED)
```



```julia
opt = Opt(:LD_MMA, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj_short.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
18.431127 seconds (31.73 M allocations: 4.827 GiB, 2.61% gc time)
(0.00010537298404809113, [0.22394966447123335, 0.7058548690391515, 0.132691
05190166866, 0.49971643945123306], :MAXEVAL_REACHED)
```





### Now the longer problem is solved for a global solution

Vern9 solver with reltol=1e-9 and abstol=1e-9 is used and the dataset is increased to 3000 observations per variable with the same integration time step of 0.01.


```julia
obj = build_loss_objective(prob,Vern9(),L2Loss(t,data),tstops=t,reltol=1e-9,abstol=1e-9)
res1 = bboptimize(obj;SearchRange = glo_bounds, MaxSteps = 4e3)
```

```
Starting optimization with optimizer BlackBoxOptim.DiffEvoOpt{BlackBoxOptim
.FitPopulation{Float64}, BlackBoxOptim.RadiusLimitedSelector, BlackBoxOptim
.AdaptiveDiffEvoRandBin{3}, BlackBoxOptim.RandomBound{BlackBoxOptim.Continu
ousRectSearchSpace}}
0.00 secs, 0 evals, 0 steps
0.50 secs, 239 evals, 163 steps, improv/step: 0.491 (last = 0.4908), fitnes
s=2116.419723321
1.00 secs, 486 evals, 397 steps, improv/step: 0.388 (last = 0.3162), fitnes
s=1074.002428869
1.50 secs, 725 evals, 634 steps, improv/step: 0.300 (last = 0.1519), fitnes
s=1074.002428869
2.00 secs, 971 evals, 880 steps, improv/step: 0.268 (last = 0.1870), fitnes
s=999.546345913
2.50 secs, 1210 evals, 1119 steps, improv/step: 0.238 (last = 0.1255), fitn
ess=902.606610413
3.00 secs, 1457 evals, 1366 steps, improv/step: 0.219 (last = 0.1336), fitn
ess=902.606610413
3.51 secs, 1696 evals, 1605 steps, improv/step: 0.198 (last = 0.0753), fitn
ess=389.160045809
4.01 secs, 1943 evals, 1852 steps, improv/step: 0.188 (last = 0.1255), fitn
ess=389.160045809
4.51 secs, 2183 evals, 2092 steps, improv/step: 0.175 (last = 0.0792), fitn
ess=293.872410548
5.01 secs, 2430 evals, 2339 steps, improv/step: 0.168 (last = 0.1093), fitn
ess=293.872410548
5.51 secs, 2670 evals, 2579 steps, improv/step: 0.160 (last = 0.0750), fitn
ess=293.872410548
6.01 secs, 2917 evals, 2827 steps, improv/step: 0.154 (last = 0.0927), fitn
ess=293.872410548
6.51 secs, 3156 evals, 3067 steps, improv/step: 0.148 (last = 0.0750), fitn
ess=293.872410548
7.01 secs, 3403 evals, 3314 steps, improv/step: 0.143 (last = 0.0810), fitn
ess=293.872410548
7.51 secs, 3642 evals, 3553 steps, improv/step: 0.138 (last = 0.0669), fitn
ess=293.872410548
8.01 secs, 3889 evals, 3800 steps, improv/step: 0.136 (last = 0.1093), fitn
ess=279.583701305

Optimization stopped after 4001 steps and 8.44 seconds
Termination reason: Max number of steps (4000) reached
Steps per second = 474.11
Function evals per second = 484.66
Improvements/step = 0.13700
Total function evaluations = 4090


Best candidate found: [1.09843, 1.08051, 0.0979729, 0.554911]

Fitness: 105.717492166

BlackBoxOptim.OptimizationResults("adaptive_de_rand_1_bin_radiuslimited", "
Max number of steps (4000) reached", 4001, 1.660972045805674e9, 8.438920974
731445, BlackBoxOptim.ParamsDictChain[BlackBoxOptim.ParamsDictChain[Dict{Sy
mbol, Any}(:RngSeed => 308407, :SearchRange => [(0.0, 5.0), (0.0, 5.0), (0.
0, 5.0), (0.0, 5.0)], :MaxSteps => 4000),Dict{Symbol, Any}()],Dict{Symbol, 
Any}(:CallbackInterval => -1.0, :TargetFitness => nothing, :TraceMode => :c
ompact, :FitnessScheme => BlackBoxOptim.ScalarFitnessScheme{true}(), :MinDe
ltaFitnessTolerance => 1.0e-50, :NumDimensions => :NotSpecified, :FitnessTo
lerance => 1.0e-8, :TraceInterval => 0.5, :MaxStepsWithoutProgress => 10000
, :MaxSteps => 10000…)], 4090, BlackBoxOptim.ScalarFitnessScheme{true}(), B
lackBoxOptim.TopListArchiveOutput{Float64, Vector{Float64}}(105.71749216600
374, [1.0984294033026054, 1.080510290841446, 0.09797294382807924, 0.5549106
68586429]), BlackBoxOptim.PopulationOptimizerOutput{BlackBoxOptim.FitPopula
tion{Float64}}(BlackBoxOptim.FitPopulation{Float64}([2.256082166509588 1.21
11580697065434 … 1.5324607117762734 1.430394083064303; 2.4896056708966317 1
.3218184403812647 … 1.4351933222702016 1.5694813113892054; 0.27789751948544
44 0.19076595202949226 … 0.14908098957179572 0.18152386594488842; 0.4994141
49421885 0.7043295421794493 … 0.684026562599732 0.6216898661788228], NaN, [
720.5357801857841, 363.72112226673283, 365.2405533846554, 730.7049554432791
, 745.3939520422077, 554.346357420792, 893.1457417743936, 790.6968403952274
, 561.5420705778174, 833.6112435634365  …  517.4122814135821, 585.707938641
7006, 522.4771394554932, 597.7890877481229, 710.2970789413024, 313.73077563
462766, 121.96900817970369, 182.7488860456937, 293.87241054791554, 325.4641
456081559], 0, BlackBoxOptim.Candidate{Float64}[BlackBoxOptim.Candidate{Flo
at64}([1.4129193984011783, 0.8561069825219421, 0.12624679395826702, 0.86811
11179525578], 16, 712.9893828277789, BlackBoxOptim.AdaptiveDiffEvoRandBin{3
}(BlackBoxOptim.AdaptiveDiffEvoParameters(BlackBoxOptim.BimodalCauchy(Distr
ibutions.Cauchy{Float64}(μ=0.65, σ=0.1), Distributions.Cauchy{Float64}(μ=1.
0, σ=0.1), 0.5, false, true), BlackBoxOptim.BimodalCauchy(Distributions.Cau
chy{Float64}(μ=0.1, σ=0.1), Distributions.Cauchy{Float64}(μ=0.95, σ=0.1), 0
.5, false, true), [1.0, 0.8291077311181397, 0.9558771863973256, 0.620453094
0083828, 1.0, 0.6298346942675679, 0.5974336017275566, 0.7263360199839107, 0
.6207571257200449, 1.0  …  1.0, 1.0, 0.7851837144613572, 0.7389903495134021
, 1.0, 0.6172575630730834, 1.0, 0.9287510332395597, 1.0, 0.5812251896845996
], [0.23044206257267674, 0.13144747103493123, 1.0, 0.5401001512633113, 0.18
494112377162883, 0.7499459001882497, 1.0, 0.052626857681012086, 1.0, 0.2562
269403023316  …  0.8996951157847478, 0.09039086091948775, 0.189680655144860
18, 0.0869885777417393, 0.19909101211359348, 0.8767475575119684, 1.0, 0.954
5109200861923, 0.8338192919600884, 0.5665384726825227])), 0), BlackBoxOptim
.Candidate{Float64}([2.4538650337361876, 2.183724002935282, 0.1624773527245
3445, 0.6638779789889137], 16, 723.2753260783848, BlackBoxOptim.AdaptiveDif
fEvoRandBin{3}(BlackBoxOptim.AdaptiveDiffEvoParameters(BlackBoxOptim.Bimoda
lCauchy(Distributions.Cauchy{Float64}(μ=0.65, σ=0.1), Distributions.Cauchy{
Float64}(μ=1.0, σ=0.1), 0.5, false, true), BlackBoxOptim.BimodalCauchy(Dist
ributions.Cauchy{Float64}(μ=0.1, σ=0.1), Distributions.Cauchy{Float64}(μ=0.
95, σ=0.1), 0.5, false, true), [1.0, 0.8291077311181397, 0.9558771863973256
, 0.6204530940083828, 1.0, 0.6298346942675679, 0.5974336017275566, 0.726336
0199839107, 0.6207571257200449, 1.0  …  1.0, 1.0, 0.7851837144613572, 0.738
9903495134021, 1.0, 0.6172575630730834, 1.0, 0.9287510332395597, 1.0, 0.581
2251896845996], [0.23044206257267674, 0.13144747103493123, 1.0, 0.540100151
2633113, 0.18494112377162883, 0.7499459001882497, 1.0, 0.052626857681012086
, 1.0, 0.2562269403023316  …  0.8996951157847478, 0.09039086091948775, 0.18
968065514486018, 0.0869885777417393, 0.19909101211359348, 0.876747557511968
4, 1.0, 0.9545109200861923, 0.8338192919600884, 0.5665384726825227])), 0)],
 Base.Threads.SpinLock(0))))
```



```julia
opt = Opt(:GN_ORIG_DIRECT_L, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[5.0,5.0,5.0,5.0])
min_objective!(opt, obj.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,glo_init)
```

```
16.757549 seconds (24.91 M allocations: 3.288 GiB, 1.79% gc time)
(81.06091854729164, [1.111111111112095, 1.1111111111081604, 0.1005944215791
2543, 0.576131687239848], :XTOL_REACHED)
```



```julia
opt = Opt(:GN_CRS2_LM, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[5.0,5.0,5.0,5.0])
min_objective!(opt, obj.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 20000)
@time (minf,minx,ret) = NLopt.optimize(opt,glo_init)
```

```
16.609765 seconds (24.60 M allocations: 3.247 GiB, 2.01% gc time)
(7.57288182415672e-19, [0.6999999999968536, 0.8000000000017804, 0.080000000
00039725, 0.4999999999985637], :XTOL_REACHED)
```



```julia
opt = Opt(:GN_ISRES, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[5.0,5.0,5.0,5.0])
min_objective!(opt, obj.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 50000)
@time (minf,minx,ret) = NLopt.optimize(opt,glo_init)
```

```
103.175618 seconds (152.95 M allocations: 20.187 GiB, 1.93% gc time)
(4.73808389073643e-16, [0.7000000001696726, 0.8000000001421825, 0.080000000
03610633, 0.5000000001668155], :MAXEVAL_REACHED)
```



```julia
opt = Opt(:GN_ESCH, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[5.0,5.0,5.0,5.0])
min_objective!(opt, obj.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 20000)
@time (minf,minx,ret) = NLopt.optimize(opt,glo_init)
```

```
41.227376 seconds (61.18 M allocations: 8.075 GiB, 1.90% gc time)
(677.3605498485495, [2.4174690259859113, 2.55277198003503, 0.10718718841618
26, 0.4549176906503949], :MAXEVAL_REACHED)
```



```julia
opt = Opt(:LN_BOBYQA, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
0.928320 seconds (1.37 M allocations: 185.220 MiB, 2.04% gc time)
(7.532340009971321e-19, [0.6999999999963404, 0.8000000000026266, 0.08000000
000036575, 0.49999999999820643], :XTOL_REACHED)
```



```julia
opt = Opt(:LN_NELDERMEAD, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj.cost_function2)
xtol_rel!(opt,1e-9)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
1.081912 seconds (1.61 M allocations: 217.055 MiB, 1.74% gc time)
(3160.405522283876, [1.0, 1.0, 1.0, 0.8656987224332], :XTOL_REACHED)
```



```julia
opt = Opt(:LD_SLSQP, 4)
lower_bounds!(opt,[0.0,0.0,0.0,0.0])
upper_bounds!(opt,[1.0,1.0,1.0,1.0])
min_objective!(opt, obj.cost_function2)
xtol_rel!(opt,1e-12)
maxeval!(opt, 10000)
@time (minf,minx,ret) = NLopt.optimize(opt,loc_init)
```

```
0.574928 seconds (843.68 k allocations: 114.094 MiB, 3.28% gc time)
(3160.405587378227, [0.9999999997608687, 0.9999999930977961, 0.999999999551
8839, 0.8657151072220817], :XTOL_REACHED)
```





As expected from other problems the longer sample proves to be extremely challenging for some of the global optimizers. A few give the accurate values, while others seem to struggle with accuracy a lot.


#### Using QuadDIRECT

```julia
obj_short = build_loss_objective(prob_short,Tsit5(),L2Loss(t_short,data_short),tstops=t_short)
lower = [0,0,0,0]
upper = [1,1,1,1]
splits = ([0,0.3,0.7],[0,0.3,0.7],[0,0.3,0.7],[0,0.3,0.7])
@time root, x0 = analyze(obj_short,splits,lower,upper)
```

```
22.358796 seconds (49.81 M allocations: 4.253 GiB, 4.54% gc time, 98.67% c
ompilation time)
(BoxRoot@[NaN, NaN, NaN, NaN], [0.3, 0.3, 0.3, 0.3])
```



```julia
minimum(root)
```

```
Box0.009539450373052817@[0.0, 0.8016093071685325, 0.3, 0.4982153959352484]
```



```julia
obj = build_loss_objective(prob,Vern9(),L2Loss(t,data),tstops=t,reltol=1e-9,abstol=1e-9)
lower = [0,0,0,0]
upper = [5,5,5,5]
splits = ([0,0.5,1],[0,0.5,1],[0,0.5,1],[0,0.5,1])
@time root, x0 = analyze(obj_short,splits,lower,upper)
```

```
0.086104 seconds (226.19 k allocations: 31.399 MiB)
(BoxRoot@[NaN, NaN, NaN, NaN], [0.5, 0.5, 0.5, 0.5])
```



```julia
minimum(root)
```

```
Box0.012650644127007012@[0.166694563010428, 0.9990234375, 0.389980536608798
5, 0.49992589668402526]
```





# Conclusion

It is observed that lower tolerance lead to higher accuracy but too low tolerance could affect the convergance time drastically. Also fitting a shorter timespan seems to be easier in comparision (quite intutively). NLOpt methods seem to give great accuracy in the shorter problem with a lot of the algorithms giving 0 fitness, BBO performs very well on it with marginal change with tol values. In case of global optimization of the longer problem there is some difference in the perfomance amongst the algorithms with :LN_BOBYQA giving accurate results for the local optimization and :GN_ISRES :GN_CRS2_LM in case of the global give the highest accuracy. BBO also fails to perform too well in the case of the longer problem. QuadDIRECT performs well in case of the shorter problem but fails to give good results in the longer version.


## Appendix

These benchmarks are a part of the SciMLBenchmarks.jl repository, found at: [https://github.com/SciML/SciMLBenchmarks.jl](https://github.com/SciML/SciMLBenchmarks.jl). For more information on high-performance scientific machine learning, check out the SciML Open Source Software Organization [https://sciml.ai](https://sciml.ai).

To locally run this benchmark, do the following commands:

```
using SciMLBenchmarks
SciMLBenchmarks.weave_file("benchmarks/ParameterEstimation","FitzHughNagumoParameterEstimation.jmd")
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
      Status `/cache/build/exclusive-amdci1-0/julialang/scimlbenchmarks-dot-jl/benchmarks/ParameterEstimation/Project.toml`
  [6e4b80f9] BenchmarkTools v1.3.1
  [a134a8b2] BlackBoxOptim v0.6.1
  [1130ab10] DiffEqParamEstim v1.26.0
  [31c24e10] Distributions v0.25.67
  [76087f3c] NLopt v0.6.5
  [1dea7af3] OrdinaryDiffEq v6.20.0
  [65888b18] ParameterizedFunctions v5.13.2
  [91a5bcdd] Plots v1.31.7
  [dae52e8d] QuadDIRECT v0.1.2 `https://github.com/timholy/QuadDIRECT.jl#master`
  [731186ca] RecursiveArrayTools v2.32.0
  [31c91b34] SciMLBenchmarks v0.1.1
```

And the full manifest:

```
      Status `/cache/build/exclusive-amdci1-0/julialang/scimlbenchmarks-dot-jl/benchmarks/ParameterEstimation/Manifest.toml`
  [c3fe647b] AbstractAlgebra v0.27.3
  [621f4979] AbstractFFTs v1.2.1
  [1520ce14] AbstractTrees v0.4.2
  [79e6a3ab] Adapt v3.4.0
  [dce04be8] ArgCheck v2.3.0
  [ec485272] ArnoldiMethod v0.2.0
  [4fba245c] ArrayInterface v6.0.22
  [30b0a656] ArrayInterfaceCore v0.1.17
  [6ba088a2] ArrayInterfaceGPUArrays v0.2.1
  [015c0d05] ArrayInterfaceOffsetArrays v0.1.6
  [b0d46f97] ArrayInterfaceStaticArrays v0.1.4
  [dd5226c6] ArrayInterfaceStaticArraysCore v0.1.0
  [a2b0951a] ArrayInterfaceTracker v0.1.1
  [4c555306] ArrayLayouts v0.8.11
  [15f4f7f2] AutoHashEquals v0.2.0
  [aae01518] BandedMatrices v0.17.5
  [198e06fe] BangBang v0.3.36
  [9718e550] Baselet v0.1.1
  [6e4b80f9] BenchmarkTools v1.3.1
  [e2ed5e7c] Bijections v0.1.4
  [62783981] BitTwiddlingConvenienceFunctions v0.1.4
  [a134a8b2] BlackBoxOptim v0.6.1
  [8e7c35d0] BlockArrays v0.16.20
  [ffab5731] BlockBandedMatrices v0.11.9
  [fa961155] CEnum v0.4.2
  [2a0fbf3d] CPUSummary v0.1.25
  [a9c8d775] CPUTime v1.0.0
  [00ebfdb7] CSTParser v3.3.6
  [49dc2e85] Calculus v0.5.1
  [7057c7e9] Cassette v0.3.10
  [082447d4] ChainRules v1.44.2
  [d360d2e6] ChainRulesCore v1.15.3
  [9e997f8a] ChangesOfVariables v0.1.4
  [fb6a15b2] CloseOpenIntervals v0.1.10
  [523fee87] CodecBzip2 v0.7.2
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
  [39dd38d3] Dierckx v0.5.2
  [2b5f629d] DiffEqBase v6.95.3
  [459566f4] DiffEqCallbacks v2.24.0
  [77a26b50] DiffEqNoiseProcess v5.12.1
  [9fdde737] DiffEqOperators v4.43.1
  [1130ab10] DiffEqParamEstim v1.26.0
  [163ba53b] DiffResults v1.0.3
  [b552c78f] DiffRules v1.11.0
  [b4f34e82] Distances v0.10.7
  [31c24e10] Distributions v0.25.67
  [ffbed154] DocStringExtensions v0.8.6
  [5b8099bc] DomainSets v0.5.11
  [fa6b7ba4] DualNumbers v0.6.8
  [7c1d4256] DynamicPolynomials v0.4.5
  [da5c29d0] EllipsisNotation v1.6.0
  [7da242da] Enzyme v0.10.4
  [d4d017d3] ExponentialUtilities v1.18.0
  [e2ba6199] ExprTools v0.1.8
  [411431e0] Extents v0.1.1
  [c87230d0] FFMPEG v0.4.1
  [7034ab61] FastBroadcast v0.2.1
  [9aa1b823] FastClosures v0.3.2
  [29a986be] FastLapackInterface v1.2.3
  [1a297f60] FillArrays v0.13.2
  [6a86dc24] FiniteDiff v2.15.0
  [53c48c17] FixedPointNumbers v0.8.4
  [59287772] Formatting v0.4.2
  [f6369f11] ForwardDiff v0.10.32
  [069b7b12] FunctionWrappers v1.1.2
  [0c68f7d7] GPUArrays v8.4.2
  [46192b85] GPUArraysCore v0.1.1
  [61eb1bfa] GPUCompiler v0.16.3
  [28b8d3ca] GR v0.66.2
  [c145ed77] GenericSchur v0.5.3
  [cf35fbd7] GeoInterface v1.0.1
  [5c1252a2] GeometryBasics v0.4.3
  [d7ba0133] Git v1.2.1
  [86223c79] Graphs v1.7.1
  [42e2da0e] Grisu v1.0.2
  [0b43b601] Groebner v0.2.10
  [d5909c97] GroupsCore v0.4.0
  [cd3eb016] HTTP v0.9.17
  [eafb193a] Highlights v0.4.5
  [3e5b6fbb] HostCPUFeatures v0.1.8
  [34004b35] HypergeometricFunctions v0.3.11
  [7073ff75] IJulia v1.23.3
  [7869d1d1] IRTools v0.4.6
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
  [98e50ef6] JuliaFormatter v1.0.9
  [ccbc3e58] JumpProcesses v9.1.0
  [ef3ab10e] KLU v0.3.0
  [ba0b0d4f] Krylov v0.8.3
  [0b1a1467] KrylovKit v0.5.4
  [929cbde3] LLVM v4.14.0
  [b964fa9f] LaTeXStrings v1.3.0
  [2ee39098] LabelledArrays v1.12.0
  [23fbe1c1] Latexify v0.15.16
  [10f19ff3] LayoutPointers v0.1.10
  [5078a376] LazyArrays v0.22.11
  [d7e5e226] LazyBandedMatrices v0.7.17
  [2d8b4e74] LevyArea v1.0.0
  [d3d80556] LineSearches v7.1.1
  [7ed4a6bd] LinearSolve v1.23.3
  [2ab3a3ac] LogExpFunctions v0.3.17
  [bdcacae8] LoopVectorization v0.12.122
  [2fda8390] LsqFit v0.12.1
  [1914dd2f] MacroTools v0.5.9
  [d125e4d3] ManualMemory v0.1.8
  [b8f27783] MathOptInterface v1.7.0
  [fdba3010] MathProgBase v0.7.8
  [a3b82374] MatrixFactorizations v0.9.2
  [739be429] MbedTLS v1.1.3
  [442fdcdd] Measures v0.3.1
  [e9d8d322] Metatheory v1.3.4
  [128add7d] MicroCollections v0.1.2
  [e1d29d7a] Missings v1.0.2
  [961ee093] ModelingToolkit v8.19.0
  [46d2c3a1] MuladdMacro v0.2.2
  [102ac46a] MultivariatePolynomials v0.4.6
  [ffc61752] Mustache v1.0.14
  [d8a4904e] MutableArithmetics v1.0.4
  [d41bc354] NLSolversBase v7.8.2
  [76087f3c] NLopt v0.6.5
  [2774e3e8] NLsolve v4.5.1
  [872c559c] NNlib v0.8.9
  [77ba4419] NaNMath v0.3.7
  [8913a72c] NonlinearSolve v0.3.22
  [d8793406] ObjectFile v0.3.7
  [6fe1bfb0] OffsetArrays v1.12.7
  [429524aa] Optim v1.7.1
  [87e2bd06] OptimBase v2.0.2
  [bac558e1] OrderedCollections v1.4.1
  [1dea7af3] OrdinaryDiffEq v6.20.0
  [90014a1f] PDMats v0.11.16
  [65888b18] ParameterizedFunctions v5.13.2
  [d96e819e] Parameters v0.12.3
  [69de0a69] Parsers v2.3.2
  [06bb1623] PenaltyFunctions v0.3.0
  [ccf2f8ad] PlotThemes v3.0.0
  [995b91a9] PlotUtils v1.3.0
  [91a5bcdd] Plots v1.31.7
  [e409e4f3] PoissonRandom v0.4.1
  [f517fe37] Polyester v0.6.14
  [1d0040c9] PolyesterWeave v0.1.8
  [85a6dd25] PositiveFactorizations v0.2.4
  [d236fae5] PreallocationTools v0.4.2
  [21216c6a] Preferences v1.3.0
  [27ebfcd6] Primes v0.5.3
  [dae52e8d] QuadDIRECT v0.1.2 `https://github.com/timholy/QuadDIRECT.jl#master`
  [1fd47b50] QuadGK v2.4.2
  [74087812] Random123 v1.6.0
  [fb686558] RandomExtensions v0.4.3
  [e6cf234a] RandomNumbers v1.5.3
  [c1ae055f] RealDot v0.1.0
  [3cdcf5f2] RecipesBase v1.2.1
  [01d81517] RecipesPipeline v0.6.3
  [731186ca] RecursiveArrayTools v2.32.0
  [f2c3362d] RecursiveFactorization v0.2.11
  [189a3867] Reexport v1.2.2
  [42d2dcc6] Referenceables v0.1.2
  [05181044] RelocatableFolders v0.3.0
  [ae029012] Requires v1.3.0
  [ae5879a3] ResettableStacks v1.1.1
  [37e2e3b7] ReverseDiff v1.14.1
  [79098fc4] Rmath v0.7.0
  [7e49a35a] RuntimeGeneratedFunctions v0.5.3
  [3cdde19b] SIMDDualNumbers v0.1.1
  [94e857df] SIMDTypes v0.1.0
  [476501e8] SLEEFPirates v0.6.33
  [0bca4576] SciMLBase v1.49.2
  [31c91b34] SciMLBenchmarks v0.1.1
  [1ed8b502] SciMLSensitivity v7.4.0
  [6c6a2e73] Scratch v1.1.1
  [efcf1570] Setfield v0.8.2
  [992d4aef] Showoff v1.0.3
  [699a6c99] SimpleTraits v0.9.4
  [66db9d55] SnoopPrecompile v1.0.0
  [b85f4697] SoftGlobalScope v1.1.0
  [a2af1166] SortingAlgorithms v1.0.1
  [47a9eef4] SparseDiffTools v1.25.1
  [d4ead438] SpatialIndexing v0.1.3
  [276daf66] SpecialFunctions v2.1.7
  [171d559e] SplittablesBase v0.1.14
  [aedffcd0] Static v0.7.6
  [90137ffa] StaticArrays v1.5.5
  [1e83bf80] StaticArraysCore v1.1.0
  [82ae8749] StatsAPI v1.5.0
  [2913bbd2] StatsBase v0.33.21
  [4c63d2b9] StatsFuns v1.0.1
  [789caeaf] StochasticDiffEq v6.52.0
  [7792a7ef] StrideArraysCore v0.3.15
  [69024149] StringEncodings v0.3.5
  [09ab397b] StructArrays v0.6.12
  [53d494c1] StructIO v0.3.0
  [d1185830] SymbolicUtils v0.19.11
  [0c5d862f] Symbolics v4.10.4
  [3783bdb8] TableTraits v1.0.1
  [bd369af6] Tables v1.7.0
  [62fd8b95] TensorCore v0.1.1
  [8ea1fca8] TermInterface v0.2.3
  [8290d209] ThreadingUtilities v0.5.0
  [ac1d9e8a] ThreadsX v0.1.10
  [a759f4b9] TimerOutputs v0.5.21
  [0796e94c] Tokenize v0.5.24
  [9f7883ad] Tracker v0.2.20
  [3bb67fe8] TranscodingStreams v0.9.7
  [28d57a85] Transducers v0.4.73
  [a2a6695c] TreeViews v0.3.0
  [d5829a12] TriangularSolve v0.1.13
  [5c2747f8] URIs v1.4.0
  [3a884ed6] UnPack v1.0.2
  [1cfade01] UnicodeFun v0.4.1
  [1986cc42] Unitful v1.11.0
  [41fe7b60] Unzip v0.1.2
  [3d5dd08c] VectorizationBase v0.21.46
  [81def892] VersionParsing v1.3.0
  [19fa3120] VertexSafeGraphs v0.2.0
  [44d3d7a6] Weave v0.10.9
  [ddb6d928] YAML v0.4.7
  [c2297ded] ZMQ v1.2.1
  [e88e6eb3] Zygote v0.6.44
  [700de1a5] ZygoteRules v0.2.2
  [6e34b625] Bzip2_jll v1.0.8+0
  [83423d85] Cairo_jll v1.16.1+1
  [cd4c43a9] Dierckx_jll v0.1.0+0
  [5ae413db] EarCut_jll v2.2.3+0
  [7cc45869] Enzyme_jll v0.0.33+0
  [2e619515] Expat_jll v2.4.8+0
  [b22a6f82] FFMPEG_jll v4.4.2+0
  [a3f928ae] Fontconfig_jll v2.13.93+0
  [d7e528f0] FreeType2_jll v2.10.4+0
  [559328eb] FriBidi_jll v1.0.10+0
  [0656b61e] GLFW_jll v3.3.8+0
  [d2c73de3] GR_jll v0.66.2+0
  [78b55507] Gettext_jll v0.21.0+0
  [f8c6e375] Git_jll v2.34.1+0
  [7746bdde] Glib_jll v2.68.3+2
  [3b182d85] Graphite2_jll v1.3.14+0
  [2e76f6c2] HarfBuzz_jll v2.8.1+1
  [aacddb02] JpegTurbo_jll v2.1.2+0
  [c1c5ebd0] LAME_jll v3.100.1+0
  [88015f11] LERC_jll v3.0.0+1
  [dad2f222] LLVMExtra_jll v0.0.16+0
  [dd4b983a] LZO_jll v2.10.1+0
  [e9f186c6] Libffi_jll v3.2.2+1
  [d4300ac3] Libgcrypt_jll v1.8.7+0
  [7e76a0d4] Libglvnd_jll v1.3.0+3
  [7add5ba3] Libgpg_error_jll v1.42.0+0
  [94ce4f54] Libiconv_jll v1.16.1+1
  [4b2f31a3] Libmount_jll v2.35.0+0
  [89763e89] Libtiff_jll v4.4.0+0
  [38a345b3] Libuuid_jll v2.36.0+0
  [079eb43e] NLopt_jll v2.7.1+0
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
  [4af54fe1] LazyArtifacts
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
