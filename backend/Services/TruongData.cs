using Do_an_co_so.Models;

namespace Do_an_co_so.Services
{
    // Danh sách trường dùng chung giữa web (đồ án cơ sở) và API của app di động,
    // để hai bên không lệch tọa độ khi tính khoảng cách tìm trọ.
    public static class TruongData
    {
        public static List<TruongDaiHoc> GetAll() => new()
        {
            new TruongDaiHoc { Id = "hutech_dbp", TenTruong = "HUTECH - Saigon Campus (Điện Biên Phủ)", Latitude = 10.8018, Longitude = 106.7115, LoaiTruong = "Đại học", Quan = "Bình Thạnh" },
            new TruongDaiHoc { Id = "hutech_uvk", TenTruong = "HUTECH - Ung Văn Khiêm Campus", Latitude = 10.8055, Longitude = 106.7145, LoaiTruong = "Đại học", Quan = "Bình Thạnh" },
            new TruongDaiHoc { Id = "vlu_cs2", TenTruong = "Đại học Văn Lang - Cơ sở 2 (Đinh Bộ Lĩnh)", Latitude = 10.8118, Longitude = 106.7081, LoaiTruong = "Đại học", Quan = "Bình Thạnh" },
            new TruongDaiHoc { Id = "hiu", TenTruong = "ĐH Quốc tế Hồng Bàng (HIU - Tòa nhà con tàu)", Latitude = 10.8000, Longitude = 106.7025, LoaiTruong = "Đại học", Quan = "Bình Thạnh" },
            new TruongDaiHoc { Id = "gtvt", TenTruong = "ĐH Giao thông Vận tải (Cơ sở chính)", Latitude = 10.8043, Longitude = 106.7190, LoaiTruong = "Đại học", Quan = "Bình Thạnh" },
            new TruongDaiHoc { Id = "ftu2", TenTruong = "ĐH Ngoại thương (Cơ sở 2)", Latitude = 10.8048, Longitude = 106.7169, LoaiTruong = "Đại học", Quan = "Bình Thạnh" },
            new TruongDaiHoc { Id = "uef", TenTruong = "ĐH Kinh tế - Tài chính (UEF)", Latitude = 10.7956, Longitude = 106.7001, LoaiTruong = "Đại học", Quan = "Bình Thạnh" },
            new TruongDaiHoc { Id = "hutech_td", TenTruong = "HUTECH - Thu Đức Campus (Khu E Làng ĐH)", Latitude = 10.8558, Longitude = 106.7851, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "hcmut_td", TenTruong = "ĐH Bách Khoa - Cơ sở Dĩ An (Làng ĐH)", Latitude = 10.8804, Longitude = 106.8053, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "spkt", TenTruong = "ĐH Sư Phạm Kỹ Thuật TP.HCM", Latitude = 10.8505, Longitude = 106.7720, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "nlu", TenTruong = "ĐH Nông Lâm TP.HCM", Latitude = 10.8697, Longitude = 106.7938, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "uit", TenTruong = "ĐH Công nghệ Thông tin (UIT)", Latitude = 10.8700, Longitude = 106.8031, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "hcmus_td", TenTruong = "ĐH Khoa học Tự nhiên (Cơ sở Làng ĐH)", Latitude = 10.8761, Longitude = 106.7979, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "buh", TenTruong = "ĐH Ngân hàng TP.HCM", Latitude = 10.8566, Longitude = 106.7621, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "uel", TenTruong = "ĐH Kinh tế - Luật (UEL)", Latitude = 10.8719, Longitude = 106.7984, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "fpt_hcm", TenTruong = "Đại học FPT TP.HCM (Khu Công Nghệ Cao)", Latitude = 10.8411, Longitude = 106.8099, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "hcmulaw_td", TenTruong = "Đại học Luật TP.HCM (Cơ sở Bình Triệu)", Latitude = 10.8266, Longitude = 106.7126, LoaiTruong = "Đại học", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "vlu_cs3", TenTruong = "Đại học Văn Lang - Cơ sở 3 (Gò Vấp)", Latitude = 10.8222, Longitude = 106.6874, LoaiTruong = "Đại học", Quan = "Gò Vấp" },
            new TruongDaiHoc { Id = "iuh", TenTruong = "ĐH Công nghiệp TP.HCM (IUH)", Latitude = 10.8225, Longitude = 106.6875, LoaiTruong = "Đại học", Quan = "Gò Vấp" },
            new TruongDaiHoc { Id = "ou_gv", TenTruong = "Đại học Mở TP.HCM (Cơ sở Nguyễn Kiệm)", Latitude = 10.8165, Longitude = 106.6775, LoaiTruong = "Đại học", Quan = "Gò Vấp" },
            new TruongDaiHoc { Id = "ueh_q3", TenTruong = "ĐH Kinh tế TP.HCM (UEH - Cơ sở chính)", Latitude = 10.7828, Longitude = 106.6925, LoaiTruong = "Đại học", Quan = "Quận 3" },
            new TruongDaiHoc { Id = "uah", TenTruong = "ĐH Kiến trúc TP.HCM", Latitude = 10.7831, Longitude = 106.6946, LoaiTruong = "Đại học", Quan = "Quận 3" },
            new TruongDaiHoc { Id = "hsu", TenTruong = "Đại học Hoa Sen (Trụ sở chính)", Latitude = 10.7712, Longitude = 106.6923, LoaiTruong = "Đại học", Quan = "Quận 1" },
            new TruongDaiHoc { Id = "ussh_q1", TenTruong = "ĐH KHXH & Nhân văn (Cơ sở Đinh Tiên Hoàng)", Latitude = 10.7860, Longitude = 106.7011, LoaiTruong = "Đại học", Quan = "Quận 1" },
            new TruongDaiHoc { Id = "hcmulaw_q4", TenTruong = "Đại học Luật TP.HCM (Cơ sở Nguyễn Tất Thành)", Latitude = 10.7629, Longitude = 106.7088, LoaiTruong = "Đại học", Quan = "Quận 4" },
            new TruongDaiHoc { Id = "ntt_q4", TenTruong = "Đại học Nguyễn Tất Thành (Trụ sở chính)", Latitude = 10.7615, Longitude = 106.7103, LoaiTruong = "Đại học", Quan = "Quận 4" },
            new TruongDaiHoc { Id = "hcmus_q5", TenTruong = "ĐH Khoa học Tự nhiên (Cơ sở Nguyễn Văn Cừ)", Latitude = 10.7630, Longitude = 106.6821, LoaiTruong = "Đại học", Quan = "Quận 5" },
            new TruongDaiHoc { Id = "hcmue", TenTruong = "ĐH Sư Phạm TP.HCM", Latitude = 10.7613, Longitude = 106.6822, LoaiTruong = "Đại học", Quan = "Quận 5" },
            new TruongDaiHoc { Id = "ump", TenTruong = "ĐH Y Dược TP.HCM", Latitude = 10.7562, Longitude = 106.6661, LoaiTruong = "Đại học", Quan = "Quận 5" },
            new TruongDaiHoc { Id = "hcmut_q10", TenTruong = "ĐH Bách Khoa - Cơ sở Lý Thường Kiệt", Latitude = 10.7732, Longitude = 106.6597, LoaiTruong = "Đại học", Quan = "Quận 10" },
            new TruongDaiHoc { Id = "huflit", TenTruong = "ĐH Ngoại ngữ - Tin học (HUFLIT)", Latitude = 10.7765, Longitude = 106.6669, LoaiTruong = "Đại học", Quan = "Quận 10" },
            new TruongDaiHoc { Id = "tdt", TenTruong = "ĐH Tôn Đức Thắng (Cơ sở Tân Phong)", Latitude = 10.7325, Longitude = 106.6983, LoaiTruong = "Đại học", Quan = "Quận 7" },
            new TruongDaiHoc { Id = "rmit", TenTruong = "ĐH RMIT Việt Nam", Latitude = 10.7293, Longitude = 106.6946, LoaiTruong = "Đại học", Quan = "Quận 7" },
            new TruongDaiHoc { Id = "vaa", TenTruong = "Học viện Hàng không Việt Nam", Latitude = 10.7997, Longitude = 106.6621, LoaiTruong = "Đại học", Quan = "Tân Bình" },
            new TruongDaiHoc { Id = "huit", TenTruong = "ĐH Công Thương TP.HCM (HUIT)", Latitude = 10.8064, Longitude = 106.6288, LoaiTruong = "Đại học", Quan = "Tân Phú" },
            new TruongDaiHoc { Id = "caothang", TenTruong = "CĐ Kỹ thuật Cao Thắng", Latitude = 10.7724, Longitude = 106.7016, LoaiTruong = "Cao đẳng", Quan = "Quận 1" },
            new TruongDaiHoc { Id = "cd_congthuong", TenTruong = "CĐ Công Thương TP.HCM", Latitude = 10.8268, Longitude = 106.7314, LoaiTruong = "Cao đẳng", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "cd_cn_thuduc", TenTruong = "CĐ Công nghệ Thủ Đức (TDC)", Latitude = 10.8523, Longitude = 106.7584, LoaiTruong = "Cao đẳng", Quan = "Thủ Đức" },
            new TruongDaiHoc { Id = "cd_fpt_poly", TenTruong = "CĐ FPT Polytechnic", Latitude = 10.8122, Longitude = 106.6789, LoaiTruong = "Cao đẳng", Quan = "Phú Nhuận" },
            new TruongDaiHoc { Id = "cd_ktdn", TenTruong = "CĐ Kinh tế Đối ngoại", Latitude = 10.7981, Longitude = 106.6872, LoaiTruong = "Cao đẳng", Quan = "Phú Nhuận" },
            new TruongDaiHoc { Id = "cd_lytutrong", TenTruong = "CĐ Lý Tự Trọng TP.HCM", Latitude = 10.7937, Longitude = 106.6493, LoaiTruong = "Cao đẳng", Quan = "Tân Bình" },
            new TruongDaiHoc { Id = "cd_gtvt", TenTruong = "CĐ Giao thông vận tải TP.HCM", Latitude = 10.7946, Longitude = 106.6669, LoaiTruong = "Cao đẳng", Quan = "Tân Phú" },
            new TruongDaiHoc { Id = "cd_viendong", TenTruong = "CĐ Viễn Đông", Latitude = 10.8521, Longitude = 106.6284, LoaiTruong = "Cao đẳng", Quan = "Quận 12" },
            new TruongDaiHoc { Id = "cd_yduoc_pasteur", TenTruong = "CĐ Y Dược Pasteur", Latitude = 10.8061, Longitude = 106.7123, LoaiTruong = "Cao đẳng", Quan = "Bình Thạnh" }
        };

        // Khoảng cách đường chim bay (km) giữa hai tọa độ.
        public static double HaversineKm(double lat1, double lon1, double lat2, double lon2)
        {
            var dLat = (lat2 - lat1) * Math.PI / 180.0;
            var dLon = (lon2 - lon1) * Math.PI / 180.0;
            var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
                  + Math.Cos(lat1 * Math.PI / 180.0) * Math.Cos(lat2 * Math.PI / 180.0)
                  * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
            return 6371 * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        }
    }
}
