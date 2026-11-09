# Nhịp — Lịch sử cập nhật

Các thay đổi được sắp xếp từ phiên bản mới nhất đến cũ hơn. Nội dung cập nhật trước đây trong README được tập hợp tại đây, đối chiếu với [QA.md](QA.md).

Hướng dẫn sử dụng hiện tại nằm trong [README.md](README.md). Chi tiết quy tắc hoạt động và kiểm tra kỹ thuật xem [SPEC.md](SPEC.md) và [QA.md](QA.md).

## 1.18.0 — Bộ mặc định mới theo cấu hình hiện tại

- Đặt sẵn 9 hoạt động: Học tập, Nghiên cứu, Thể thao, Giải trí, Công việc, Sinh hoạt cá nhân, Ngủ, Khác và Nghỉ ngơi, cùng icon và màu đã chọn.
- Học tập/Nghiên cứu/Giải trí/Công việc/Khác/Nghỉ ngơi dùng Cả hai; Thể thao/Sinh hoạt cá nhân tự ghi nhận; Ngủ giữ vai trò ghi giấc ngủ riêng. Hoạt động Nghỉ ngơi thường không bị nhận nhầm thành Ngủ.
- Đặt nhóm ưu tiên ban đầu gồm Học tập, Nghiên cứu, Thể thao, Công việc và Ngủ. Các dashboard bắt đầu với ba mục Học tập, Nghiên cứu, Thể thao.
- Bật âm báo mặc định và cập nhật icon mặc định cho Tuần, Tháng, Năm, Hoạt động; có icon dự phòng cho macOS chưa hỗ trợ biểu tượng mới.
- Bộ cấu hình áp dụng khi cài mới hoặc đặt lại dữ liệu; giữ nguyên cấu hình và lịch sử đang lưu. Không đưa tên cá nhân, lịch sử hoặc phiên đang chạy vào bộ mặc định.
- Bộ kiểm tra đạt 177/177 trường hợp, gồm kiểm tra bộ mặc định mới và tương thích dữ liệu cũ.

## 1.17.0 — Chọn hoạt động cho từng dashboard

- Thêm **Cài đặt → Dashboard** để chọn riêng hoạt động cho Ngày, Tuần, Tháng, Năm và Tổng kết; mỗi trang tối đa 6 hoạt động.
- Mặc định chọn 3 hoạt động, ưu tiên các mục đã đánh sao. Có thể chọn/bỏ cả dòng, đổi thứ tự bằng mũi tên và đặt lại lựa chọn mặc định của từng trang.
- Lựa chọn tự lưu, giữ qua lần mở app sau và gắn với hoạt động dù đổi tên hoặc icon. Hoạt động mới không tự thêm vào dashboard.
- Lựa chọn ô thống kê độc lập với nhóm ưu tiên dùng để so sánh, bộ lọc biểu đồ và bảng tổng thời gian. Cho phép bỏ chọn hết và mở lại phần cấu hình từ trang đó.
- Bộ kiểm tra đạt 170/170 trường hợp.

## 1.16.1 — Các ô thống kê cập nhật theo hoạt động

- Sửa lỗi đổi tên hoạt động khiến ô tổng giờ về 0 hoặc vẫn hiện icon cũ; dữ liệu đã ghi được giữ nguyên.
- Tên, icon và màu trên các ô lấy từ hoạt động hiện tại; tổng giờ gắn với ID hoạt động.
- Các ô được chuyển sang danh sách hoạt động động ở cả năm trang thống kê. Phần chọn số ô và hoạt động cụ thể được bổ sung trong 1.17.0.

## 1.16.0 — Tự chỉnh giờ nhắc ngủ

- Cho chỉnh giờ/phút của Ngủ đêm, Thức dậy buổi sáng, Ngủ trưa và Thức dậy sau ngủ trưa trong Cài đặt.
- Thêm **Lưu giờ nhắc** và **Giờ mặc định**. Lịch nhắc và nội dung thông báo cập nhật theo giờ đã lưu; bật/tắt không làm mất lịch đã chọn.
- Phiên ngủ mới dùng giờ mục tiêu mới. Phiên đang ngủ và lịch sử cũ giữ mốc giờ trước đó để kết quả không bị thay đổi ngược.
- Xử lý hạn ngủ đêm trước/sau nửa đêm, qua năm và theo múi giờ; thời lượng nghỉ vẫn tính từ thời điểm thực tế.

