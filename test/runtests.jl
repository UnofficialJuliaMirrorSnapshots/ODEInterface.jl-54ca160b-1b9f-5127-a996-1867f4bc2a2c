"""
  Module for testing ODEInterface
  """
module ODEInterfaceTest

using Test

using ODEInterface
@ODEInterface.import_huge

const dl_solvers = (DL_DOPRI5, DL_DOPRI5_I32, 
                    DL_DOP853, DL_DOP853_I32,
                    DL_ODEX, DL_ODEX_I32,
                    DL_RADAU5, DL_RADAU5_I32, DL_RADAU, DL_RADAU_I32,
                    DL_SEULEX, DL_SEULEX_I32, 
                    DL_RODAS, DL_RODAS_I32,
                    DL_BVPSOL, DL_BVPSOL_I32,
                    DL_DDEABM, DL_DDEABM_I32,
                    DL_DDEBDF, DL_DDEBDF_I32,
                    DL_BVPM2,
                    ) 
const solvers = (dopri5, dopri5_i32, 
                 dop853, dop853_i32,
                 odex, odex_i32, 
                 radau5, radau5_i32, radau, radau_i32,
                 seulex, seulex_i32, 
                 rodas, rodas_i32,
                 ddeabm, ddeabm_i32,
                 ddebdf, ddebdf_i32,
                )

const solvers_without_dense_output = (ddeabm, ddeabm_i32, ddebdf, ddebdf_i32)

const solvers_without_special_struct_support = (ddebdf, ddebdf_i32)

const solvers_mas = ( radau5, radau5_i32, radau, radau_i32,
                      seulex, seulex_i32, 
                      rodas, rodas_i32,
                    )

const solvers_jac = ( radau5, radau5_i32, radau, radau_i32,
                      seulex, seulex_i32, 
                      rodas, rodas_i32,
                      ddebdf, ddebdf_i32,
                    )

const solvers_rhsdt = ( rodas, rodas_i32
                      )

const solvers_bvpsol  = ( bvpsol, bvpsol_i32 
                       )

const solvers_colnew  = ( colnew, colnew_i32 
                       )

"""
  create a callable-type in order to check, if solvers
  can handle callable-types (which are not a subclass of
  Function) as right-hand sides.
  """
mutable struct Callable_Type
  param :: Float64
end

function (ct::Callable_Type)(t,x)
  return ct.param*x
end

function mylinspace(a, b, length::Integer)
  return collect(range(a, stop=b, length=length))
end

function test_ode1(solver::Function)
  opt = OptionsODE("ode1",
        OPT_RTOL => 1e-10,
        OPT_ATOL => 1e-10)
  t0 = 0; T = 1; x0=[1,2]; rhs = (t,x) -> x

  (t,x,retcode,stats) = solver(rhs, t0, T, x0, opt)
  @assert 1 == retcode
  @assert t == T
  @assert x0 == [1,2]
  @assert isapprox(x[1],exp(1),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[2],2*exp(1),rtol=1e-7,atol=1e-7)
  if haskey(stats,"step_predict")
    @assert isa(stats["step_predict"],Number)
  end
  return true
end

function test_ode2(solver::Function)
  dense_flag = !(solver in solvers_without_dense_output)
  x3 = NaN
  called_init = false
  called_done = false

  function outputfcn(reason,told,t,x,eval_sol_fcn,extra_data)
    if reason == OUTPUTFCN_CALL_INIT 
      called_init = true
      extra_data["test_ode2_data"] = 56
    end
    if reason == OUTPUTFCN_CALL_DONE 
      called_done = true
      @assert extra_data["test_ode2_data"] == 56
    end
    if reason == OUTPUTFCN_CALL_STEP
      if told ≤ 3.0 ≤ t
        if dense_flag
          x3 = eval_sol_fcn(3.0)[1]
        end
        return OUTPUTFCN_RET_STOP
      end
    end
    return OUTPUTFCN_RET_CONTINUE
  end
  opt = OptionsODE("ode2",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8,
        OPT_OUTPUTFCN => outputfcn,
        OPT_OUTPUTMODE => dense_flag ? OUTPUTFCN_DENSE : OUTPUTFCN_WODENSE,
        )
  t0 = 0; T = 5000; x0=[1,2]; rhs = (t,x) -> x
  (t,x,retcode,stats) = solver(rhs, t0, T, x0, opt)
  @assert called_init && called_done
  @assert 2 == retcode
  @assert t < T
  if dense_flag
    @assert isapprox(x3,exp(3),rtol=1e-7,atol=1e-7)
  end
  return true
end

function test_ode3(solver::Function)
  opt = OptionsODE("ode3",
        OPT_RTOL => 1e-10,
        OPT_ATOL => 1e-10,
        OPT_RHS_CALLMODE => RHS_CALL_INSITU,
        )
  function rhs(t,x,dx)
    dx[1]=x[1]; dx[2]=x[2];
    return nothing
  end
  t0 = 0; T = 1; x0=[1,2]; 

  (t,x,retcode,stats) = solver(rhs, t0, T, x0, opt)
  @assert 1 == retcode
  @assert t == T
  @assert x0 == [1,2]
  @assert isapprox(x[1],exp(1),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[2],2*exp(1),rtol=1e-7,atol=1e-7)
  return true
