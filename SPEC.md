# Nhịp — Đặc tả ứng dụng ghi nhận hoạt động trên macOS

Phiên bản đặc tả: 1.1 · Ngày: 07/11/2026 · Ghi nhận ngủ/thức, mục tiêu đúng giờ và tự lưu Nghỉ ngơi.

Từ 1.13.0, thay lưới 12 biểu tượng trong Sửa hoạt động bằng thư viện 148 biểu tượng macOS có nhãn tiếng Việt và từ khóa. Bộ lọc gồm Tất cả và sáu nhóm Học & công việc, Sức khỏe, Sinh hoạt, Giải trí, Di chuyển, Khác. Tìm kiếm kết hợp nhóm, hỗ trợ chữ hoa/thường, tiếng Việt có dấu/không dấu (cả đ/d), từ khóa tiếng Anh và tên biểu tượng. Chỉ hiện biểu tượng hệ điều hành hỗ trợ, không cần mạng hay tải tài nguyên ngoài.

Bộ chọn có xem trước tên/icon hiện tại, số kết quả, lưới tám cột cuộn trong khung cố định, viền/màu nhận diện mục đang chọn, nút xóa tìm kiếm và trạng thái không tìm thấy. Giữ các icon đã lưu ngoài thư viện nếu người dùng chưa đổi; Hủy không lưu, Lưu cập nhật cùng ID hoạt động. Sheet mở rộng để có chỗ tìm/chọn và không tràn màn hình.

Đổi tên/icon không được đổi vai trò ghi nhận: thêm Activity.personalKindResolved tùy chọn để phân biệt nil đã xác định (hoạt động thông thường) với dữ liệu legacy cần suy vai trò. Khi lưu Sửa hoạt động, chốt vai trò của bản gốc trước khi nhận biểu tượng mới; nhờ đó chọn hình cà phê/nhà/chạy bộ cho một mục công việc không tự chuyển thành Nghỉ ngơi/sinh hoạt/thể thao. Vai trò ngủ/thể thao/sinh hoạt đã có vẫn giữ khi đổi sang icon khác. Tương thích JSON/SQLite cũ và sao lưu.

Từ 1.12.4, gộp hai phần so sánh ở Tuần/Tháng/Năm thành một phần theo bố cục so sánh cũ phía trên. Chỉ dùng Reports.priorityComparison: tăng/giảm/bằng kỳ trước, % chênh lệch, kỳ đối chiếu và cùng phần thời gian đã trôi qua, tổng giờ hai kỳ, trung bình/ngày lấy giờ ưu tiên chia dayCount của từng khoảng. Bỏ khối riêng có tiêu đề sao, danh sách tên và hai cột lớn. Không còn phép so sánh tổng tất cả hoạt động/bộ lọc biểu đồ. Danh sách sao trống hiện nút chọn trong Cài đặt, không tự chuyển sang cộng toàn bộ; kỳ trước 0 không chia tính %. Giữ biểu đồ, heatmap, biểu đồ trung bình năm theo bộ lọc và Card ưu tiên Ngày hiện có.

Từ 1.12.3, ô ưu tiên của trang Ngày dùng tiêu đề Tổng thời gian ưu tiên, bỏ dòng liệt kê tên hoạt động, thay nhãn ngày cụ thể bằng Hôm nay/Hôm qua. Dòng so sánh dùng Nhiều hơn/Ít hơn/Bằng hôm qua. Giữ nguyên hai khoảng ngày theo bộ chọn ngày và toàn bộ cách tính giờ/tỷ lệ/chênh lệch; phần so sánh tuần/tháng/năm không đổi.

Từ 1.12.2, chuyển Card Thời gian ưu tiên của trang Ngày xuống ngay sau Card Dòng thời gian và trước Thời gian theo hoạt động. Hai tổng ngày có tỷ lệ = số giây / 86.400, trình bày ≈ x,x% của 24 giờ, dùng mẫu số cố định 24h theo yêu cầu. Thêm Nhiều hơn/Ít hơn ngày trước [thời lượng] và % chênh so với ngày trước khi mẫu số > 0; chênh bằng 0 hiện Bằng ngày trước, không tự ghi Tăng 0. Giữ nguyên cách tính tổng cả ngày trước và nguồn dữ liệu/nhóm sao, không đổi lịch nhắc hoặc mục tiêu.

Từ 1.12.1, trang Ngày có Card Thời gian ưu tiên sau các thẻ tổng giờ và trước timeline. Số chính là tổng giờ nhóm sao trong ngày đang chọn, dưới là tổng cả ngày liền trước kèm dd/MM/yyyy. Dùng Calendar/múi giờ báo cáo và hai khoảng ngày đầy đủ, không giới hạn ngày trước đến giờ hiện tại như so sánh kỳ đang diễn ra. Cắt đúng phần Entry qua nửa đêm/DST, tổng mọi nguồn ghi và độc lập bộ lọc biểu đồ. Chưa chọn sao hiện nút mở Cài đặt → Hoạt động; lựa chọn/ngày thay đổi cập nhật ngay.

Từ 1.12.0, mỗi Activity có cờ isPriority tùy chọn, mặc định chưa chọn, tương thích JSON/SQLite cũ. Người dùng bật/tắt sao ở Cài đặt → Hoạt động hoặc Toggle Hoạt động ưu tiên trong Sửa hoạt động. Lưu ngay khi bấm sao; theo ID qua đổi tên/lưu trữ, độc lập chế độ nhắc/tự ghi và các mục tiêu. Reset tạo danh mục mặc định không ưu tiên. Không tự chọn thay người dùng.

Giữ phép so sánh thông thường và thêm nhóm Thời gian ưu tiên ở Tuần/Tháng/Năm: tên các mục ưu tiên, tổng giờ kỳ này/kỳ trước, chênh lệch thời lượng và phần trăm. Tính từ mọi nguồn Entry (checkin/manual/personal-timer/sleep) thuộc ID ưu tiên, gồm hoạt động lưu trữ để giữ lịch sử. Kỳ đang diễn ra dùng cùng comparisonRanges theo phần thời gian trôi qua; cắt Entry đúng biên ngày/tháng/năm. Không có giờ kỳ trước thì không tính %. Chưa chọn ưu tiên hiện trạng thái rỗng và nút mở trực tiếp Cài đặt → Hoạt động.

Danh sách ưu tiên là cấu hình hiện tại và được áp dụng như nhau cho cả hai kỳ, không tạo trọng số hoặc nhân số giờ. Không bị thay bởi bộ lọc hoạt động của biểu đồ; nhóm so sánh thường vẫn dùng bộ lọc đó. Không sửa Entry/Goal/Preferences khi bật ưu tiên. Truy vấn cộng giờ ưu tiên quét Entry một lần; chữ ký/bundle cập nhật giữ các lựa chọn cũ và chưa tự bật cờ mới.

Từ 1.11.5, bỏ nhãn Mỗi ngày trên từng dòng mục tiêu ngày do nhóm Nhiệm vụ trong ngày đã xác định kỳ; giữ tên, mục tiêu thời lượng, tiến độ và nhãn Mỗi tuần của mục tiêu tuần.

Từ 1.11.4, lưới Nhịp hoạt động trong tháng dùng một dãy ô có ID duy nhất gồm ô trống đầu tuần và toàn bộ ngày 1 đến cuối tháng. Giữ căn thứ Hai–Chủ nhật, không bỏ các ngày 1–6 khi tháng bắt đầu Chủ nhật. Nút ngày có nhãn trợ năng đầy đủ ngày/tháng/năm. Tại Mục tiêu, nhóm mục tiêu do người dùng tạo có tiêu đề Nhiệm vụ trong ngày, tách với tiêu đề Ngủ & thức dậy.

