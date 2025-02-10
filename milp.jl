using JuMP, CPLEX
function sbrp(C, V, S, c, s, i, kmax, time_limit)

    n = length(V)
    
    model_sbrp = Model(optimizer_with_attributes(CPLEX.Optimizer,
    "CPX_PARAM_TILIM" => time_limit,
    "CPX_PARAM_THREADS" => 1))

    @variables(model_sbrp, begin
    x[i in V, j in V, k in 1:n], Bin
    y[i in V, k in 1:n], Bin
    z[i in V, l in S, k in 1:kmax], Bin
    2 <= u[i in V, k in 1:n] <= length(V)
    end) 
    fix.(u[1, :], 1; force = true)
    @objective(
        model_sbrp,
        Min,
        sum(c[i, j] * x[i, j, k] for i in V, j in V, k in 1:n),
    )
    @constraints(model_sbrp, begin
        # For all nodes and routes, flow out == flow in
        [i in V, k in 1:n], sum(x[i, :, k]) == sum(x[:, i, k])
        # Flow in and out of other nodes is 1
        [i in V; i != 1], sum(x[i, :, :]) <= 1
        [i in V; i != 1], sum(x[:, i, :]) <= 1
        # MTZ constraints
        [i in V, j in V, k in 1:n; i != 1 && j != 1],
            u[i, k] - u[j, k] + 1 <= (n - 1) * (1 - x[i, j, k])
        # y[i, k] is 1 if node i is in route k
        [i in V, k in 1:n], sum(x[i, :, k]) == y[i, k]
        # each node can be in at most one route, except node 1, which is in every 
        # route
        [i in V; i != 1], sum(y[i, :]) <= 1
        # I don't understand these constraints
        # Garante que cada aluno seja pego em uma parada.
        [i in V, l in S], sum(z[i, l, :]) <= s[i, l]
        # Garante que a capacidade dos ônibus não seja excedida.
        [k in 1:kmax], sum(z[:, :, k]) <= C
        # Certifica que o aluno l não é pego na parada i pelo onibus k se o onibus k não visitar a parada i.
        [i in V, l in S, k in 1:kmax], z[i, l, k] <= y[i, k]
        # Garante que cada estudante seja pego em uma parada apenas uma vez. 
        [l in S], sum(z[:, l, :]) == 1
    end)

    status = optimize!(model_sbrp)
    X_values = value.(x)
    Y_values = value.(y)
    Z_values = value.(z)
    #println(Y_values)
    zIP = objective_value(model_sbrp)
    tzIP = MOI.get(model_sbrp, MOI.SolveTimeSec())
    LRG = MOI.get(model_sbrp, MOI.RelativeGap())
    return(zIP, tzIP, LRG, X_values, Y_values, Z_values)
end