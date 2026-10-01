-- ============================================================
-- QUẢN LÝ NHÀ TRỌ - DATABASE SCHEMA (DB-First)
-- MySQL 8.x
-- ============================================================

-- Tắt kiểm tra khóa ngoại khi tạo bảng
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 1. BẢNG NGƯỜI DÙNG (nguoi_dung)
-- Lưu thông tin tài khoản: chủ trọ và khách thuê
-- ============================================================
CREATE TABLE IF NOT EXISTS nguoi_dung (
    user_id     BIGINT          NOT NULL AUTO_INCREMENT,
    ho_ten      VARCHAR(100)    NOT NULL,
    email       VARCHAR(100)    NOT NULL,
    mat_khau    VARCHAR(255)    NOT NULL,
    sdt         VARCHAR(15)     NULL,
    cccd        VARCHAR(12)     NULL,
    vai_tro     ENUM('CHU_TRO','KHACH_THUE') NOT NULL COMMENT 'CHU_TRO | KHACH_THUE',
    trang_thai  ENUM('HOAT_DONG','BI_KHOA') NOT NULL DEFAULT 'HOAT_DONG' COMMENT 'HOAT_DONG | BI_KHOA',
    ngay_tao    DATETIME        NULL DEFAULT CURRENT_TIMESTAMP,
    so_lan_sai_mat_khau INT     NOT NULL DEFAULT 0,

    PRIMARY KEY (user_id),
    UNIQUE KEY uk_nguoi_dung_email (email),
    UNIQUE KEY uk_nguoi_dung_cccd (cccd)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. BẢNG KHU TRỌ (khu_tro)
-- Lưu thông tin các khu/dãy trọ
-- ============================================================
CREATE TABLE IF NOT EXISTS khu_tro (
    khu_tro_id  BIGINT          NOT NULL AUTO_INCREMENT,
    ten_khu     VARCHAR(100)    NOT NULL,
    dia_chi     VARCHAR(255)    NOT NULL,
    so_tang     INT             NULL,
    mo_ta       TEXT            NULL,

    PRIMARY KEY (khu_tro_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. BẢNG PHÒNG TRỌ (phong_tro)
-- Lưu thông tin từng phòng trong khu trọ
-- ============================================================
CREATE TABLE IF NOT EXISTS phong_tro (
    phong_id    BIGINT          NOT NULL AUTO_INCREMENT,
    khu_tro_id  BIGINT          NOT NULL,
    so_phong    VARCHAR(10)     NOT NULL,
    tang        INT             NULL,
    dien_tich   FLOAT           NULL,
    gia_thue    DECIMAL(12,0)   NULL,
    trang_thai  ENUM('TRONG','DA_THUE','BAO_TRI') NOT NULL DEFAULT 'TRONG' COMMENT 'TRONG | DA_THUE | BAO_TRI',
    mo_ta       TEXT            NULL,

    PRIMARY KEY (phong_id),
    UNIQUE KEY uk_phong_tro_khu_so (khu_tro_id, so_phong),
    CONSTRAINT fk_phong_tro_khu_tro
        FOREIGN KEY (khu_tro_id) REFERENCES khu_tro (khu_tro_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. BẢNG TÀI SẢN PHÒNG TRỌ (tai_san_phong_tro)
-- Lưu danh sách tài sản của từng phòng
-- ============================================================
CREATE TABLE IF NOT EXISTS tai_san_phong_tro (
    tai_san_id  BIGINT          NOT NULL AUTO_INCREMENT,
    phong_id    BIGINT          NOT NULL,
    ten_tai_san VARCHAR(200)    NOT NULL,
    tinh_trang  VARCHAR(100)    NULL,

    PRIMARY KEY (tai_san_id),
    CONSTRAINT fk_tai_san_phong_tro
        FOREIGN KEY (phong_id) REFERENCES phong_tro (phong_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. BẢNG THÀNH VIÊN PHÒNG TRỌ (thanh_vien_phong_tro)
-- Lưu danh sách người ở trong mỗi phòng
-- ============================================================
CREATE TABLE IF NOT EXISTS thanh_vien_phong_tro (
    thanh_vien_id   BIGINT      NOT NULL AUTO_INCREMENT,
    phong_id        BIGINT      NOT NULL,
    ho_ten          VARCHAR(100) NOT NULL,
    sdt             VARCHAR(20) NULL,
    cccd            VARCHAR(20) NULL,
    ngay_bat_dau    DATE        NOT NULL,
    trang_thai      VARCHAR(255) NOT NULL COMMENT 'Đang ở | Đã rời đi',

    PRIMARY KEY (thanh_vien_id),
    CONSTRAINT fk_thanh_vien_phong_tro
        FOREIGN KEY (phong_id) REFERENCES phong_tro (phong_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 6. BẢNG HỢP ĐỒNG (hop_dong)
-- Lưu thông tin hợp đồng thuê phòng
-- ============================================================
CREATE TABLE IF NOT EXISTS hop_dong (
    hop_dong_id     BIGINT      NOT NULL AUTO_INCREMENT,
    phong_id        BIGINT      NOT NULL,
    khach_thue_id   BIGINT      NOT NULL,
    ngay_bat_dau    DATE        NOT NULL,
    ngay_ket_thuc   DATE        NOT NULL,
    gia_thue        DECIMAL(12,0) NOT NULL,
    tien_coc        DECIMAL(12,0) NOT NULL,
    trang_thai      ENUM('DANG_HIEU_LUC','SAP_HET_HAN','DA_CHAM_DUT') NOT NULL DEFAULT 'DANG_HIEU_LUC'
                                COMMENT 'DANG_HIEU_LUC | SAP_HET_HAN | DA_CHAM_DUT',
    ghi_chu         TEXT        NULL,

    PRIMARY KEY (hop_dong_id),
    CONSTRAINT fk_hop_dong_phong_tro
        FOREIGN KEY (phong_id) REFERENCES phong_tro (phong_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_hop_dong_khach_thue
        FOREIGN KEY (khach_thue_id) REFERENCES nguoi_dung (user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 7. BẢNG PHỤ LỤC HỢP ĐỒNG (phu_luc_hop_dong)
-- Lưu phụ lục gia hạn / thay đổi giá thuê
-- ============================================================
CREATE TABLE IF NOT EXISTS phu_luc_hop_dong (
    phu_luc_id      BIGINT      NOT NULL AUTO_INCREMENT,
    hop_dong_id     BIGINT      NOT NULL,
    gia_thue_mmoi   DECIMAL(12,0) NOT NULL COMMENT 'Giá thuê mới',
    ngay_ket_thuc_moi DATE      NOT NULL COMMENT 'Ngày kết thúc mới',
    ngay_hieu_luc   DATE        NULL COMMENT 'Ngày khách duyệt phụ lục',
    trang_thai      ENUM('CHO_PHE_DUYET','DA_PHE_DUYET','DA_TU_CHOI') NOT NULL DEFAULT 'CHO_PHE_DUYET'
                                COMMENT 'CHO_PHE_DUYET | DA_PHE_DUYET | DA_TU_CHOI',
    ghi_chu         TEXT        NULL,
    ngay_tao        DATETIME    NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (phu_luc_id),
    CONSTRAINT fk_phu_luc_hop_dong
        FOREIGN KEY (hop_dong_id) REFERENCES hop_dong (hop_dong_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 8. BẢNG DỊCH VỤ (dich_vu)
-- Bảng giá dịch vụ: điện, nước, internet, rác...
-- ============================================================
CREATE TABLE IF NOT EXISTS dich_vu (
    dich_vu_id  BIGINT          NOT NULL AUTO_INCREMENT,
    ten_dv      VARCHAR(50)     NOT NULL,
    don_gia     DECIMAL(12,2)   NOT NULL,
    don_vi_tinh VARCHAR(20)     NULL,

    PRIMARY KEY (dich_vu_id),
    UNIQUE KEY uk_dich_vu_ten (ten_dv)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 9. BẢNG CHỈ SỐ ĐIỆN NƯỚC (chi_so_dien_nuoc)
-- Ghi nhận chỉ số điện/nước hàng tháng theo phòng
-- ============================================================
CREATE TABLE IF NOT EXISTS chi_so_dien_nuoc (
    chi_so_id   BIGINT          NOT NULL AUTO_INCREMENT,
    phong_id    BIGINT          NOT NULL,
    ky_ghi      VARCHAR(7)      NOT NULL COMMENT 'Kỳ ghi, VD: 2026-03',
    dien_cu     INT             NOT NULL DEFAULT 0,
    dien_moi    INT             NOT NULL DEFAULT 0,
    nuoc_cu     INT             NOT NULL DEFAULT 0,
    nuoc_moi    INT             NOT NULL DEFAULT 0,
    ngay_ghi    DATE            NULL,

    PRIMARY KEY (chi_so_id),
    UNIQUE KEY uk_chi_so_phong_ky (phong_id, ky_ghi),
    CONSTRAINT fk_chi_so_phong_tro
        FOREIGN KEY (phong_id) REFERENCES phong_tro (phong_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 10. BẢNG HÓA ĐƠN (hoa_don)
-- Hóa đơn tiền phòng hàng tháng
-- ============================================================
CREATE TABLE IF NOT EXISTS hoa_don (
    hoa_don_id      BIGINT      NOT NULL AUTO_INCREMENT,
    hop_dong_id     BIGINT      NOT NULL,
    ky_thanh_toan   VARCHAR(7)  NOT NULL COMMENT 'Kỳ thanh toán, VD: 2026-03',
    tien_phong      DECIMAL(12,0) NULL,
    tien_dien       DECIMAL(12,0) NULL,
    tien_nuoc       DECIMAL(12,0) NULL,
    phi_dich_vu     DECIMAL(12,0) NULL,
    tong_tien       DECIMAL(12,0) NOT NULL,
    han_thanh_toan  DATE        NULL,
    trang_thai      ENUM('CHUA_THANH_TOAN','DA_THANH_TOAN','THANH_TOAN_MOT_PHAN') NOT NULL DEFAULT 'CHUA_THANH_TOAN'
                                COMMENT 'CHUA_THANH_TOAN | THANH_TOAN_MOT_PHAN | DA_THANH_TOAN',
    ngay_tao        DATETIME    NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (hoa_don_id),
    UNIQUE KEY uk_hoa_don_hd_ky (hop_dong_id, ky_thanh_toan),
    CONSTRAINT fk_hoa_don_hop_dong
        FOREIGN KEY (hop_dong_id) REFERENCES hop_dong (hop_dong_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 11. BẢNG GIAO DỊCH (giao_dich)
-- Ghi nhận các lần thanh toán cho hóa đơn
-- ============================================================
CREATE TABLE IF NOT EXISTS giao_dich (
    giao_dich_id    BIGINT      NOT NULL AUTO_INCREMENT,
    hoa_don_id      BIGINT      NULL,
    so_tien         DECIMAL(12,0) NOT NULL,
    phuong_thuc     ENUM('TIEN_MAT','CHUYEN_KHOAN','ONLINE') NOT NULL COMMENT 'TIEN_MAT | CHUYEN_KHOAN | ONLINE',
    trang_thaigd    VARCHAR(50) NULL DEFAULT 'DA_XAC_NHAN'
                                COMMENT 'CHO_XAC_NHAN | DA_XAC_NHAN | DA_HUY',
    ngay_giao_dich  DATETIME    NULL DEFAULT CURRENT_TIMESTAMP,
    ghi_chu         VARCHAR(255) NULL,

    PRIMARY KEY (giao_dich_id),
    CONSTRAINT fk_giao_dich_hoa_don
        FOREIGN KEY (hoa_don_id) REFERENCES hoa_don (hoa_don_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 12. BẢNG THÔNG BÁO (thong_bao)
-- Thông báo gửi đến người dùng
-- ============================================================
CREATE TABLE IF NOT EXISTS thong_bao (
    thong_bao_id    BIGINT      NOT NULL AUTO_INCREMENT,
    nguoi_nhan_id   BIGINT      NOT NULL,
    tieu_de         VARCHAR(200) NOT NULL,
    noi_dung        TEXT        NULL,
    link            VARCHAR(200) NULL,
    da_doc          BIT(1)      NOT NULL DEFAULT 0,
    ngay_tao        DATETIME    NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (thong_bao_id),
    CONSTRAINT fk_thong_bao_nguoi_nhan
        FOREIGN KEY (nguoi_nhan_id) REFERENCES nguoi_dung (user_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 13. BẢNG YÊU CẦU SỰ CỐ (yeu_cau_su_co)
-- Khách thuê gửi yêu cầu báo sự cố
-- ============================================================
CREATE TABLE IF NOT EXISTS yeu_cau_su_co (
    ticket_id       BIGINT      NOT NULL AUTO_INCREMENT,
    phong_id        BIGINT      NOT NULL,
    khach_thue_id   BIGINT      NOT NULL,
    loai_su_co      VARCHAR(50) NULL,
    mo_ta           TEXT        NOT NULL,
    hinh_anh        MEDIUMTEXT NULL,
    muc_do_uu_tien  ENUM('THAP','TRUNG_BINH','CAO') NULL DEFAULT 'TRUNG_BINH'
                                COMMENT 'THAP | TRUNG_BINH | CAO',
    trang_thai      ENUM('MOI','DA_TIEP_NHAN','DANG_SUA','DA_XONG') NOT NULL DEFAULT 'MOI'
                                COMMENT 'MOI | DA_TIEP_NHAN | DANG_SUA | DA_XONG',
    ngay_tao        DATETIME    NULL DEFAULT CURRENT_TIMESTAMP,
    ghi_chu_xu_ly   TEXT        NULL,

    PRIMARY KEY (ticket_id),
    CONSTRAINT fk_su_co_phong_tro
        FOREIGN KEY (phong_id) REFERENCES phong_tro (phong_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_su_co_khach_thue
        FOREIGN KEY (khach_thue_id) REFERENCES nguoi_dung (user_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 14. BẢNG YÊU CẦU GIA HẠN (yeu_cau_gia_han)
-- Khách thuê gửi yêu cầu gia hạn hợp đồng
-- ============================================================
CREATE TABLE IF NOT EXISTS yeu_cau_gia_han (
    yeu_cau_id      BIGINT      NOT NULL AUTO_INCREMENT,
    khach_thue_id   BIGINT      NOT NULL,
    hop_dong_id     BIGINT      NOT NULL,
    thoi_gian_gia_han INT       NOT NULL COMMENT 'Số tháng gia hạn',
    ghi_chu         TEXT        NULL,
    trang_thai      ENUM('CHO_PHE_DUYET','DA_PHE_DUYET','DA_TU_CHOI') NOT NULL DEFAULT 'CHO_PHE_DUYET'
                                COMMENT 'CHO_PHE_DUYET | DA_PHE_DUYET | DA_TU_CHOI',
    ngay_tao        DATETIME    NULL DEFAULT CURRENT_TIMESTAMP,
    ly_do_tu_choi   VARCHAR(255) NULL,

    PRIMARY KEY (yeu_cau_id),
    CONSTRAINT fk_gia_han_khach_thue
        FOREIGN KEY (khach_thue_id) REFERENCES nguoi_dung (user_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_gia_han_hop_dong
        FOREIGN KEY (hop_dong_id) REFERENCES hop_dong (hop_dong_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 15. BẢNG YÊU CẦU CHẤM DỨT (yeu_cau_cham_dut)
-- Khách thuê gửi yêu cầu chấm dứt hợp đồng
-- ============================================================
CREATE TABLE IF NOT EXISTS yeu_cau_cham_dut (
    yeu_cau_id      BIGINT      NOT NULL AUTO_INCREMENT,
    khach_thue_id   BIGINT      NOT NULL,
    hop_dong_id     BIGINT      NOT NULL,
    ngay_du_kien_tra DATE       NOT NULL COMMENT 'Ngày dự kiến trả phòng',
    ly_do           TEXT        NULL,
    trang_thai      ENUM('CHO_PHE_DUYET','DA_PHE_DUYET','DA_TU_CHOI') NOT NULL DEFAULT 'CHO_PHE_DUYET'
                                COMMENT 'CHO_PHE_DUYET | DA_PHE_DUYET | DA_TU_CHOI',
    ngay_tao        DATETIME    NULL DEFAULT CURRENT_TIMESTAMP,
    ly_do_tu_choi   VARCHAR(255) NULL,

    PRIMARY KEY (yeu_cau_id),
    CONSTRAINT fk_cham_dut_khach_thue
        FOREIGN KEY (khach_thue_id) REFERENCES nguoi_dung (user_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_cham_dut_hop_dong
        FOREIGN KEY (hop_dong_id) REFERENCES hop_dong (hop_dong_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bật lại kiểm tra khóa ngoại
SET FOREIGN_KEY_CHECKS = 1;
