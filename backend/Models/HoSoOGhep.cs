using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace Do_an_co_so.Models
{
    public class HoSoOGhep
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public string UserId { get; set; } = string.Empty;

        // Các mức: 'Ngủ sớm', 'Cú đêm', 'Linh hoạt'
        [Required]
        public string GioGiacSinhHoat { get; set; } = "Linh hoạt";

        // Các mức: 'Nam', 'Nữ', 'Không yêu cầu'
        [Required]
        public string GioiTinhUuTien { get; set; } = "Không yêu cầu";

        public bool CoNauAn { get; set; }

        public bool CoNuoiPet { get; set; }

        public bool KhongHutThuoc { get; set; }

        public bool UaSachSe { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal NganSachToiDa { get; set; }

        [Required]
        public string KhuVucMongMuon { get; set; } = string.Empty;

        public string? MoTaThem { get; set; }

        public bool DangTimBan { get; set; } = true;

        public DateTime NgayCapNhat { get; set; } = DateTime.Now;

        [ForeignKey("UserId")]
        [JsonIgnore]
        public virtual AppUser? User { get; set; }
    }
}
