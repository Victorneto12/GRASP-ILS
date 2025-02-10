using DelimitedFiles,CSV,DataFrames,Plots
include("milp.jl") 
include("read_instance_SBRP.jl")
include("plot_results_MILP.jl")

# Salvando o nome de todos os arquivos xpress na pasta instaces
pasta = "instances"
extensao = "xpress"
caminho_pasta = joinpath(pasta)
arquivos = readdir(caminho_pasta)
# Filtra os arquivos pela extensão desejada
arquivos_xpress = filter(x -> endswith(x, ".$extensao"), arquivos)

# Criando um dataframe para armazenar resultados das instâncias para cada um dos métodos
N_instance = Int[]
N_stop = Int[]
N_students = Int[]
cap = Int[]
Method = String[]
Zopt = Float64[]
Time = Float64[]
GAP = Float64[]
Time_limit = Float64[]
results = DataFrame(N_instance=N_instance, N_stop=N_stop, N_students=N_students, cap=cap, Method=Method, Zopt=Zopt, Time=Time, GAP=GAP, Time_limit=Time_limit)

global count = 0
global time_limit = 30
for arquivo in arquivos_xpress
    global count += 1
    path_inst = "instances/"*arquivo
    # Leitura dos parâmetros da instância
    stop, q, C, w, coord_n, coord_q = read_instance(path_inst)

    # Incluindo a escola como sendo uma parada
    n = stop + 1

    # Calcular a matriz de distâncias
    c = zeros(Float64, n, n)
    for origem in 1:n
        for destino in 1:n
            c[origem, destino] = ((coord_n[origem, :X]-coord_n[destino, :X])^2 + (coord_n[origem, :Y]-coord_n[destino, :Y])^2)^0.5
        end
    end
    c = round.(c, digits=2)
    #println("A matriz de distancias é : ", c)  

    # conjunto de potenciais paradas
    V = Int[] 
    for j in 1:n
        push!(V,j)
    end
    #println("O vetor de potenciais paradas é: ", V)

    # Matriz que indica se existe aluno no percurso i,j 
    i = 1 # index da escola
    s = zeros(n, q)

    # Calcular a matriz de alunos
    for student in 1:q
        for stop in 2:n
            d = ((coord_q[student, :X]-coord_n[stop, :X])^2 + (coord_q[student, :Y]-coord_n[stop, :Y])^2)^0.5
            if (d <= w)
                s[stop, student] = 1
            end
        end
    end
    #println("A matriz contendo os alunos é:  ", s)

    S = collect(1:size(s,2)) # conjunto de estudantes 
    #println("O conjunto de estudantes é :",S)

    kmin = (size(s,2)/C)
    kmax = Int(round.(kmin*1.5, digits = 0))

    zIP, tzIP, LRG, X_values, Y_values, Z_values = sbrp(C, V, S, c, s, i, kmax, time_limit)
    println("O valor da função objetivo é: ", zIP)
    println("O tempo de processamento é: ", tzIP)

    # Salvando os resultados do SBRP
    namefile = "resultados/MILP/SBRP_"*string(count)*"_s"*string(stop)*"_q"*string(q)*"_C"*string(C)*"_w"*string(w)*".txt"
    file = open(namefile, "w")
    println(file,"O valor da solução é: " *string(zIP))
    println(file, "O tempo de processamento é: "*string(tzIP))
    println(file, "A matriz de de distancias é: "*string(c))
    println(file, "A matriz de estudantes é: "*string(s))
    println(file,X_values)
    println(file,"A matriz y_values é:")
    println(file, Y_values)
    println(file,"A matriz z_values é:")
    println(file, Z_values)
    close(file)

    plot_result( count, n, q, C, kmax, w, coord_n, coord_q, X_values, Z_values)

    #Salvando os resultados no dataframe
    result = Dict("N_instance" => count, "N_stop" => stop, "N_students" => q, "cap" => C, "Method" => "MILP", "Zopt" => zIP, "Time" => tzIP, "GAP" => LRG, "Time_limit" => time_limit)
    push!(results, result)
end

println(results)
CSV.write("resultados_MILP_"*string(time_limit)*".csv",results, delim=',')
println("Os resultados foram salvos com sucesso!")