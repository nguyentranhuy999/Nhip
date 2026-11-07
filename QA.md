# Kiểm tra bản 1.0–1.9.0

## Cập nhật 1.9.0 — Hoạt động cá nhân và sửa thời gian khi về muộn

- Thêm trang Hoạt động cá nhân dưới Mục tiêu, chuyển nguyên phần ghi nhận ngủ/lịch sử ngủ sang; bốn mục tiêu ngủ vẫn ở trang Mục tiêu. Hai hàng thể thao/sinh hoạt có Bắt đầu/Kết thúc, bảng sửa ngày/giờ trước khi Lưu và kết thúc, lịch sử Sửa giờ/xóa/Xem thêm. Chỉ ghi nhận một phiên ngủ/thể thao/sinh hoạt cùng lúc. Nới thanh bên để tên mục mới hiện đầy đủ.
- **93/93 kiểm tra đạt**: thêm bộ lọc lựa chọn 5 phút, di trú vai trò danh mục bền qua đổi tên/lưu trữ, phiên thể thao/sinh hoạt và mục tiêu, kết thúc theo giờ thực tế trong quá khứ và tiếp tục theo dõi từ lúc về máy, sửa cả hai mốc không cộng trùng, giữ manual/timed pause, ngừng check-in trong phiên, chặn cùng lúc với ngủ, xung đột/lỗi nguyên tử, hủy/xóa, JSON/SQLite/legacy, chia báo cáo qua nửa đêm. Dataset năm 105.120 khoảng: 0,072 giây.
- UI riêng `.smoke-personal-v19`: khôi phục phiên thể thao đang mở, khóa các nút bắt đầu khác và chỉ bật kết thúc thể thao. Bảng kết thúc có đủ hai DatePicker. Đổi giờ kết thúc từ lúc về máy 19:46 về 19:30 rồi lưu; mở Sửa giờ đổi về 19:20. Đối chiếu SQLite: cùng ID Entry/Session, thời lượng giảm chính xác 600 giây giữa hai lần lưu, không tạo bản sao. Bắt đầu/kết thúc sinh hoạt tạo bản ghi đúng danh mục, chế độ theo dõi tạm dừng giữ nguyên.
- UI trang Mục tiêu có bốn checkbox ngủ, không còn phần ghi nhận ngủ. Preview 5 phút chỉ có Học/Nghiên cứu/Giải trí/Công việc/Khác; không có thể thao/sinh hoạt/nghỉ ngơi hoặc Giống lần trước khi lần trước là thể thao. Preview không ghi dữ liệu. Đã xem ảnh chụp trang mới và bảng chỉnh giờ; các phép thử không dùng dữ liệu thật.
- Build/chữ ký đạt, cài cả hai bản Applications lên 1.9.0 (17). Bản thật hiện trang mới với hai giấc ngủ cũ và hai hàng thể thao/sinh hoạt, menu có Hoạt động cá nhân. Đối chiếu checksum từng bản ghi: giữ nguyên 11 entries/3 goals, sleepHistory/sleepReminders và ID/tên/màu/trạng thái danh mục; chỉ thêm vai trò phân loại danh mục phục vụ lọc. Không tạo phiên thử trong dữ liệu thật.

## Cập nhật 1.8.1 — hai hàng Ngủ trưa/Ngủ đêm