## 1.15.2 — Chỉ báo tên trùng trong Cài đặt

- Thông báo tên hoạt động trùng hiện ngay dưới ô thêm trong Cài đặt, không bật đồng thời ở giao diện chính.
- Giữ tên đã nhập khi lỗi; sửa nội dung hoặc thêm thành công sẽ xóa dòng báo lỗi.

## 1.15.1 — Chặn hoạt động trùng và nhận nhầm loại

- Chặn thêm/đổi tên trùng hoạt động đã có, gồm cả mục lưu trữ; bỏ qua khác biệt hoa/thường, dấu và khoảng trắng thừa.
- Hoạt động tự thêm không tự biến thành Nghỉ ngơi, thể thao hay sinh hoạt vì tên hoặc icon.
- Ghi ngủ tìm đúng hoạt động nghỉ đang dùng, kể cả khi đã đổi tên; không lấy nhầm một hoạt động thường cùng tên.
- Giữ nguyên các mục và lịch sử cũ, không tự xóa hoặc gộp dữ liệu.

## 1.15.0 — Đổi tên các mục giao diện

- Cho sửa tên và icon của các mục điều hướng trong cùng cửa sổ tại **Cài đặt → Giao diện → Sửa**.
- Tên mới cập nhật trên menu và tiêu đề trang, được lưu qua lần mở app sau; có thể khôi phục từng mục hoặc tất cả về mặc định.
- Tên dài hiển thị dấu “…” và có thể rê chuột xem đầy đủ, giữ cùng cỡ chữ với các mục khác.

## 1.14.4 — Đồng nhất chữ ở mục Hoạt động

- Bỏ quy tắc tự thu nhỏ còn sót lại từ tên dài trước đây, giúp chữ **Hoạt động** cùng cỡ và độ đậm với các mục khác.

## 1.14.3 — Sắp xếp lại menu

- Nhóm trên đường kẻ gồm **Ngày → Mục tiêu → Hoạt động**; nhóm dưới gồm **Tuần → Tháng → Năm → Tổng kết**.
- Đổi tên **Hoạt động hàng ngày** thành **Hoạt động** trên menu, tiêu đề trang và phần chọn icon.

## 1.14.2 — Âm xác nhận trong bảng xem thử

- Sửa thao tác chọn hoạt động trong **Xem thử bảng nhắc nhanh** để phát tiếng xác nhận sau khi panel đóng.
- Chế độ xem thử vẫn không tạo bản ghi trong lịch sử.

## 1.14.1 — Âm thanh khi ghi nhận thành công

- Thêm tiếng “ting-ting” khoảng 0,7 giây sau khi ghi nhận thành công hoạt động hoặc bấm Lặp lại.
- Thêm bật/tắt âm xác nhận và nút **Nghe thử** trong Cài đặt; âm xác nhận độc lập âm nhắc định kỳ.
- Âm thanh được đóng gói cùng ứng dụng và tiếp tục phát khi bảng nhắc đóng. Lỗi lưu, bỏ qua hoặc hết giờ không phát âm xác nhận.

## 1.14.0 — Mở rộng thư viện icon và tùy chỉnh giao diện

- Mở rộng thư viện lên 9.184 tên icon hiển thị được trên máy kiểm tra, gồm các biến thể; chỉ hiện icon mà phiên bản macOS đang dùng hỗ trợ.
- Thêm nhóm tìm kiếm, từ khóa tiếng Việt phổ biến và tiếng Anh; thư viện tải nền để giao diện vẫn phản hồi.
- Thêm phần đổi icon cho các mục Ngày, Tuần, Tháng, Năm, Tổng kết, Mục tiêu, Hoạt động và Cài đặt; có nút khôi phục mặc định.

## 1.13.1 — Đồng bộ icon các thẻ tổng giờ

- Các thẻ tổng giờ lấy icon đã chọn trong Cài đặt thay vì luôn dùng icon cố định.

## 1.13.0 — Bộ chọn icon có tìm kiếm

