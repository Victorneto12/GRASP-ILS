function resolver_alocacao_global(
    s_distance::Matrix{Float64},
    max_walking_distance::Vector{Float64},
    C::Int64,
    q::Int64,
    n::Int64
)
    if length(max_walking_distance) != q
        println("Erro: max_walking_distance deve ter o mesmo tamanho que o número de alunos (q).")
        return nothing
    end

    modelo = Model(HiGHS.Optimizer)
    set_silent(modelo)

    # Variáveis de decisão
    @variable(modelo, 0 <= x[2:n, 1:q] <= 1, Bin)  # Alocação de alunos às paradas (excluindo escola)
    @variable(modelo, y[2:n], Bin)  # Parada usada ou não (excluindo escola)

    # Restrição 1: Cada aluno deve ser alocado a exatamente uma parada
    @constraint(modelo, [j=1:q], sum(x[i, j] for i in 2:n) == 1)

    # Restrição 2: Capacidade máxima de cada parada
    @constraint(modelo, [i=2:n], sum(x[i, j] for j in 1:q) <= C)

    # Restrição 3: Distância máxima permitida
    @constraint(modelo, [i=2:n, j=1:q], x[i, j] * s_distance[i, j] <= max_walking_distance[j])

    # Restrição 4: Ativar parada apenas se usada
    @constraint(modelo, [i=2:n, j=1:q], x[i, j] <= y[i])

    # Função objetivo: Minimizar a distância total
    @objective(modelo, Min, sum(s_distance[i, j] * x[i, j] for i in 2:n, j in 1:q))

    optimize!(modelo)

    if termination_status(modelo) == MOI.OPTIMAL
        # Obter resultados
        resultado_alocacao = value.(x)
        alunos_por_parada = vec(sum(Array(resultado_alocacao), dims=2))

        # Inserir a escola como a primeira parada com valor zero
        alunos_por_parada_com_escola = vcat(0, alunos_por_parada)

        # Identificar paradas usadas
        y_values = Array(value.(y))
        paradas_usadas = findall(y_values .> 0.5) .+ 1

        # Determinar paradas obrigatórias
        paradas_obrigatorias = Set{Int64}()
        for j in 1:q
            parada_alocada = findfirst(i -> resultado_alocacao[i, j] > 0.5, 2:n)
            if parada_alocada !== nothing
                push!(paradas_obrigatorias, parada_alocada + 1)
            end
        end

        return alunos_por_parada_com_escola, paradas_obrigatorias 
    else
        println("Solução inviável: restrições não atendidas.")
        return nothing
    end
end