Từ 1.11.3, nhóm sáu thẻ Học/Nghiên cứu/Làm việc/Tập thể thao/Nghỉ ngơi/Giải trí vào cùng khung Thời gian theo từng hoạt động. Tiêu đề nằm trên các thẻ; bên dưới các thẻ là tổng cộng và các dòng chi tiết. Nhiệm vụ đã hoàn thành vẫn đứng trước khung này; không đổi thứ tự sáu thẻ hoặc các trang kỳ khác.

Từ 1.11.2, đưa Nhiệm vụ đã hoàn thành lên ngay sau lời chào Tổng kết, trước sáu thẻ tổng giờ; sau đó vẫn là bảng Thời gian theo từng hoạt động. Chỉ đổi vị trí, giữ nguyên thứ tự và nội dung các phần khác.

Từ 1.11.1, reset nhật ký đặt lại mốc thống kê ngủ về ngày reset, xóa mọi lượt mục tiêu/hoàn thành cũ. Mốc đã lưu là ranh giới cố định: phiên Ngủ đêm bắt đầu sau 00:00 vẫn có goalDay của tối trước theo quy tắc ngủ, nhưng không được kéo mốc thống kê lùi ngày. Tổng kết chỉ đếm lượt ngủ từ mốc đã lưu; marker cũ ngoài mốc không tính vào tử số. Dữ liệu legacy chưa có mốc mới suy ra từ lịch sử. Sau reset mặc định là 0/4 nhiệm vụ ngày, 0/0 tuần; qua ngày sau thêm 4 lượt, không đổi chỉ vì bắt đầu ngủ sau nửa đêm.

Từ 1.11.0, cuối Tổng kết thêm Nhiệm vụ đã hoàn thành với hai ô Nhiệm vụ ngày/Nhiệm vụ tuần, completed/total, tỷ lệ một chữ số thập phân và thanh tiến độ. Đếm lượt lặp của từng mục tiêu từ kỳ effectiveFrom đến kỳ hiện tại (gồm kỳ đang diễn ra), không đếm số định nghĩa duy nhất; hoàn thành theo cùng tiêu chí của trang mục tiêu. Tuần chọn phiên bản áp dụng cho từng tuần, limit chỉ đạt sau khi tuần kết thúc, observe không tính vào mẫu số. Chia thời lượng đúng ranh giới Calendar/múi giờ và DST; gồm danh mục lưu trữ, không cộng nhầm hoạt động. Mẫu số bằng 0 hiện “—”, không ghi 100%.

Theo lựa chọn người dùng, thống kê ngày gồm bốn mục tiêu ngủ/thức dậy khi chức năng nhắc ngủ bật. Lấy ngày sớm nhất có bằng chứng mục tiêu ngủ trong dữ liệu cũ; nếu chưa có, lấy ngày cập nhật đầu tiên. Lưu statisticsStartDay tùy chọn trong SleepReminderState để ngày chưa ghi nhận cũng được cộng khi sang ngày mới. Marker giấc ngủ thật ưu tiên hơn dấu tích legacy, đúng giờ tính như trang Mục tiêu; không lấy lịch sử công việc xa xưa làm ngày bắt đầu nhiệm vụ ngủ. Tắt chức năng ngủ thì nhóm này không nằm trong thống kê, giống danh sách mục tiêu hiện hành.

Thống kê tính lại từ mục tiêu và lịch sử còn được lưu, không có bộ đếm tăng vĩnh viễn. Xóa mục tiêu sẽ loại mục tiêu đó khỏi thống kê; sửa mức mục tiêu ngày áp dụng lại mức hiện tại cho các ngày từ effectiveFrom, vì dữ liệu ngày cũ không có phiên bản theo thời gian. Phiên bản mục tiêu tuần đã được lưu nên vẫn giữ mức đúng từng tuần. Không suy đoán lại mục tiêu đã xóa hoặc thời điểm bật/tắt ngủ trước khi có dữ liệu. Làm mới sau chỉnh sửa và mỗi 30 giây; tổng hợp Entry bằng lượt quét theo kỳ, marker ngủ được lập chỉ mục một lần, tránh quét toàn lịch sử cho từng ngày.

Từ 1.10.1, bỏ nút Thêm hoạt động ở Tuần/Tháng/Năm/Tổng kết, giữ ở Ngày. Bỏ toàn bộ nút share/xuất CSV trên dashboard; Cài đặt → Dữ liệu có Sao lưu JSON/Khôi phục JSON/Xuất CSV toàn bộ lịch sử. Thay nhãn Toàn bộ lịch sử ở Tổng kết bằng Xin chào [tên]! Tên sửa tại Cài đặt → Cá nhân → Tên người dùng → Lưu tên, cập nhật ngay và lưu trong preferences.userName tùy chọn để tương thích dữ liệu cũ/sao lưu. Chưa đặt tên dùng NSFullUserName của macOS, dự phòng “bạn”. Không đổi phạm vi báo cáo toàn lịch sử.

Từ 1.10.0, Cài đặt → Hoạt động có lựa chọn riêng cho từng danh mục: Nhắc định kỳ, Tự ghi nhận, Cả hai. Lưu ngay trên từng hàng. Nhắc định kỳ đưa danh mục đang dùng vào bảng hỏi và Giống lần trước; Tự ghi nhận thêm hàng Bắt đầu/Kết thúc ở Hoạt động hàng ngày; Cả hai cho phép cả hai đường ghi. Nghỉ ngơi không có lựa chọn này, tiếp tục qua ngủ riêng. Mặc định dữ liệu cũ giữ nguyên hành vi: danh mục công việc nhắc định kỳ, thể thao/sinh hoạt thủ công. Mode tùy chọn gắn ID hoạt động, bền qua đổi tên và JSON/SQLite; không sửa bản ghi hoặc mục tiêu cũ.

Phiên thủ công dùng activityID cho mọi danh mục, không giới hạn thể thao/sinh hoạt. Khi đổi chế độ hoặc lưu trữ danh mục đang ghi dở, vẫn giữ hàng để kết thúc/hủy; khi xong áp dụng danh sách mới. Tất cả các đường ghi dùng chung Entry/danh mục để tổng hợp mục tiêu và báo cáo. Trong phiên thủ công không chạy chu kỳ hỏi để tránh ghi trùng; kết thúc tiếp tục từ thời điểm trở về máy nếu theo dõi đang bật. Nếu mọi danh mục đều tự ghi, đóng chu kỳ và không hiện nhắc rỗng; bật lại danh mục nhắc bắt đầu chu kỳ mới. Lịch sử, sửa giờ và mục tiêu giữ nguyên khi đổi mode. Các mô tả lọc cứng danh mục cá nhân ở phiên bản cũ bên dưới được thay bằng lựa chọn này.

Từ 1.9.5, âm nhắc ghi nhận hoạt động cũng dùng chu kỳ 3 giây như nhắc ngủ, phát ở 0/3/6…57, đóng ở 60 giây. Giữ công tắc Phát âm báo của ghi nhận; chọn hoạt động/Bỏ qua/đóng/tạm dừng phải dừng âm và hủy timer ngay. Chu kỳ hỏi hoạt động vẫn 5 phút (hoặc chu kỳ đã chọn), không đổi thành 3 giây. Các mô tả ghi nhận âm 10 giây bên dưới thuộc phiên bản cũ.

