# tests/test_benchmark.jl
# Đo lường và so sánh hiệu năng: Index-BitTableFI vs Naive DFS
# Kỹ thuật tối ưu hóa: BitTable (BitVector) cho tidset representation
#   - Tính support bằng bitwise AND thay vì set intersection
#   - Subsume Index: output trực tiếp các combinations mà không tính support lại
#   - Kết hợp BFS (subsume phase) + DFS (tail phase)

using Test
using BenchmarkTools
using Printf
include("../src/utils.jl")
include("../src/algorithm/index_bittablefi.jl")
include("../src/algorithm/naive_dfs.jl")

# ─────────────────────────────────────────────────────────────────────────────
# Hàm đo thời gian trung bình (chạy nhiều lần để ổn định)
# ─────────────────────────────────────────────────────────────────────────────
function measure_time(f, args...; n_runs=5)
    # Warm-up
    f(args...)
    # Đo chính xác
    times = [(@elapsed f(args...)) for _ in 1:n_runs]
    return minimum(times)   # dùng minimum để tránh outliers
end

# ─────────────────────────────────────────────────────────────────────────────
# Cấu hình benchmark: chess dataset với 3 mức minsup
# ─────────────────────────────────────────────────────────────────────────────
chess_path = "data/toy/chess.txt"

@testset "Performance Benchmark" begin

    transactions = read_spmf(chess_path)
    @test length(transactions) == 3196

    configs = [
        (minsup=3000, label="minsup=3000 (high)"),
        (minsup=2800, label="minsup=2800 (medium)"),
        (minsup=2500, label="minsup=2500 (low)"),
    ]

    println("\n" * "="^70)
    println("  BENCHMARK — Index-BitTableFI vs Naive DFS  |  Dataset: Chess")
    println("  Kỹ thuật tối ưu: BitTable (BitVector) + Subsume Index (BFS+DFS)")
    println("="^70)

    for cfg in configs
        println("\n  [$( cfg.label )]")

        # Kiểm tra correctness trước
        res_index = index_bittablefi(transactions, cfg.minsup)
        res_naive = naive_dfs(transactions, cfg.minsup)
        @test length(res_index) == length(res_naive)

        n_itemsets = length(res_index)

        # Đo thời gian
        t_naive = measure_time(naive_dfs, transactions, cfg.minsup)
        t_index = measure_time(index_bittablefi, transactions, cfg.minsup)

        speedup     = t_naive / t_index
        improvement = (1.0 - t_index / t_naive) * 100.0

        # In kết quả
        println()
        println("  ┌────────────────────────┬──────────────┬──────────────┐")
        println("  │ Thuật toán             │ Thời gian    │ Speedup      │")
        println("  ├────────────────────────┼──────────────┼──────────────┤")
        @printf "  │ %-22s │ %8.4f s    │ %8.2fx     │\n" "Naive DFS (baseline)" t_naive 1.0
        @printf "  │ %-22s │ %8.4f s    │ %8.2fx  ↑  │\n" "Index-BitTableFI" t_index speedup
        println("  └────────────────────────┴──────────────┴──────────────┘")
        @printf "  Frequent itemsets: %d  |  Cải thiện tốc độ: %.1f%% nhanh hơn\n" n_itemsets improvement
    end

    println()
    println("="^70)
    println("  Ghi chú về kỹ thuật tối ưu hóa:")
    println("  • BitVector/BitArray: tính support bằng bitwise AND (64 bit/lệnh)")
    println("  • Subsume Index: output kết hợp subsume KHÔNG cần tính AND")
    println("  • Anti-monotone pruning: cắt nhánh sớm khi sup < minsup")
    println("="^70)
    println()

end
