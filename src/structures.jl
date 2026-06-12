# src/structures.jl
# Data structures for Index-BitTableFI algorithm
# Based on: Song et al., "Index-BitTableFI: An improved algorithm for mining
# frequent itemsets", Knowledge-Based Systems 21 (2008) 507-513.

"""
    IndexEntry

Represents one element of the Index Array (Definition 4 in the paper).
- `item`: the representative item (original item ID)
- `support`: support count of the representative item
- `subsume`: subsume index — list of items j such that item ≺ j and tidset(item) ⊆ tidset(j)
"""
struct IndexEntry
    item::Int
    support::Int
    subsume::Vector{Int}
end

"""
    BitTableDB

Compressed database representation using BitTable both horizontally and vertically.

Fields:
- `num_trans`: number of transactions (N)
- `num_freq_items`: number of frequent 1-itemsets (m₁)
- `item_order`: frequent items sorted in support ascending order [a₁, a₂, ..., aₘ]
- `item_to_rank`: maps original item ID → rank position (1-indexed) in item_order
- `tidsets`: vertical BitTable — tidsets[rank] is a BitVector of length N,
  where bit t is set iff transaction t contains item_order[rank]
- `trans_bitvecs`: horizontal BitTable — trans_bitvecs[t] is a BitVector of length m₁,
  where bit r is set iff transaction t contains item_order[r]
"""
struct BitTableDB
    num_trans::Int
    num_freq_items::Int
    item_order::Vector{Int}          # items sorted by support ascending
    item_to_rank::Dict{Int,Int}      # original item ID → rank in item_order
    tidsets::Vector{BitVector}        # tidsets[rank] = BitVector(num_trans)
    trans_bitvecs::Vector{BitVector}  # trans_bitvecs[tid] = BitVector(num_freq_items)
end
