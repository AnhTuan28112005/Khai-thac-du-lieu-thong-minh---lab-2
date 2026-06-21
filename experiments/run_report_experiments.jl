# experiments/run_report_experiments.jl
#
# Automated experiments for the report requirements:
#   a) correctness vs SPMF
#   b) runtime by minsup
#   c) number of frequent itemsets by minsup
#   d) memory usage for basic vs optimized implementation
#   e) scalability by database size
#   f) effect of average transaction length on runtime
#
# Usage:
#   julia --project=. experiments/run_report_experiments.jl
#
# Optional SPMF integration:
#   $env:SPMF_JAR="D:\path\to\spmf.jar"
#   julia --project=. experiments/run_report_experiments.jl
#
# Optional knobs:
#   $env:REPORT_MODE="full"          # quick | full
#   $env:REPORT_DATASETS="chess,retail"
#   $env:SPMF_ALGORITHM="FPGrowth_itemsets"
#   $env:SPMF_MINSUP_MODE="absolute" # absolute | relative | percent
#   $env:MEASURE_PEAK="1"            # also poll worker process RSS

using Dates
using Printf
using Random
using Statistics
using StatsBase: sample
using Plots

const ROOT = abspath(joinpath(@__DIR__, ".."))
const RESULTS_DIR = joinpath(@__DIR__, "results")
const FIGURES_DIR = joinpath(@__DIR__, "figures")
const OUTPUTS_DIR = joinpath(@__DIR__, "outputs")
const GENERATED_DIR = joinpath(@__DIR__, "generated")

include(joinpath(ROOT, "src", "utils.jl"))
include(joinpath(ROOT, "src", "algorithm", "index_bittablefi.jl"))
include(joinpath(ROOT, "src", "algorithm", "naive_dfs.jl"))

function ensure_dirs!()
    for dir in (RESULTS_DIR, FIGURES_DIR, OUTPUTS_DIR, GENERATED_DIR)
        isdir(dir) || mkpath(dir)
    end
end