- Mở rộng bộ chọn lên 148 icon, có chia nhóm, tìm tiếng Việt có/không dấu và từ khóa tiếng Anh.
- Thêm xem trước, trạng thái đang chọn và thông báo khi không tìm thấy; chỉ lưu thay đổi khi bấm Lưu.
- Giữ cách ghi nhận, vai trò và lịch sử khi đổi tên hoặc icon hoạt động.

## 1.12.4 — Gộp so sánh theo thời gian ưu tiên

- Gộp hai phần so sánh ở Tuần/Tháng/Năm thành một phần dùng thời gian của các hoạt động ưu tiên.
- Giữ tăng/giảm, tỷ lệ phần trăm, tổng hai kỳ và trung bình mỗi ngày; kỳ đang diễn ra so với cùng phần thời gian của kỳ trước.
- Khi chưa chọn hoạt động ưu tiên, có lối mở Cài đặt để chọn.

## 1.12.3 — Rút gọn ô ưu tiên ngày

- Đổi tiêu đề thành **Tổng thời gian ưu tiên**, bỏ danh sách tên hoạt động ưu tiên bên dưới.
- Dùng nhãn **Hôm nay / Hôm qua** và cách diễn đạt nhiều hơn, ít hơn hoặc bằng hôm qua.

## 1.12.2 — Bổ sung tỷ lệ và chênh lệch ưu tiên ngày

- Chuyển ô ưu tiên xuống dưới **Dòng thời gian**.
- Hiện tỷ lệ tổng giờ trên 24 giờ cho ngày đang xem và ngày trước, cùng chênh lệch thời gian và phần trăm khi có dữ liệu đối chiếu.

## 1.12.1 — Thời gian ưu tiên của ngày và ngày trước

- Thêm ô tổng giờ ưu tiên của ngày đang xem, bên dưới là tổng cả ngày liền trước.
- Tính đúng các khoảng qua nửa đêm; phần này dùng nhóm ưu tiên riêng với bộ lọc biểu đồ.

## 1.12.0 — Đánh dấu hoạt động ưu tiên

- Cho đánh dấu sao tại **Cài đặt → Hoạt động** hoặc trong cửa sổ sửa hoạt động.
- Cộng giờ các hoạt động đã chọn để so sánh giữa các kỳ; giữ lựa chọn khi đổi tên hoặc lưu trữ hoạt động.

## 1.11.5 — Bỏ nhãn “Mỗi ngày” lặp lại

- Bỏ chữ **Mỗi ngày** trên từng dòng nhiệm vụ vì nhóm đã có tiêu đề riêng; giữ tiến độ và nội dung mục tiêu.

## 1.11.4 — Đủ ngày đầu tháng và rõ nhóm nhiệm vụ

- Sửa lưới tháng để hiển thị từ ngày 1, kể cả khi tháng bắt đầu vào Chủ nhật.
- Thêm tiêu đề **Nhiệm vụ trong ngày** cho các mục tiêu người dùng tạo, tách với nhóm ngủ/thức dậy.

## 1.11.3 — Đưa tiêu đề lên trên nhóm thống kê

- Đặt **Thời gian theo từng hoạt động** trên cả nhóm thẻ và bảng chi tiết trong Tổng kết.
- Giữ tổng cộng và các dòng chi tiết bên dưới các thẻ.

## 1.11.2 — Đưa nhiệm vụ hoàn thành lên đầu Tổng kết

- Chuyển nhóm **Nhiệm vụ đã hoàn thành** lên trước phần thống kê thời gian; giữ thứ tự các phần còn lại.

## 1.11.1 — Sửa số nhiệm vụ sau khi xóa dữ liệu

- Sửa lỗi mốc thống kê bị kéo về ngày trước bởi lần ngủ đêm sau nửa đêm, khiến mới reset đã có 8 nhiệm vụ ngày.
- Sau reset, bắt đầu từ ngày mới với 4 nhiệm vụ ngủ/thức dậy khi bật tính năng này.

## 1.11.0 — Thống kê nhiệm vụ đã hoàn thành

- Thêm số nhiệm vụ ngày/tuần đã hoàn thành, tổng nhiệm vụ, tỷ lệ phần trăm và thanh tiến độ trong Tổng kết.
- Tính cả bốn nhiệm vụ ngủ/thức dậy khi bật nhắc ngủ; chưa có nhiệm vụ thì tỷ lệ hiện “—”.

