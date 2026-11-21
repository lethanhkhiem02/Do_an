using Do_an_co_so.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Do_an_co_so.Data
{
    public class ApplicationDbContext : IdentityDbContext<AppUser>
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
        {
        }

        public DbSet<PhongTro> PhongTro { get; set; }
        public DbSet<Message> Messages { get; set; }
        public DbSet<DanhGia> DanhGias { get; set; }

        // --- THÊM BẢNG HÓA ĐƠN VÀO DATABASE ---
        public DbSet<HoaDon> HoaDons { get; set; }

        // --- THÊM BẢNG BÁO CÁO LỪA ĐẢO VÀO DATABASE ---
        public DbSet<BaoCao> BaoCaos { get; set; }

        // --- CACHE BẢN DỊCH MÁY CHO MÔ TẢ / ĐỊA CHỈ PHÒNG ---
        public DbSet<DichNoiDung> DichNoiDungs { get; set; }

        // --- TIỆN ÍCH XUNG QUANH PHÒNG (KẾT QUẢ QUÉT OPENSTREETMAP LÚC ĐĂNG BÀI) ---
        public DbSet<TienIchXungQuanh> TienIchXungQuanh { get; set; }

        // --- HỒ SƠ TÌM BẠN Ở GHÉP ---
        public DbSet<HoSoOGhep> HoSoOGheps { get; set; }

        // --- HỢP ĐỒNG THUÊ PHÒNG ONLINE (BÊN A CHỦ TRỌ - BÊN B SINH VIÊN) ---
        public DbSet<HopDong> HopDongs { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<AppUser>()
                .Property(u => u.SoDu)
                .HasColumnType("decimal(18,2)");

            modelBuilder.Entity<PhongTro>()
                .Property(p => p.Gia)
                .HasColumnType("decimal(18,2)");

            // --- CẤU HÌNH KIỂU TIỀN TỆ CHO BẢNG HÓA ĐƠN TRÁNH CẢNH BÁO ---
            modelBuilder.Entity<HoaDon>()
                .Property(h => h.TongTien)
                .HasColumnType("decimal(18,2)");

            modelBuilder.Entity<HoaDon>()
                .Property(h => h.TienHoaHong)
                .HasColumnType("decimal(18,2)");

            modelBuilder.Entity<HoaDon>()
                .Property(h => h.TienChuTroNhan)
                .HasColumnType("decimal(18,2)");

            // --- THÊM CHỐNG XUNG ĐỘT XÓA DỮ LIỆU (CASCADE DELETE) CHO BẢNG BÁO CÁO ---
            modelBuilder.Entity<BaoCao>()
                .HasOne(b => b.NguoiBaoCao)
                .WithMany()
                .HasForeignKey(b => b.NguoiBaoCaoId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<BaoCao>()
                .HasOne(b => b.NguoiBiBaoCao)
                .WithMany()
                .HasForeignKey(b => b.NguoiBiBaoCaoId)
                .OnDelete(DeleteBehavior.Restrict);

            // Một đoạn văn bản chỉ lưu một bản dịch cho mỗi ngôn ngữ.
            modelBuilder.Entity<DichNoiDung>()
                .HasIndex(d => new { d.NgonNgu, d.MaHash })
                .IsUnique();

            // Màn chi tiết luôn tra tiện ích theo phòng, và xóa phòng phải dọn kèm
            // snapshot của nó nên khóa ngoài là required (cascade mặc định).
            modelBuilder.Entity<TienIchXungQuanh>()
                .HasIndex(t => new { t.PhongTroId, t.Loai });

            // Hồ sơ ở ghép liên kết 1-1 với AppUser
            modelBuilder.Entity<HoSoOGhep>()
                .HasIndex(h => h.UserId)
                .IsUnique();

            modelBuilder.Entity<HoSoOGhep>()
                .Property(h => h.NganSachToiDa)
                .HasColumnType("decimal(18,2)");

            // Một hợp đồng trỏ tới hai AppUser khác nhau nên phải nêu rõ cách xóa,
            // nếu không SQL Server sẽ tự dựng nhiều luồng cascade và từ chối migration.
            modelBuilder.Entity<HopDong>(h =>
            {
                h.Property(x => x.GiaThue).HasColumnType("decimal(18,2)");
                h.HasOne(x => x.BenA).WithMany().HasForeignKey(x => x.BenAId).OnDelete(DeleteBehavior.Restrict);
                h.HasOne(x => x.BenB).WithMany().HasForeignKey(x => x.BenBId).OnDelete(DeleteBehavior.Restrict);
                h.HasOne(x => x.PhongTro).WithMany().HasForeignKey(x => x.PhongTroId).OnDelete(DeleteBehavior.Cascade);
                h.HasIndex(x => x.PhongTroId);
            });
        }
    }
}