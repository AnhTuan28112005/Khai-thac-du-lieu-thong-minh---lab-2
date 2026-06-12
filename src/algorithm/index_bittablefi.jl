# src/algorithm/index_bittablefi.jl
# Implementation of Index-BitTableFI algorithm
# Based on: Song et al., "Index-BitTableFI: An improved algorithm for mining
# frequent itemsets", Knowledge-Based Systems 21 (2008) 507-513.
#
# This file contains:
#   - build_bittable_db:     Scan DB, filter infrequent items, build BitTable
#   - compute_index_array:   Algorithm 1 — compute index array with subsume indices
#   - index_bittablefi:      Algorithm 2 — main mining algorithm (hybrid BFS+DFS)
#   - depth_first!:          Procedure Depth_First — DFS extension of itemsets

include(joinpath(@__DIR__, "..", "structures.jl"))

# ─────────────────────────────────────────────────────────────────────────────
# BUILD BITTABLE DATABASE
# ─────────────────────────────────────────────────────────────────────────────

"""
    build_bittable_db(transactions::Vector{Vector{Int}}, minsup::Int) -> BitTableDB

Scan the transaction database once, remove infrequent items, sort remaining
items in support ascending order, then build horizontal and vertical BitTable
representations.

Steps (matching Algorithm 1, Steps 1–5):
  1. Count support for each item
  2. Prune items with support < minsup
  3. Sort frequent items by support ascending (ties broken by item ID ascending)
  4. Build vertical BitTable: tidsets[rank] = BitVector over transactions
  5. Build horizontal BitTable: trans_bitvecs[tid] = BitVector over frequent items
"""
function build_bittable_db(transactions::Vector{Vector{Int}}, minsup::Int)::BitTableDB
    N = length(transactions)

    # Step 1: Count supports
    support_count = Dict{Int,Int}()
    for trans in transactions
        for item in trans
            support_count[item] = get(support_count, item, 0) + 1
        end
    end

    # Step 2: Filter to frequent items only
    freq_items = Int[]
    freq_supports = Int[]
    for (item, sup) in support_count
        if sup >= minsup
            push!(freq_items, item)
            push!(freq_supports, sup)
        end
    end

    if isempty(freq_items)
        return BitTableDB(N, 0, Int[], Dict{Int,Int}(), BitVector[], BitVector[])
    end

    # Step 3: Sort by support ascending, then by item ID ascending for tie-breaking
    perm = sortperm(collect(zip(freq_supports, freq_items)); by = x -> (x[1], x[2]))
    item_order = freq_items[perm]
    m = length(item_order)

    # Build rank mapping: item → position in item_order (1-indexed)
    item_to_rank = Dict{Int,Int}()
    for (r, item) in enumerate(item_order)
        item_to_rank[item] = r
    end

    # Step 4: Build vertical BitTable (tidsets)
    tidsets = [falses(N) for _ in 1:m]
    # Step 5: Build horizontal BitTable (trans_bitvecs)
    trans_bitvecs = [falses(m) for _ in 1:N]

    @inbounds for t in 1:N
        for item in transactions[t]
            r = get(item_to_rank, item, 0)
            if r > 0
                tidsets[r][t] = true
                trans_bitvecs[t][r] = true
            end
        end
    end

    return BitTableDB(N, m, item_order, item_to_rank, tidsets, trans_bitvecs)
end

# ─────────────────────────────────────────────────────────────────────────────
# ALGORITHM 1: COMPUTE INDEX ARRAY
# ─────────────────────────────────────────────────────────────────────────────

"""
    compute_index_array(db::BitTableDB) -> Vector{IndexEntry}

Algorithm 1 from the paper: compute the index array.

For each frequent item aⱼ (in support ascending order):
  - candidate = AND of all horizontal bitvecs of transactions containing aⱼ
  - subsume(aⱼ) = {aᵢ : i > j and bit i is set in candidate}

The subsume index identifies items that always co-occur with the representative
item (i.e., tidset(aⱼ) ⊆ tidset(aᵢ)).
"""
function compute_index_array(db::BitTableDB)::Vector{IndexEntry}
    m = db.num_freq_items
    if m == 0
        return IndexEntry[]
    end

    index_array = Vector{IndexEntry}(undef, m)

    @inbounds for j in 1:m
        item = db.item_order[j]
        tidset_j = db.tidsets[j]
        sup_j = count(tidset_j)

        # Step 8: candidate = intersection of all transactions containing item j
        # Initialize candidate with all bits set
        candidate = trues(m)
        for t in 1:db.num_trans
            if tidset_j[t]
                # AND with horizontal bitvec of transaction t
                candidate .&= db.trans_bitvecs[t]
            end
        end

        # Steps 9-13: extract subsume index from candidate
        subsume = Int[]
        for i in (j+1):m
            if candidate[i]
                push!(subsume, db.item_order[i])
            end
        end

        index_array[j] = IndexEntry(item, sup_j, subsume)
    end

    return index_array
end

# ─────────────────────────────────────────────────────────────────────────────
# PROCEDURE DEPTH_FIRST (from Algorithm 2)
# ─────────────────────────────────────────────────────────────────────────────

