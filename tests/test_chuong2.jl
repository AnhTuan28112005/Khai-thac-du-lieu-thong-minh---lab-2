# tests/test_chuong2.jl
# Unit tests cho dữ liệu chương 2 (VD1, VD2)
#
# Ánh xạ item:
#   VD1: A=1, B=2, C=3, D=4, E=5
#   VD2: M=1, N=2, P=3, X=4, Y=5

using Test
include("../src/utils.jl")
include("../src/algorithm/index_bittablefi.jl")

# Helper: chuyển kết quả thành Dict{Set => support} để dễ tra cứu
function results_to_dict(results)
    return Dict(Set(itemset) => sup for (itemset, sup) in results)
end

# ─────────────────────────────────────────────────────────────────────────────
# VD1
# ─────────────────────────────────────────────────────────────────────────────
#
# Database VD1 (file: data/toy_chuong2/toy/VD1.csv):
#   TID | Items
#   ----|----------------
#   T1  | A, B, C, E
#   T2  | B, C, D
#   T3  | A, B, C, D
#   T4  | A, C, E
#   T5  | A, B, C, E
#   T6  | B, D
#
# Ánh xạ sang số nguyên (SPMF): A=1, B=2, C=3, D=4, E=5
# File SPMF tương ứng: data/toy_chuong2/toy/VD1_spmf.txt
# min_sup = 3
#
# Support từng item:
#   A(1): T1,T3,T4,T5       → sup = 4  (frequent ✓)
#   B(2): T1,T2,T3,T5,T6    → sup = 5  (frequent ✓)
#   C(3): T1,T2,T3,T4,T5    → sup = 5  (frequent ✓)
#   D(4): T2,T3,T6           → sup = 3  (frequent ✓)
#   E(5): T1,T4,T5           → sup = 3  (frequent ✓)
#
# Kết quả đúng (13 frequent itemsets):
#   1-itemset (5): A:4, B:5, C:5, D:3, E:3
#   2-itemset (6): AB:3, AC:4, AE:3, BC:4, BD:3, CE:3
#   3-itemset (2): ABC:3, ACE:3
# ─────────────────────────────────────────────────────────────────────────────

@testset "VD1 — Ví dụ chương 2 (min_sup=3)" begin
    transactions = read_spmf("data/toy_chuong2/toy/VD1_spmf.txt")
    minsup = 3

    @test length(transactions) == 6   # 6 giao dịch

    results  = index_bittablefi(transactions, minsup)
    res_dict = results_to_dict(results)

    # ── 1-itemsets ──────────────────────────────────────────────────────────
    @test res_dict[Set([1])] == 4   # A
    @test res_dict[Set([2])] == 5   # B
    @test res_dict[Set([3])] == 5   # C
    @test res_dict[Set([4])] == 3   # D
    @test res_dict[Set([5])] == 3   # E

    # ── 2-itemsets frequent (sup ≥ 3) ───────────────────────────────────────
    # AB: T1,T3,T5 → sup=3
    @test res_dict[Set([1,2])] == 3
    # AC: T1,T3,T4,T5 → sup=4
    @test res_dict[Set([1,3])] == 4
    # AE: T1,T4,T5 → sup=3
    @test res_dict[Set([1,5])] == 3
    # BC: T1,T2,T3,T5 → sup=4
    @test res_dict[Set([2,3])] == 4
    # BD: T2,T3,T6 → sup=3
    @test res_dict[Set([2,4])] == 3
    # CE: T1,T4,T5 → sup=3
    @test res_dict[Set([3,5])] == 3

    # ── 3-itemsets frequent (sup ≥ 3) ───────────────────────────────────────
    # ABC: T1,T3,T5 → sup=3
    @test res_dict[Set([1,2,3])] == 3
    # ACE: T1,T4,T5 → sup=3
    @test res_dict[Set([1,3,5])] == 3

    # ── Kiểm tra tổng số: 5 + 6 + 2 = 13 frequent itemsets ─────────────────
    @test length(results) == 13

    # ── Itemsets KHÔNG frequent (sup < 3) ───────────────────────────────────
    # CD: T2,T3 → sup=2 < 3
    @test !haskey(res_dict, Set([3,4]))
    # BE: T1,T5 → sup=2 < 3
    @test !haskey(res_dict, Set([2,5]))
    # AD: T3 → sup=1
    @test !haskey(res_dict, Set([1,4]))
    # DE: không có TID nào chứa cả D lẫn E → sup=0
    @test !haskey(res_dict, Set([4,5]))
    # ABD: T3 → sup=1
    @test !haskey(res_dict, Set([1,2,4]))

    # ── Kiểm tra tính nhất quán: đồng nhất với naive_dfs ───────────────────
    include("../src/algorithm/naive_dfs.jl")
    naive_res  = naive_dfs(transactions, minsup)
    index_sets = Set(Set.(map(first, results)))
    naive_sets = Set(Set.(map(first, naive_res)))
    @test index_sets == naive_sets   # Hai thuật toán cho cùng tập kết quả

    # ── Kiểm tra output được sắp xếp tăng dần ───────────────────────────────
    for (itemset, _) in results
        @test issorted(itemset)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# VD2