- Thay picker/checkbox bằng hai hàng riêng, mỗi hàng có biểu tượng mặt trời/trăng, nút Ngủ (giường) và Thức dậy (mặt trời mọc), màu cam/tím. Khi đang ngủ chỉ bật nút Thức dậy đúng hàng; khóa cả hai nút Ngủ. Giờ bắt đầu và nút hủy nằm cùng hàng đang hoạt động. Giữ logic lưu giấc ngủ/mục tiêu/Nghỉ ngơi và lịch sử.
- Build release và chữ ký đạt. UI cô lập `.smoke-sleep-v181`: thử ngủ đêm → cả hai nút Ngủ khóa, dậy trưa khóa, dậy sáng bật; bấm dậy tạo Nghỉ ngơi và mở lại hai nút Ngủ. Thử ngủ trưa → dậy trưa bật, dậy sáng khóa; hủy hoạt động đúng. Kiểm tra ảnh chụp bố cục hai hàng và biểu tượng ở cửa sổ rộng 940 điểm.
- Cập nhật cả hai bản Applications lên 1.8.1 (16), mở lại bản chính thành công. Thay đổi chỉ ở giao diện; xác minh bằng build/chữ ký và thao tác UI trên dữ liệu riêng. Trong lúc đối chiếu bản thật có thêm hai phiên ngủ và một mục tiêu mới. Đối chiếu subset checksum xác nhận 9 bản ghi/2 mục tiêu ban đầu giữ nguyên; hai bản Nghỉ ngơi mới khớp chính xác timestamp và ID của phiên ngủ, cài đặt nhắc ngủ không đổi. Không ghi đè các thay đổi mới phát sinh khi người dùng thao tác.

## Cập nhật 1.8.0 — nhắc thuần túy, ghi nhận ngủ và tự lưu Nghỉ ngơi

- Bỏ các nút trong cửa sổ ngủ và native category actions. Cửa sổ chỉ có nội dung/giờ, không có nút tiêu đề, không nhận click; giữ thời hạn 60 giây/âm 10 giây. Mục tiêu ngủ chỉ đọc và tự tính theo timestamp. Bên dưới thêm loại giấc ngủ và checkbox Đang ngủ (tích đi ngủ, bỏ tích thức dậy), hủy phiên đang mở, xóa phiên đã kết thúc.
- **79/79 kiểm tra đạt**. Bổ sung ngủ trưa sớm/đúng phút/muộn, ngủ đêm gán tối hôm trước và sáng hôm sau, qua 00:00, wake sớm trước nửa đêm, thời lượng chia qua ngày, không tạo check-in trong lúc ngủ, giữ manual/timed pause, double-click và xung đột nguyên tử, đổi tên/lưu trữ Nghỉ ngơi, xóa phiên không xóa phần chỉnh sửa tay, SQLite/JSON/legacy và DST/múi giờ. Tổng hợp một năm 105.120 khoảng: 0,078 giây ở lần đo này.
- UI cô lập `.smoke-sleep-v18`: tích ngủ đêm tự đổi mục tiêu 0/4 → 1/4 và hiện giờ/Đúng giờ. Thoát/mở lại vẫn Đang ngủ đêm; bỏ tích tạo đúng một Entry source=sleep, thời điểm khớp phiên ngủ, 132,864 giây Nghỉ ngơi; chế độ theo dõi ban đầu vẫn tạm dừng. Ngủ trưa ghi buổi tối hiện Muộn, checkbox mục tiêu không tích. Hủy giấc ngủ đang mở và xóa phiên hoàn tất hoạt động đúng; checksum xác nhận toàn bộ bản ghi/mục tiêu của fixture trở lại nguyên trạng. Đã xem ảnh chụp bố cục phần mục tiêu và ghi nhận bên dưới, thử gọi nhắc ngủ mới.
- Các dấu tích legacy giữ để tương thích; mốc có phiên mới ưu tiên tính từ timestamp. Không thử ghi ngủ/thức trên dữ liệu thật. Các kiểm tra đánh thức phần cứng/Focus và giới hạn native fallback vẫn như 1.7.1.
- Build release và chữ ký đạt; cài hai bản Applications lên 1.8.0 (15). Kiểm tra bản thật có Ghi nhận giấc ngủ/Đang ngủ cùng mục tiêu Học/Nghiên cứu cũ. SHA-256 trước/sau cho 9 bản ghi và 2 mục tiêu khớp hoàn toàn; theo dõi vẫn tạm dừng, không tạo phiên ngủ thử trong dữ liệu thật. Chạy lại 79/79 sau khi làm rõ lỗi xung đột; tổng hợp năm 0,073 giây.