## 1.10.1 — Gọn dashboard và lời chào cá nhân

- Giữ nút thêm hoạt động ở trang Ngày; bỏ nút thêm ở Tuần/Tháng/Năm/Tổng kết và bỏ các nút chia sẻ trên dashboard.
- Đưa xuất dữ liệu về **Cài đặt → Dữ liệu**.
- Thay dòng toàn bộ lịch sử bằng lời chào dùng tên trong **Cài đặt → Cá nhân**.

## 1.10.0 — Chọn cách ghi nhận từng hoạt động

- Thêm **Nhắc định kỳ / Tự ghi nhận / Cả hai** trong Cài đặt.
- Cho cùng một hoạt động dùng cả nhắc nhanh lẫn Bắt đầu/Kết thúc; tổng giờ và mục tiêu dùng chung lịch sử.
- Đổi chế độ không xóa dữ liệu; phiên đang chạy vẫn có thể kết thúc sau khi đổi chế độ hoặc lưu trữ.

## 1.9.5 — Âm nhắc hoạt động mỗi 3 giây

- Đổi chu kỳ âm của lời nhắc hoạt động thành 3 giây, trong thời hạn tối đa 60 giây.

## 1.9.4 — Tắt lời nhắc ngủ ngay

- Thêm nút **Tắt lời nhắc** để đóng và dừng âm ngay.
- Đổi âm nhắc ngủ thành mỗi 3 giây.

## 1.9.3 — Sáu thẻ trong Tổng kết

- Thêm các thẻ Làm việc, Nghỉ ngơi và Giải trí.
- Bố trí Học – Nghiên cứu – Làm việc ở hàng trên; Tập thể thao – Nghỉ ngơi – Giải trí ở hàng dưới.

## 1.9.2 — Đổi tên mục Hoạt động hàng ngày

- Đổi tên **Hoạt động cá nhân** thành **Hoạt động hàng ngày**.

## 1.9.1 — Bảng nhắc gọn theo nội dung

- Đổi bảng nhắc thành thẻ bo góc rộng 400 điểm, chiều cao tự vừa số hoạt động; danh sách dài có cuộn.
- Ghi chú có thể mở/thu gọn; cửa sổ thay đổi chiều cao nhẹ và giữ vị trí góc trên phải.
- Bấm cả ô để chọn, có nút đóng và Lặp lại; lời nhắc tự hiện không giành bàn phím.

## 1.9.0 — Ghi nhận hoạt động ngoài máy

- Thêm mục Hoạt động cá nhân, chuyển phần ghi ngủ sang đây và giữ nhiệm vụ ngủ tại Mục tiêu.
- Thêm Bắt đầu/Kết thúc cho thể thao và sinh hoạt; cho sửa giờ thực tế khi về máy muộn.
- Thêm lịch sử, sửa giờ và xóa phiên. Phiên đang mở được giữ qua lần đóng/mở app.
- Tạm ngừng nhắc 5 phút khi đang ghi ngủ hoặc một phiên hoạt động; không tự bù thời gian rời máy vào công việc.

## 1.8.1 — Hai hàng ghi nhận giấc ngủ

- Tách **Ngủ trưa** và **Ngủ đêm** thành hai hàng, mỗi hàng có nút Ngủ/Thức dậy kèm biểu tượng.

## 1.8.0 — Ghi ngủ/dậy và tự tính thời gian nghỉ

- Lời nhắc ngủ chỉ nhắc giờ; người dùng chủ động ghi khi đi ngủ và thức dậy.
- Tự tạo thời gian Nghỉ ngơi từ hai mốc thực tế và tự tích nhiệm vụ nếu đúng giờ hoặc sớm hơn.
- Xử lý ngủ đêm qua nửa đêm, tạm dừng nhắc hoạt động khi ngủ, hủy ghi nhầm và xóa lịch sử ngủ.

## 1.7.1 — Giới hạn thời gian thông báo

- Bảng nhắc hoạt động và nhắc ngủ tự đóng sau tối đa 1 phút.
- Thêm âm lặp mỗi 10 giây; trả lời, bỏ qua hoặc đóng sẽ dừng âm tương ứng.

