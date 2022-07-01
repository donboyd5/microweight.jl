function direct_test(prob, shares0, result; maxiter=100, objscale=1.0, interval=1, whweight, kwargs...)
    # println("shares0 start: ", Statistics.quantile(vec(shares0)))
    kwkeys_allowed = (:show_trace, :x_tol, :g_tol)
    kwargs_keep = clean_kwargs(kwargs, kwkeys_allowed)

    # %% setup preallocations
    p = 1.0
    # shares0 = fill(1. / prob.s, prob.h * prob.s)
    p_mshares = Array{Float64,2}(undef, prob.h, prob.s)
    p_whs = Array{Float64,2}(undef, prob.h, prob.s)
    p_calctargets = Array{Float64,2}(undef, prob.s, prob.k)
    p_pdiffs = Array{Float64,2}(undef, prob.s, prob.k)
    p_whpdiffs = Array{Float64,1}(undef, prob.h)

    if whweight===nothing
        whweight = length(shares0) / length(p_calctargets)
    end
    println("Household weights component weight: ", whweight)

    fp = (shares, p) -> objfn_direct(shares, prob.wh_scaled, prob.xmat_scaled, prob.geotargets_scaled,
        p_mshares, p_whs, p_calctargets, p_pdiffs, p_whpdiffs, interval, whweight)

    function cons_addup(shares, wh)
        mshares = reshape(shares, length(wh), :)
        sum(mshares, dims=2) .- 1.
    end
    cons = (shares, p) -> cons_addup(shares, prob.wh)

    fpof = OptimizationFunction{true}(fp, Optimization.AutoZygote())
    # fpof = OptimizationFunction{true}(fp, Optimization.AutoZygote(), cons=cons) # ERROR: AutoZygote does not currently support constraints
    # fpof = OptimizationFunction{true}(fp, Optimization.AutoReverseDiff(), cons=cons) # ERROR: AutoReverseDiff does not currently support constraints
    # fpof = OptimizationFunction{true}(fp, Optimization.AutoModelingToolkit(), cons=cons)
    # fpof = OptimizationFunction{true}(fp, Optimization.AutoForwardDiff(), cons=cons)

    # AutoForwardDiff
    fprob = OptimizationProblem(fpof, shares0, lb=zeros(length(shares0)), ub=ones(length(shares0)))
    # fprob = OptimizationProblem(fpof, shares0, lb=zeros(length(shares0)), ub=ones(length(shares0)), lcons=zeros(prob.h), ucons=zeros(prob.h))

    # fprob = OptimizationProblem(fpof, shares0)

    # opt = Optimization.solve(fprob, Optim.LBFGS(), maxiters=maxiter)
    # opt = Optimization.solve(fprob, NLopt.LD_MMA(), maxiters=maxiter)
    # opt = Optimization.solve(fprob, NLopt.LD_LBFGS(), maxiters=maxiter)
    # opt = Optimization.solve(fprob, NLopt.LD_CCSAQ(), maxiters=maxiter)  # Excellent
    # opt = Optimization.solve(fprob, NLopt.LD_MMA(), maxiters=maxiter)

    # ERROR: AutoZygote does not currently support constraints
    # opt = Optimization.solve(fprob, IPNewton(), maxiters=maxiter)
    # opt = Optimization.solve(fprob, Ipopt.Optimizer()) # no options other than max time; not practical

    opt = Optimization.solve(fprob, NLopt.LD_AUGLAG(), local_method = NLopt.LD_LBFGS(), local_maxiters=10000, maxiters=maxiter)
    # opt = Optimization.solve(fprob, NLopt.LD_CCSAQ(), maxiters=maxiter)

    # LD_TNEWTON_PRECOND slow progress
    # LD_MMA pretty good
    # LD_CCSAQ ok not great
    # LD_AUGLAG
    # LD_LBFGS slow
    # LD_VAR2 about same as LD_LBFGS
    # LD_TNEWTON_PRECOND_RESTART faster than lbfgs

    result.solver_result = opt
    result.success = opt.retcode == Symbol("true")
    result.iterations = -9 # opt.original.iterations
    result.shares = opt.minimizer
    return result
end