Từ 1.9.4, lời nhắc ngủ có nút Tắt lời nhắc (bell.slash.fill), cửa sổ nhận click để người dùng đóng ngay mà không cần chờ hết một phút. Bấm nút hủy timer và dừng NSSound ngay, không đổi lịch nhắc các lần sau hoặc tạo dấu tích/nhật ký. Nhắc ngủ phát âm mỗi 3 giây ở 0/3/6…57 và tự đóng ở 60 giây; ghi nhận công việc giữ 10 giây. Bộ điều khiển dùng cadence riêng mỗi lượt, hủy callback cũ khi đóng; timer trễ không phát dồn. Cửa sổ ngủ vẫn không giành bàn phím khi tự hiện; preview được người dùng yêu cầu thì có thể nhận focus để thử nút đóng. Mô tả nhắc ngủ không nút/âm 10 giây ở các phiên bản cũ bên dưới được thay bằng quy tắc này.

Từ 1.9.3, trang Tổng kết tất cả thời gian có sáu thẻ xếp ba cột/hai hàng. Thứ tự hàng trên Học/Nghiên cứu/Làm việc; hàng dưới Tập thể thao/Nghỉ ngơi/Giải trí. Làm việc đọc danh mục Công việc hoặc Làm việc, giữ dữ liệu gốc. Thẻ lấy tổng thời lượng toàn lịch sử, gồm danh mục đã lưu trữ, có giờ thập phân và giờ/phút. Các màn hình Ngày/Tuần/Tháng/Năm tiếp tục dùng ba thẻ theo kỳ như trước.

Từ 1.9.1, thu gọn bảng Ghi nhận nhanh: bỏ frame 440×570 và khoảng Spacer dưới, dùng thẻ bo góc 22 điểm rộng 400, nền material, viền/bóng nhẹ, không thanh tiêu đề hệ thống; có nút đóng riêng. Lưới hai cột, ô cao 52 điểm, khoảng cách 8; chiều cao vừa số hàng, tối đa bốn hàng rồi cuộn. Đo chiều cao nội dung SwiftUI để cập nhật NSPanel, giữ góc trên phải và chuyển kích thước nhẹ khi hiện/ẩn ghi chú hoặc danh mục thay đổi. Ô ghi chú mặc định ẩn, bấm Ghi chú mới mở và nhận focus; lượt mới đặt lại nội dung và trạng thái ghi chú. Xem thử có nhãn riêng và không tạo dữ liệu. Giữ click ô để ghi ngay, Lặp lại, Bỏ qua, không giành bàn phím khi tự hiện, thời hạn 60 giây và âm 10 giây.

Từ 1.9.0, thêm mục Hoạt động hàng ngày ngay dưới Mục tiêu trên thanh bên và menu. Chuyển nguyên phần ghi nhận giấc ngủ/lịch sử ngủ sang đây, giữ bốn mục tiêu ngủ cố định tại Mục tiêu. Bổ sung hai hàng Tập thể thao và Sinh hoạt cá nhân với nút Bắt đầu/Kết thúc có biểu tượng; khi Kết thúc mở bảng cho chỉnh ngày/giờ bắt đầu và kết thúc trước khi Lưu và kết thúc. Lịch sử đã lưu có Sửa giờ, xóa và Xem thêm. Hủy bảng kết thúc giữ phiên đang chạy. Phiên dùng thời điểm thực tế, không chia thành các câu hỏi 5 phút; ghi vào Entry và tổng hợp báo cáo/mục tiêu như cũ. Cho sửa giờ sau khi kết thúc để xử lý về nhà muộn, không tự ghi hoạt động trong khoảng chênh.

Một phiên ngủ/thể thao/sinh hoạt đang mở tại một thời điểm, lưu qua thoát/crash/mở lại và sao lưu JSON/SQLite. Trong phiên không tạo khoảng hoặc nhắc công việc; khi lưu kết thúc, chu kỳ công việc mới tính từ lúc thao tác trên máy, không từ giờ kết thúc đã sửa trong quá khứ. Giữ enabled/manual pause/lịch; không tự bật lại theo dõi đã tắt. Cấm giờ ngược, giờ tương lai, phiên hoặc Entry chồng lấn; lỗi nguyên tử, giữ dữ liệu khác. Sửa cùng ID Entry để không cộng trùng. Hủy phiên đang mở hoặc xóa phiên tự tạo không xóa các bản ghi khác/phần đã chỉnh sửa tay.

Thêm vai trò tùy chọn personalKind trên Activity và personalHistory tùy chọn trên Journal, tương thích dữ liệu cũ. Ba vai trò là exercise/personal/rest (rest dùng cho ngủ). Khi đọc dữ liệu cũ, nhận diện tên/biểu tượng hoặc liên kết nghỉ ngơi của giấc ngủ để gắn vai trò; giữ ID, entries và goals cũ. Sau đó vai trò bền qua đổi tên/lưu trữ danh mục. Bảng hỏi 5 phút chỉ hiện hoạt động đang dùng không có vai trò cá nhân, ẩn cả lựa chọn Giống lần trước nếu lần trước thuộc ba nhóm này. Chỉ lọc giao diện ghi nhận nhanh; không bỏ chúng khỏi thống kê, chọn mục tiêu hoặc thêm/sửa thủ công.

Từ 1.8.1, giao diện ghi nhận giấc ngủ là hai hàng Ngủ trưa/Ngủ đêm, thay picker và checkbox Đang ngủ. Mỗi hàng có biểu tượng riêng và hai nút Ngủ (bed.double.fill), Thức dậy (sunrise.fill). Chưa ngủ thì hai nút Ngủ khả dụng; khi có phiên đang mở, khóa nút Ngủ của cả hai hàng, chỉ bật Thức dậy ở đúng hàng đó; có giờ bắt đầu và nút hủy ở hàng đang ngủ. Giữ nguyên cách lưu thời điểm, tính mục tiêu và sinh Nghỉ ngơi từ 1.8.0.

Từ app 1.8.0, lời nhắc ngủ chỉ hiển thị nội dung/giờ, không có nút xác nhận/mở mục tiêu/đóng; cửa sổ không có nút tiêu đề và không nhận click. Native fallback cũng không có action. Giữ thời hạn 60 giây và âm 10 giây khi app chạy. Không tạo dữ liệu từ việc giao thông báo hoặc các action của thông báo cũ.

Trang Mục tiêu có bốn mục tiêu ngủ/thức dậy tự tính, không cho tích bằng tay. Bên dưới thêm Ghi nhận giấc ngủ: chọn Ngủ trưa/Ngủ đêm, tích Đang ngủ để lưu thời điểm bắt đầu, bỏ tích để lưu thời điểm thức dậy. Một giấc ngủ đang mở tại một thời điểm, lưu bền qua thoát/crash/khởi động và sao lưu/khôi phục. Khi kết thúc, tạo đúng một Entry Nghỉ ngơi từ start tới end, nguồn sleep; không tự suy đoán từ việc máy sleep/wake. Tổng hợp ngày/tuần/tháng/năm dùng Entry này như hoạt động bình thường, chia đúng phần qua nửa đêm. Nghỉ ngơi được liên kết bằng ID để đổi tên/lưu trữ danh mục vẫn ghi đúng. Không ghi đè hoạt động xung đột; báo lỗi nguyên tử để người dùng xử lý. Có hủy phiên đang mở/xóa phiên đã kết thúc và bản tự sinh, không xóa phần người dùng đã sửa thủ công.

