# tests/verify_benchmarks.jl

# Hàm đọc file output chuẩn SPMF và chuyển thành Dict{Set{Int}, Int}
function parse_spmf_output(filepath)
    dict = Dict{Set{Int}, Int}()
    if !isfile(filepath)
        return nothing # Trả về nothing nếu chưa chạy/thiếu file
    end
    
    for line in eachline(filepath)
        line = strip(line)
        if isempty(line) continue end
        
        parts = split(line, "#SUP:")
        if length(parts) == 2
            # Chuyển chuỗi "1 2 3" thành mảng số nguyên, rồi ném vào Set
            items = parse.(Int, split(strip(parts[1])))
            sup = parse(Int, strip(parts[2]))
            dict[Set(items)] = sup
        end
    end
    return dict
end

# Hàm so sánh và in dòng kết quả của bảng
function compare_and_print(dataset_name, minsup_val, spmf_file, julia_file)
    spmf_dict = parse_spmf_output(spmf_file)
    julia_dict = parse_spmf_output(julia_file)
    
    if spmf_dict === nothing || julia_dict === nothing
        println("| $dataset_name | $minsup_val | Thiếu file output | Thiếu file output | N/A |")
        return
    end
    
    len_spmf = length(spmf_dict)
    len_julia = length(julia_dict)
    
    # Kiểm tra xem 2 dictionary có khớp nhau 100% cả về key và value không
    is_match = (spmf_dict == julia_dict)
    match_str = is_match ? "100%" : "LỆCH!"
    
    println("| $dataset_name | $minsup_val | $len_spmf | $len_julia | $match_str |\n")
end

# --- CHƯƠNG TRÌNH CHÍNH ---
println("ĐANG KIỂM TRA TÍNH ĐÚNG ĐẮN CỦA CÁC TẬP BENCHMARK...\n")
println("| Tập dữ liệu | Minsup | FIs (SPMF) | FIs (Nhóm) | Tỉ lệ khớp (%) |\n")


# 1. Chess
compare_and_print("Chess", "2557 (80%)", 
    "output_nhom_chess.txt", 
    "output_spmf_chess.txt")

# 2. Mushroom 
compare_and_print("Mushroom", "1683 (20%)", 
    "output_nhom_mushrooms.txt", 
    "output_spmf_mushrooms.txt")

# 3. Retail
compare_and_print("Retail", "882 (1%)", 
    "output_nhom_retail.txt", 
    "output_spmf_retail.txt")
	
# 4. Accident
compare_and_print("Accident", "272146(80%)", 
    "output_nhom_accidents.txt", 
    "output_spmf_accidents.txt")

println("\nHoàn tất kiểm tra!")