function csv_escape(x)
    s = string(x)
    if occursin(",", s) || occursin("\"", s) || occursin("\n", s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function write_csv(path, rows, columns)
    open(path, "w") do io
        println(io, join(columns, ","))
        for row in rows
            println(io, join((csv_escape(getproperty(row, c)) for c in columns), ","))
        end
    end
end

function parse_spmf_output(path)::Dict{Set{Int},Int}
    dict = Dict{Set{Int},Int}()
    isfile(path) || return dict
    for line in eachline(path)
        line = strip(line)
        isempty(line) && continue
        parts = split(line, "#SUP:")
        length(parts) == 2 || continue
        left = strip(parts[1])
        items = isempty(left) ? Int[] : parse.(Int, split(left))
        sup = parse(Int, strip(parts[2]))
        dict[Set(items)] = sup
    end
    return dict
end

function results_to_dict(results)::Dict{Set{Int},Int}
    return Dict(Set(itemset) => sup for (itemset, sup) in results)
end

function compare_outputs(group_dict, spmf_dict)
    spmf_keys = Set(keys(spmf_dict))
    group_keys = Set(keys(group_dict))
    common_keys = intersect(group_keys, spmf_keys)
    support_mismatch = count(k -> group_dict[k] != spmf_dict[k], common_keys)
    perfect = count(k -> group_dict[k] == spmf_dict[k], common_keys)
    missing = length(setdiff(spmf_keys, group_keys))
    extra = length(setdiff(group_keys, spmf_keys))
    denom = max(length(spmf_keys), 1)
    return (
        spmf_count = length(spmf_keys),
        group_count = length(group_keys),
        perfect_match = perfect,
        missing = missing,
        extra = extra,
        support_mismatch = support_mismatch,
        match_rate = 100.0 * perfect / denom,
    )
end

const DATASETS_FULL = [
    (name = "chess", file = "data/benchmark/chess.txt",
     minsups = [3000, 2900, 2800, 2700, 2600, 2500], mid = 2800),
    (name = "mushrooms", file = "data/benchmark/mushrooms.txt",
     minsups = [5000, 4000, 3000, 2500, 2000, 1683], mid = 3000),
    (name = "retail", file = "data/benchmark/retail.txt",
     minsups = [5000, 3000, 2000, 1500, 1000, 882], mid = 2000),
    (name = "accidents", file = "data/benchmark/accidents.txt",
     minsups = [340000, 320000, 300000, 280000, 272146], mid = 300000),
]

const DATASETS_QUICK = [
    (name = "paper_example", file = "data/toy/paper_example.txt",
     minsups = [7, 6, 5, 4, 3, 2], mid = 4),
    (name = "simple", file = "data/toy/simple.txt",
     minsups = [6, 5, 4, 3, 2], mid = 3),
    (name = "VD1", file = "data/toy/VD1_spmf.txt",
     minsups = [6, 5, 4, 3, 2], mid = 3),
]

function selected_datasets()
    mode = lowercase(get(ENV, "REPORT_MODE", "quick"))
    datasets = mode == "full" ? DATASETS_FULL : DATASETS_QUICK
    selected = strip(get(ENV, "REPORT_DATASETS", ""))
    if !isempty(selected)
        names = Set(strip.(split(selected, ",")))
        datasets = filter(ds -> ds.name in names, vcat(DATASETS_FULL, DATASETS_QUICK))
    end
    return datasets
end

function spmf_jar_path()
    explicit = strip(get(ENV, "SPMF_JAR", ""))
    !isempty(explicit) && isfile(explicit) && return explicit
    local_path = joinpath(ROOT, "tools", "spmf.jar")
    isfile(local_path) && return local_path
    return nothing
end

function spmf_minsup_arg(minsup::Int, ntrans::Int)
    mode = lowercase(get(ENV, "SPMF_MINSUP_MODE", "absolute"))
    if mode == "relative"
        return @sprintf("%.8f", minsup / ntrans)
    elseif mode == "percent"
        return @sprintf("%.6f%%", 100.0 * minsup / ntrans)
    else
        return string(minsup)
    end
end

function run_spmf(input_file, output_file, minsup::Int, ntrans::Int)
    jar = spmf_jar_path()
    jar === nothing && return (available = false, ok = false, time_ms = missing)

    alg = get(ENV, "SPMF_ALGORITHM", "FPGrowth_itemsets")
    minsup_arg = spmf_minsup_arg(minsup, ntrans)
    log_file = output_file * ".log"
    cmd = `java -jar $jar run $alg $input_file $output_file $minsup_arg`

    ok = true
    elapsed = @elapsed begin
        open(log_file, "w") do io
            try
                run(pipeline(cmd, stdout = io, stderr = io))
            catch
                ok = false
            end
        end
    end
    return (available = true, ok = ok, time_ms = elapsed * 1000.0)
end

function timed_group(transactions, minsup::Int, algorithm::Symbol)
    alg = algorithm == :naive ? naive_dfs : index_bittablefi
    GC.gc()
    t = @timed alg(transactions, minsup)
    return (
        results = t.value,
        time_ms = t.time * 1000.0,
        allocated_mb = t.bytes / 1024.0^2,
    )
end

function run_group_and_write(transactions, minsup::Int, output_file; algorithm::Symbol = :index)
    measured = timed_group(transactions, minsup, algorithm)
    write_spmf(measured.results, output_file)
    return measured
end

function experiment_correctness(datasets)
    rows = NamedTuple[]
    for ds in datasets
        input = joinpath(ROOT, ds.file)
        transactions = read_spmf(input)
        minsup = ds.mid
        group_output = joinpath(OUTPUTS_DIR, "$(ds.name)_group_m$(minsup).txt")
        spmf_output = joinpath(OUTPUTS_DIR, "$(ds.name)_spmf_m$(minsup).txt")

        group = run_group_and_write(transactions, minsup, group_output)
        spmf = run_spmf(input, spmf_output, minsup, length(transactions))

        if spmf.available && spmf.ok
            cmp = compare_outputs(results_to_dict(group.results), parse_spmf_output(spmf_output))
            push!(rows, (dataset = ds.name, minsup = minsup,
                         spmf_count = cmp.spmf_count, group_count = cmp.group_count,
                         perfect_match = cmp.perfect_match,
                         match_rate_percent = round(cmp.match_rate, digits = 4),
                         missing = cmp.missing, extra = cmp.extra,
                         support_mismatch = cmp.support_mismatch,
                         status = "ok"))
        else
            push!(rows, (dataset = ds.name, minsup = minsup,
                         spmf_count = missing, group_count = length(group.results),
                         perfect_match = missing, match_rate_percent = missing,
                         missing = missing, extra = missing,
                         support_mismatch = missing,
                         status = spmf.available ? "spmf_failed" : "spmf_missing"))
        end
    end
    write_csv(joinpath(RESULTS_DIR, "correctness.csv"), rows,
              [:dataset, :minsup, :spmf_count, :group_count, :perfect_match,
               :match_rate_percent, :missing, :extra, :support_mismatch, :status])
    return rows
end

function experiment_runtime_and_size(datasets)
    time_rows = NamedTuple[]
    size_rows = NamedTuple[]
    for ds in datasets
        input = joinpath(ROOT, ds.file)
        transactions = read_spmf(input)
        for minsup in ds.minsups
            group_output = joinpath(OUTPUTS_DIR, "$(ds.name)_group_m$(minsup).txt")
            group = run_group_and_write(transactions, minsup, group_output)
            push!(time_rows, (dataset = ds.name, minsup = minsup,
                              algorithm = "group_index_bittablefi",
                              time_ms = round(group.time_ms, digits = 4),
                              status = "ok"))
            push!(size_rows, (dataset = ds.name, minsup = minsup,
                              algorithm = "group_index_bittablefi",
                              itemsets = length(group.results),
                              status = "ok"))

            spmf_output = joinpath(OUTPUTS_DIR, "$(ds.name)_spmf_m$(minsup).txt")
            spmf = run_spmf(input, spmf_output, minsup, length(transactions))
            if spmf.available && spmf.ok
                spmf_count = length(parse_spmf_output(spmf_output))
                push!(time_rows, (dataset = ds.name, minsup = minsup,
                                  algorithm = "spmf",
                                  time_ms = round(spmf.time_ms, digits = 4),
                                  status = "ok"))
                push!(size_rows, (dataset = ds.name, minsup = minsup,
                                  algorithm = "spmf",
                                  itemsets = spmf_count,
                                  status = "ok"))
            else
                push!(time_rows, (dataset = ds.name, minsup = minsup,
                                  algorithm = "spmf",
                                  time_ms = missing,
                                  status = spmf.available ? "spmf_failed" : "spmf_missing"))
                push!(size_rows, (dataset = ds.name, minsup = minsup,
                                  algorithm = "spmf",
                                  itemsets = missing,
                                  status = spmf.available ? "spmf_failed" : "spmf_missing"))
            end
        end
    end

    write_csv(joinpath(RESULTS_DIR, "runtime_by_minsup.csv"), time_rows,
              [:dataset, :minsup, :algorithm, :time_ms, :status])
    write_csv(joinpath(RESULTS_DIR, "itemsets_by_minsup.csv"), size_rows,
              [:dataset, :minsup, :algorithm, :itemsets, :status])
    return time_rows, size_rows
end

function current_rss_bytes(pid::Int)
    try
        if Sys.iswindows()
            out = read(`powershell -NoProfile -Command "(Get-Process -Id $pid -ErrorAction SilentlyContinue).WorkingSet64"`, String)
            s = strip(out)
            isempty(s) && return 0
            return parse(Int, split(s)[end])
        elseif Sys.islinux()
            status = read("/proc/$pid/status", String)
            m = match(r"VmRSS:\s+(\d+)\s+kB", status)
            m === nothing && return 0
            return parse(Int, m.captures[1]) * 1024
        else
            out = read(`ps -o rss= -p $pid`, String)
            s = strip(out)
            isempty(s) && return 0
            return parse(Int, split(s)[1]) * 1024
        end
    catch
        return 0
    end
end

function worker_mode(args)
    algorithm = Symbol(args[2])
    input = args[3]
    minsup = parse(Int, args[4])
    output = args[5]
    transactions = read_spmf(input)
    measured = run_group_and_write(transactions, minsup, output; algorithm = algorithm)
    println("itemsets=$(length(measured.results))")
end

function peak_process_mb(algorithm::Symbol, input_file, minsup::Int)
    out = joinpath(OUTPUTS_DIR, "peak_$(algorithm)_$(basename(input_file))_m$(minsup).txt")
    cmd = `$(Base.julia_cmd()) --project=$ROOT $(@__FILE__) --worker $(String(algorithm)) $input_file $minsup $out`
    proc = run(cmd, wait = false)
    pid = getpid(proc)
    peak = 0
    while process_running(proc)
        peak = max(peak, current_rss_bytes(pid))
        sleep(0.15)
    end
    wait(proc)
    peak = max(peak, current_rss_bytes(pid))
    return peak / 1024.0^2
end

function experiment_memory(datasets)
    rows = NamedTuple[]
    measure_peak = get(ENV, "MEASURE_PEAK", "0") == "1"
    for ds in datasets
        input = joinpath(ROOT, ds.file)
        transactions = read_spmf(input)
        for algorithm in (:naive, :index)
            measured = timed_group(transactions, ds.mid, algorithm)
            peak_mb = measure_peak ? peak_process_mb(algorithm, input, ds.mid) : missing
            push!(rows, (dataset = ds.name, minsup = ds.mid,
                         algorithm = algorithm == :naive ? "basic_naive_dfs" : "optimized_index_bittablefi",
                         time_ms = round(measured.time_ms, digits = 4),
                         allocated_mb = round(measured.allocated_mb, digits = 4),
                         peak_process_mb = peak_mb isa Missing ? missing : round(peak_mb, digits = 4),
                         itemsets = length(measured.results)))
        end
    end
    write_csv(joinpath(RESULTS_DIR, "memory.csv"), rows,
              [:dataset, :minsup, :algorithm, :time_ms, :allocated_mb,
               :peak_process_mb, :itemsets])
    return rows
end

function write_transactions(path, transactions)
    open(path, "w") do io
        for trans in transactions
            println(io, join(trans, " "))
        end
    end
end

function experiment_scalability()
    mode = lowercase(get(ENV, "REPORT_MODE", "quick"))
    base_name = get(ENV, "SCALABILITY_DATASET", mode == "full" ? "retail" : "chess")
    matches = filter(d -> d.name == base_name, DATASETS_FULL)
    ds = isempty(matches) ? DATASETS_FULL[1] : matches[1]

    input = joinpath(ROOT, ds.file)
    transactions = read_spmf(input)
    minsup_ratio = ds.mid / length(transactions)
    fractions = [0.10, 0.25, 0.50, 0.75, 1.00]
    rows = NamedTuple[]

    for frac in fractions
        n = max(1, round(Int, frac * length(transactions)))
        subset = transactions[1:n]
        subset_file = joinpath(GENERATED_DIR, "$(ds.name)_subset_$(round(Int, frac * 100)).txt")
        write_transactions(subset_file, subset)
        minsup = max(1, round(Int, minsup_ratio * n))
        measured = timed_group(subset, minsup, :index)
        push!(rows, (dataset = ds.name, fraction_percent = round(Int, frac * 100),
                     transactions = n, minsup = minsup,
                     algorithm = "group_index_bittablefi",
                     time_ms = round(measured.time_ms, digits = 4),
                     itemsets = length(measured.results)))

        spmf_output = joinpath(OUTPUTS_DIR, "$(ds.name)_subset_$(round(Int, frac * 100))_spmf.txt")
        spmf = run_spmf(subset_file, spmf_output, minsup, n)
        if spmf.available && spmf.ok
            push!(rows, (dataset = ds.name, fraction_percent = round(Int, frac * 100),
                         transactions = n, minsup = minsup,
                         algorithm = "spmf",
                         time_ms = round(spmf.time_ms, digits = 4),
                         itemsets = length(parse_spmf_output(spmf_output))))
        end
    end
    write_csv(joinpath(RESULTS_DIR, "scalability.csv"), rows,
              [:dataset, :fraction_percent, :transactions, :minsup,
               :algorithm, :time_ms, :itemsets])
    return rows
end

function generate_synthetic_dataset(path; ntrans = 3000, nitems = 200, trans_len = 10, seed = 42)
    rng = MersenneTwister(seed + trans_len)
    open(path, "w") do io
        for _ in 1:ntrans
            trans = sort!(sample(rng, 1:nitems, min(trans_len, nitems); replace = false))
            println(io, join(trans, " "))
        end
    end
end

function experiment_transaction_length()
    lengths = parse.(Int, split(get(ENV, "SYNTH_LENGTHS", "5,10,20,40,80"), ","))
    ntrans = parse(Int, get(ENV, "SYNTH_NTRANS", "3000"))
    nitems = parse(Int, get(ENV, "SYNTH_NITEMS", "200"))
    minsup = parse(Int, get(ENV, "SYNTH_MINSUP", string(max(2, round(Int, 0.10 * ntrans)))))
    rows = NamedTuple[]

    for len in lengths
        file = joinpath(GENERATED_DIR, "synthetic_len_$(len).txt")
        generate_synthetic_dataset(file; ntrans = ntrans, nitems = nitems, trans_len = len)
        transactions = read_spmf(file)
        measured = timed_group(transactions, minsup, :index)
        avg_len = mean(length.(transactions))
        push!(rows, (dataset = "synthetic", transactions = ntrans,
                     items = nitems, avg_transaction_length = round(avg_len, digits = 4),
                     minsup = minsup, time_ms = round(measured.time_ms, digits = 4),
                     allocated_mb = round(measured.allocated_mb, digits = 4),
                     itemsets = length(measured.results)))
    end

    write_csv(joinpath(RESULTS_DIR, "transaction_length.csv"), rows,
              [:dataset, :transactions, :items, :avg_transaction_length,
               :minsup, :time_ms, :allocated_mb, :itemsets])
    return rows
end

function values_for(rows, dataset, algorithm, xfield, yfield)
    filtered = filter(r -> getproperty(r, :dataset) == dataset &&
                          getproperty(r, :algorithm) == algorithm &&
                          !(getproperty(r, yfield) isa Missing), rows)
    sort!(filtered, by = r -> getproperty(r, xfield), rev = true)
    return getproperty.(filtered, xfield), getproperty.(filtered, yfield)
end

function plot_runtime(time_rows)
    datasets = unique(getproperty.(time_rows, :dataset))
    for ds in datasets
        plt = plot(title = "Runtime by minsup - $ds",
                   xlabel = "minsup", ylabel = "time (ms)",
                   marker = :circle, xflip = true, legend = :topleft)
        for alg in unique(getproperty.(time_rows, :algorithm))
            xs, ys = values_for(time_rows, ds, alg, :minsup, :time_ms)
            isempty(xs) || plot!(plt, xs, ys, label = alg, marker = :circle)
        end
        savefig(plt, joinpath(FIGURES_DIR, "runtime_by_minsup_$ds.png"))
    end
end

function plot_itemsets(size_rows)
    datasets = unique(getproperty.(size_rows, :dataset))
    for ds in datasets
        plt = plot(title = "Frequent itemsets by minsup - $ds",
                   xlabel = "minsup", ylabel = "number of itemsets",
                   marker = :circle, xflip = true, legend = :topleft)
        for alg in unique(getproperty.(size_rows, :algorithm))
            xs, ys = values_for(size_rows, ds, alg, :minsup, :itemsets)
            isempty(xs) || plot!(plt, xs, ys, label = alg, marker = :circle)
        end
        savefig(plt, joinpath(FIGURES_DIR, "itemsets_by_minsup_$ds.png"))
    end
end

function plot_memory(memory_rows)
    datasets = unique(getproperty.(memory_rows, :dataset))
    labels = unique(getproperty.(memory_rows, :algorithm))
    for ds in datasets
        rows = filter(r -> r.dataset == ds, memory_rows)
        vals = [r.allocated_mb for alg in labels for r in rows if r.algorithm == alg]
        plt = bar(labels, vals, title = "Allocated memory - $ds",
                  xlabel = "algorithm", ylabel = "allocated MB", legend = false,
                  xrotation = 15)
        savefig(plt, joinpath(FIGURES_DIR, "memory_$ds.png"))
    end
end

function plot_scalability(rows)
    plt = plot(title = "Scalability by database size",
               xlabel = "transactions", ylabel = "time (ms)",
               marker = :circle, legend = :topleft)
    for alg in unique(getproperty.(rows, :algorithm))
        subset = filter(r -> r.algorithm == alg, rows)
        sort!(subset, by = r -> r.transactions)
        plot!(plt, getproperty.(subset, :transactions), getproperty.(subset, :time_ms),
              label = alg, marker = :circle)
    end
    savefig(plt, joinpath(FIGURES_DIR, "scalability.png"))
end

function plot_transaction_length(rows)
    sort!(rows, by = r -> r.avg_transaction_length)
    plt = plot(getproperty.(rows, :avg_transaction_length), getproperty.(rows, :time_ms),
               title = "Runtime by average transaction length",
               xlabel = "average transaction length", ylabel = "time (ms)",
               marker = :circle, label = "group_index_bittablefi")
    savefig(plt, joinpath(FIGURES_DIR, "transaction_length.png"))
end

function main()
    ensure_dirs!()
    if length(ARGS) >= 1 && ARGS[1] == "--worker"
        worker_mode(ARGS)
        return
    end

    datasets = selected_datasets()
    isempty(datasets) && error("No datasets selected.")

    println("Report experiment runner")
    println("Mode       : ", get(ENV, "REPORT_MODE", "quick"))
    println("SPMF jar   : ", something(spmf_jar_path(), "not found; SPMF rows will be marked missing"))
    println("Results dir: ", RESULTS_DIR)
    println("Figures dir: ", FIGURES_DIR)

    println("\n[a] correctness")
    correctness_rows = experiment_correctness(datasets)

    println("[b,c] runtime and output size by minsup")
    time_rows, size_rows = experiment_runtime_and_size(datasets)

    println("[d] memory")
    memory_rows = experiment_memory(datasets)

    println("[e] scalability")
    scalability_rows = experiment_scalability()

    println("[f] transaction length")
    length_rows = experiment_transaction_length()

    println("plotting")
    plot_runtime(time_rows)
    plot_itemsets(size_rows)
    plot_memory(memory_rows)
    plot_scalability(scalability_rows)
    plot_transaction_length(length_rows)

    println("\nDone.")
    println("CSV files: ", RESULTS_DIR)
    println("Figures  : ", FIGURES_DIR)
    println("Correctness rows: ", length(correctness_rows))
end

main()
