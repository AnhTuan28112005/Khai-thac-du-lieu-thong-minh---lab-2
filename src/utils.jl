# src/utils.jl

using ArgParse

"""
    read_spmf(file_path::String)

Reads a file in SPMF format and returns a Vector of transactions, 
where each transaction is a Vector of integers.
"""
function read_spmf(file_path::String)::Vector{Vector{Int}}
    transactions = Vector{Vector{Int}}()
    
    open(file_path, "r") do io
        for line in eachline(io)
            clean_line = strip(line)
            if isempty(clean_line) || startswith(clean_line, "#")
                continue
            end
            
            try
                items = parse.(Int, split(clean_line))
                push!(transactions, items)
            catch e
                @warn "Skipping malformed line: $clean_line"
            end
        end
    end
    
    return transactions
end

"""
    write_spmf(results::Vector{Tuple{Vector{Int}, Int}}, file_path::String)

Writes the frequent itemsets to a file in SPMF format:
`item1 item2 ... #SUP: support`
The items in each itemset are guaranteed to be sorted ascendingly to match SPMF output.
"""
function write_spmf(results::Vector{Tuple{Vector{Int}, Int}}, file_path::String)
    open(file_path, "w") do io
        for (itemset, sup) in results
            # Sort items to match SPMF standard output
            sorted_items = sort(itemset)
            item_str = join(sorted_items, " ")
            println(io, "$item_str #SUP: $sup")
        end
    end
end

"""
    parse_cli_args()

Parses command line arguments for the main CLI entry point.
"""
function parse_cli_args()
    s = ArgParseSettings(description = "Frequent Itemset Mining using Index-BitTableFI")

    @add_arg_table! s begin
        "--input", "-i"
            help = "Path to the input SPMF dataset file"
            required = true
        "--output", "-o"
            help = "Path to the output file"
            default = "results.txt"
        "--minsup", "-m"
            help = "Minimum support threshold (absolute count)"
            arg_type = Int
            required = true
        "--algorithm", "-a"
            help = "Algorithm to use: 'index-bittablefi' or 'naive-dfs'"
            default = "index-bittablefi"
    end

    return parse_args(s)
end