Quy tắc người dùng xác nhận: ngủ đêm tối ngày D đạt nếu bắt đầu ≤00:00 ngày D+1; mục tiêu sáng D+1 đạt nếu kết thúc ≤07:00 ngày D+1. Bắt đầu sau 00:00 tới trước 12:00 thuộc tối trước; từ 12:00 trở đi thuộc tối cùng ngày. Ngủ trưa đạt ≤12:30, dậy trưa đạt ≤13:30 cùng ngày. Độ chính xác phút, ví dụ 12:30:59 vẫn thuộc phút 12:30; 12:31 là muộn. Mỗi mốc đạt độc lập, vẫn ghi thời lượng nghỉ khi muộn. Deadline và ngày mục tiêu giữ múi giờ tại lúc bắt đầu, không đổi quá khứ khi đổi cài đặt. Dấu tích legacy không có timestamp được giữ để tương thích; các mốc đã có phiên ngủ mới thì ưu tiên tính theo giờ thật.

Trong lúc có giấc ngủ đang mở, ngừng tạo khoảng/nhắc ghi nhận 5 phút, đóng bảng nhắc cũ; khi kết thúc/hủy chỉ tiếp tục nếu runtime đang bật và lịch/pause cho phép. Không tự bật lại chế độ đã tạm dừng bằng tay; không tạo backlog cho thời gian ngủ. Tắt nhắc ngủ không ngăn ghi nhận thủ công giấc ngủ. Các mô tả xác nhận trực tiếp trên thông báo ở 1.7 bên dưới được thay bằng quy tắc 1.8 này.

Từ app 1.7.1, áp dụng thời hạn 60 giây cho cả ghi nhận 5 phút và nhắc ngủ. Khi hiện phát âm một lần rồi ở các mốc 10/20/30/40/50 giây; đến 60 giây đóng cửa sổ, dừng âm, không tự trả lời hoặc tích mục tiêu. Trả lời, bỏ qua, đóng sớm, tạm dừng ghi nhận hoặc tắt nhắc ngủ phải hủy bộ đếm và dừng âm tương ứng ngay. Âm ghi nhận giữ công tắc Phát âm báo; âm ngủ theo công tắc Nhắc nhở ngủ. Dùng cả thời gian hệ thống và uptime để đổi ngược đồng hồ không kéo dài lượt; sau sleep/lock hoặc timer trễ không phát dồn âm đã lỡ. Cửa sổ nhắc ngủ không kích hoạt dashboard/giành bàn phím.

Trong khi app chạy, lịch ngủ do timer theo Calendar/múi giờ báo cáo hiển thị cửa sổ riêng, hủy bốn request macOS để tránh nhắc đôi. Đóng dashboard vẫn nhắc đủ 60 giây/10 giây; app không tự đánh thức máy. Thoát bình thường phải chờ đặt lại bốn thông báo macOS lặp mỗi ngày trước khi kết thúc; mở app hủy lịch dự phòng và thông báo cũ. Khi app đã thoát hoặc bị buộc dừng, app không thể điều khiển thời gian banner hoặc lặp âm 10 giây; native fallback chịu quyền/Focus/cài đặt macOS và không được bảo đảm nếu crash. Các mô tả native notifications trong mục 1.7 bên dưới áp dụng cho lịch dự phòng. Preview dùng cùng thời hạn/âm báo nhưng không ghi dữ liệu.

Từ app 1.7, thêm bốn lời nhắc ngủ cố định hằng ngày theo múi giờ báo cáo: 00:00 ngủ đêm, 07:00 dậy buổi sáng, 12:30 ngủ trưa, 13:30 dậy sau ngủ trưa. Mặc định bật theo yêu cầu; công tắc tại Cài đặt → Nhắc & lịch bật/tắt ngay cả bốn lịch và bốn mục tiêu cố định. Mục tiêu xuất hiện trong trang Mục tiêu mỗi ngày, có checkbox xác nhận/bỏ xác nhận thủ công hoặc qua nút Đã đi ngủ/Đã thức dậy trên thông báo. Không tự tích chỉ vì đã đến giờ; không tự cộng giờ ngủ vào thống kê hoạt động. Mỗi ngày có trạng thái riêng, sang 00:00 bắt đầu lại. Không xóa riêng từng mục cố định; dùng công tắc chung. Tắt giữ lịch sử và bỏ qua thao tác từ thông báo cũ; bật lại giữ kết quả trong ngày. Dữ liệu mới là trường tùy chọn, tương thích JSON/SQLite cũ, bao gồm sao lưu/khôi phục.

Lịch ngủ dùng UNCalendarNotificationTrigger lặp hằng ngày, hoạt động riêng với ghi nhận 5 phút và vẫn được macOS giữ khi app thoát. Tắt chức năng phải hủy các lịch đã đặt và thông báo đã hiển thị; đổi múi giờ/khôi phục/hoàn tác phải đồng bộ lại. Cần quyền Notifications; Focus hoặc cài đặt macOS có thể ẩn thông báo. Không có chức năng đánh thức máy đang ngủ/gập nắp/tắt. Thông báo thử sau 3 giây không thay đổi mục tiêu hoặc nhật ký; dữ liệu demo dùng mã thông báo riêng, không thay lịch thật.

Từ app 1.6, màn hình Tuần có phần Mục tiêu tuần ngay dưới ba ô tổng giờ, gồm biểu mẫu chọn hoạt động/số giờ, tiến độ, checkbox tự tích, xóa và hoàn tác. Mức tối thiểu từ 1 phút đến 168 giờ, áp dụng từ tuần đang chọn và lặp sang các tuần sau; tiến độ tính riêng tuần thứ Hai–Chủ nhật đang xem, không cộng nhầm tuần khác hoặc mục tiêu ngày. Lưu lại trong cùng tuần để sửa mức; lưu ở tuần khác tạo phiên bản mới để giữ mức của tuần trước. Các mục tiêu tuần cũ chuyển sang quản lý tại đây; trang Mục tiêu mỗi ngày chỉ còn mục tiêu ngày. Không thêm các dòng chú thích phụ đã được yêu cầu gỡ.

Từ app 1.5, Mục tiêu được chuyển khỏi Cài đặt thành mục riêng dưới Tổng kết. Mục tiêu mới là mức thời gian tối thiểu cho từng hoạt động, lặp lại mỗi ngày; tiến độ chỉ tính các bản ghi trong ngày theo múi giờ báo cáo, tự tính lại từ 00:00. Checkbox do app tự tính từ thời lượng, không đánh dấu bằng tay; sửa hoặc xóa hoạt động sẽ tính lại trạng thái. Có nút xóa mục tiêu và hoàn tác xóa, không ảnh hưởng nhật ký hoạt động. Mỗi hoạt động có tối đa một mục tiêu hằng ngày hiện hành, mức từ 1 phút đến 24 giờ; lưu lại cùng hoạt động để điều chỉnh mức hiện tại. Mục tiêu tuần cũ được giữ riêng, không tự đổi sang mục tiêu ngày. Dữ liệu cũ thiếu trường period được hiểu là tuần.

Từ app 1.4, thay lối mở Ghi nhận nhanh thủ công bằng mục “Tổng kết” trên thanh bên và “Tổng kết tất cả thời gian” trên thanh menu. Màn hình này tổng hợp mọi bản ghi qua mọi năm, hiển thị từng danh mục với số giờ, thời lượng giờ/phút, tỷ trọng, tổng cộng và phạm vi ngày có dữ liệu. Bao gồm danh mục đã lưu trữ; danh mục chưa có bản ghi hiện 0 giờ. Không dùng bộ lọc ngày hoặc hoạt động của các màn hình khác. Có thể xuất CSV toàn bộ lịch sử. Bảng nhắc tự hiện mỗi chu kỳ vẫn được giữ để ghi nhận hoạt động.

