# tests/test_report.jl
# Báo cáo tỉ lệ đúng của thuật toán Index-BitTableFI
# so với kết quả tham chiếu (naive_dfs) trên 5 CSDL
#
# Cách tiếp cận:
#   - naive_dfs được dùng làm "ground truth" (không dùng optimization nào)
#   - Tỉ lệ đúng = số itemsets khớp / tổng itemsets ground truth * 100%

using Test
using Printf
include("../src/utils.jl")
include("../src/algorithm/index_bittablefi.jl")
include("../src/algorithm/naive_dfs.jl")

# ─────────────────────────────────────────────────────────────────────────────
# Hàm tính accuracy report cho 1 dataset
# ─────────────────────────────────────────────────────────────────────────────
function compute_accuracy(transactions, minsup)
    res_index = index_bittablefi(transactions, minsup)
    res_naive = naive_dfs(transactions, minsup)

    index_sets = Set(Set.(map(first, res_index)))
    naive_sets = Set(Set.(map(first, res_naive)))

    ground_truth = length(naive_sets)
    found        = length(index_sets)
    correct      = length(intersect(index_sets, naive_sets))
    extra        = length(setdiff(index_sets, naive_sets))   # thừa (false positive)
    missing_     = length(setdiff(naive_sets, index_sets))   # thiếu (false negative)
    accuracy     = ground_truth == 0 ? 100.0 : correct / ground_truth * 100.0

    return (
        ground_truth = ground_truth,
        found        = found,
        correct      = correct,
        extra        = extra,
        missing      = missing_,
        accuracy     = accuracy,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Cấu hình 5 CSDL
# ─────────────────────────────────────────────────────────────────────────────
datasets = [
    (name="Paper Example",  file="data/toy/paper_example.txt", minsup=2),
    (name="Simple Toy",     file="data/toy/simple.txt",        minsup=3),
    (name="VD1 Chương 2",  file="data/toy/VD1_spmf.txt",      minsup=3),
    (name="VD2 Chương 2",  file="data/toy/VD2_spmf.txt",      minsup=2),
    (name="Chess",          file="data/toy/chess.txt",         minsup=2900),
]

# ─────────────────────────────────────────────────────────────────────────────
# Chạy và thu thập kết quả
# ─────────────────────────────────────────────────────────────────────────────
println("\n" * "="^72)
println("  BÁO CÁO TỈ LỆ ĐÚNG — Index-BitTableFI vs. Ground Truth (Naive DFS)")
println("="^72)

results_table = []

for ds in datasets
    transactions = read_spmf(ds.file)
    r = compute_accuracy(transactions, ds.minsup)
    push!(results_table, (name=ds.name, minsup=ds.minsup,
                          ntrans=length(transactions), r...))
end

# In bảng kết quả
println()
println("┌──────────────────┬────────┬───────┬────────┬───────┬────────┬────────┬────────────┐")
println("│ Dataset          │ minsup │ Trans │ Ground │ Found │ Đúng   │ Thừa  │ Tỉ lệ     │")
println("│                  │        │       │ Truth  │       │        │       │            │")
println("├──────────────────┼────────┼───────┼────────┼───────┼────────┼────────┼────────────┤")
for r in results_table
    name   = lpad(rpad(r.name, 16), 16)
    minsup = lpad(string(r.minsup), 6)
    ntrans = lpad(string(r.ntrans), 5)
    gt     = lpad(string(r.ground_truth), 6)
    found  = lpad(string(r.found), 5)
    cor    = lpad(string(r.correct), 6)
    extra  = lpad(string(r.extra), 5)
    acc    = lpad(@sprintf("%.2f%%", r.accuracy), 8)
    println("│ $name │ $minsup │ $ntrans │ $gt │ $found │ $cor │ $extra  │ $acc   │")
end
println("└──────────────────┴────────┴───────┴────────┴───────┴────────┴────────┴────────────┘")
println()

# ─────────────────────────────────────────────────────────────────────────────
# Unit tests để xác nhận tỉ lệ đúng = 100%
# ─────────────────────────────────────────────────────────────────────────────
@testset "Accuracy Report — 5 Datasets" begin
    for (i, r) in enumerate(results_table)
        ds = datasets[i]
        @testset "$(ds.name) (minsup=$(ds.minsup))" begin
            @test r.accuracy  == 100.0   # Tỉ lệ đúng phải 100%
            @test r.extra     == 0       # Không có itemset thừa
            @test r.missing   == 0       # Không có itemset thiếu
            @test r.found     == r.ground_truth  # Đúng số lượng
        end
    end
end
