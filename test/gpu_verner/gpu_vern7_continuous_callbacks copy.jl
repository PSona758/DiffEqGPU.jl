using DiffEqGPU, OrdinaryDiffEq, StaticArrays, LinearAlgebra, CUDA
@info "Callbacks"

function f(u, p, t)
    du1 = u[2]
    du2 = -p[1]
    return SVector{2}(du1, du2)
end

u0 = @SVector[45.0f0, 0.0f0]
tspan = (0.0f0, 10.0f0)
p = @SVector [10.0f0]
prob = ODEProblem{false}(f, u0, tspan, p)
prob_func = (prob, i, repeat) -> remake(prob, p = prob.p)
monteprob = EnsembleProblem(prob, safetycopy = false)

function affect!(integrator)
    integrator.u += @SVector[0.0f0, -2.0f0] .* integrator.u
end

function condition(u, t, integrator)
    u[1]
end

cb = ContinuousCallback(condition, affect!; save_positions = (false, false))

@info "Unadaptive version"

sol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
            trajectories = 2,
            adaptive = false, dt = 0.1f0, callback = cb, merge_callbacks = true)

bench_sol = solve(prob, Vern7(),
                  adaptive = false, dt = 0.1f0, callback = cb, merge_callbacks = true)

@test norm(bench_sol.u - sol[1].u) < 7e-4

@info "Callback: CallbackSets"

cb = CallbackSet(cb, cb)

sol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
            trajectories = 2,
            adaptive = false, dt = 0.1f0, callback = cb, merge_callbacks = true)

bench_sol = solve(prob, Vern7(),
                  adaptive = false, dt = 0.1f0, callback = cb, merge_callbacks = true)

@test norm(bench_sol.u - sol[1].u) < 7e-4

@info "saveat and callbacks"

sol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
            trajectories = 2,
            adaptive = false, dt = 1.0f0, callback = cb, merge_callbacks = true,
            saveat = [3.1f0, 9.1f0])

bench_sol = solve(prob, Vern7(),
                  adaptive = false, dt = 1.0f0, callback = cb, merge_callbacks = true,
                  saveat = [3.1f0, 9.1f0])

@test norm(bench_sol.u - sol[1].u) < 2e-4

@info "save_everystep and callbacks"

sol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
            trajectories = 2,
            adaptive = false, dt = 1.0f0, callback = cb, merge_callbacks = true,
            save_everystep = false)

bench_sol = solve(prob, Vern7(),
                  adaptive = false, dt = 1.0f0, callback = cb, merge_callbacks = true,
                  save_everystep = false)

@test norm(bench_sol.u - sol[1].u) < 2e-4

@info "Adaptive version"

cb = ContinuousCallback(condition, affect!; save_positions = (false, false))

sol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
            trajectories = 2,
            adaptive = true, dt = 1.0f0, callback = cb, merge_callbacks = true)

bench_sol = solve(prob, Vern7(),
                  adaptive = true, save_everystep = false, dt = 1.0f0, callback = cb,
                  merge_callbacks = true)

@test norm(bench_sol.u - sol[1].u) < 1e-3

@info "Callback: CallbackSets"

cb = CallbackSet(cb, cb)

sol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
            trajectories = 2,
            adaptive = true, dt = 1.0f0, callback = cb, merge_callbacks = true)

bench_sol = solve(prob, Vern7(),
                  adaptive = true, dt = 1.0f0, save_everystep = false, callback = cb,
                  merge_callbacks = true)

@test norm(bench_sol.u - sol[1].u) < 1e-3

@info "saveat and callbacks"

sol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
            trajectories = 2,
            adaptive = true, dt = 1.0f0, callback = cb, merge_callbacks = true,
            saveat = [3.1f0, 9.1f0], reltol = 1.0f-6, abstol = 1.0f-6)

bench_sol = solve(prob, Vern7(),
                  adaptive = true, save_everystep = false, dt = 1.0f0, callback = cb,
                  merge_callbacks = true,
                  tstops = [24.0f0, 40.0f0], saveat = [3.1f0, 9.1f0], reltol = 1.0f-6,
                  abstol = 1.0f-6)

@test norm(bench_sol.u - sol[1].u) < 2e-4

@info "Unadaptive and Adaptive comparison"

sol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
            trajectories = 2,
            adaptive = false, dt = 1.0f0, callback = cb, merge_callbacks = true,
            saveat = [3.1f0, 9.1f0])

asol = solve(monteprob, GPUVern7(), EnsembleGPUKernel(),
             trajectories = 2,
             adaptive = true, dt = 1.0f0, callback = cb, merge_callbacks = true,
             saveat = [3.1f0, 9.1f0])

@test norm(asol[1].u - sol[1].u) < 2e-2
