# src/association_rules.jl
# Module này thực hiện:
#   1. Sinh tất cả association rules từ tập frequent itemsets
#   2. Tính confidence và lift cho từng rule
#   3. Lọc và xếp hạng theo lift

# -----------------------------------------------------------------------------
# CẤU TRÚC DỮ LIỆU
# -----------------------------------------------------------------------------

"""
    AssociationRule

Biểu diễn một association rule X => Y với các độ đo:
- `antecedent` (X): tập điều kiện (vế trái)
- `consequent` (Y): tập kết quả (vế phải)
- `support`:    sup(X U Y) / N  — tỉ lệ xuất hiện của cả hai vế
- `confidence`: sup(X U Y) / sup(X) — xác suất Y xuất hiện khi có X
- `lift`:       confidence / sup(Y) — mức độ tương quan thực sự (> 1 là tích cực)
"""
struct AssociationRule
    antecedent::Vector{Int}
    consequent::Vector{Int}
    support::Float64
    confidence::Float64
    lift::Float64
end

# -----------------------------------------------------------------------------
# XÂY DỰNG LOOKUP TABLE
# -----------------------------------------------------------------------------

"""
    build_support_lookup(freq_itemsets, num_trans) -> Dict{Vector{Int}, Float64}

Xây dựng bảng tra cứu support (dạng tương đối) từ danh sách frequent itemsets.
Key là itemset đã được sort để đảm bảo tính nhất quán khi tra cứu.
"""
function build_support_lookup(
    freq_itemsets::Vector{Tuple{Vector{Int},Int}},
    num_trans::Int
)::Dict{Vector{Int},Float64}
    lookup = Dict{Vector{Int},Float64}()
    for (itemset, count) in freq_itemsets
        key = sort(itemset)
        lookup[key] = count / num_trans
    end
    return lookup
end

# -----------------------------------------------------------------------------
# SINH TẤT CẢ NONEMPTY PROPER SUBSETS
# -----------------------------------------------------------------------------

"""
    proper_nonempty_subsets(items) -> Vector{Vector{Int}}

Sinh tất cả các tập con không rỗng và không phải chính nó (proper subsets).
Được dùng để liệt kê tất cả các cách chia X U Y thành (antecedent, consequent).

Với itemset có k phần tử, có 2^k - 2 proper nonempty subsets.
Giới hạn k ≤ 20 để tránh bùng nổ tổ hợp.
"""
function proper_nonempty_subsets(items::Vector{Int})::Vector{Vector{Int}}
    k = length(items)
    result = Vector{Vector{Int}}()
    # mask từ 1 đến 2^k - 2  (bỏ mask=0 và mask=2^k-1)
    for mask in 1:(1 << k) - 2
        subset = Int[]
        for bit in 0:(k-1)
            if (mask >> bit) & 1 == 1
                push!(subset, items[bit+1])
            end
        end
        push!(result, subset)
    end
    return result
end

# -----------------------------------------------------------------------------
# SINH ASSOCIATION RULES
# -----------------------------------------------------------------------------

