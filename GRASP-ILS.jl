# Função para calcular o custo total de uma solução
function calcular_custo(solucao::Vector{Vector{Int}}, c::Matrix{Float64})::Float64
    custo = 0.0
    for rota in solucao
        for i in 1:(length(rota) - 1)
            custo += c[rota[i], rota[i + 1]]
        end
    end
    return custo
end

# Verificação se as paradas não estão sendo repetidas
function verificar_paradas_unicas(solucao::Vector{Vector{Int}})::Bool
    visitadas = Set{Int}()
    for rota in solucao
        for parada in rota[2:end-1] # Ignora a escola (primeira e última parada)
            if parada in visitadas
                return false
            end
            push!(visitadas, parada)
        end
    end
    return true
end

# Verificação da capacidade dos ônibus
function verificar_capacidades(solucao::Vector{Vector{Int}}, capacidades::Vector{Int}, Q::Int)::Bool
    for rota in solucao
        demanda_rota = sum(capacidades[parada] for parada in rota if parada > 1)  # Ignora a escola (parada 1)
        if demanda_rota > Q
            return false
        end
    end
    return true
end

# Perturbações intrarotas (reversão de sublista ou troca de paradas dentro da mesma rota)
function perturbacao_intrarota(rotas::Vector{Vector{Int}})
    nova_solucao = deepcopy(rotas)
    rota_idx = rand(1:length(nova_solucao))
    rota = nova_solucao[rota_idx]

    if length(rota) > 3
        i, j = sort(rand(2:length(rota) - 1, 2))
        reverse!(rota[i:j])
    end

    return nova_solucao
end

# Perturbações interrotas (troca de paradas entre duas rotas diferentes)
function perturbacao_interrota(rotas::Vector{Vector{Int}})
    if length(rotas) < 2
        return rotas
    end

    nova_solucao = deepcopy(rotas)
    rota1_idx, rota2_idx = rand(1:length(nova_solucao), 2)
    while rota1_idx == rota2_idx
        rota2_idx = rand(1:length(nova_solucao))
    end

    rota1, rota2 = nova_solucao[rota1_idx], nova_solucao[rota2_idx]

    if length(rota1) > 2 && length(rota2) > 2
        parada1 = rand(2:length(rota1) - 1)
        parada2 = rand(2:length(rota2) - 1)

        rota1[parada1], rota2[parada2] = rota2[parada2], rota1[parada1]
    end

    return nova_solucao
end

# Busca local: Swap para instâncias com até 10 paradas
function busca_local_swap(rotas::Vector{Vector{Int}}, c::Matrix{Float64})
    melhor_solucao = deepcopy(rotas)
    melhor_custo = calcular_custo(melhor_solucao, c)

    for rota in melhor_solucao
        for i in 2:(length(rota) - 2)
            for j in (i + 1):(length(rota) - 1)
                rota[i], rota[j] = rota[j], rota[i]
                novo_custo = calcular_custo(melhor_solucao, c)
                if novo_custo < melhor_custo
                    melhor_custo = novo_custo
                else
                    rota[i], rota[j] = rota[j], rota[i]  # Reverte se não melhorar
                end
            end
        end
    end

    return melhor_solucao
end

# Busca local: 2-opt para instâncias com mais de 10 paradas
function busca_local_2opt(rotas::Vector{Vector{Int}}, c::Matrix{Float64})
    melhor_solucao = deepcopy(rotas)
    melhor_custo = calcular_custo(melhor_solucao, c)

    for rota in melhor_solucao
        for i in 2:(length(rota) - 3)
            for j in (i + 1):(length(rota) - 2)
                rota[i:j] = reverse(rota[i:j])
                novo_custo = calcular_custo(melhor_solucao, c)
                if novo_custo < melhor_custo
                    melhor_custo = novo_custo
                else
                    rota[i:j] = reverse(rota[i:j])  # Reverte se não melhorar
                end
            end
        end
    end

    return melhor_solucao
end

# Algoritmo ILS com GRASP como solução inicial
function ils(grasp_solucao::Tuple{Vector{Vector{Int}}, Float64}, c::Matrix{Float64}, Q::Int, capacidades::Vector{Int}, tempo_limite::Float64)
    melhor_solucao, melhor_custo = grasp_solucao
    inicio = time()
    tempo_melhor_solucao = inicio  # Marca o tempo inicial

    while (time() - inicio) < tempo_limite
        # Perturbação
        if rand() < 0.5
            nova_solucao = perturbacao_intrarota(melhor_solucao)
        else
            nova_solucao = perturbacao_interrota(melhor_solucao)
        end

        # Valida a solução após perturbação
        if !verificar_capacidades(nova_solucao, capacidades, Q)
            continue  # Descarta soluções inviáveis
        end

        # Busca local
        if length(c) <= 10
            nova_solucao = busca_local_swap(nova_solucao, c)
        else
            nova_solucao = busca_local_2opt(nova_solucao, c)
        end

        # Valida a solução após busca local
        if !verificar_capacidades(nova_solucao, capacidades, Q)
            continue  # Descarta soluções inviáveis
        end

        # Cálculo do custo
        novo_custo = calcular_custo(nova_solucao, c)

        # Atualização da solução
        if novo_custo < melhor_custo
            melhor_solucao, melhor_custo = nova_solucao, novo_custo
            tempo_melhor_solucao = time()  # Atualiza o tempo da melhor solução
        end
    end

    # Validação final antes de retornar a solução
    if !verificar_capacidades(melhor_solucao, capacidades, Q)
        error("Solução final inviável: capacidade dos veículos não respeitada.")
    end

    # Calcula o tempo para encontrar a melhor solução
    tempo_para_melhor_solucao = tempo_melhor_solucao - inicio

    return melhor_solucao, melhor_custo, tempo_para_melhor_solucao
end
