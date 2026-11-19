namespace Do_an_co_so.Models
{
    // Phân loại phòng cho bộ lọc của app. Giá trị 0 là Phòng riêng nên toàn bộ
    // tin đăng cũ (kể cả dữ liệu seed của đồ án cơ sở) tự hiểu là phòng riêng
    // mà không cần chạy UPDATE cho các dòng đã tồn tại.
    public enum LoaiHinhPhong
    {
        PhongRieng = 0,
        KyTucXa = 1
    }
}