## 1.7.0 — Nhắc ngủ và bốn nhiệm vụ cố định

- Thêm nhắc ngủ đêm 00:00, dậy sáng 07:00, ngủ trưa 12:30 và dậy trưa 13:30.
- Thêm bốn nhiệm vụ cố định hằng ngày và công tắc bật/tắt trong Cài đặt.

## 1.6.0 — Mục tiêu tuần

- Thêm quản lý mục tiêu trong trang Tuần: chọn hoạt động, nhập số giờ và xem tiến độ.
- Tự tích khi hoàn thành, hỗ trợ xóa/hoàn tác; mục tiêu lặp theo tuần từ thứ Hai.
- Thay mục tiêu ở một tuần không ghi đè các tuần trước hoặc mục tiêu ngày.

## 1.5.2 — Rút gọn chú thích giao diện

- Bỏ các dòng chú thích lặp về lưu dữ liệu, múi giờ, tự lặp mục tiêu và tự tích checkbox để giao diện gọn hơn.

## 1.5.1 — Chọn đúng đơn vị thời gian

- Ngày chọn ngày; Tuần chọn tuần/năm; Tháng chọn tháng/năm; Năm chỉ chọn năm.
- Đổi nút về kỳ hiện tại thành Hôm nay, Tuần này, Tháng này, Năm nay và giữ hai mũi tên lùi/tiến đúng kỳ.

## 1.5.0 — Trang Mục tiêu mỗi ngày

- Chuyển mục tiêu từ Cài đặt thành trang riêng.
- Cho đặt mục tiêu giờ theo hoạt động, lặp mỗi ngày và tự đánh dấu khi đủ thời gian.
- Thêm xóa nhiệm vụ và hoàn tác xóa; giữ mục tiêu tuần riêng.

## 1.4.2 — Mở Tổng kết mặc định

- Hiển thị Tổng kết khi khởi động hoặc mở lại ứng dụng từ Dock/Finder.

## 1.4.1 — Chỉnh focus và tiêu đề các kỳ

- Bỏ khung focus xanh mặc định quanh mục Ngày trên các phiên bản macOS hỗ trợ.
- Làm rõ tiêu đề Tuần/Tháng/Năm theo đúng khoảng thời gian đang xem.

## 1.4.0 — Tổng kết toàn bộ lịch sử

- Thêm mục Tổng kết với tổng giờ, thời lượng và tỷ trọng từng hoạt động trong toàn bộ lịch sử.
- Dùng mục này thay lối mở Ghi nhận nhanh trên menu; bảng nhắc tự động vẫn giữ nguyên.

## 1.3.0 — Chỉ hiển thị hoạt động đã ghi nhận

- Bỏ các phần Chưa xác định/Cần bổ sung và yêu cầu nhớ lại các lượt đã bỏ lỡ.
- Khoảng không trả lời không tự cộng vào một hoạt động khác; cho chỉnh hoặc thêm thủ công khi cần.

## 1.2.0 — Tổng giờ theo ba hoạt động

- Thêm ba ô Học, Nghiên cứu, Tập thể thao theo ngày/tuần/tháng/năm, kèm tổng giờ và thời lượng giờ/phút.

## 1.1.1 — Bấm trực tiếp ô hoạt động

- Bỏ checkbox trong ghi nhận nhanh, cho bấm bất kỳ chỗ nào trong ô để ghi và đóng bảng ngay.

## 1.1 — Bảng ghi nhận nhanh

- Thêm bảng nổi có ô tick để chọn hoạt động khi đến lượt nhắc, cùng ghi chú, lặp lại và bỏ qua.

## Các tính năng nền tảng

- Nhắc ghi hoạt động mỗi 5 phút, danh mục hoạt động và lịch theo dõi có thể điều chỉnh.
- Dòng thời gian ngày, báo cáo tuần/tháng/năm, biểu đồ, lọc và chỉnh/tách bản ghi.
- Lưu dữ liệu trên máy, sao lưu/khôi phục và xuất CSV.
- Tạm dừng theo dõi khi máy ngủ hoặc khóa màn hình; theo dõi ngày/tuần theo múi giờ cấu hình.
- Chạy từ thanh menu, cho mở cùng đăng nhập và dùng dữ liệu minh họa riêng khi kiểm tra.