## Cập nhật 1.7.1 — lời nhắc một phút, âm báo mỗi 10 giây

- Áp dụng cả ghi nhận 5 phút và ngủ/thức dậy. Cửa sổ tự đóng ở giây 60, âm báo ở 0/10/20/30/40/50; trả lời/bỏ qua/đóng sớm dừng âm và hủy timer. Timeout không ghi nhận hoạt động hoặc tích mục tiêu. Âm ghi nhận giữ công tắc Phát âm báo. Cửa sổ ngủ nổi, không kích hoạt dashboard/giành bàn phím.
- **65/65 kiểm tra đạt**, thêm biên 60 giây, sáu mốc âm, callback lặp, hủy sớm, timer trễ, đồng hồ quay ngược, phiên mới độc lập và chọn mốc ngủ kế tiếp qua ngày/năm/múi giờ.
- Kiểm tra run loop thật bằng chính `ReminderAlertController`, tắt tiếng trong phép đo: sáu callback đúng 0/10/20/30/40/50 (lần đo đầu: 0,000 / 10,004 / 20,000 / 30,000 / 40,000 / 50,000), callback hết hạn ở 60,000 giây; hủy ở giây 2 không phát thêm callback hoặc hết hạn. Không chỉ kiểm tra bằng cách tua thời gian giả.
- UI cô lập `.smoke-alerts-v171`, âm bật: deadline 5 phút tự mở ghi nhận, nhắc ngủ thử dùng cùng controller. Log cho thấy `NSSound.play()` thành công khi hiện và sau 10 giây; đóng sớm hủy các lượt, không có âm tiếp theo. Dữ liệu thử vẫn 0 bản ghi/0 dấu tích ngủ. `--smoke-alerts` chỉ ghi log trong demo có `--data-dir`; không thay đổi dữ liệu thật.
- Lịch ngủ khi chạy dùng timer Calendar riêng: native pending = 0 để tránh hai thông báo. Thoát app bình thường đã chờ đặt đủ bốn UNCalendarNotificationTrigger lặp đúng giờ/timezone (kiểm tra từ chính tiến trình, mode `nativeFallback`); demo xóa request thử trước khi kết thúc. Giữ native fallback khi app đã thoát, nhưng chế độ đó do macOS quyết định thời gian/âm, không bảo đảm 60 giây/10 giây. Không thử đánh thức phần cứng hoặc đợi cả bốn giờ thực tế.
- Build release và chữ ký đạt; cập nhật cả `/Applications/Nhip.app` và `~/Applications/Nhip.app` lên 1.7.1 (14). Đối chiếu checksum: giữ nguyên 9 bản ghi, 2 mục tiêu cũ; âm ghi nhận đang bật và theo dõi vẫn tạm dừng. Sau khi thêm chặn callback timer cũ, chạy lại phép đo thật: hết hạn 60,004 giây, sáu mốc âm sai lệch tối đa 0,005 giây; hủy sớm đạt.

## Cập nhật 1.7.0 — nhắc ngủ và bốn mục tiêu cố định