Quy tắc hiện hành từ app 1.3: bỏ các phần “Chưa xác định”, “Cần bổ sung”, số lượng khoảng chờ, vùng màu cho khoảng chưa trả lời và các cảnh báo độ đầy đủ khỏi giao diện. Khoảng bỏ qua không được tự gán hoạt động và không hỏi lại. Mỗi lần nhắc chỉ hỏi khoảng vừa qua; lượt mới thay thế lượt cũ. Các mốc theo dõi cũ vẫn giữ nội bộ để tương thích dữ liệu; không xóa hoạt động đã lưu. Các mô tả về danh sách chờ và cảnh báo độ đầy đủ bên dưới thuộc thiết kế ban đầu, được thay bằng quy tắc hiện hành này.

## 1. Mục tiêu sản phẩm

Ứng dụng cá nhân chạy trên MacBook Air M1, nhắc người dùng mỗi 5 phút để ghi lại hoạt động vừa thực hiện. Người dùng có thể xem lại lịch sử trong ngày, tổng thời gian theo hoạt động và xu hướng theo tuần, tháng, năm.

Đây là nhật ký do người dùng xác nhận, có độ phân giải mặc định 5 phút. Thời lượng là ước lượng theo câu trả lời, không phải phép đo tự động toàn bộ cuộc sống. Không tự đọc màn hình, lịch sử trình duyệt hay ứng dụng đang dùng.

Tên “Nhịp” là tên làm việc, có thể đổi sau.

## 2. Phạm vi bản đầu tiên

- Ứng dụng macOS có biểu tượng trên thanh menu và cửa sổ dashboard riêng.
- Nhắc mặc định mỗi 5 phút, có tùy chỉnh chu kỳ và khung giờ hoạt động.
- Chọn hoạt động nhanh, ghi chú tùy chọn, sửa hoặc bổ sung lịch sử.
- Timeline và thống kê theo ngày.
- Biểu đồ theo tuần, tháng, năm và so sánh với kỳ trước.
- Mục tiêu hằng ngày cho từng hoạt động, tự đánh dấu hoàn thành; giữ các mục tiêu tuần đã tạo trước đây.
- Lưu dữ liệu trên máy, xuất CSV và sao lưu/khôi phục dữ liệu.
- Tùy chọn mở cùng lúc đăng nhập máy, mặc định tắt.

Chưa thuộc bản đầu: đồng bộ cloud, ứng dụng điện thoại, AI chấm điểm, nhận diện hoạt động tự động, tài khoản và bảng xếp hạng.

## 3. Danh mục hoạt động

| Hoạt động mặc định | Ví dụ |
| --- | --- |
| Học | Học môn mới, làm bài tập, học ngoại ngữ |
| Nghiên cứu | Đọc tài liệu chuyên sâu, thử nghiệm, phân tích |
| Tập thể thao | Chạy bộ, gym, yoga, vận động |
| Giải trí | Xem phim, chơi game, mạng xã hội |
| Công việc | Công việc chuyên môn, dự án, việc hành chính |
| Sinh hoạt cá nhân | Ăn uống, vệ sinh, việc nhà |
| Nghỉ ngơi | Nghỉ giải lao, thư giãn |
| Khác | Hoạt động chưa có nhóm phù hợp |

Người dùng có thể thêm, đổi tên, sắp xếp, đổi màu và lưu trữ danh mục. Mỗi khoảng thời gian có đúng một hoạt động chính để tránh cộng trùng; có thể thêm ghi chú về hoạt động phụ. “Chưa xác định” là trạng thái dữ liệu, không phải danh mục hoạt động.

Lưu trữ danh mục không làm mất lịch sử. Đổi tên được áp dụng cho cách hiển thị cả dữ liệu cũ; danh mục giữ nguyên ID.

## 4. Luồng sử dụng

### 4.1. Thiết lập lần đầu

1. Giới thiệu ngắn cách hoạt động và quy tắc “trả lời cho khoảng vừa qua”.
2. Giải thích bảng nhắc tự hiện; quyền banner macOS là tùy chọn.
3. Cho phép chỉnh danh mục và chu kỳ; mặc định 5 phút.
4. Chọn theo dõi thủ công hoặc theo lịch. Mặc định thủ công: bắt đầu khi người dùng bật theo dõi, không tự đặt một lịch sinh hoạt thay người dùng.
5. Bấm “Bắt đầu theo dõi”; lần nhắc đầu sau 5 phút.

### 4.2. Nhắc và trả lời

Ví dụ bắt đầu lúc 09:00, đến 09:05 app tạo một yêu cầu ghi nhận cho khoảng 09:00–09:05.

Nội dung thông báo:

> Bạn đang làm gì?
> Ghi nhận hoạt động trong 5 phút vừa qua · 09:00–09:05.

Đến giờ, bảng chọn nhanh của app tự hiện ở góc màn hình, hiển thị:

- Khoảng thời gian đang được hỏi.
- Các ô hoạt động có vùng bấm phủ toàn bộ ô; mỗi lần bấm ghi nhận một hoạt động chính cho khoảng.
- Nút “Giống lần trước”, ghi rõ tên hoạt động sẽ dùng; chỉ bật khi đã có lần trả lời trước đó.
- Ghi chú tùy chọn.
- “Bỏ qua khoảng này” và liên kết mở dashboard.

Bấm vào ô hoạt động để lưu ngay và đóng bảng, không có checkbox hoặc bước bấm Lưu riêng. Nếu muốn ghi chú, nhập trước khi chọn ô. Có thể hoàn tác hoặc sửa trong lịch sử. Bảng là một cửa sổ nổi riêng, tự hiện mỗi chu kỳ nhưng không tự đưa dashboard ra trước hay giành bàn phím khi vừa xuất hiện. Nếu bảng vẫn mở lúc đến chu kỳ tiếp theo, chuyển sang khoảng vừa kết thúc; không gom các lượt cũ thành danh sách chờ.

Tất cả danh mục nằm trong bảng nhắc riêng của app, có vùng cuộn khi danh sách dài. Bảng này không phải banner Notification Center, không cần quyền thông báo và có thể hiện khi Focus bật. Người dùng tạm dừng Nhịp nếu không muốn bảng hiện. Banner macOS là tùy chọn và vẫn chịu thiết lập thông báo của hệ điều hành. Có nút “Xem thử bảng nhắc nhanh” để thử thao tác mà không ghi nhật ký.

### 4.3. Thanh menu

Hiển thị trạng thái đang theo dõi/tạm dừng và thời điểm nhắc kế tiếp. Các thao tác chính:

- Ghi nhận khoảng chờ gần nhất.
- Mở dashboard.
- Tạm dừng 15 phút, 30 phút, 60 phút hoặc đến khi bật lại.
- Tiếp tục theo dõi.
- Cài đặt.
- Thoát ứng dụng, kèm giải thích rằng thoát sẽ dừng nhắc.

Đóng cửa sổ dashboard không đồng nghĩa với thoát ứng dụng.

## 5. Quy tắc thời gian và dữ liệu

### 5.1. Chia khoảng và gán hoạt động

- Mỗi lần trả lời gán hoạt động cho khoảng thời gian được ghi rõ trên bảng chọn, không gán cho 5 phút tiếp theo.
- Các khoảng dùng biên bắt đầu bao gồm, biên kết thúc không bao gồm: [start, end), không chồng lấn.
- Lưu thời gian đến giây; hiển thị phút hoặc giờ/phút. Chỉ làm tròn khi trình bày, không làm tròn từng bản ghi trước khi cộng.
- Trả lời trễ không thay đổi khoảng thời gian cần ghi nhận.
- Nếu trong 5 phút có nhiều hoạt động, chọn hoạt động chiếm phần lớn; có thể tách khoảng chính xác hơn trong màn hình chỉnh sửa.
- Các khoảng liền nhau cùng hoạt động được gộp khi hiển thị timeline, vẫn giữ dữ liệu nguồn để chỉnh sửa.
- Khoảng đang diễn ra chưa được tự cộng vào thời gian của bất kỳ hoạt động nào.