# ─────────────────────────────────────────────────────────────────────────────
#
# Database VD2 (file: data/toy_chuong2/toy/VD2.csv):
#   TID | Items
#   ----|------------------
#   T1  | M, N, P, X
#   T2  | M, N, P, Y
#   T3  | M, N, P, X, Y
#   T4  | M, N, P
#
# Ánh xạ sang số nguyên (SPMF): M=1, N=2, P=3, X=4, Y=5
# File SPMF tương ứng: data/toy_chuong2/toy/VD2_spmf.txt
# min_sup = 2
#
# Support từng item:
#   M(1): T1,T2,T3,T4 → sup = 4  (frequent ✓)
#   N(2): T1,T2,T3,T4 → sup = 4  (frequent ✓)
#   P(3): T1,T2,T3,T4 → sup = 4  (frequent ✓)
#   X(4): T1,T3       → sup = 2  (frequent ✓)
#   Y(5): T2,T3       → sup = 2  (frequent ✓)
#
# Đặc điểm: {M,N,P} đồng xuất hiện trong mọi transaction
#   → Theorem 2: mọi subset của {M,N,P} kết hợp với X hoặc Y đều frequent
#   Lưu ý: {X,Y} chỉ có trong T3 → sup=1 → NOT frequent!
#          → Mọi tập chứa CẢ X lẫn Y đều NOT frequent
#
# Kết quả đúng (23 frequent itemsets):
#   1-itemset (5): X:2, Y:2, M:4, N:4, P:4
#   2-itemset (9): XM:2, XN:2, XP:2, YM:2, YN:2, YP:2, MN:4, MP:4, NP:4
#   3-itemset (7): XMN:2, XMP:2, XNP:2, YMN:2, YMP:2, YNP:2, MNP:4
#   4-itemset (2): XMNP:2, YMNP:2
# ─────────────────────────────────────────────────────────────────────────────

@testset "VD2 — Ví dụ chương 2 (min_sup=2)" begin
    transactions = read_spmf("data/toy_chuong2/toy/VD2_spmf.txt")
    minsup = 2

    @test length(transactions) == 4   # 4 giao dịch

    results  = index_bittablefi(transactions, minsup)
    res_dict = results_to_dict(results)

    # ── 1-itemsets ──────────────────────────────────────────────────────────
    @test res_dict[Set([1])] == 4   # M
    @test res_dict[Set([2])] == 4   # N
    @test res_dict[Set([3])] == 4   # P
    @test res_dict[Set([4])] == 2   # X
    @test res_dict[Set([5])] == 2   # Y

    # ── 2-itemsets (9 tập) ──────────────────────────────────────────────────
    # {M,N}, {M,P}, {N,P} — cùng sup=4 theo Theorem 2 (subsume index)
    @test res_dict[Set([1,2])] == 4   # MN
    @test res_dict[Set([1,3])] == 4   # MP
    @test res_dict[Set([2,3])] == 4   # NP
    # {X,M}, {X,N}, {X,P} — T1,T3 → sup=2
    @test res_dict[Set([1,4])] == 2   # XM
    @test res_dict[Set([2,4])] == 2   # XN
    @test res_dict[Set([3,4])] == 2   # XP
    # {Y,M}, {Y,N}, {Y,P} — T2,T3 → sup=2
    @test res_dict[Set([1,5])] == 2   # YM
    @test res_dict[Set([2,5])] == 2   # YN
    @test res_dict[Set([3,5])] == 2   # YP

    # ── 3-itemsets (7 tập) ──────────────────────────────────────────────────
    # {M,N,P} — sup=4
    @test res_dict[Set([1,2,3])] == 4   # MNP
    # Kết hợp X với {M,N}, {M,P}, {N,P} — T1,T3 → sup=2
    @test res_dict[Set([1,2,4])] == 2   # XMN
    @test res_dict[Set([1,3,4])] == 2   # XMP
    @test res_dict[Set([2,3,4])] == 2   # XNP
    # Kết hợp Y với {M,N}, {M,P}, {N,P} — T2,T3 → sup=2
    @test res_dict[Set([1,2,5])] == 2   # YMN
    @test res_dict[Set([1,3,5])] == 2   # YMP
    @test res_dict[Set([2,3,5])] == 2   # YNP

    # ── 4-itemsets (2 tập) ──────────────────────────────────────────────────
    @test res_dict[Set([1,2,3,4])] == 2   # XMNP — T1,T3 → sup=2
    @test res_dict[Set([1,2,3,5])] == 2   # YMNP — T2,T3 → sup=2

    # ── Itemsets KHÔNG frequent ──────────────────────────────────────────────
    # Tất cả tập chứa CẢ X lẫn Y: tidset(X)∩tidset(Y) = {T3} → sup=1 < 2
    # (từ ảnh: XY:1, XYM:1, XYN:1, XYP:1, XYMN:1, XYMP:1, XYNP:1, XYMNP:1)
    @test !haskey(res_dict, Set([4,5]))         # XY
    @test !haskey(res_dict, Set([1,4,5]))       # MXY
    @test !haskey(res_dict, Set([2,4,5]))       # NXY
    @test !haskey(res_dict, Set([3,4,5]))       # PXY
    @test !haskey(res_dict, Set([1,2,4,5]))     # MNXY
    @test !haskey(res_dict, Set([1,3,4,5]))     # MPXY
    @test !haskey(res_dict, Set([2,3,4,5]))     # NPXY
    @test !haskey(res_dict, Set([1,2,3,4,5]))   # MNPXY

    # ── Kiểm tra tổng số itemsets ────────────────────────────────────────────
    # 1-itemset(5) + 2-itemset(9) + 3-itemset(7) + 4-itemset(2) = 23
    @test length(results) == 23

    # ── Kiểm tra tính nhất quán: đồng nhất với naive_dfs ───────────────────
    include("../src/algorithm/naive_dfs.jl")
    naive_res  = naive_dfs(transactions, minsup)
    index_sets = Set(Set.(map(first, results)))
    naive_sets = Set(Set.(map(first, naive_res)))
    @test index_sets == naive_sets

    # ── Kiểm tra output được sắp xếp tăng dần ───────────────────────────────
    for (itemset, _) in results
        @test issorted(itemset)
    end
end