- Thêm bốn lịch lặp hằng ngày: 00:00 ngủ đêm, 07:00 dậy sáng, 12:30 ngủ trưa, 13:30 dậy sau ngủ trưa. Công tắc Nhắc nhở ngủ trong Nhắc & lịch áp dụng ngay, độc lập với theo dõi hoạt động. Dấu tích được xác nhận bằng tay hoặc nút thông báo; gửi thông báo không tự tích và không cộng thời lượng ngủ.
- **57/57 kiểm tra đạt**: thêm lịch chính xác, native calendar trigger, biên 00:00/giao năm Việt Nam, DST, xác nhận lặp/bỏ tích, bật tắt giữ lịch sử, bỏ qua hành động khi tắt, dữ liệu cũ/JSON/SQLite và dữ liệu lỗi. Kiểm tra một năm 105.120 khoảng: 0,115 giây.
- UI riêng `.smoke-sleep-v17`: bốn dòng đúng giờ, checkbox 0/4 → 1/4 → 0/4; tắt ẩn bốn dòng, bật lại giữ dấu tích. Đối chiếu danh sách pending từ chính UNUserNotificationCenter: bật có đúng bốn request lặp, đúng timezone/giờ/phút/category/next trigger; tắt còn 0. Banner thử hiển thị nút Đã đi ngủ và Mở mục tiêu; thông báo thử không tạo dấu tích mới. Kiểm tra ảnh chụp bố cục trang Mục tiêu.
- `--demo --smoke-sleep --data-dir PATH` cho phép kiểm tra lịch thật bằng mã `nhip.sleep.demo.*`, xuất `sleep-schedule-check.json` vào dữ liệu thử. Demo thường không đặt lịch lặp; demo không thay bốn request của dữ liệu thật. Thoát demo hủy lịch thử. Không mô phỏng đánh thức phần cứng, Focus hay chờ đến cả bốn giờ thực tế; app không có chức năng đánh thức máy.
- Build release và chữ ký đạt; cập nhật `/Applications/Nhip.app` và `~/Applications/Nhip.app` lên 1.7.0 (13). Bản thật có đủ bốn mục tiêu, công tắc đang bật, Notifications đã được cho phép. Đối chiếu SHA-256 trước/sau: giữ nguyên 9 bản ghi và 2 mục tiêu đã có; trạng thái ghi nhận vẫn tạm dừng. Không tích mục tiêu ngủ thật trong lúc thử.

## Cập nhật 1.6.0 — quản lý mục tiêu tuần trong màn hình Tuần

- Thay phần mục tiêu tuần trống bằng biểu mẫu chọn hoạt động/số giờ, tiến độ, checkbox, xóa và hoàn tác. Đặt ngay dưới ba ô tổng giờ. Trang Mục tiêu mỗi ngày chỉ quản lý mục tiêu ngày; mục tiêu tuần cũ được giữ và chuyển sang màn hình Tuần.
- Mục tiêu lặp sang các tuần sau; tiến độ tính theo tuần đang chọn, thứ Hai–Chủ nhật. Lưu trong cùng tuần sửa mức hiện tại; lưu ở tuần khác giữ phiên bản mục tiêu cũ. Không thay mục tiêu ngày hoặc thời lượng hoạt động.
- **50/50 kiểm tra đạt**, thêm kiểm tra phiên bản theo tuần, cộng nhiều ngày, reset thứ Hai, chia thời gian qua biên tuần, giới hạn và xóa/hoàn tác.
- UI thử riêng `.smoke-weekly-v16`: mục tiêu Học 1 giờ trên 1 giờ 21 phút đã ghi nhận tự tích; sang tuần sau checkbox bỏ tích và quay về tuần này lại tích. Sửa thành 100 giờ bỏ tích; xóa và hoàn tác hoạt động đúng. Trang Mục tiêu ngày không xuất hiện mục tiêu ngày mới do tạo nhầm.
- Build release và chữ ký đạt; cập nhật cả hai bản cài. Trên bản thật, màn hình Tuần có đủ bộ nhập và nút Lưu mục tiêu tuần. Đối chiếu checksum trước/sau cập nhật cho các hoạt động và mục tiêu có sẵn để xác nhận dữ liệu giữ nguyên.

## Cập nhật 1.5.2 — rút gọn chú thích

- Gỡ footer lưu trên máy/không cần mạng/múi giờ, lời giải thích lặp mục tiêu, nhãn Tự động đánh dấu, hướng dẫn checkbox, cơ sở so sánh và các đoạn giới thiệu phụ.
- Giữ tiêu đề, số liệu, khoảng ngày của tuần, nhãn chức năng, thông báo thao tác và lỗi. Cấu hình múi giờ vẫn có trong Cài đặt; checkbox và lặp mục tiêu không đổi.
- Build release và chữ ký đạt; đã cập nhật cả hai bản cài. Kiểm tra giao diện thật ở Ngày, Tuần, Tổng kết, Mục tiêu: không còn các dòng chú thích được yêu cầu gỡ. Kiểm tra ảnh chụp trang Mục tiêu, vẫn có tiến độ, checkbox và nút xóa.
- Đây là thay đổi nội dung hiển thị; không đổi tính toán hoặc dữ liệu.