### 5.2. Bỏ qua hoặc trả lời trễ

- Không trả lời hoặc bấm bỏ qua: khoảng đó có trạng thái “chưa xác định”. Không tự tiếp tục hoạt động cũ.
- Mỗi chu kỳ tiếp theo vẫn tạo khoảng mới trong thời gian theo dõi.
- Chỉ duy trì thông báo nhắc mới nhất và xóa/thay thông báo nhắc cũ khi có thể; lịch sử khoảng chưa xác định vẫn được giữ trong app.
- Thông báo bị mở trễ phải dẫn tới đúng khoảng gốc. Nếu khoảng đã được xử lý, hiển thị dữ liệu đã lưu thay vì tạo bản ghi mới.
- Dashboard chỉ hiển thị các hoạt động đã ghi nhận, không hiển thị danh sách khoảng bỏ qua và không yêu cầu điền lại. Bảng ghi nhận nhanh chỉ mở lượt gần nhất chưa trả lời, chưa bỏ qua và chưa hết một chu kỳ; không quay về các lượt cũ.

### 5.3. Sleep, khóa màn hình và tạm dừng

- Mặc định tạm dừng theo dõi khi máy sleep hoặc khóa màn hình, không gửi nhắc trong khoảng này.
- Khi chuyển sang tạm dừng, chốt phần khoảng còn dang dở thành “chưa xác định”; chỉ đưa vào danh sách cần bổ sung, không phát thêm thông báo.
- Khi máy thức/mở khóa, bắt đầu chu kỳ mới nếu trước đó đang theo dõi và vẫn trong lịch hoạt động. Không phát dồn các thông báo đã lỡ.
- Khoảng máy sleep, khóa, tạm dừng hoặc ngoài lịch được thể hiện là “không theo dõi”, không tính vào mẫu số độ đầy đủ.
- Không đồng nhất sleep của máy với người dùng đang ngủ. Người dùng vẫn có thể thêm thủ công hoạt động đã làm khi rời máy, ví dụ tập thể thao.
- Nếu người dùng tạm dừng thủ công thì mở khóa không tự bật lại trước khi hết thời hạn tạm dừng.

### 5.4. Khởi động lại, lỗi và chỉnh đồng hồ

- Lưu các mốc khoảng và câu trả lời ngay khi thay đổi; mở lại app không nhân đôi bản ghi.
- Thoát app chủ động chốt khoảng dang dở; thời gian sau đó là “không theo dõi”.
- Ghi heartbeat định kỳ để có thể phát hiện phiên bị dừng bất thường. Khi mở lại sau lỗi, chỉ khôi phục phần phiên đã được xác nhận đang chạy; không tự gán hoạt động hay kéo dài theo dõi suốt thời gian app không chạy.
- Dùng thời gian đơn điệu cho bộ đếm trong phiên, cùng timestamp UTC để lưu trữ. Phát hiện thay đổi đồng hồ và tạo mốc phiên mới nếu cần, không tạo thời lượng âm hoặc khoảng chồng nhau.
- Khoảng theo dõi hiện tại được chốt khi đổi chu kỳ hoặc lịch; cấu hình mới áp dụng từ mốc đó.

### 5.5. Ngày, tuần và múi giờ

- Múi giờ báo cáo mặc định là Asia/Ho_Chi_Minh, có thể đổi trong cài đặt.
- Một ngày tính từ 00:00 đến 24:00 theo múi giờ báo cáo. Tuần từ thứ Hai đến Chủ nhật; tháng và năm theo lịch.
- Khoảng đi qua nửa đêm được chia khi tổng hợp theo ngày, không nhân đôi thời lượng.
- Đổi múi giờ báo cáo có thể thay đổi ngày chứa một bản ghi; dữ liệu timestamp gốc giữ nguyên.
- Thời lượng thực tế tính bằng chênh lệch timestamp; xử lý cả ngày có đổi giờ mùa hè nếu người dùng chọn múi giờ khác.

## 6. Dashboard

Giao diện chỉ giữ tiêu đề, số liệu, đơn vị, bộ điều khiển, thông báo thao tác và lỗi cần xử lý. Bỏ footer lưu trên máy/không cần mạng/múi giờ và các chú thích giải thích cơ chế lặp, tự tích checkbox hoặc cơ sở so sánh. Các chức năng liên quan và cấu hình múi giờ vẫn hoạt động như trước.

Màn hình mặc định khi khởi động hoặc mở lại app từ Dock/Finder là Tổng kết tất cả thời gian. Người dùng vẫn có thể chuyển sang Ngày, Tuần, Tháng, Năm khi cần.

Tiêu đề từng kỳ: Ngày dùng “Một ngày của bạn”; Tuần dùng “Tổng kết tuần [số tuần]” kèm khoảng ngày; Tháng dùng “Tổng kết tháng MM/yyyy”; Năm dùng “Tổng kết năm yyyy”. Thanh bên đánh dấu mục đang xem bằng nền tím nhạt, tắt viền focus mặc định trên macOS 14+.

Bộ chọn thời gian dùng đúng độ chi tiết của từng kỳ: Ngày dùng dd/MM/yyyy; Tuần chọn số tuần và năm của tuần; Tháng chọn MM/yyyy; Năm chỉ chọn yyyy. Nút về thời điểm hiện tại tương ứng Hôm nay/Tuần này/Tháng này/Năm nay. Mũi tên tiến/lùi đúng một kỳ từ đầu kỳ. Khi đổi từ năm có tuần 53 sang năm chỉ có 52 tuần, chọn tuần 52. Nhãn biểu đồ và so sánh dùng cùng định dạng; phần so sánh kỳ đang diễn ra vẫn ghi rõ chỉ xét phần thời gian đã trôi qua.

### 6.1. Hôm nay và lịch sử theo ngày

Thanh trên cùng có bộ chọn ngày, nút về “Hôm nay” và trạng thái theo dõi.

Ba ô chỉ số đầu màn hình, áp dụng cho cả Ngày/Tuần/Tháng/Năm:

- Tổng giờ Học.
- Tổng giờ Nghiên cứu.
- Tổng giờ Tập thể thao.

Tính theo kỳ và ngày đang chọn; hiển thị giờ với hai chữ số thập phân, kèm thời lượng giờ/phút để dễ đọc. Các ô luôn thể hiện tổng của cả ba danh mục, độc lập với bộ lọc hoạt động trong biểu đồ chi tiết. Chưa có bản ghi thì hiển thị 0 giờ. Các thông tin chi tiết khác vẫn có ở timeline, bảng hoạt động và phần so sánh:

- Tổng thời gian đã phân loại.
- Thời gian đã phân loại theo từng hoạt động.

Các vùng nội dung:

1. Timeline màu chỉ cho các hoạt động đã ghi nhận, ví dụ 09:00–09:30 Học, 09:30–09:45 Giải trí. Các khoảng còn lại dùng nền trống, không gắn nhãn hoặc màu cảnh báo.
2. Bảng tổng hợp hoạt động: thời lượng và tỷ trọng trên tổng thời gian đã phân loại.
3. Biểu đồ thanh ngang theo hoạt động, dùng thống nhất màu với timeline.
4. Danh sách chi tiết có giờ bắt đầu/kết thúc, hoạt động, ghi chú và thao tác sửa.

Cho phép thêm thủ công, thay hoạt động, chỉnh mốc thời gian, tách khoảng và xóa bản ghi. Mọi thao tác phải ngăn thời gian chồng lấn; nếu thay thế dữ liệu hiện có, hiển thị phần bị ảnh hưởng để người dùng xác nhận. Xóa bản ghi sẽ gỡ hoạt động khỏi lịch sử, không tạo lời nhắc bổ sung.

