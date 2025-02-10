using DelimitedFiles, CSV, DataFrames, Plots, Random, StatsBase, JuMP, HiGHS
include("grasp_VN.jl")
include("GRASP-ILS.jl")
include("alocacao.jl")
include("read_instance_SBRP.jl")


# Caminho para os arquivos de instância
pasta = "instances"
extensao = "xpress"
caminho_pasta = joinpath(pasta)
arquivos = readdir(caminho_pasta)
arquivos_xpress = filter(x -> endswith(x, ".$extensao"), arquivos)

# Criar dataframe para armazenar os resultados
results = DataFrame(
    N_instance=Int[],
    N_stop=Int[],
    N_students=Int[],
    cap=Int[],
    w=Int[],
    Z_GRASP=Float64[],
    Time_GRASP=Float64[],
    Z_ILS=Float64[],
    Time_ILS=Float64[],
    Iterations_without_improvement=Int[]
)

# Parâmetros para calibração
max_iter_sem_melhoria = 50

# Definir tempo limite para o ILS em segundos
tempo_limite = 60.0

for (count, arquivo) in enumerate(arquivos_xpress)
    path_inst = joinpath(pasta, arquivo)

    # Leitura dos parâmetros da instância
    stop, q, C, w, coord_n, coord_q = read_instance(path_inst)

    # Adicionar a escola como uma parada
    n = stop + 1

    # Calcular a matriz de distâncias
    c = zeros(Float64, n, n)
    for origem in 1:n
        for destino in 1:n
            c[origem, destino] = sqrt((coord_n[origem, 1] - coord_n[destino, 1])^2 + (coord_n[origem, 2] - coord_n[destino, 2])^2)
        end
    end

    # Calcular as distâncias dos alunos às paradas
    s_distance = zeros(Float64, n, q)
    for student in 1:q
        for stop in 2:n
            d = sqrt((coord_q[student, 1] - coord_n[stop, 1])^2 + (coord_q[student, 2] - coord_n[stop, 2])^2)
            s_distance[stop, student] = d
        end
    end

    # Criar o vetor max_walking_distance com o valor de w para cada aluno
    max_walking_distance = fill(Float64(w), q)

    # Resolver o problema de alocação global
    alunos_por_parada_com_escola, paradas_obrigatorias = resolver_alocacao_global(s_distance, max_walking_distance, C, q, n)


    if alunos_por_parada_com_escola === nothing
        println("Solução inviável para a instância: ", arquivo)
        continue
    else
        println("Solução viável encontrada para a instância: ", arquivo)
    end

    alunos_por_parada = Int.(alunos_por_parada_com_escola)
    println("Demanda inicial dos alunos por parada: ", alunos_por_parada)

    # Criar DataFrame com os pontos das paradas
    pontos = DataFrame(X=coord_n[:, 1], Y=coord_n[:, 2], q=alunos_por_parada)

    # Rodar o GRASP
    t0 = time_ns()
    α = 0.1
    sol_grasp, c_grasp = grasp(DataFrame(q=alunos_por_parada), c, n, C, α)
    time_grasp = (time_ns() - t0) / 1e9
    println("Solução GRASP: ", sol_grasp)
    println("Custo GRASP: ", c_grasp)
    println("Tempo GRASP: ", time_grasp)

    # Ajustar formato de sol_grasp
    sol_grasp = [Int.(rota) for rota in sol_grasp]
    println("Solução do grasp:", sol_grasp)
    # Rodar o ILS
    println("Rodando GRASP-ILS com limite de tempo de $tempo_limite segundos.")
    t0_ils = time_ns()
    solucao_ils, custo_ils, tempo_para_melhor = ils(
        (sol_grasp, c_grasp),  # Solução inicial do GRASP
        c,                     # Matriz de custos
        C,                     # Capacidade dos veículos
        alunos_por_parada,     # Vetor de demandas por parada
        tempo_limite           # Tempo limite em segundos
    )
    time_ils = (time_ns() - t0_ils) / 1e9

    println("Solução GRASP-ILS: ", solucao_ils)
    println("Custo GRASP-ILS: ", custo_ils)
    println("Tempo GRASP-ILS: ", time_ils)

    
    # Salvar resultados no DataFrame
    push!(results, (count, stop, q, C, w, c_grasp, time_grasp, custo_ils, time_ils, max_iter_sem_melhoria))
end

# Salvar os resultados em um arquivo CSV
println(results)
CSV.write("Resultados_Calibracao.csv", results)
println("Resultados salvos com sucesso!")