## Cập nhật 1.5.1 — chọn thời gian đúng từng kỳ

- Bộ chọn Ngày dùng ngày; Tuần dùng số tuần/năm của tuần; Tháng dùng tháng/năm; Năm chỉ dùng năm. Nút trở về kỳ hiện tại lần lượt Hôm nay/Tuần này/Tháng này/Năm nay.
- Nhãn biểu đồ và so sánh cũng dùng đúng định dạng, không in cả khoảng dd/MM/yyyy cho tháng/năm. So sánh kỳ đang diễn ra vẫn ghi rõ cùng phần thời gian đã trôi qua.
- Mũi tên đi từ đầu kỳ, tránh lệch ngày khi chuyển từ tháng dài sang tháng ngắn. Tuần dùng quy tắc ISO của lịch báo cáo; năm không có tuần 53 được giới hạn về tuần 52.
- **46/46 kiểm tra đạt**, thêm các trường hợp tuần giao năm, tuần 53, tháng 2 năm nhuận và tiến/lùi qua biên kỳ.
- Build release, chữ ký và cập nhật hai bản cài đạt. Trên app thật: Tuần có hai bộ chọn Tuần 45/2026 và Tuần này; Tháng có 11/2026 và Tháng này; Năm chỉ có 2026 và Năm nay. Thử Năm trước chuyển sang 2025, Năm nay trở lại 2026. Xác nhận Ngày vẫn dùng date picker 7/11/26 và Hôm nay. Kiểm tra ảnh chụp màn hình Năm.

## Cập nhật 1.5.0 — Mục tiêu mỗi ngày

- Chuyển Mục tiêu khỏi Cài đặt, đặt ngay dưới Tổng kết trên thanh bên; thêm lối mở từ thanh menu. Vẫn mặc định mở Tổng kết khi khởi động/mở lại.
- Mỗi hoạt động có một mục tiêu hằng ngày lặp lại, từ 1 phút đến 24 giờ. Checkbox tính từ bản ghi trong ngày theo múi giờ báo cáo, tự cập nhật khi đủ thời gian, sang ngày mới hoặc sửa/xóa hoạt động.
- Có thùng rác và Hoàn tác xóa. Xóa mục tiêu tuần loại các phiên bản cũ cùng hoạt động để không làm mục tiêu cũ xuất hiện lại; hoàn tác khôi phục các phiên bản đó. Không xóa thời gian hoạt động.
- Tương thích JSON/SQLite cũ: trường period thiếu được hiểu là week; mục tiêu tuần được giữ trong phần riêng của trang Mục tiêu.
- **42/42 kiểm tra đạt**: thêm kiểm tra tương thích mục tiêu cũ, đạt ngưỡng đúng hoạt động, reset qua ngày, cắt tại nửa đêm, tự bỏ tích khi sửa dữ liệu, lưu/khôi phục và xóa/hoàn tác.
- Thử UI riêng bằng `.smoke-goals-v15`: tạo mục tiêu Học 5 phút trên 10 phút đã ghi nhận → checkbox 1; đổi mục tiêu thành 1 giờ → checkbox 0. Xóa → danh sách 0 mục tiêu; hoàn tác → mục tiêu trở lại. Xác nhận Cài đặt không còn tab Mục tiêu. Không ghi dữ liệu minh họa vào nhật ký thật.
- Build release, chữ ký và cập nhật hai bản cài đạt. Trên app thật, mục tiêu tuần Học 3 giờ vẫn hiển thị ngay sau cập nhật, tiến độ 15 phút/3 giờ; checksum các bản ghi hoạt động không đổi. Các thao tác mục tiêu người dùng thực hiện sau đó là thay đổi độc lập với cập nhật.