end

function test_ode4(solver::Function)
  opt = OptionsODE("ode1",
        OPT_RTOL => 1e-10,
        OPT_ATOL => 1e-10)
  t0 = 0; T = 1; x0=[1,2]; 
  rhs = Callable_Type(1.0)

  (t,x,retcode,stats) = solver(rhs, t0, T, x0, opt)
  @assert 1 == retcode
  @assert t == T
  @assert x0 == [1,2]
  @assert isapprox(x[1],exp(1),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[2],2*exp(1),rtol=1e-7,atol=1e-7)
  if haskey(stats,"step_predict")
    @assert isa(stats["step_predict"],Number)
  end
  return true
end

function test_massode1(solver::Function)
  mas = [ 2.0 1.0; 1.0 2.0]
  x1_exact = t -> 1.5*exp(t/3)-0.5*exp(t)
  x2_exact = t -> 1.5*exp(t/3)+0.5*exp(t)
  opt = OptionsODE("massode1",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8,
        OPT_MASSMATRIX => mas,
        )
  t0 = 0; T = 1; x0=[1,2]; rhs = (t,x) -> x
  (t,x,retcode,stats) = solver(rhs, t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[1],x1_exact(T),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[2],x2_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_massode2(solver::Function)
  mas = BandedMatrix(5,5, 1,1, 0.0)
  setdiagonal!(mas,0,2); setdiagonal!(mas,1,1); setdiagonal!(mas,-1,1)

  x1_exact = t -> 0.5*(-3*exp(t/3)+2*exp(t/2)-exp(t)+
                        (2+sqrt(3))*exp((2-sqrt(3))*t)-
                        (sqrt(3)-2)*exp((2+sqrt(3))*t) )
  x3_exact = t -> -exp(t/2)+(2+sqrt(3))*exp((2-sqrt(3))*t) - 
                  (sqrt(3)-2)*exp((2+sqrt(3))*t)

  opt = OptionsODE("massode2",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8,
        OPT_MASSMATRIX => mas,
        )
  t0 = 0; T = 1; x0=[1,2,3,4,5]; rhs = (t,x) -> x

  (t,x,retcode,stats) = solver(rhs, t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[1],x1_exact(T),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[3],x3_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_massode3(solver::Function)
  mas = [2 1 ; 1 2 ]

  x5_exact = t -> -0.5*exp(t/3)*(exp(2*t/3)-11)
  x6_exact = t ->  0.5*exp(t/3)*(exp(2*t/3)+11)

  opt = OptionsODE("massode3",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8,
        OPT_M1       => 4,
        OPT_M2       => 2,
        OPT_MASSMATRIX => mas,
        )
  t0 = 0; T = 1; x0=[1,2,3,4,5,6]; 
  rhs = (t,x) -> [ x[5],x[6] ]

  (t,x,retcode,stats) = solver(rhs, t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[5],x5_exact(T),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[6],x6_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_massode4(solver::Function)
  mas = BandedMatrix(3,3, 1,1, 0.0)
  setdiagonal!(mas,0,2); setdiagonal!(mas,1,1); setdiagonal!(mas,-1,1)

  x4_exact = t -> 4*exp(t)*(cosh(t/sqrt(2))-sqrt(2)*sinh(t/sqrt(2)))

  opt = OptionsODE("massode4",
        OPT_RTOL => 1e-10,
        OPT_ATOL => 1e-10,
        OPT_M1       => 2,
        OPT_M2       => 2,
        OPT_MASSMATRIX => mas,
        )
  t0 = 0; T = 1; x0=[1,2,3,4,5]; 
  rhs = (t,x) -> [ x[3],x[4],x[5] ]

  (t,x,retcode,stats) = solver(rhs, t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[4],x4_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_jacode1(solver::Function)
  x1_exact = t -> exp(2*t)/(2-exp(2*t))
  x2_exact = t -> 2*sqrt(1.0/(2-exp(2*t)))
  
  function myjac(t,x,J)
    @assert isa(J,Array{Float64})
    J[1,1] = x[2]^2
    J[1,2] = 2*x[1]*x[2]
    J[2,1] = x[2]
    J[2,2] = x[1]
  end

  opt = OptionsODE("odejac1",
        OPT_RTOL => 1e-10,
        OPT_ATOL => 1e-10,
        OPT_JACOBIMATRIX => myjac,
        )
  t0 = 0; T = 0.2; x0=[1,2]; 
  (t,x,retcode,stats) = solver( (t,x)-> [x[1]*(x[2])^2,x[1]*x[2]], 
                              t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[1],x1_exact(T),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[2],x2_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_jacode2(solver::Function)
  function myrhs(t,x)
    return [ x[1], x[1]+x[2], x[2]+x[3], x[3]+x[4] ]
  end
  
  function myjac(t,x,J)
    @assert isa(J,BandedMatrix{Float64})
    setdiagonal!(J,0,1.0)
    setdiagonal!(J,-1,1.0)
  end

  x1_exact = t -> exp(t)
  x2_exact = t -> (2+t)*exp(t)
  x4_exact = t -> exp(t)/6*(24+18*t+6*t^2+t^3)

  opt = OptionsODE("odejac2",
        OPT_RTOL => 1e-10,
        OPT_ATOL => 1e-10,
        OPT_JACOBIMATRIX => myjac,
        OPT_JACOBIBANDSTRUCT => (1,0),
        OPT_JACRECOMPFACTOR => -1,
        )
  t0 = 0; T = 1; x0=[1,2,3,4]; 

  (t,x,retcode,stats) = solver(myrhs, t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[1],x1_exact(T),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[2],x2_exact(T),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[4],x4_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_jacode3(solver::Function)
  if solver ∈ solvers_without_special_struct_support
    return true
  end
  function myrhs(t,x)
    return [ # x[3], x[4],
             x[1]+x[2]+x[4],
             x[1]+x[2]+x[3] ]
  end
  
  function myjac(t,x,J)
    @assert isa(J,Array{Float64})
    @assert (2,4)==size(J)
    J[1,1] = 1; J[1,2] = 1; J[1,3]=0; J[1,4]=1;
    J[2,1] = 1; J[2,2] = 1; J[2,3]=1; J[2,4]=0;
  end
  
  x1_exact = t -> exp(-t)/3*(1-3*exp(t)+5*exp(3*t))
  x4_exact = t -> 2*exp(-t)/3*(1+5*exp(3*t))

  opt = OptionsODE("odejac3",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8,
        OPT_M1 => 2,
        OPT_M2 => 2,
        OPT_JACOBIMATRIX => myjac,
        OPT_JACOBIBANDSTRUCT => nothing,
        OPT_JACRECOMPFACTOR => -1,
        )
  t0 = 0; T = 1; x0=[1,2,3,4]; 

  (t,x,retcode,stats) = solver(myrhs, t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[1],x1_exact(T),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[4],x4_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_jacode4(solver::Function)
  if solver ∈ solvers_without_special_struct_support
    return true
  end
  function myrhs(t,x)
    return [ # x[3], x[4],
             2*x[1] + 2*x[3],
               x[2] +   x[4] ]
  end

  function myjac(t,x,J1,J2)
    @assert isa(J1,BandedMatrix{Float64}) && isa(J2,BandedMatrix{Float64})
    @assert (2,2)==size(J1) && (2,2)==size(J2)
    setdiagonal!(J1,0,[2,1])
    setdiagonal!(J2,0,[2,2])
  end

  hp = 1+sqrt(3); hm = 1-sqrt(3)

  x3_exact = t -> (-5*exp(hm*t)+3*sqrt(3)*exp(hm*t)+ 
                    5*exp(hp*t)+3*sqrt(3)*exp(hp*t) )/(2*sqrt(3))

  opt = OptionsODE("odejac3",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8,
        OPT_M1 => 2,
        OPT_M2 => 2,
        OPT_JACOBIMATRIX => myjac,
        OPT_JACOBIBANDSTRUCT => (0,0,),
        OPT_JACRECOMPFACTOR => -1,
        )
  t0 = 0; T = 1; x0=[1,2,3,4]; 

  (t,x,retcode,stats) = solver(myrhs, t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[3],x3_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_rhstimederiv1(solver::Function)
  myrhs = (t,x) -> [ t*x[2], 4*t*x[1] ]

  function myjac(t,x,J)
    @assert isa(J,Array{Float64})
    @assert (2,2)==size(J)
    J[1,1] = 0; J[1,2] = t;
    J[2,1] = 4*t; J[2,2] = 0;
    return nothing
  end

  function myrhstimederiv(t,x,drhsdt)
    @assert isa(drhsdt,Array{Float64})
    @assert (2,)==size(drhsdt)
    drhsdt[1] = x[2]
    drhsdt[2] = 4*x[1]
    return nothing
  end

  x1_exact = t -> cosh(t*t) + 0.5*sinh(t*t)
  x2_exact = t -> cosh(t*t) + 2.0*sinh(t*t)

  opt = OptionsODE("odetimederiv1",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8,
        OPT_JACOBIMATRIX => myjac,
        OPT_RHSTIMEDERIV => myrhstimederiv,
        )
  t0 = 0; T = 1; x0=[1.0,1]

  (t,x,retcode,stats) = solver(myrhs, t0, T, x0, opt)
  @assert 1==retcode
  @assert isapprox(x[1],x1_exact(T),rtol=1e-7,atol=1e-7)
  @assert isapprox(x[2],x2_exact(T),rtol=1e-7,atol=1e-7)
  return true
end

function test_odecall1(solver::Function)
  opt = OptionsODE("odecall1",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8)
  t = mylinspace(0,1,10)
  x0=[1,2]; rhs = (t,x) -> x
  (tVec,xVec,retcode,stats) = odecall(solver,rhs,t,x0,opt)
  @assert 1 == retcode
  @assert t == tVec
  return true
end

function test_odecall2(solver::Function)
  opt = OptionsODE("odecall2",
        OPT_RTOL => 1e-8,
        OPT_ATOL => 1e-8)
  t = [0,1]
  x0=[1,2]; rhs = (t,x) -> x
  (tVec,xVec,retcode,stats) = odecall(solver,rhs,t,x0,opt)
  @assert 1 == retcode
  @assert length(tVec)>2
  return true
end

function test_bvp1(solver::Function)
  ivpopt = OptionsODE("ivpoptions",
                   OPT_RHS_CALLMODE => RHS_CALL_INSITU)
                 
  opt = OptionsODE("bvp1",
                   OPT_RHS_CALLMODE => RHS_CALL_INSITU,
                   OPT_MAXSTEPS     => 10,
                   OPT_RTOL         => 1e-6,
                   OPT_BVPCLASS     => 0,
                   OPT_SOLMETHOD    => 0,
                   OPT_IVPOPT       => ivpopt)

  tNodes = [0,5]
  xInit = [ 5.0  0.45938665265299; 1  1];
  odesolver = nothing

  function f(t,x,dx)
    dx[1] =  x[2]
    dx[2] = -x[1]
    return nothing
  end

  function bc(xa,xb,r)
    r[1] = xa[1] - 5
    r[2] = xb[1] - 0.45938665265299
    return nothing
  end

  (t,x,code,stats) = solver(f,bc,tNodes,xInit,odesolver,opt)
  @assert tNodes == [0,5]
  @assert code>0
  @assert t == tNodes
  @assert isapprox(x[1,1],5.0,rtol=1e-4,atol=1e-4)
  @assert isapprox(x[2,1],1.0,rtol=1e-4,atol=1e-4)
  @assert isapprox(x[1,2],0.459387,rtol=1e-4,atol=1e-4)
  @assert isapprox(x[2,2],5.07828,rtol=1e-4,atol=1e-4)
  
  return true
end

function test_bvp2(solver::Function)
  ivpopt = OptionsODE("ivpoptions",
                   OPT_RHS_CALLMODE => RHS_CALL_INSITU)
                 
  opt = OptionsODE("bvp2",
                   OPT_RHS_CALLMODE => RHS_CALL_INSITU,
                   OPT_MAXSTEPS     => 10,
                   OPT_RTOL         => 1e-6,
                   OPT_BVPCLASS     => 0,
                   OPT_SOLMETHOD    => 0,
                   OPT_IVPOPT       => ivpopt)

  tNodes = [0,5]
  xInit = [ 5.0  0.45938665265299; 1  1];
  odesolver = dop853

  function f(t,x,dx)
    dx[1] =  x[2]
    dx[2] = -x[1]
    return nothing
  end

  function bc(xa,xb,r)
    r[1] = xa[1] - 5
    r[2] = xb[1] - 0.45938665265299
    return nothing
  end

  (t,x,code,stats) = solver(f,bc,tNodes,xInit,odesolver,opt)
  @assert tNodes == [0,5]
  @assert code>0
  @assert t == tNodes
  @assert isapprox(x[1,1],5.0,rtol=1e-4,atol=1e-4)
  @assert isapprox(x[2,1],1.0,rtol=1e-4,atol=1e-4)
  @assert isapprox(x[1,2],0.459387,rtol=1e-4,atol=1e-4)
  @assert isapprox(x[2,2],5.07828,rtol=1e-4,atol=1e-4)
  
  return true
end

function test_bvp3(solver::Function)
  ivpopt = OptionsODE("ivpoptions",
                   OPT_RHS_CALLMODE => RHS_CALL_INSITU)
                 
  opt = OptionsODE("bvp3",
                 OPT_RHS_CALLMODE => RHS_CALL_INSITU,
                 OPT_MAXSTEPS     => 100,
                 OPT_RTOL         => 1e-6,
                 OPT_BVPCLASS     => 2,
                 OPT_SOLMETHOD    => 1,
                 OPT_IVPOPT       => ivpopt)

  tNodes = mylinspace(0,5,11)
  xInit = [ones(1,length(tNodes)-1) 0 ; ones(1,length(tNodes)) ]
  odesolver = dop853

  function f(t,x,dx)
    dx[1] = t*x[2]
    dx[2] = 4*max(0,x[1])^1.5
    return nothing
  end

  function bc(xa,xb,r)
    r[1] = xa[1] - 1
    r[2] = xb[1] - 0
    return nothing
  end

  (t,x,code,stats) = solver(f,bc,tNodes,xInit,odesolver,opt)
  @assert code>0
  @assert isapprox(x[1,1],1,rtol=1e-4,atol=1e-4)
  @assert isapprox(x[2,1],-3.17614,rtol=1e-4,atol=1e-4)
  @assert isapprox(x[1,2],0.755201,rtol=1e-4,atol=1e-4)
  
  return true
end

function test_colnew1(solver::Function)
  a, b = -pi/2, pi/2
  orders = [1, 1,]
  ζ = [a, b]

  ε = nothing 
  ε_old = nothing
  sol_old = nothing

  function rhs(x, z, f)
      s² = sin(x)^2
      f[1] = (s²-z[2]*s²*s²/z[1])/ε
      f[2] = 0.0
  end
  
  function Drhs(x, z, df)
      df[:] .= 0.0
      s⁴ = sin(x)^4
      df[1,1] = z[2]*s⁴/(z[1]^2)
      df[1,2] = -s⁴/z[1]
  end
  
  function bc(i, z, bc)
      bc[1] = z[1]-1.0
  end
  
  function Dbc(i, z, dbc)
      dbc[1] = 1.0
      dbc[2] = 0.0
  end
  
  function initial_guess(x, z, dmz)
      z[1] = 0.5
      z[2] = 1.0
      rhs(x, z, dmz)
  end

  opt = OptionsODE("colnew1",
        OPT_BVPCLASS => 2, OPT_COLLOCATIONPTS => 7,
        OPT_RTOL => [1e-4, 1e-4], OPT_MAXSUBINTERVALS => 200)

  sol = nothing
  for ε_new = [1.0, 0.5, 0.2, 0.1]
    ε = ε_new
    guess = sol_old !== nothing ? sol_old : initial_guess    
    sol, retcode, stats = colnew([a,b], orders, ζ, rhs, Drhs, bc, Dbc, 
       guess ,opt);
    @assert retcode>0
    sol_old = sol; ε_old = ε
  end
  
  z₀ = evalSolution(sol, 0.0)
  @assert isapprox(z₀[1], 0.161671, rtol=1e-3,atol=1e-3)
  @assert isapprox(z₀[2], 1.01863, rtol=1e-3,atol=1e-3)
  return true
end

function test_bvpm2_1()
  ε = 0.1
  a, b = -pi/2.0, pi/2.0

  function rhs(x, y, p, f)
    @assert length(y) == length(f) == 1
    @assert length(p) == 1
    f[1] = ( sin(x)^2 - p[1]*sin(x)^4/y[1] ) / ε
  end
  
  function Drhs(x, y, p, dfdy, dfdp)
    @assert length(y) == 1
    @assert length(p) == 1
    @assert size(dfdy) == (1,1)
    @assert size(dfdp) == (1,1)
  
    dfdy[1,1] = ( p[1]*sin(x)^4/y[1]^2 ) / ε
    dfdp[1,1] = ( -sin(x)^4/y[1] ) / ε
  end
  
  function bc(ya, yb, p, bca, bcb)
    @assert length(ya) == length(yb) == 1
    @assert length(bca) == length(bcb) == 1
    @assert length(p) == 1
    bca[1] = ya[1] - 1.0
    bcb[1] = yb[1] - 1.0
  end
  
  function Dbc(ya, yb, dya, dyb, p, dpa, dpb)
    @assert length(ya) == length(yb) == 1
    @assert size(dya) == size(dyb) == (1,1)
    @assert length(p) == 1
    @assert size(dpa) == size(dpb) == (1,1)
    dya[1,1] = 1.0
    dyb[1,1] = 1.0
    dpa[1,1] = 0.0
    dpb[1,1] = 0.0
  end

  opt = OptionsODE("test_bvpm2_1",
          OPT_RTOL => 1e-6,
          OPT_METHODCHOICE => 4,)
  guess_obj = Bvpm2()
  bvpm2_init(guess_obj, 1, 1, mylinspace(a, b, 20), [0.5,], [1.0,])
  retcode = Vector{Int64}(undef, 4)
  sol = Vector{ODEInterface.Bvpm2}(undef, 4)
  stat = Vector{Dict}(undef, 4)
  z = Vector{Matrix}(undef, 4)

  (sol[1], retcode[1], stat[1]) = bvpm2_solve(guess_obj, rhs, bc, opt)
  (sol[2], retcode[2], stat[2]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                              Drhs=Drhs)
  (sol[3], retcode[3], stat[3]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                              Dbc=Dbc)
  (sol[4], retcode[4], stat[4]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                               Drhs=Drhs, Dbc=Dbc)
  for k=1:length(retcode)
    @assert retcode[k] == 0
    @assert stat[k]["no_rhs_calls"] > 0
    @assert stat[k]["no_bc_calls"] > 0
    z[k] = evalSolution(sol[k], mylinspace(a, b, 5))
  end
  @assert stat[1]["no_jac_calls"] == stat[3]["no_jac_calls"] == 0
  @assert stat[1]["no_Dbc_calls"] == stat[2]["no_Dbc_calls"] == 0
  @assert stat[2]["no_jac_calls"] > 0
  @assert stat[4]["no_jac_calls"] > 0
  @assert stat[1]["no_rhs_calls"] > stat[2]["no_rhs_calls"]
  @assert stat[1]["no_rhs_calls"] > stat[4]["no_rhs_calls"]

  for k=1:length(retcode)-1
    @assert isapprox(z[k], z[k+1], rtol=1e-4, atol=1e-4)
  end

  bvpm2_destroy(guess_obj)
  for k=1:length(retcode)
    bvpm2_destroy(sol[k])
  end
  return true
end

function test_bvpm2_2()
  exact_sol = x -> [ 1/sqrt(1+x^2/3), -9/(9+3*x^2)^1.5*x ]
  a,b = 0.0, 1.0

  function rhs(x, y, f)
    @assert length(y) == length(f) == 2
    f[1] = y[2]
    f[2] = -y[1]^5
  end

  function Drhs(x, y, dfdy)
    @assert length(y) == 2
    @assert size(dfdy) == (2,2)
    dfdy[:] .= 0
    dfdy[1,2] = 1.0
    dfdy[2,1] = -5*y[1]^4
  end

  function bc(ya, yb, bca, bcb)
    @assert length(ya) == length(yb) == 2
    @assert length(bca) == length(bcb) == 1
    bca[1] = ya[2]
    bcb[1] = yb[1] - sqrt(0.75)
  end

  function Dbc(ya, yb, dya, dyb)
    @assert length(ya) == length(yb) == 2
    @assert size(dya) == (1,2)
    @assert size(dyb) == (1,2)
    dya[:] .= 0
    dya[1,2] = 1.0
    dyb[:] .= 0
    dyb[1,1] = 1.0
  end

  opt = OptionsODE("test_bvpm2_2",
          OPT_RTOL => 1e-6,
          OPT_METHODCHOICE => 6,
          OPT_SINGULARTERM => [ 0 0 ; 0 -2 ],
          )

  guess_obj = Bvpm2()
  bvpm2_init(guess_obj, 2, 1, mylinspace(a, b, 10), [sqrt(0.75), 1e-4])
  retcode = Vector{Int64}(undef, 4)
  sol = Vector{ODEInterface.Bvpm2}(undef, 4)
  stat = Vector{Dict}(undef, 4)
  z = Vector{Matrix}(undef, 4)

  (sol[1], retcode[1], stat[1]) = bvpm2_solve(guess_obj, rhs, bc, opt)
  (sol[2], retcode[2], stat[2]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                              Drhs=Drhs)
  (sol[3], retcode[3], stat[3]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                              Dbc=Dbc)
  (sol[4], retcode[4], stat[4]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                               Drhs=Drhs, Dbc=Dbc)
  xx = mylinspace(a, b, 5)
  for k=1:length(retcode)
    @assert retcode[k] == 0
    @assert stat[k]["no_rhs_calls"] > 0
    @assert stat[k]["no_bc_calls"] > 0
    z[k] = evalSolution(sol[k], xx)
  end
  @assert stat[1]["no_jac_calls"] == stat[3]["no_jac_calls"] == 0
  @assert stat[1]["no_Dbc_calls"] == stat[2]["no_Dbc_calls"] == 0
  @assert stat[2]["no_jac_calls"] > 0
  @assert stat[4]["no_jac_calls"] > 0
  @assert stat[1]["no_rhs_calls"] > stat[2]["no_rhs_calls"]
  @assert stat[1]["no_rhs_calls"] > stat[4]["no_rhs_calls"]

  for k=1:length(retcode)
    for j=1:length(xx)
      @assert isapprox(z[k][:,j], exact_sol(xx[j]), rtol=1e-4, atol=1e-4)
    end
  end

  bvpm2_destroy(guess_obj)
  for k=1:length(retcode)
    bvpm2_destroy(sol[k])
  end
  return true
end

function test_bvpm2_3()
  exact_sol = x -> [ exp(x), exp(x) ]
  a,b = 0.0, 1.0

  function rhs(x, y, f)
    @assert length(y) == length(f) == 2
    f[1] = y[2]
    f[2] = y[1]
  end
  
  function Drhs(x, y, dfdy)
    @assert length(y) == 2
    @assert size(dfdy) == (2,2)
    dfdy[:] .= 0
    dfdy[1,2] = 1.0
    dfdy[2,1] = 1.0
  end
  
  function bc(ya, yb, bca, bcb)
    @assert length(ya) == length(yb) == 2
    @assert length(bca) == length(bcb) == 1
    bca[1] = ya[1] - 1.0
    bcb[1] = yb[1] - exp(1)
  end
  
  function Dbc(ya, yb, dya, dyb)
    @assert length(ya) == length(yb) == 2
    @assert size(dya) == (1,2)
    @assert size(dyb) == (1,2)
    dya[:] .= 0
    dya[1,1] = 1.0
    dyb[:] .= 0
    dyb[1,1] = 1.0
  end
  
  function guess(x, y)
    @assert length(y) == 2
    y[1] = 1+x
    y[2] = 1.0
  end

  opt = OptionsODE("test_bvpm2_3",
          OPT_RTOL => 1e-6 )

  guess_obj = Bvpm2()
  bvpm2_init(guess_obj, 2, 1, mylinspace(a, b, 3), guess)
  retcode = Vector{Int64}(undef, 4)
  sol = Vector{ODEInterface.Bvpm2}(undef, 4)
  stat = Vector{Dict}(undef, 4)
  z = Vector{Matrix}(undef, 4)

  (sol[1], retcode[1], stat[1]) = bvpm2_solve(guess_obj, rhs, bc, opt)
  (sol[2], retcode[2], stat[2]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                              Drhs=Drhs)
  (sol[3], retcode[3], stat[3]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                              Dbc=Dbc)
  (sol[4], retcode[4], stat[4]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                               Drhs=Drhs, Dbc=Dbc)
  xx = mylinspace(a, b, 5)
  for k=1:length(retcode)
    @assert retcode[k] == 0
    @assert stat[k]["no_rhs_calls"] > 0
    @assert stat[k]["no_bc_calls"] > 0
    z[k] = evalSolution(sol[k], xx)
  end
  @assert stat[1]["no_jac_calls"] == stat[3]["no_jac_calls"] == 0
  @assert stat[1]["no_Dbc_calls"] == stat[2]["no_Dbc_calls"] == 0
  @assert stat[2]["no_jac_calls"] > 0
  @assert stat[4]["no_jac_calls"] > 0
  @assert stat[1]["no_rhs_calls"] > stat[2]["no_rhs_calls"]
  @assert stat[1]["no_rhs_calls"] > stat[4]["no_rhs_calls"]

  for k=1:length(retcode)
    for j=1:length(xx)
      @assert isapprox(z[k][:,j], exact_sol(xx[j]), rtol=1e-4, atol=1e-4)
    end
  end

  bvpm2_destroy(guess_obj)
  for k=1:length(retcode)
    bvpm2_destroy(sol[k])
  end
  return true
end

function test_bvpm2_4()
  exact_sol = x -> [ exp(x), exp(x) ]
  a,b = 0.0, 1.0

  function rhs(x, y, p, f)
    @assert length(y) == length(f) == 2
    @assert length(p) == 1
    f[1] = y[2]
    f[2] = y[1]*p[1]
  end
  
  function Drhs(x, y, p, dfdy, dfdp)
    @assert length(y) == 2
    @assert length(p) == 1
    @assert size(dfdy) == (2,2)
    @assert size(dfdp) == (2,1)
    dfdy[:] .= 0
    dfdy[1,2] = 1.0
    dfdy[2,1] = p[1]
  
    dfdp[:] .= 0
    dfdp[2,1] = y[1]
  end
  
  function bc(ya, yb, p, bca, bcb)
    @assert length(ya) == length(yb) == 2
    @assert length(bca) == 2
    @assert length(bcb) == 1
    @assert length(p) == 1
    bca[1] = ya[1] - 1.0
    bca[2] = ya[2] - 1.0
    bcb[1] = yb[1] - exp(1)
  end
  
  function Dbc(ya, yb, dya, dyb, p, dpa, dpb)
    @assert length(ya) == length(yb) == 2
    @assert length(p) == 1
    @assert size(dya) == (2,2)
    @assert size(dyb) == (1,2)
    @assert size(dpa) == (2,1)
    @assert size(dpb) == (1,1)
    dya[:] .= 0
    dya[1,1] = 1.0
    dya[2,2] = 1.0
    dyb[:] .= 0
    dyb[1,1] = 1.0
    dpa[:] .= 0
  end
  
  function guess(x, y)
    y[1] = 1+x
    y[2] = 1.0
  end
  
  opt = OptionsODE("test_bvpm2_4",
          OPT_RTOL => 1e-6 )

  guess_obj = Bvpm2()
  bvpm2_init(guess_obj, 2, 2, mylinspace(a, b, 3), guess, [0.9,])
  retcode = Vector{Int64}(undef, 4)
  sol = Vector{ODEInterface.Bvpm2}(undef, 4)
  stat = Vector{Dict}(undef, 4)
  z = Vector{Matrix}(undef, 4)

  (sol[1], retcode[1], stat[1]) = bvpm2_solve(guess_obj, rhs, bc, opt)
  (sol[2], retcode[2], stat[2]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                              Drhs=Drhs)
  (sol[3], retcode[3], stat[3]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                              Dbc=Dbc)
  (sol[4], retcode[4], stat[4]) = bvpm2_solve(guess_obj, rhs, bc, opt, 
                                               Drhs=Drhs, Dbc=Dbc)
  xx = mylinspace(a, b, 5)
  for k=1:length(retcode)
    @assert retcode[k] == 0
    @assert stat[k]["no_rhs_calls"] > 0
    @assert stat[k]["no_bc_calls"] > 0
    z[k] = evalSolution(sol[k], xx)
  end
  @assert stat[1]["no_jac_calls"] == stat[3]["no_jac_calls"] == 0
  @assert stat[1]["no_Dbc_calls"] == stat[2]["no_Dbc_calls"] == 0
  @assert stat[2]["no_jac_calls"] > 0
  @assert stat[4]["no_jac_calls"] > 0
  @assert stat[1]["no_rhs_calls"] > stat[2]["no_rhs_calls"]
  @assert stat[1]["no_rhs_calls"] > stat[4]["no_rhs_calls"]

  for k=1:length(retcode)
    for j=1:length(xx)
      @assert isapprox(z[k][:,j], exact_sol(xx[j]), rtol=1e-4, atol=1e-4)
    end
    @assert isapprox(bvpm2_get_params(sol[k]),[1.0,], rtol=1e-4, atol=1e-4)
  end

  bvpm2_destroy(guess_obj)
  for k=1:length(retcode)
    bvpm2_destroy(sol[k])
  end
  return true
end

function test_Banded()
  @testset "Banded" begin
    @test_throws ArgumentErrorODE  BandedMatrix{Float64}(
                                   5,4,1,2,zeros(Float64,(4,5)))
    @test_throws ArgumentErrorODE  BandedMatrix{Float64}(
                                   5,4,1,2,zeros(Float64,(5,4)))
    @test_throws ArgumentErrorODE  BandedMatrix{Float64}(
                                   5,4,5,1,zeros(Float64,(7,5)))
    
    bm = BandedMatrix(5,4, 1,2, NaN)
    @test   (bm[1,1] = 1.0) == 1.0
    @test   (bm[2,1] = 2  ) == 2.0
    @test   (bm[2,4] = 7  ) == 7.0
    @test   (bm[3,2] = 8  ) == 8.0
    @test_throws BoundsError  bm[1,4] = 1.1
    @test_throws BoundsError  bm[3,1] = 1.1
    @test_throws BoundsError  bm[4,1] = 1.1
    @test_throws BoundsError  bm[4,2] = 1.1
    @test_throws BoundsError  bm[5,3] = 1.1
 
    bm = BandedMatrix(5,4, 1,2, NaN)
    @test (bm[1:2,1]=[1,5]) == [1,5]
    @test (bm[1:3,2]=[4,2,4]) == [4,2,4]
    @test (bm[1:4,3]=[2,3,3,3]) == [2,3,3,3]
    @test (bm[2:5,4]=[1,0,4,2]) == [1,0,4,2]
    @test full(bm) == [1 4 2 0; 5 2 3 1; 0 4 3 0; 0 0 3 4; 0 0 0 2]
    bm_test = createBandedMatrix(
       [1.0 4 2 0; 5.0 2 3 1; 0 4.0 3 0; 0 0 3 4.0; 0 0 0 2.0]) 
    @test bm_test == bm

    bm = BandedMatrix(5,4, 1,2, NaN)
    @test setdiagonal!(bm,2,[2,1]) == [2,1]
    @test setdiagonal!(bm,1,[4,3,0]) == [4,3,0]
    @test setdiagonal!(bm,0,[1,2,3,4]) == [1,2,3,4]
    @test setdiagonal!(bm,-1,[5,4,3,2]) == [5,4,3,2]
    @test full(bm) == [1 4 2 0; 5 2 3 1; 0 4 3 0; 0 0 3 4; 0 0 0 2]

    bm = BandedMatrix(5,4, 1,2, NaN)
    diagonals = Any[ [2 1], [4 3 0], [1,2,3,4], [5 4 3 2]  ]
    @test setdiagonals!(bm,diagonals) == diagonals
    @test full(bm) == [1 4 2 0; 5 2 3 1; 0 4 3 0; 0 0 3 4; 0 0 0 2]
    
    bm2 = BandedMatrix(5,4, 1,2, NaN)
    setdiagonals!(bm2,bm)
    @test bm ≢ bm2
    @test bm == bm2
  end
end

function test_Options()
  @testset "Options" begin
    opt1 = OptionsODE("test1");
    @test isa(opt1, OptionsODE)
    @test isa(opt1, ODEInterface.AbstractOptionsODE)
    @test setOption!(opt1,"test_key",56) === nothing
    @test setOption!(opt1,"test_key",82) == 56
    @test getOption(opt1,"test_key",0) == 82
    @test getOption(opt1,"nokey",nothing) === nothing
    @test getOption(opt1,"nokey","none") == "none"
    @test setOptions!(opt1, "test_key" => 100, "new_key" => "bla") ==
          [82,nothing]

    opt2 = OptionsODE("test2",opt1)
    @test getOption(opt1,"test_key",0) == 100
  end
end

function test_DLSolvers()
  @testset "DLSolvers" begin
    result = loadODESolvers()
    @testset for dl in dl_solvers
      @test result[dl].error === nothing
      @test result[dl].libhandle ≠ C_NULL
    end
    
    @testset for dl in dl_solvers 
      @testset for method in result[dl].methods
        @test method.error === nothing
        @test method.method_ptr ≠ C_NULL
        @test method.generic_name ≠ ""
        @test method.methodname_found ≠ ""
      end
    end
  end
end

function test_vanilla()
  problems = (test_ode1,test_ode2,test_ode3,test_ode4)
  @testset "solvers" begin
    @testset for solver in solvers,
                  problem in problems
      @test problem(solver)
    end
  end
end

function test_mas_solvers()
  problems = (test_massode1,test_massode2,test_massode3,test_massode4)
  @testset "mas-solvers" begin
    @testset for solver in solvers_mas,
                  problem in problems
      @test problem(solver)
    end
  end
end

function test_jac_solvers()
  problems = (test_jacode1,test_jacode2,test_jacode3,test_jacode4)
  @testset "jac-solvers" begin
    @testset for solver in solvers_jac,
                  problem in problems
      @test problem(solver)
    end
  end
end

function test_rhsdt_solvers()
  problems = (test_rhstimederiv1,)
  @testset "rhs_dt-sol." begin
    @testset for solver in solvers_rhsdt,
                  problem in problems
      @test problem(solver)
    end
  end
end

function test_solvers()
  test_vanilla()
  test_mas_solvers()
  test_jac_solvers()
  test_rhsdt_solvers()
end

function test_odecall()
  problems = (test_odecall1,test_odecall2,)
  @testset "odecall" begin
    @testset for solver in solvers,
                  problem in problems
      @test problem(solver)
    end
  end
end

function test_bvp()
  problems = (test_bvp1,test_bvp2,test_bvp3,)
  @testset "bvpsol" begin
    @testset for solver in solvers_bvpsol,
                  problem in problems
      @test problem(solver)
    end
  end
end

function test_colnew()
  problems = (test_colnew1, )
  @testset "colnew" begin
    @testset for solver in solvers_colnew,
                  problem in problems
      @test problem(solver)
    end
  end
end

function test_bvpm2()
  problems = (test_bvpm2_1, test_bvpm2_2, test_bvpm2_3, test_bvpm2_4, )
  @testset "bvpm2" begin
    @testset for problem in problems
      @test problem()
    end
  end
end

function test_all()
  test_Banded()
  test_Options()
  test_DLSolvers()
  test_solvers()
  test_odecall()
  test_bvp()
  test_colnew()
  test_bvpm2()
end

test_all()

end

# vim:syn=julia:cc=79:fdm=indent:
