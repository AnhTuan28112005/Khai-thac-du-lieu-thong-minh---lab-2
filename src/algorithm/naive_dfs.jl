# src/algorithm/naive_dfs.jl
# Baseline Naive DFS algorithm for performance comparison

include(joinpath(@__DIR__, "..", "structures.jl"))

"""
    naive_dfs(transactions::Vector{Vector{Int}}, minsup::Int)

A baseline Depth-First Search algorithm for frequent itemset mining.
Does NOT use BitTable, Index Array, or any advanced structures.
Computes support by directly counting subset inclusions.
"""
function naive_dfs(transactions::Vector{Vector{Int}}, minsup::Int)::Vector{Tuple{Vector{Int},Int}}
    # 1. Count supports
    counts = Dict{Int, Int}()
    for trans in transactions
        for item in trans
            counts[item] = get(counts, item, 0) + 1
        end
    end
    
    # 2. Filter frequent items and sort them (to break ties and provide consistent expansion order)
    freq_items = [item for (item, sup) in counts if sup >= minsup]
    sort!(freq_items, by=x->(counts[x], x))
    
    results = Tuple{Vector{Int},Int}[]
    
    # Pre-process transactions to only contain frequent items for faster subset checking
    clean_trans = [intersect(Set(t), Set(freq_items)) for t in transactions]
    
    function get_support(itemset::Vector{Int})
        sup = 0
        set_itemset = Set(itemset)
        for t in clean_trans
            if issubset(set_itemset, t)
                sup += 1
            end
        end
        return sup
    end

    function dfs_extend(itemset::Vector{Int}, tail::Vector{Int})
        for i in 1:length(tail)
            new_itemset = sort(vcat(itemset, tail[i]))
            sup = get_support(new_itemset)
            
            if sup >= minsup
                push!(results, (new_itemset, sup))
                # Recursive call with remaining items in tail
                if i < length(tail)
                    dfs_extend(new_itemset, tail[(i+1):end])
                end
            end
        end
    end

    # 3. Start DFS for each frequent 1-itemset
    for i in 1:length(freq_items)
        item = freq_items[i]
        push!(results, ([item], counts[item]))
        if i < length(freq_items)
            dfs_extend([item], freq_items[(i+1):end])
        end
    end

    return results
end