## Cập nhật 1.4.2 — mặc định mở Tổng kết

- Đặt Tổng kết tất cả thời gian làm lựa chọn ban đầu khi khởi động.
- Xử lý sự kiện mở lại từ Dock/Finder để chuyển về Tổng kết và hiện dashboard ngay cả khi app vẫn đang chạy.
- Build release và chữ ký đạt; cập nhật cả hai bản cài. Kiểm tra trực tiếp: khởi động mới mở Tổng kết; khi app đang ở cửa sổ Cài đặt, gọi mở lại `/Applications/Nhip.app` cũng trở về Tổng kết.
- Không thay đổi dữ liệu, mục tiêu hoặc chu kỳ nhắc.

## Cập nhật 1.4.1 — viền focus và tiêu đề theo kỳ

- Xác nhận trước khi sửa: dashboard đang ở Năm nhưng focus bàn phím vẫn ở nút Ngày, tạo khung xanh nhỏ quanh chữ Ngày.
- Dùng `focusEffectDisabled` cho các nút điều hướng trên macOS 14+, giữ nền tím nhạt cho mục đang xem. Không tắt khả năng nhận focus của nút.
- Tiêu đề Tuần hiển thị số tuần và khoảng ngày; Tháng hiển thị tháng/năm; Năm hiển thị năm. Có mô tả riêng cho từng kỳ.
- Build release và chữ ký đạt; cập nhật cả hai bản cài. Kiểm tra app thật: “Tổng kết tuần 45”, “Tổng kết tháng 11/2026”, “Tổng kết năm 2026”. Ảnh chụp sau khi chuyển sang Năm xác nhận không còn khung xanh quanh nút Ngày.
- Chỉ đổi giao diện, không đổi dữ liệu, thống kê hoặc chu kỳ nhắc.

## Cập nhật 1.4.0 — tổng kết tất cả thời gian

- Thay lối mở Ghi nhận nhanh trên thanh bên/thanh menu bằng Tổng kết; bảng nhắc định kỳ được giữ nguyên.
- Tổng kết dùng phạm vi từ bản ghi đầu đến bản ghi cuối, bao gồm các năm trước và danh mục đã lưu trữ. Hiển thị số giờ, thời lượng, tỷ trọng, tổng cộng; danh mục chưa có thời gian hiện 0 giờ. CSV trong màn hình này xuất toàn bộ lịch sử.
- **32/32 kiểm tra đạt**, gồm hai kiểm tra mới cho dữ liệu qua nhiều năm/danh mục lưu trữ và lịch sử trống.
- Build release, kiểm tra chữ ký và cập nhật cả hai bản cài thành công; mở bản chính `/Applications/Nhip.app`.
- Trên app thật, bấm Tổng kết: thấy tiêu đề “Tổng kết tất cả thời gian”, “Toàn bộ lịch sử”, đủ 8 hoạt động và cột Tổng giờ/Thời lượng/Tỷ trọng. Không có bộ chọn ngày hoặc bộ lọc hoạt động ở màn hình Tổng kết; nút xuất có nhãn “Xuất CSV toàn bộ lịch sử”. Kiểm tra bố cục qua ảnh chụp cửa sổ.

## Cập nhật 1.3.0 — chỉ hiển thị hoạt động đã ghi nhận