"""
    generate_rules(freq_itemsets, num_trans; minconf, max_itemset_size) -> Vector{AssociationRule}

Sinh tất cả association rules từ tập frequent itemsets với:
- `minconf`: ngưỡng confidence tối thiểu (mặc định 0.5)
- `max_itemset_size`: giới hạn kích thước itemset được xét để tránh bùng nổ tổ hợp

  Với mỗi frequent itemset F có |F| ≥ 2:
    Với mỗi nonempty proper subset X ⊂ F:
      Y = F \\ X
      confidence = sup(F) / sup(X)
      lift = confidence / sup(Y)
      Nếu confidence ≥ minconf -> ghi nhận rule X => Y
"""
function generate_rules(
    freq_itemsets::Vector{Tuple{Vector{Int},Int}},
    num_trans::Int;
    minconf::Float64 = 0.5,
    max_itemset_size::Int = 10
)::Vector{AssociationRule}

    support_map = build_support_lookup(freq_itemsets, num_trans)
    rules = AssociationRule[]

    for (itemset, count) in freq_itemsets
        k = length(itemset)
        # Chỉ xét itemsets có ít nhất 2 item và không vượt quá max_itemset_size
        k < 2 && continue
        k > max_itemset_size && continue

        sup_full = count / num_trans
        sorted_itemset = sort(itemset)

        for antecedent in proper_nonempty_subsets(sorted_itemset)
            consequent = setdiff(sorted_itemset, antecedent)
            isempty(consequent) && continue

            sup_ant = get(support_map, sort(antecedent), 0.0)
            sup_ant == 0.0 && continue

            conf = sup_full / sup_ant

            if conf >= minconf
                sup_con = get(support_map, sort(consequent), 0.0)
                lft = sup_con > 0.0 ? conf / sup_con : 0.0

                push!(rules, AssociationRule(
                    sort(antecedent),
                    sort(consequent),
                    sup_full,
                    conf,
                    lft
                ))
            end
        end
    end

    return rules
end

# -----------------------------------------------------------------------------
# TIỆN ÍCH HIỂN THỊ
# -----------------------------------------------------------------------------

"""
    top_rules_by_lift(rules, n) -> Vector{AssociationRule}

Lấy top-n rules có lift cao nhất.
Tie-breaking theo confidence giảm dần, sau đó support giảm dần.
"""
function top_rules_by_lift(rules::Vector{AssociationRule}, n::Int=10)::Vector{AssociationRule}
    sorted = sort(rules, by = r -> (-r.lift, -r.confidence, -r.support))
    return first(sorted, min(n, length(sorted)))
end

"""
    format_rule(rule, item_names) -> String

Format một rule thành chuỗi 
Nếu có `item_names` (Dict{Int,String}), sẽ hiển thị tên item thay vì ID.
"""
function format_rule(rule::AssociationRule, item_names::Dict{Int,String}=Dict{Int,String}())::String
    fmt_items(items) = if isempty(item_names)
        "{" * join(items, ", ") * "}"
    else
        "{" * join([get(item_names, i, string(i)) for i in items], ", ") * "}"
    end

    ant_str = fmt_items(rule.antecedent)
    con_str = fmt_items(rule.consequent)
    @sprintf("%-40s =>  %-20s  sup=%.4f  conf=%.4f  lift=%.4f",
             ant_str, con_str, rule.support, rule.confidence, rule.lift)
end

"""
    print_top_rules(rules, n; item_names)

In top-n rules theo lift ra stdout 
"""
function print_top_rules(
    rules::Vector{AssociationRule},
    n::Int = 10;
    item_names::Dict{Int,String} = Dict{Int,String}()
)
    top = top_rules_by_lift(rules, n)
    println("\n╔══════════════════════════════════════════════════════════════════════════╗")
    println("║              TOP-$(lpad(n,2)) ASSOCIATION RULES (theo Lift)                  ║")
    println("╠══════════════════════════════════════════════════════════════════════════╣")
    println("║  #   Antecedent => Consequent                    Sup     Conf    Lift   ║")
    println("╠══════════════════════════════════════════════════════════════════════════╣")
    for (i, rule) in enumerate(top)
        ant = isempty(item_names) ? join(rule.antecedent, " ") : join([get(item_names, x, string(x)) for x in rule.antecedent], " ")
        con = isempty(item_names) ? join(rule.consequent, " ") : join([get(item_names, x, string(x)) for x in rule.consequent], " ")
        @printf("║  %-3d {%-18s} => {%-12s}  %.4f  %.4f  %.4f ║\n",
                i, ant, con, rule.support, rule.confidence, rule.lift)
    end
    println("╚══════════════════════════════════════════════════════════════════════════╝")
end
