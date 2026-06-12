# tests/runtests.jl
# Main test script — chạy toàn bộ test suite

using Test

println("="^60)
println("  Frequent Itemset Mining — Index-BitTableFI")
println("  Chạy toàn bộ test suite...")
println("="^60)

@testset "Index-BitTableFI Test Suite" begin
    include("test_correctness.jl")   # Correctness trên 5 CSDL
    include("test_report.jl")        # Báo cáo tỉ lệ đúng
    include("test_benchmark.jl")     # Benchmark tốc độ
end