- Gỡ danh sách, bộ đếm, màn hình bổ sung, màu timeline và các cảnh báo liên quan đến khoảng chưa trả lời. Heatmap chỉ đánh dấu ngày có hoạt động đã lưu; ngày trống hiển thị dấu gạch.
- Lần nhắc mới chuyển sang khoảng vừa qua; không hỏi lại backlog. Ghi nhận nhanh mở thủ công cũng chỉ xét lượt gần nhất, còn trong hạn và chưa bỏ qua.
- **30/30 kiểm tra đạt**, gồm hai trường hợp mới về lượt hết hạn, lượt đã bỏ qua/đã trả lời và không quay lại lượt cũ.
- Build release thành công, kiểm tra chữ ký đạt; cập nhật cả `/Applications/Nhip.app` và bản cũ trong `~/Applications/Nhip.app`, mở bản chính ở `/Applications`.
- Trên app thật: kiểm tra cả Ngày, Tuần, Tháng, Năm không còn “Chưa xác định”, “Cần bổ sung”, “Độ đầy đủ” hoặc lời nhắc bổ sung. Mở Ghi nhận nhanh với lịch sử bỏ lỡ: hiển thị không có lượt mới thay vì yêu cầu nhớ lại khoảng cũ.
- Không xóa mốc thời gian nội bộ hay hoạt động người dùng đã lưu. So sánh checksum danh sách hoạt động trước/sau cập nhật để xác nhận không thay đổi.

## Cập nhật 1.2.0 — tổng giờ theo ba hoạt động

- Build release và chữ ký đạt; cập nhật bản cài trong `~/Applications/Nhip.app`.
- Ba ô đầu dashboard được thay bằng tổng giờ Học, Nghiên cứu, Tập thể thao; có thời lượng giờ/phút bên dưới.
- Đã mở cả bốn màn hình Ngày/Tuần/Tháng/Năm trên app thật và xác minh ba ô xuất hiện trong từng kỳ. Với dữ liệu hiện tại đều nằm trong ngày 07/11/2026, số giờ là 0,16 / 0,00 / 0,07; đối chiếu độc lập từ SQLite theo biên từng kỳ.
- Các ô tổng giờ dùng toàn bộ dữ liệu trong kỳ, độc lập với bộ lọc hoạt động của biểu đồ chi tiết. Không đổi bản ghi hoặc cách chia khoảng thời gian.

## Cập nhật 1.1.1 — bấm trực tiếp ô hoạt động

- Build release và kiểm tra chữ ký thành công; đã cập nhật bản cài trong `~/Applications/Nhip.app`.
- Bảng Ghi nhận nhanh hiển thị danh mục dưới dạng nút phủ toàn bộ ô, không còn checkbox và nút Lưu riêng.
- Đã kiểm tra trên bản cài thật bằng chế độ xem thử: bấm vùng trống gần mép phải của ô Học (không bấm biểu tượng hoặc chữ) đóng bảng ngay. Vùng bấm phủ toàn bộ ô như yêu cầu.
- Ghi chú được đặt trước lưới hoạt động để có thể nhập trước khi bấm ghi nhận. “Giống lần trước” cũng ghi nhận ngay.
- Phần thay đổi giới hạn ở giao diện và lời hướng dẫn; không đổi cách lưu, tính thời gian hoặc lịch nhắc.

## Cập nhật 1.1 — bảng nhắc có ô tick

- Build release 1.1.0 thành công; cập nhật bản cài tại `~/Applications/Nhip.app`, chữ ký kiểm tra đạt. Giữ nguyên dữ liệu cũ.
- Chạy lại bộ kiểm tra: **28/28 đạt**. Tổng hợp + tìm khoảng thiếu trong dữ liệu một năm: khoảng 0,127 giây ở lần đo này.
- Dùng `--demo --smoke-reminder --data-dir .../.smoke-quick-v11` để thử riêng đường đi của timer: đặt mốc bắt đầu cách deadline 3 giây, vẫn dùng khoảng dài đúng 5 phút và cùng hàm xử lý như vận hành bình thường. Có bản ghi nguồn `checkin`, thời lượng 300 giây trong SQLite của bộ thử.
- Trên bản cài thật: mở “Xem thử bảng nhắc nhanh”; thấy đầy đủ 8 ô tick. Chưa chọn thì nút hoàn tất bị vô hiệu hóa. Tick Thể thao thì nút được bật; đổi sang Nghiên cứu thì ô Thể thao tự bỏ tick. Bấm hoàn tất đóng bảng. Chế độ xem thử không gọi lưu bản ghi.
- Bảng nhắc dùng NSPanel nổi, có thể xuất hiện ở các Space, không tự đưa dashboard lên hoặc chiếm bàn phím khi timer gọi. Chưa kiểm tra bằng chuyển Space/toàn màn hình trên máy thật.
- Không còn gửi banner cho mỗi chu kỳ để tránh nhắc trùng. Bảng riêng có thể hiện khi Focus bật; người dùng có thể tạm dừng Nhịp. Banner thử và xử lý thông báo cũ vẫn được giữ.

