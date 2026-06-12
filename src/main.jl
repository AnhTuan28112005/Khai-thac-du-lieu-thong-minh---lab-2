# src/main.jl
# Main entry point for the FIM algorithm CLI

include("utils.jl")
include("algorithm/index_bittablefi.jl")
include("algorithm/naive_dfs.jl")

function main()
    args = parse_cli_args()
    
    input_file = args["input"]
    output_file = args["output"]
    minsup = args["minsup"]
    algo_name = args["algorithm"]
    
    println("--- Frequent Itemset Mining ---")
    println("Input file : $input_file")
    println("Min support: $minsup")
    println("Algorithm  : $algo_name")
    
    println("\nReading dataset...")
    transactions = read_spmf(input_file)
    println("Loaded $(length(transactions)) transactions.")
    
    println("\nRunning algorithm...")
    local results
    time_taken = @elapsed begin
        if algo_name == "index-bittablefi"
            results = index_bittablefi(transactions, minsup)
        elseif algo_name == "naive-dfs"
            results = naive_dfs(transactions, minsup)
        else
            error("Unknown algorithm: $algo_name")
        end
    end
    
    num_itemsets = length(results)
    println("Found $num_itemsets frequent itemsets in $(round(time_taken, digits=4)) seconds.")
    
    println("\nWriting results to $output_file...")
    write_spmf(results, output_file)
    println("Done.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
