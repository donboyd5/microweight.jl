#=
Notes
https://discourse.julialang.org/t/convergence-in-optim-questions/65139
      once_diff = OnceDifferentiable(f, [1.98,-1.95]; autodiff = :forward);
res = Optim.optimize(once_diff, [1.25, -2.1], [Inf, Inf], [2.0, 2.0], Fminbox(ConjugateGradient()),
                     Optim.Options(x_abstol = 1e-3, x_reltol = 1e-3, f_abstol = 1e-3, f_reltol =
                                   1e-3, g_tol = 1e-3))

Options


=#

function cg_optim(prob, beta0, result; maxiter=100, objscale, interval, kwargs...)
    # for allowable arguments:

    kwkeys_allowed = (:show_trace, :x_tol, :g_tol)
    kwargs_keep = clean_kwargs(kwargs, kwkeys_allowed)

    global fcalls

    # f = beta -> objfn(beta, prob.wh_scaled, prob.xmat_scaled, prob.geotargets_scaled) .* objscale
    f = beta -> objfn2(beta, prob.wh_scaled, prob.xmat_scaled, prob.geotargets_scaled, fcalls, interval) .* objscale
    # fbeta = (beta, p) -> objfn2(beta, prob.wh_scaled, prob.xmat_scaled, prob.geotargets_scaled, fcalls, interval) .* objscale

    # f = beta -> objvec2(beta, prob.wh_scaled, prob.xmat_scaled, prob.geotargets_scaled, fcalls, interval) .* objscale
    # g! = (out, beta) -> out .= ForwardDiff.jacobian(beta -> objvec2(beta, prob.wh_scaled, prob.xmat_scaled, prob.geotargets_scaled, fcalls, interval) .* objscale, beta)
    # g! = (out, beta) -> out .= Zygote.jacobian(beta -> objvec2(beta, prob.wh_scaled, prob.xmat_scaled, prob.geotargets_scaled, fcalls, interval) .* objscale, beta)[1]

    # f = beta -> objvec2(beta, prob.wh_scaled, prob.xmat_scaled, prob.geotargets_scaled, fcalls, interval) .* objscale
    # f_init = f(beta0)
    # od = NLSolversBase.OnceDifferentiable(f, beta0, copy(f_init); inplace = false, autodiff = :forward)
    # opt = LsqFit.levenberg_marquardt(od, beta0; maxIter=maxiter, kwargs_keep...)

    # opt = Optim.optimize(f, beta0, ConjugateGradient(eta=0.01; alphaguess = LineSearches.InitialConstantChange(), linesearch = LineSearches.HagerZhang()),
    #   Optim.Options(g_tol = 1e-99, iterations = maxiter, store_trace = true, show_trace = true);
    #   autodiff = :forward)

    od = NLSolversBase.OnceDifferentiable(f, beta0, copy(f(beta0)); inplace = false, autodiff = :forward)

    opt = Optim.optimize(od, beta0,
    Optim.ConjugateGradient(eta=0.01; alphaguess = LineSearches.InitialConstantChange(), linesearch = LineSearches.HagerZhang()),
    Optim.Options(x_abstol = 1e-8, x_reltol = 1e-8, f_abstol = 1e-8, f_reltol =1e-8, g_tol = 0.,
                  iterations = maxiter, store_trace = true, show_trace = false))

    # opt = Optim.optimize(od, beta0,
    #   Optim.ConjugateGradient(eta=0.01; alphaguess = LineSearches.InitialConstantChange(), linesearch = LineSearches.HagerZhang()),
    #   Optim.Options(x_abstol = 1e-8, x_reltol = 1e-8, f_abstol = 1e-8, f_reltol =1e-8, g_tol = 0.,
    #                 iterations = maxiter, store_trace = true, show_trace = false))

    result.solver_result = opt
    result.success = opt.iteration_converged || opt.x_converged || opt.f_converged || opt.g_converged
    result.iterations = opt.iterations
    result.beta = opt.minimizer

    return result
end