Các kết quả bản đầu bên dưới được giữ để tham khảo; từ bản 1.1, lần nhắc định kỳ dùng bảng riêng thay cho banner.

Ngày: 07/11/2026. Máy: Apple Silicon arm64, macOS 26.6.2, Swift 6.3, Command Line Tools.

## Kết quả tự động

Lệnh: `zsh scripts/test.sh` — **28/28 đạt**.

Bao gồm chia khoảng 5 phút; trả lời trễ/lặp; khoảng chưa xác định; tạm dừng; khôi phục từ heartbeat; sửa và thay thế thời gian chồng lấn; gán phần trống; dữ liệu thủ công ngoài phiên; nửa đêm và DST; danh mục lưu trữ; JSON/SQLite round trip; checkpoint và khóa chống nhiều tiến trình; từ chối bản sao lưu lỗi; CSV; biên lịch; so sánh tháng ngắn hơn; số ngày có dữ liệu.

Bộ dữ liệu hiệu năng: 105.120 khoảng trong một năm, 94.608 bản ghi đã phân loại, 10.512 khoảng chưa xác định. Tổng hợp cùng tìm khoảng thiếu: khoảng **0,117 giây** ở release trong lần đo trên máy này. Đây là đo phần xử lý dữ liệu, không phải thời gian render toàn bộ dashboard.

Build release thành công, executable arm64. Info.plist hợp lệ. Bản cài trong `~/Applications/Nhip.app` được kiểm tra bằng `codesign --verify --strict`.

## Kiểm tra trên giao diện thật

Dùng bộ dữ liệu riêng `.smoke-data`, không trộn với nhật ký thật:

- Mở dashboard ngày, timeline, tổng thời gian và trạng thái chưa xác định.
- Mở biểu đồ tuần, tháng/heatmap, năm và đường trung bình theo ngày.
- Mở bảng chỉnh sửa; nhập và lưu ghi chú tiếng Việt. Kiểm tra ghi chú đã xuất hiện trên dashboard và trong SQLite.
- Đóng/mở app: ghi chú và dữ liệu còn nguyên.
- Mở bảng ghi nhận nhanh, xác nhận một khoảng: tổng từ 25 lên 30 phút, chưa xác định từ 5 xuống 0 phút.
- Mở phần cài đặt, kiểm tra chu kỳ mặc định 5 phút, âm báo và mở cùng đăng nhập mặc định tắt.
- Yêu cầu quyền thông báo; cho phép qua hộp thoại macOS. Thông báo thử được nhìn thấy trong Notification Center.
- Mở bản cài với thư mục dữ liệu thật: không có dữ liệu minh họa.

## Phần chưa xác minh bằng thao tác hệ thống thật

- Chưa khóa màn hình hoặc đưa máy sleep để tránh gián đoạn máy đang dùng. Quy tắc chốt khoảng/tạm dừng/khôi phục có kiểm tra tự động; sự kiện hệ thống cần tiếp tục theo dõi khi dùng thực tế.
- Chưa đăng xuất/khởi động lại máy để kiểm tra Login Items. Tùy chọn này dùng SMAppService và vẫn mặc định tắt.
- Đã kiểm tra thông báo thử thực tế và tính chu kỳ bằng đồng hồ giả lập; chưa thực hiện một phiên nghiệm thu liên tục nhiều giờ với banner mỗi 5 phút.
- Chưa đo mức dùng pin qua một ngày hoặc kiểm chứng mục tiêu phản hồi 300 ms bằng profiler.
- Chưa ký Developer ID hoặc notarize để phát hành công khai.
