# Thí nghiệm cho báo cáo

Thư mục này tự động hóa các thí nghiệm cần thiết cho báo cáo.

## Chạy kiểm tra nhanh

```powershell
julia --project=. experiments/run_report_experiments.jl
```

Chế độ nhanh dùng các bộ dữ liệu nhỏ để bạn kiểm tra xem bảng CSV và biểu đồ có
được tạo đúng hay không.

## Chạy đầy đủ cho báo cáo

```powershell
$env:REPORT_MODE="full"
julia --project=. experiments/run_report_experiments.jl
```

Chế độ đầy đủ dùng các bộ dữ liệu benchmark được cấu hình trong
`experiments/run_report_experiments.jl`.

## Bật so sánh với SPMF

Đặt `spmf.jar` vào `tools/spmf.jar`, hoặc khai báo rõ đường dẫn đến file jar:

```powershell
$env:SPMF_JAR="D:\path\to\spmf.jar"
$env:SPMF_ALGORITHM="FPGrowth_itemsets"
$env:SPMF_MINSUP_MODE="absolute"
julia --project=. experiments/run_report_experiments.jl
```

Nếu lệnh SPMF của bạn yêu cầu minsup dạng tương đối hoặc phần trăm, dùng:

```powershell
$env:SPMF_MINSUP_MODE="relative"
# or
$env:SPMF_MINSUP_MODE="percent"
```

## Kết quả đầu ra

- Bảng CSV: `experiments/results/`
- Biểu đồ PNG: `experiments/figures/`
- Kết quả itemset được sinh ra: `experiments/outputs/`
- Bộ dữ liệu con/tổng hợp được sinh ra: `experiments/generated/`

Theo mặc định, `memory.csv` báo cáo lượng bộ nhớ do Julia cấp phát. Để đo thêm
RSS cao nhất của tiến trình, chạy với:

```powershell
$env:MEASURE_PEAK="1"
julia --project=. experiments/run_report_experiments.jl
```

Các file CSV chính:

- `correctness.csv`
- `runtime_by_minsup.csv`
- `itemsets_by_minsup.csv`
- `memory.csv`
- `scalability.csv`
- `transaction_length.csv`
