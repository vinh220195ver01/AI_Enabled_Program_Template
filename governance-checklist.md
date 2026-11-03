# Danh sách vi phạm governance

File này do governance guard tự ghi (quy tắc: bảng AI-Enabled QA Governance v0.1).
Chỉ ghi mã rule và tên file, không bao giờ ghi nội dung dữ liệu nhạy cảm.
Người xem xét đổi `[ ]` thành `[x]` khi đã xử lý xong.

**Mức độ**
- **NGHIÊM TRỌNG**: dữ liệu nhạy cảm (mật khẩu, khóa, token, số thẻ) đã được dùng hoặc lưu.
  Cần báo Security/Privacy/Data Owner ngay (AR-06).
- **Cần xem lại**: công cụ chưa duyệt hoặc bị hạn chế, nhắc tới dữ liệu confidential/production,
  hoặc hành vi có rủi ro. Chưa phải lỗi (AR-03, AR-05, AR-07); hành vi bị cấm (P-*) chỉ là lỗi
  khi có bằng chứng đáng tin cậy (AR-04).

**Cách đọc mã** (tra trong file Excel AI-Enabled QA_Governance)
- D-3, D-4, D-5: phân loại dữ liệu (sheet Data Policy): Confidential, Secret, Top Secret
- R-01 đến R-06: công cụ bị hạn chế (sheet Restricted)
- AC-xx: công cụ AI (sheet AI Tools); AC-08, AC-09 đang ở trạng thái Needs Review
- P-04 đến P-08: hành vi bị cấm (sheet Prohibited)
- AR-xx: quy tắc đánh giá (sheet Assessor Rules)

| Xong | Thời điểm | Mức độ | Phát hiện ở | Mã | Vấn đề | Cần làm |
|---|---|---|---|---|---|---|
| [ ] | 04/11/2026 00:25 | Cần xem lại | File: README.md | D-3 | Mentions confidential / secret / top-secret material | Kiểm tra phân loại dữ liệu, che hoặc dùng dữ liệu giả, xin duyệt trước khi dùng với AI (sheet Data Policy) <!-- key:file:README.md:D-3:Mentions confidential / secret / top-secret material:4241021110 --> |
| [ ] | 04/11/2026 00:25 | Cần xem lại | File: README.md | D-5 | Mentions production or real customer data | Kiểm tra phân loại dữ liệu, che hoặc dùng dữ liệu giả, xin duyệt trước khi dùng với AI (sheet Data Policy) <!-- key:file:README.md:D-5:Mentions production or real customer data:511684906 --> |
