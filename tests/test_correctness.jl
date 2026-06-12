# tests/test_correctness.jl
# Kiểm tra tính đúng đắn của thuật toán Index-BitTableFI
# trên 5 CSDL khác nhau (bao gồm 2 CSDL từ chương 2)
#
# Ánh xạ item:
#   paper_example: 1=A, 2=B, 3=C, 4=D, 5=E, 6=F, 7=G
#   simple:        items 1–5
#   VD1 (chương 2): A=1, B=2, C=3, D=4, E=5
#   VD2 (chương 2): M=1, N=2, P=3, X=4, Y=5
#   chess:         items là số nguyên (75 items thực tế)

using Test
include("../src/utils.jl")
include("../src/algorithm/index_bittablefi.jl")
include("../src/algorithm/naive_dfs.jl")

function results_to_dict(results)
    return Dict(Set(itemset) => sup for (itemset, sup) in results)
end

@testset "Correctness Tests — 5 Datasets" begin

    # =========================================================================
    # CSDL 1: Paper Example (Table 1) — minsup = 2
    # =========================================================================
    # DB: 10 transactions, 7 frequent items (A,B,C,D,E,F,G)
    # Kết quả: 43 frequent itemsets
    @testset "CSDL 1: Paper Example (minsup=2)" begin
        transactions = read_spmf("data/toy/paper_example.txt")
        minsup = 2

        results  = index_bittablefi(transactions, minsup)
        res_dict = results_to_dict(results)

        # Tổng số
        @test length(results) == 43

        # 1-itemsets (support của 7 frequent items)
        @test res_dict[Set([2])] == 2   # B
        @test res_dict[Set([6])] == 2   # F
        @test res_dict[Set([4])] == 2   # D
        @test res_dict[Set([1])] == 8   # A
        @test res_dict[Set([3])] == 8   # C
        @test res_dict[Set([5])] == 8   # E
        @test res_dict[Set([7])] == 5   # G

        # Theorem 2: subsume(B) = {F,A,C,E} → {B}∪S frequent với mọi S⊆{F,A,C,E}
        @test res_dict[Set([2,6])]       == 2   # BF
        @test res_dict[Set([2,1])]       == 2   # BA
        @test res_dict[Set([2,6,1,3,5])] == 2   # BFACE

        # G có DFS → {G,E} và các combinations
        @test res_dict[Set([7,5])]     == 4   # GE
        @test res_dict[Set([7,1,5])]   == 4   # GAE
        @test res_dict[Set([7,3,5])]   == 4   # GCE

        # Output phải sắp xếp tăng dần
        for (itemset, _) in results
            @test issorted(itemset)
        end

        # Nhất quán với naive_dfs
        naive_res  = naive_dfs(transactions, minsup)
        @test Set(Set.(map(first, results))) == Set(Set.(map(first, naive_res)))
    end

    # =========================================================================
    # CSDL 2: Simple Toy Dataset — minsup = 3
    # =========================================================================
    # DB: 6 transactions
    #   1 2 3 | 1 2 4 | 1 3 4 | 1 2 3 4 | 2 3 5 | 1 3 5
    # Kết quả: 9 frequent itemsets
    @testset "CSDL 2: Simple Toy (minsup=3)" begin
        transactions = read_spmf("data/toy/simple.txt")
        minsup = 3

        results  = index_bittablefi(transactions, minsup)
        res_dict = results_to_dict(results)

        # 1-itemsets (item 5 có sup=2 → NOT frequent)
        @test res_dict[Set([1])] == 5
        @test res_dict[Set([2])] == 4
        @test res_dict[Set([3])] == 5
        @test res_dict[Set([4])] == 3
        @test !haskey(res_dict, Set([5]))   # item 5: sup=2

        # 2-itemsets
        @test res_dict[Set([1,2])] == 3
        @test res_dict[Set([1,3])] == 4
        @test res_dict[Set([2,3])] == 3
        @test res_dict[Set([1,4])] == 3

        # {1,2,3}: sup=2 → NOT frequent
        @test !haskey(res_dict, Set([1,2,3]))

        # Tổng: 4 singleton + 4 pairs = 8 (không có 3-itemset nào đạt sup≥3)
        @test length(results) == 8

        # Nhất quán với naive_dfs
        naive_res = naive_dfs(transactions, minsup)
        @test Set(Set.(map(first, results))) == Set(Set.(map(first, naive_res)))
    end

    # =========================================================================
    # CSDL 3: VD1 Chương 2 — minsup = 3
    # =========================================================================
    # DB: 6 transactions, items A=1,B=2,C=3,D=4,E=5
    #   T1: A,B,C,E | T2: B,C,D | T3: A,B,C,D
    #   T4: A,C,E   | T5: A,B,C,E | T6: B,D
    # Kết quả: 13 frequent itemsets
    @testset "CSDL 3: VD1 Chương 2 (minsup=3)" begin
        transactions = read_spmf("data/toy/VD1_spmf.txt")
        minsup = 3

        results  = index_bittablefi(transactions, minsup)
        res_dict = results_to_dict(results)

        # Tổng: 5 + 6 + 2 = 13
        @test length(results) == 13

        # 1-itemsets
        @test res_dict[Set([1])] == 4   # A
        @test res_dict[Set([2])] == 5   # B
        @test res_dict[Set([3])] == 5   # C
        @test res_dict[Set([4])] == 3   # D
        @test res_dict[Set([5])] == 3   # E

        # 2-itemsets frequent (sup ≥ 3)
        @test res_dict[Set([1,2])] == 3   # AB
        @test res_dict[Set([1,3])] == 4   # AC
        @test res_dict[Set([1,5])] == 3   # AE
        @test res_dict[Set([2,3])] == 4   # BC
        @test res_dict[Set([2,4])] == 3   # BD
        @test res_dict[Set([3,5])] == 3   # CE

        # 3-itemsets
        @test res_dict[Set([1,2,3])] == 3   # ABC
        @test res_dict[Set([1,3,5])] == 3   # ACE

        # NOT frequent (sup < 3)
        @test !haskey(res_dict, Set([3,4]))   # CD: sup=2
        @test !haskey(res_dict, Set([2,5]))   # BE: sup=2
        @test !haskey(res_dict, Set([1,4]))   # AD: sup=1
        @test !haskey(res_dict, Set([4,5]))   # DE: sup=0

        # Nhất quán với naive_dfs
        naive_res = naive_dfs(transactions, minsup)
        @test Set(Set.(map(first, results))) == Set(Set.(map(first, naive_res)))
    end

    # =========================================================================
    # CSDL 4: VD2 Chương 2 — minsup = 2
    # =========================================================================
    # DB: 4 transactions, items M=1,N=2,P=3,X=4,Y=5
    #   T1: M,N,P,X | T2: M,N,P,Y | T3: M,N,P,X,Y | T4: M,N,P
    # Kết quả: 23 frequent itemsets
    @testset "CSDL 4: VD2 Chương 2 (minsup=2)" begin
        transactions = read_spmf("data/toy/VD2_spmf.txt")
        minsup = 2

        results  = index_bittablefi(transactions, minsup)
        res_dict = results_to_dict(results)

        # Tổng: 5 + 9 + 7 + 2 = 23
        @test length(results) == 23

        # 1-itemsets
        @test res_dict[Set([1])] == 4   # M
        @test res_dict[Set([2])] == 4   # N
        @test res_dict[Set([3])] == 4   # P
        @test res_dict[Set([4])] == 2   # X
        @test res_dict[Set([5])] == 2   # Y

        # 2-itemsets (9 tập)
        @test res_dict[Set([1,2])] == 4   # MN
        @test res_dict[Set([1,3])] == 4   # MP
        @test res_dict[Set([2,3])] == 4   # NP
        @test res_dict[Set([1,4])] == 2   # XM
        @test res_dict[Set([2,4])] == 2   # XN
        @test res_dict[Set([3,4])] == 2   # XP
        @test res_dict[Set([1,5])] == 2   # YM
        @test res_dict[Set([2,5])] == 2   # YN
        @test res_dict[Set([3,5])] == 2   # YP

        # 3-itemsets (7 tập)
        @test res_dict[Set([1,2,3])] == 4   # MNP
        @test res_dict[Set([1,2,4])] == 2   # XMN
        @test res_dict[Set([1,3,4])] == 2   # XMP
        @test res_dict[Set([2,3,4])] == 2   # XNP
        @test res_dict[Set([1,2,5])] == 2   # YMN
        @test res_dict[Set([1,3,5])] == 2   # YMP
        @test res_dict[Set([2,3,5])] == 2   # YNP

        # 4-itemsets (2 tập)
        @test res_dict[Set([1,2,3,4])] == 2   # XMNP
        @test res_dict[Set([1,2,3,5])] == 2   # YMNP

        # NOT frequent: tất cả tập chứa cả X lẫn Y (sup=1)
        @test !haskey(res_dict, Set([4,5]))         # XY
        @test !haskey(res_dict, Set([1,2,3,4,5]))   # MNPXY

        # Nhất quán với naive_dfs
        naive_res = naive_dfs(transactions, minsup)
        @test Set(Set.(map(first, results))) == Set(Set.(map(first, naive_res)))
    end

    # =========================================================================
    # CSDL 5: Chess Dataset — minsup = 2900
    # =========================================================================
    # DB: 3196 transactions, 75 items (dense dataset)
    # Dùng naive_dfs làm ground truth để kiểm tra tính nhất quán
    @testset "CSDL 5: Chess (minsup=2900)" begin
        chess_path = "data/toy/chess.txt"
        transactions = read_spmf(chess_path)
        minsup = 2900

        @test length(transactions) == 3196   # Xác nhận đọc đúng số transactions

        results_index = index_bittablefi(transactions, minsup)
        results_naive = naive_dfs(transactions, minsup)

        # Số lượng itemsets phải bằng nhau
        @test length(results_index) == length(results_naive)

        # Tập itemsets phải giống nhau hoàn toàn
        index_sets = Set(Set.(map(first, results_index)))
        naive_sets = Set(Set.(map(first, results_naive)))
        @test index_sets == naive_sets

        # Mọi support đều ≥ minsup
        for (_, sup) in results_index
            @test sup >= minsup
        end

        # Output phải sắp xếp tăng dần
        for (itemset, _) in results_index
            @test issorted(itemset)
        end
    end

    # =========================================================================
    # Edge Cases
    # =========================================================================
    @testset "Edge Cases" begin
        # Database rỗng
        @test isempty(index_bittablefi(Vector{Vector{Int}}(), 1))

        # minsup lớn hơn tất cả support
        transactions = [[1, 2], [1, 3]]
        @test isempty(index_bittablefi(transactions, 3))

        # Chỉ có 1 item lặp lại
        transactions = [[1], [1], [1]]
        results = index_bittablefi(transactions, 2)
        @test length(results) == 1
        @test results[1] == ([1], 3)
    end

end