Ví dụ cách hiển thị tổng: Học 2 giờ 15 phút; Nghiên cứu 1 giờ; Thể thao 45 phút; Giải trí 30 phút.

### 6.2. Tuần

- Biểu đồ cột chồng 7 ngày, mỗi màu là một hoạt động.
- Tổng thời lượng và trung bình mỗi ngày theo hoạt động.
- Chọn một hoặc nhiều hoạt động để lọc.
- So sánh tuần trước, kèm thời lượng chênh lệch và tỷ lệ phần trăm khi có cơ sở tính.
- Nếu có mục tiêu tuần: hiển thị thời gian hiện tại/mục tiêu và tiến độ tương ứng.

### 6.3. Tháng

- Biểu đồ thời lượng theo từng ngày, có bộ lọc hoạt động.
- Lịch heatmap cho hoạt động đang chọn; ngày chưa có dữ liệu có ký hiệu khác ngày đã ghi nhận nhưng hoạt động đó bằng 0.
- Tổng theo hoạt động và so sánh với tháng trước.

### 6.4. Năm

- Biểu đồ cột theo 12 tháng, có phân chia theo hoạt động.
- Đường xu hướng thời lượng trung bình theo ngày trong mỗi tháng để giảm ảnh hưởng tháng dài/ngắn.
- Tổng thời gian theo hoạt động và so sánh cùng kỳ năm trước khi có dữ liệu.

### 6.5. Định nghĩa tiến bộ và thụt lùi

Không mặc định giải trí là xấu hoặc tăng số giờ luôn là tiến bộ. Với mỗi danh mục, người dùng có thể chọn:

- Tăng đến mục tiêu, ví dụ tập thể thao ít nhất 3 giờ/tuần.
- Giữ dưới giới hạn, ví dụ giải trí tối đa 7 giờ/tuần.
- Chỉ quan sát, không đánh giá.

Khi chưa đặt mục tiêu, app chỉ ghi “tăng/giảm thời lượng đã ghi nhận”. Khi có mục tiêu, hiển thị đạt/chưa đạt hoặc vượt giới hạn, không đưa ra điểm năng suất chung.

## 7. Công thức và quy tắc biểu đồ

- Thời lượng hoạt động A = tổng thời lượng các khoảng đã phân loại A trong phạm vi lọc, bao gồm bản ghi thủ công hợp lệ.
- Tổng đã phân loại = tổng thời lượng của mọi hoạt động, không chứa khoảng chưa xác định hoặc không theo dõi.
- Tỷ trọng A = thời lượng A / tổng đã phân loại. Nếu tổng bằng 0, hiển thị “Chưa có dữ liệu”.
- Độ đầy đủ = thời lượng đã phân loại bên trong các khoảng theo dõi / tổng thời lượng các khoảng theo dõi đã kết thúc. Bản ghi thủ công ngoài các khoảng theo dõi không làm tăng chỉ số này.
- Thời gian đang chờ hết chu kỳ không nằm trong mẫu số. Nếu chưa có khoảng theo dõi đã kết thúc, độ đầy đủ hiển thị “Chưa có dữ liệu”.
- Chênh lệch phần trăm = (kỳ hiện tại − kỳ trước) / kỳ trước × 100%. Nếu kỳ trước bằng 0 hoặc thiếu dữ liệu, hiển thị chênh lệch tuyệt đối và “Không đủ cơ sở tính %”.
- Kỳ đang diễn ra được so với cùng phần thời gian đã trôi qua ở kỳ trước. Nếu tháng trước thiếu ngày tương ứng, dùng phần ngày/giờ chung tồn tại ở cả hai kỳ và ghi rõ phạm vi.
- Hai kỳ đã kết thúc được so toàn kỳ, kèm số ngày và thời lượng trung bình/ngày. Năm nhuận dùng cùng nguyên tắc phần thời gian chung khi so kỳ chưa kết thúc.
- Trung bình/ngày dùng số ngày lịch trong phạm vi đang so sánh, kèm số ngày có dữ liệu; không âm thầm loại ngày trống khỏi mẫu số.
- So sánh chỉ dựa trên hoạt động đã ghi nhận, hiển thị thời lượng tăng/giảm, trung bình/ngày và phạm vi ngày so sánh. Không hiển thị chỉ số độ đầy đủ hoặc yêu cầu nhớ lại khoảng đã lỡ.
- Không có dữ liệu không có nghĩa là hoạt động bằng 0; tooltip và trạng thái rỗng phải thể hiện rõ điều này.

## 8. Cài đặt

- Chu kỳ nhắc mặc định 5 phút; lựa chọn 5, 10, 15, 30 hoặc 60 phút.
- Lịch theo ngày trong tuần; hỗ trợ nhiều khung giờ trong một ngày. Mặc định theo dõi thủ công.
- Âm báo bật/tắt, mặc định tắt.
- Tùy chọn khởi động cùng đăng nhập, mặc định tắt.
- Danh mục hoạt động. Mục tiêu có trang riêng trên thanh bên.
- Múi giờ báo cáo.
- Xuất CSV theo khoảng ngày; sao lưu/khôi phục toàn bộ qua JSON có phiên bản schema.
- Khôi phục bản sao lưu: kiểm tra hợp lệ và cho xem số bản ghi trước khi xác nhận thay thế dữ liệu; tạo bản sao lưu hiện tại trước khi thay thế. Bản đầu chưa hỗ trợ trộn hai bộ dữ liệu.
- Xóa toàn bộ dữ liệu cần xác nhận rõ ràng.

## 9. Dữ liệu và quyền riêng tư

Đề xuất lưu dữ liệu cục bộ bằng SQLite. Không có tài khoản, quảng cáo, analytics hay truyền dữ liệu lên server trong bản đầu.

Các thực thể tối thiểu:

| Thực thể | Trường chính |
| --- | --- |
| ActivityCategory | id, name, color, sortOrder, isArchived |
| TrackingSession | id, startedAtUTC, endedAtUTC, lastHeartbeatUTC, endReason |
| TrackingInterval | id, sessionId, startedAtUTC, endedAtUTC |
| ActivityEntry | id, startedAtUTC, endedAtUTC, categoryId, note, source, createdAtUTC, updatedAtUTC |
| CheckIn | id, intervalId, scheduledAtUTC, answeredAtUTC, status |
| ActivityGoal | id, categoryId, direction, minutes, effectiveFrom, period (day/week; thiếu trường này là week) |
| Settings | intervalMinutes, reportTimezone, schedule, sound, launchAtLogin |

ActivityEntry có thể phủ toàn bộ hoặc một phần TrackingInterval. Phần của khoảng theo dõi không có ActivityEntry được suy ra là “chưa xác định”; tránh lưu hai nguồn tổng thời lượng mâu thuẫn nhau. Bản ghi thủ công có thể nằm ngoài TrackingInterval, nhưng không được chồng với ActivityEntry khác.

Nguồn bản ghi phân biệt trả lời nhắc, nhập thủ công và chỉnh sửa. CheckIn giữ danh tính của lần nhắc để mở thông báo cũ đúng ngữ cảnh. Mục tiêu tuần cũ giữ ngày hiệu lực và phiên bản; mục tiêu mỗi ngày lưu mức lặp hiện tại, chọn cùng hoạt động để điều chỉnh mức đó. Trạng thái hoàn thành luôn suy ra từ bản ghi, không lưu một cờ tích có thể bị mang sang ngày hôm sau.

