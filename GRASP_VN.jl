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

# Função para calcular a matriz de economias
function calcular_economias(c::Matrix{Float64}, n::Int)::Array{Float64, 2}
    economias = zeros(n, n)
    for i in 2:n
        for j in 2:n
            if i != j
                economias[i, j] = c[i, 1] + c[1, j] - c[i, j]  # Economia ao conectar i-j
            end
        end
    end
    return economias
end

# Função para construir a RCL (Lista Restrita de Candidatos)
function construir_rcl(economias::Array{Float64, 2}, pares_validos::Vector{Tuple{Int, Int}}, α::Float64)
    economias_pares = [economias[i, j] for (i, j) in pares_validos]
    
    # Define o limite com base em α
    economia_min, economia_max = minimum(economias_pares), maximum(economias_pares)
    limite_rcl = economia_max - α * (economia_max - economia_min)
    
    # Filtra pares que atendem ao critério da RCL
    rcl = [(i, j) for (i, j) in pares_validos if economias[i, j] >= limite_rcl]
    return rcl
end

# Função para seleção por roleta (proporcional às economias)
function selecionar_par_roleta(rcl::Vector{Tuple{Int, Int}}, economias::Array{Float64, 2})
    # Calcula as probabilidades (economias) para os pares na RCL
    probabilidades = [economias[i, j] for (i, j) in rcl if isfinite(economias[i, j]) && economias[i, j] > 0]
    
    # Verifica se a lista de probabilidades está vazia após filtragem
    if isempty(probabilidades)
        return rcl[rand(1:length(rcl))]  # Seleciona um par aleatório se não houver probabilidades válidas
    end
    
    # Normaliza as probabilidades apenas se a soma for maior que zero
    soma_prob = sum(probabilidades)
    if soma_prob == 0
        return rcl[rand(1:length(rcl))]  # Evita divisão por zero
    end
    probabilidades /= soma_prob  # Normalização
    
    # Seleciona com base nas probabilidades normalizadas
    return rcl[sample(1:length(probabilidades), Weights(probabilidades))]
end



function grasp(pontos::DataFrame, c::Matrix{Float64}, n::Int, Q::Int, α::Float64)
    rotas = [[i] for i in 2:n]  # Cada parada inicialmente é uma rota individual (excluindo a escola)
    capacidades_rotas = [pontos[i, :q] for i in 2:n]  # Capacidades individuais das paradas

    economias = calcular_economias(c, n)
    pares_validos = [(i, j) for i in 2:n for j in 2:n if i != j]

    while !isempty(pares_validos)
        # Constrói a RCL usando o parâmetro α
        rcl = construir_rcl(economias, pares_validos, α)
        if isempty(rcl)
            break  # Termina se não houver pares viáveis
        end
        
        # Seleciona um par aleatório da RCL usando a roleta
        (i, j) = selecionar_par_roleta(rcl, economias)
        
        # Encontra as rotas que contêm i e j
        rota_i_idx = findfirst(x -> i in x, rotas)
        rota_j_idx = findfirst(x -> j in x, rotas)

        # Verifica se ambos foram encontrados
        if isnothing(rota_i_idx) || isnothing(rota_j_idx) || rota_i_idx == rota_j_idx
            filter!(pair -> pair != (i, j), pares_validos)  # Remove pares inválidos
            continue
        end

        # Calcula a capacidade total se as rotas forem unidas
        capacidade_total = capacidades_rotas[rota_i_idx] + capacidades_rotas[rota_j_idx]

        if capacidade_total <= Q  # Verifica a capacidade do veículo
            # Mescla as rotas i e j
            append!(rotas[rota_i_idx], rotas[rota_j_idx])
            capacidades_rotas[rota_i_idx] = capacidade_total  # Atualiza capacidade
            deleteat!(rotas, rota_j_idx)
            deleteat!(capacidades_rotas, rota_j_idx)
            
            # Remove pares já processados
            pares_validos = [(p, q) for (p, q) in pares_validos if p != i && q != j]
        else
            filter!(pair -> pair != (i, j), pares_validos)  # Remove pares inviáveis
        end
    end

    # Adiciona a escola (ponto 1) no início e fim de cada rota
    for rota in rotas
        pushfirst!(rota, 1)
        push!(rota, 1)
    end
    
    custo_total = calcular_custo(rotas, c)
    return rotas, custo_total
end