"""
    depth_first!(results, itemset, itemset_tidset, tail, tail_tidsets, minsup)

Procedure Depth_First from Algorithm 2.

Extends `itemset` in depth-first order by trying to add each item in `tail`.
Support is computed by intersecting BitVector tidsets (vertical BitTable).

Arguments:
- `results`: accumulator for (itemset, support) tuples
- `itemset`: current itemset as sorted Vector{Int}
- `itemset_tidset`: BitVector tidset of current itemset
- `tail`: items available for extension (after itemset in support order)
- `tail_tidsets`: corresponding BitVector tidsets for tail items
- `minsup`: minimum support threshold
"""
function depth_first!(
    results::Vector{Tuple{Vector{Int},Int}},
    itemset::Vector{Int},
    itemset_tidset::BitVector,
    tail::Vector{Int},
    tail_tidsets::Vector{BitVector},
    minsup::Int
)
    n = length(tail)
    if n == 0
        return
    end

    # We iterate and build a new_tail for recursive calls
    @inbounds for idx in 1:n
        i = tail[idx]
        i_tidset = tail_tidsets[idx]

        # Compute tidset of itemset ∪ {i} by AND
        f_tidset = itemset_tidset .& i_tidset
        f_sup = count(f_tidset)

        if f_sup >= minsup
            # Build new itemset and ensure it is sorted
            f_itemset = sort(vcat(itemset, i))

            push!(results, (f_itemset, f_sup))

            # Recursive: tail becomes items after idx
            if idx < n
                new_tail = tail[(idx+1):n]
                new_tail_tidsets = tail_tidsets[(idx+1):n]
                depth_first!(results, f_itemset, f_tidset,
                             new_tail, new_tail_tidsets, minsup)
            end
        end
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# ALGORITHM 2: INDEX-BITTABLEFI
# ─────────────────────────────────────────────────────────────────────────────

"""
    generate_nonempty_subsets(items::Vector{Int}) -> Vector{Vector{Int}}

Generate all 2^m - 1 nonempty subsets of `items`.
Used in Algorithm 2, Steps 8-9 and 14-15 to enumerate subsume combinations.
"""
function generate_nonempty_subsets(items::Vector{Int})::Vector{Vector{Int}}
    m = length(items)
    subsets = Vector{Vector{Int}}()
    # Total subsets = 2^m - 1 (exclude empty set)
    sizehint!(subsets, (1 << m) - 1)
    for mask in 1:(1 << m) - 1
        subset = Int[]
        for bit in 1:m
            if (mask >> (bit - 1)) & 1 == 1
                push!(subset, items[bit])
            end
        end
        push!(subsets, subset)
    end
    return subsets
end

"""
    index_bittablefi(transactions::Vector{Vector{Int}}, minsup::Int)
        -> Vector{Tuple{Vector{Int}, Int}}

Main entry point: Algorithm 2 (Index-BitTableFI).

Returns a vector of (itemset, support) pairs, where each itemset is a
sorted Vector{Int} of original item IDs.

Overview:
  For each element in the index array:
  1. Output the representative item with its support
  2. If subsume is empty and sup > minsup: extend via Depth_First
  3. If subsume is not empty:
     a. Enumerate all 2^m-1 nonempty subsets of subsume → output with same support
     b. If sup > minsup: extend item and each combination via Depth_First
        (excluding subsume items from tail)
"""
function index_bittablefi(transactions::Vector{Vector{Int}}, minsup::Int)::Vector{Tuple{Vector{Int},Int}}
    # Build BitTable database (scan + filter + sort + build bitvecs)
    db = build_bittable_db(transactions, minsup)

    if db.num_freq_items == 0
        return Tuple{Vector{Int},Int}[]
    end

    # Compute index array (Algorithm 1)
    index_array = compute_index_array(db)

    m = db.num_freq_items
    results = Tuple{Vector{Int},Int}[]
    sizehint!(results, m * 4)  # heuristic pre-allocation

    @inbounds for j in 1:m
        entry = index_array[j]
        item = entry.item
        sup = entry.support
        item_rank = db.item_to_rank[item]

        # Step 2: Write out representative item and its support
        push!(results, (sort([item]), sup))

        if isempty(entry.subsume)
            # Steps 3-6: subsume is empty
            if sup > minsup
                # Build tail: all frequent items after index[j].item in support order
                tail = Int[]
                tail_tidsets = BitVector[]
                for r in (item_rank+1):m
                    push!(tail, db.item_order[r])
                    push!(tail_tidsets, db.tidsets[r])
                end

                depth_first!(results, [item], db.tidsets[item_rank],
                             tail, tail_tidsets, minsup)
            end
        else
            # Steps 7-18: subsume is not empty
            subsume_items = entry.subsume

            # Steps 8-9: Generate all nonempty subsets of subsume
            # Each combination has the same support as the representative item
            subsets = generate_nonempty_subsets(subsume_items)
            for s_item in subsets
                combined = sort(vcat([item], s_item))
                push!(results, (combined, sup))
            end

            # Steps 11-16: DFS extension if sup > minsup
            if sup > minsup
                # Build tail: items after item_rank, EXCLUDING subsume items
                subsume_set = Set(subsume_items)
                tail = Int[]
                tail_tidsets = BitVector[]
                for r in (item_rank+1):m
                    candidate_item = db.item_order[r]
                    if !(candidate_item in subsume_set)
                        push!(tail, candidate_item)
                        push!(tail_tidsets, db.tidsets[r])
                    end
                end

                # Step 13: Depth_First(index[j].item, tail)
                depth_first!(results, [item], db.tidsets[item_rank],
                             tail, tail_tidsets, minsup)

                # Steps 14-15: Extend each combination of item ∪ subset
                for s_item in subsets
                    combined = sort(vcat([item], s_item))
                    # Compute tidset of combined (same as item's tidset by Theorem 2)
                    combined_tidset = db.tidsets[item_rank]  # sup is the same

                    depth_first!(results, combined, combined_tidset,
                                 tail, tail_tidsets, minsup)
                end
            end
        end
    end

    return results
end