CSV gồm: thời gian bắt đầu, thời gian kết thúc, múi giờ, thời lượng phút, hoạt động, ghi chú và nguồn ghi nhận. Sao lưu JSON bao gồm toàn bộ dữ liệu và cài đặt, không chỉ các dòng CSV.

Quyền hệ thống cần dùng: gửi thông báo. Không yêu cầu Accessibility, Screen Recording, camera, microphone hoặc đọc lịch sử trình duyệt.

## 10. Định hướng kỹ thuật

Đề xuất xây app native bằng Swift + SwiftUI, chạy trên Apple Silicon; dùng AppKit ở các chỗ cần tương tác cửa sổ/vòng đời macOS. Dùng SQLite cho dữ liệu, truy vấn tổng hợp cho dashboard; lựa chọn thư viện lưu trữ và vẽ biểu đồ được kiểm tra khi triển khai sau khi biết phiên bản macOS thực tế.

Biểu tượng thanh menu có thể dùng SwiftUI MenuBarExtra; thông báo cục bộ dùng UserNotifications. Bộ lập lịch của app quản lý các mốc và đối soát khi mở lại, không chỉ dựa vào một timer trong cửa sổ dashboard.

Tài liệu Apple tham chiếu:

- Menu bar: https://developer.apple.com/documentation/swiftui/menubarextra
- Thông báo: https://developer.apple.com/documentation/usernotifications
- Thao tác thông báo: https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types

File main.py hiện đang trống. Spec này chưa quyết định phải dùng Python vì một tên file trong workspace; ưu tiên trải nghiệm ứng dụng macOS native cho sản phẩm này.

Phiên bản macOS tối thiểu và bộ công cụ build được chốt sau khi kiểm tra máy hiện tại. Bàn giao app .app mở được trên máy này cùng mã nguồn và hướng dẫn build. Phát hành công khai, ký bằng Developer ID và notarization chưa nằm trong phạm vi bản đầu.

## 11. Yêu cầu chất lượng

- Hoạt động offline; dashboard và ghi nhận không cần mạng.
- Khi đang theo dõi, máy thức và không bị hệ thống chặn, chu kỳ nhắc mục tiêu là 5 phút. Thời điểm banner xuất hiện chịu cơ chế thông báo và Focus của macOS; không cam kết banner luôn xuất hiện chính xác đến giây.
- Nếu quyền thông báo bị từ chối, hiển thị hướng dẫn bật trong System Settings; vẫn có thể nhập dữ liệu thủ công. Không lặp hộp thoại xin quyền.
- Không né Focus/Do Not Disturb của hệ thống. Khoảng dữ liệu bị lỡ vẫn xử lý theo quy tắc chưa xác định.
- Không dùng vòng lặp kiểm tra liên tục; tránh truy vấn và vẽ lại biểu đồ khi dashboard đóng.
- Mục tiêu thao tác chọn hoạt động phản hồi dưới 300 ms; dashboard một năm dữ liệu mở trong khoảng 2 giây trên máy hiện tại. Đây là mục tiêu cần đo khi nghiệm thu, không phải số liệu đã kiểm chứng.
- Dùng transaction khi sửa dữ liệu; migration schema không làm mất lịch sử; không tạo bản ghi trùng khi bấm hai lần.
- Giao diện tiếng Việt, hỗ trợ sáng/tối, điều khiển bằng bàn phím, nhãn đọc màn hình; biểu đồ dùng cả chữ/tooltip, không chỉ màu.

## 12. Tiêu chí nghiệm thu

| ID | Tình huống | Kết quả cần đạt |
| --- | --- | --- |
| AC01 | Bắt đầu 09:00, theo dõi liên tục 15 phút | Có các khoảng 09:00–09:05, 09:05–09:10, 09:10–09:15; mỗi khoảng nhận diện riêng |
| AC02 | Chọn Học cho hai khoảng liên tiếp | Tổng Học 10 phút; timeline gộp thành một đoạn 10 phút |
| AC03 | Bỏ qua một khoảng 5 phút | Chưa xác định tăng 5 phút; hoạt động trước đó không tăng |
| AC04 | Mở thông báo cũ đã được trả lời | Mở đúng dữ liệu đã lưu, không tạo thêm 5 phút |
| AC05 | Không trả lời 4 chu kỳ | Có 20 phút chưa xác định; không phát dồn bốn thông báo khi trở lại |
| AC06 | Sleep/khóa rồi mở lại | Không tính thời gian dừng vào hoạt động; bắt đầu chu kỳ mới nếu đủ điều kiện |
| AC07 | Tạm dừng thủ công rồi khóa/mở máy | Giữ trạng thái tạm dừng theo lựa chọn của người dùng |
| AC08 | Sửa 09:00–09:10 từ Học sang Nghiên cứu | Học giảm 10 phút, Nghiên cứu tăng 10 phút; tổng không đổi |
| AC09 | Thêm thủ công 30 phút thể thao ngoài phiên | Thể thao và tổng đã phân loại tăng 30 phút; độ đầy đủ của phiên không đổi |
| AC10 | Thêm khoảng đè lên dữ liệu cũ | Bị chặn hoặc yêu cầu xác nhận phần thay thế; không cộng trùng |
| AC11 | Có 15 phút trong phiên, đã phân loại 10 phút | Độ đầy đủ 66,7%; còn 5 phút chưa xác định |
| AC12 | 23:55–00:05 cùng hoạt động | Mỗi ngày nhận 5 phút; tổng vẫn 10 phút |
| AC13 | Kỳ trước bằng 0 hoặc không có dữ liệu | Không chia cho 0; hiển thị chênh lệch tuyệt đối và nhãn phù hợp |
| AC14 | Một kỳ ghi nhận thiếu nhiều | Có nhãn dữ liệu chưa đủ đồng đều; không tự kết luận thụt lùi |
| AC15 | Khởi động lại hoặc app dừng bất thường | Dữ liệu đã lưu còn nguyên; không tự tính cả thời gian app không chạy |
| AC16 | Thu hồi quyền thông báo/đang bật Focus | App vẫn dùng được, dashboard thể hiện trạng thái; không hứa đã hiển thị banner |
| AC17 | Xuất rồi khôi phục bản sao lưu | Danh mục, thời gian, ghi chú, mục tiêu và cài đặt khớp dữ liệu gốc |
| AC18 | Đổi chu kỳ giữa một khoảng | Chốt đúng phần đã trôi qua; chu kỳ mới không chồng khoảng cũ |
| AC19 | Đóng dashboard | Theo dõi vẫn tiếp tục; chỉ Thoát mới dừng ứng dụng |

Kiểm thử cần gồm kiểm thử tính khoảng/tổng hợp bằng đồng hồ giả lập và kiểm tra thực tế notification, sleep/wake, khóa/mở khóa trên chính MacBook hiện tại.

## 13. Thứ tự triển khai dự kiến

1. Kiểm tra macOS và công cụ build; tạo app thanh menu, lưu dữ liệu và ghi nhận thủ công.
2. Thêm lịch nhắc, quyền thông báo và các trường hợp vòng đời máy/app.
3. Xây dashboard ngày, chỉnh sửa timeline và xử lý khoảng chưa xác định.
4. Thêm báo cáo tuần/tháng/năm, so sánh và mục tiêu.
5. Hoàn thiện sao lưu, kiểm thử trên máy thật, đo hiệu năng và đóng gói .app.

Các lựa chọn mặc định của spec này là đề xuất có thể điều chỉnh trước khi viết code: ghi nhận hồi cứu 5 phút; không suy đoán khoảng bỏ qua; tạm dừng khi sleep/khóa; dữ liệu chỉ lưu trên máy; SwiftUI native là hướng ưu tiên.
