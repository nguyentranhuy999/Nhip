# Nhịp

Ứng dụng macOS native cho Mac Apple Silicon, nhắc ghi nhận hoạt động mỗi 5 phút và tổng hợp nhật ký ngày/tuần/tháng/năm. SwiftUI, Swift Charts, UserNotifications, SQLite; không có dependency tải từ mạng.

## Mở ứng dụng

Bản dùng hằng ngày trên máy hiện tại đã được cài tại **/Applications/Nhip.app** (Applications chung của máy). Bản cài trước trong **~/Applications/Nhip.app** vẫn được giữ lại; bản build trong mã nguồn nằm ở **dist/Nhip.app**. Hoặc chạy từ Terminal trong thư mục dự án:

```sh
python3 main.py
```

Nếu chưa có app, launcher tự build bằng Swift có trong Xcode Command Line Tools. Yêu cầu macOS 13+, Swift 5.9+. Máy triển khai ban đầu: Mac Apple Silicon, macOS 26.6.2, Swift 6.3.

```sh
zsh scripts/build.sh
zsh scripts/test.sh
```

Bộ kiểm tra chạy bằng chương trình Swift độc lập (`NhipChecks`), không yêu cầu XCTest hoặc cài Xcode đầy đủ. Có 93 tình huống, gồm phiên thể thao/sinh hoạt và sửa giờ, lọc lời nhắc 5 phút, ghi nhận ngủ/thức, mục tiêu, thời hạn/âm báo, điều hướng kỳ, tương thích dữ liệu cũ và dữ liệu một năm với 105.120 khoảng.

Sau khi mở, bấm **Bắt đầu**. Nhịp nằm trên thanh menu (biểu tượng đường sóng); đóng dashboard vẫn tiếp tục theo dõi. Chọn **Thoát Nhịp** ở thanh menu mới dừng ứng dụng. Có thể kéo Nhip.app vào Applications nếu muốn tự cài đặt.

## Ghi nhận và xem lại

Giao diện rút gọn các dòng chú thích phụ: không có footer lưu trên máy/múi giờ, đoạn giải thích lặp mục tiêu, nhãn tự động đánh dấu hay hướng dẫn checkbox. Chức năng lưu dữ liệu, lịch nhắc, múi giờ và tự hoàn thành mục tiêu giữ nguyên; múi giờ vẫn có thể chỉnh trong Cài đặt.

- Lần nhắc đầu sau 5 phút: bảng **Ghi nhận nhanh** tự hiện ở góc màn hình. Bấm vào bất kỳ chỗ nào trong ô hoạt động để ghi nhận ngay và đóng bảng, không cần checkbox hoặc nút Lưu. Nếu muốn ghi chú, nhập trước khi bấm ô; có thể Bỏ qua.
- Bảng nhắc nổi trên các cửa sổ, không tự đưa dashboard ra trước hoặc giành bàn phím khi vừa hiện. Mỗi chu kỳ hỏi về khoảng vừa qua. Lượt bị bỏ qua không được nhắc lại hay đưa vào danh sách chờ; đến chu kỳ mới, bảng chuyển sang khoảng mới.
- **Cài đặt → Nhắc & lịch → Xem thử bảng nhắc nhanh** cho phép thử bấm ô hoạt động mà không tạo dữ liệu nhật ký.
- Màn hình Ngày chỉ hiển thị timeline và danh sách các hoạt động đã ghi nhận; có thể chỉnh sửa/tách khoảng.
- Mục **Tổng kết** thay nút Ghi nhận nhanh trên thanh bên: xem tổng số giờ, thời lượng và tỷ trọng của từng hoạt động trong toàn bộ lịch sử, không giới hạn ngày/tuần/tháng/năm. Bao gồm hoạt động đã lưu trữ; danh mục chưa có dữ liệu hiện 0 giờ. Nút xuất CSV trong mục này xuất toàn bộ lịch sử.
- **Tổng kết tất cả thời gian** là màn hình mặc định khi khởi động Nhịp và khi mở lại app từ Dock/Finder, kể cả lúc app vẫn đang chạy.
- Bảng ghi nhận tự hiện mỗi chu kỳ vẫn hoạt động như trước; mục Tổng kết chỉ thay lối mở thủ công trên thanh bên và thanh menu.
- **Mục tiêu** nằm ngay dưới Tổng kết, không còn trong Cài đặt. Chọn hoạt động và số giờ tối thiểu mỗi ngày (ví dụ `1,5`). Mục tiêu tự lặp mỗi ngày, tiến độ tính lại từ 00:00 theo múi giờ báo cáo. Checkbox tự tích khi tổng thời gian đã ghi nhận trong ngày đạt mục tiêu; sửa/xóa hoạt động cũng cập nhật lại checkbox.
- **Nhắc nhở ngủ**: 00:00 ngủ đêm, 07:00 thức dậy buổi sáng, 12:30 ngủ trưa, 13:30 thức dậy sau ngủ trưa. Từ 1.8, thông báo chỉ nhắc, không có nút thao tác. Vẫn tự đóng sau 60 giây và phát âm mỗi 10 giây khi Nhịp chạy nền; thông báo không tự ghi nhận hoặc tích mục tiêu.
- **Hoạt động cá nhân** nằm ngay dưới Mục tiêu: chứa toàn bộ phần ghi nhận giấc ngủ và hai hàng **Tập thể thao**, **Sinh hoạt cá nhân**. Mục tiêu ngủ vẫn cố định ở trang Mục tiêu. Ba nhóm này (ngủ lưu thành Nghỉ ngơi) được ẩn khỏi bảng hỏi 5 phút và lựa chọn Giống lần trước, vẫn có trong báo cáo/mục tiêu/lịch sử cũ. Vai trò gắn với ID danh mục để đổi tên không làm xuất hiện lại trong bảng hỏi.
- **Hoạt động cá nhân → Ghi nhận giấc ngủ**: hai hàng **Ngủ trưa** và **Ngủ đêm**, mỗi hàng có nút **Ngủ** (biểu tượng giường) và **Thức dậy** (biểu tượng mặt trời mọc). Bấm Ngủ khi đi ngủ, Thức dậy trên cùng hàng khi dậy. App lưu hai thời điểm và tự tạo một hoạt động **Nghỉ ngơi** đúng khoảng đó, cập nhật timeline/tổng giờ/biểu đồ. Giấc ngủ đang ghi nhận vẫn còn sau khi tắt/mở app; không cần để app chạy suốt giấc ngủ.
- **Thể thao & sinh hoạt**: bấm **Bắt đầu** khi bắt đầu, **Kết thúc** khi về máy. Trong bảng kết thúc, có thể sửa cả giờ bắt đầu/kết thúc về giờ thực tế rồi bấm **Lưu và kết thúc**; ví dụ tập xong 18:00, về nhà 18:30 thì sửa giờ kết thúc thành 18:00. Các phiên đã lưu có nút **Sửa giờ** và xóa trong lịch sử, bấm Xem thêm để xem các phiên cũ hơn. Không cho giờ kết thúc trước bắt đầu, giờ tương lai hoặc chồng hoạt động khác. Sửa giờ cập nhật cùng bản ghi, không tạo bản sao hoặc xóa dữ liệu khác.
- Trong lúc ngủ/thể thao/sinh hoạt, app ngừng hỏi công việc 5 phút. Chỉ ghi nhận một phiên tại một thời điểm. Phiên đang mở được lưu qua đóng/mở app; lưu kết thúc hoặc hủy mới bắt đầu chu kỳ làm việc tiếp theo nếu trước đó đang theo dõi. Giữ trạng thái tạm dừng bằng tay/lịch, không bù giờ rời máy thành công việc. Nếu sửa giờ kết thúc về trước lúc về nhà, khoảng chênh không tự gán hoạt động.
- Bốn mục tiêu ngủ/thức dậy tự tích khi mốc thực tế đúng giờ hoặc sớm hơn; ghi muộn vẫn lưu Nghỉ ngơi, mục tiêu hiện Muộn. Ngủ trưa ≤12:30, dậy trưa ≤13:30; ngủ đêm thuộc buổi tối hôm đó, hạn 00:00 kế tiếp; dậy ≤07:00 thuộc sáng hôm sau. So sánh ở độ chính xác phút. Sau nửa đêm đến trước 12:00, giờ bắt đầu ngủ đêm thuộc tối hôm trước, không được coi là ngủ sớm cho tối hôm sau. Giờ mục tiêu giữ múi giờ lúc bắt đầu giấc ngủ.
- Có nút **Hủy lần ghi nhận** khi tích nhầm và thùng rác cho lịch sử ngủ. Xóa lần ngủ xóa bản Nghỉ ngơi tự tạo của lần đó; giữ các hoạt động khác và phần đã chỉnh sửa thủ công. Nếu khoảng ngủ chồng hoạt động đã có, app báo lỗi và giữ dữ liệu cũ. Dấu tích cũ từ phiên bản trước vẫn được giữ; các lần mới tính theo giờ ghi nhận.
- **Cài đặt → Nhắc & lịch → Bật nhắc nhở ngủ** bật/tắt ngay cả bốn lịch và bốn mục tiêu cố định. Tắt không xóa lịch sử, bật lại giữ dấu tích của ngày hiện tại. Nhắc ngủ có âm thanh riêng, độc lập với việc tạm dừng ghi nhận và lịch theo dõi. Nút **Thử lời nhắc ngủ** gửi thông báo sau 3 giây, không tích mục tiêu thật.
- Từ **1.7.1**, cả bảng ghi nhận và nhắc ngủ chỉ hiện tối đa **60 giây**; phát âm lúc hiện rồi mỗi **10 giây** (0, 10, 20, 30, 40, 50), không phát thêm ở giây 60. Trả lời, Bỏ qua, đóng cửa sổ, tạm dừng ghi nhận hoặc tắt nhắc ngủ tương ứng sẽ dừng âm ngay; tự đóng không ghi nhận hoạt động hay tích mục tiêu. Âm ghi nhận tuân theo công tắc **Phát âm báo**. Lượt mới thay lượt cũ và có thời hạn riêng, không nhắc dồn âm đã lỡ.
- Nút thùng rác trên mỗi mục tiêu cho phép xóa nhập nhầm; bấm **Hoàn tác xóa** để khôi phục. Xóa mục tiêu không xóa lịch sử hoạt động. Chọn lại hoạt động trong biểu mẫu để chỉnh mức mục tiêu hiện tại. Mục tiêu tuần cũ được giữ và quản lý trong màn hình Tuần.
- Trong **Tuần**, phần **Mục tiêu tuần** nằm ngay dưới ba ô tổng giờ: chọn hoạt động, số giờ mỗi tuần và bấm Lưu. Có checkbox tự tích, tiến độ, xóa và hoàn tác như mục tiêu ngày. Mục tiêu áp dụng từ tuần đang chọn và lặp sang các tuần sau; tiến độ tính riêng từng tuần từ thứ Hai. Thay mức ở tuần khác tạo một phiên bản riêng, không đổi mục tiêu các tuần trước; mục tiêu ngày không bị thay đổi.
- Ba ô thống kê đầu mỗi màn hình Ngày/Tuần/Tháng/Năm hiển thị tổng giờ **Học**, **Nghiên cứu**, **Tập thể thao** của kỳ đang xem, kèm thời lượng giờ/phút. Các ô này luôn tổng hợp cả ba danh mục, kể cả khi lọc biểu đồ theo một hoạt động khác.
- Tuần/tháng/năm có biểu đồ và so sánh thời gian đã ghi nhận cùng phần kỳ trước; tháng có heatmap, năm có đường trung bình/ngày. Không hiển thị mục “Chưa xác định”, “Cần bổ sung” hoặc cảnh báo yêu cầu nhớ lại dữ liệu đã lỡ.
- Cài đặt có chu kỳ, lịch nhiều khung giờ/ngày, âm báo, mở cùng đăng nhập, múi giờ, danh mục và sao lưu.
- Ngày và tuần dùng múi giờ báo cáo, mặc định Việt Nam; tuần bắt đầu thứ Hai.
- Tiêu đề tuần hiển thị số tuần và khoảng ngày; tiêu đề tháng hiển thị tháng/năm, tiêu đề năm hiển thị năm đang xem. Mục đang chọn trên thanh bên dùng nền tím nhạt; không vẽ thêm viền focus mặc định trên macOS 14+.
- Bộ chọn thời gian theo đúng màn hình: Ngày chọn ngày, Tuần chọn số tuần/năm, Tháng chọn tháng/năm, Năm chỉ chọn năm. Nút về kỳ hiện tại lần lượt là **Hôm nay**, **Tuần này**, **Tháng này**, **Năm nay**; hai mũi tên lùi/tiến đúng một kỳ. Nhãn biểu đồ và so sánh cũng dùng cùng đơn vị thời gian.
- Khi sleep/khóa màn hình, app dừng theo dõi; thời gian đi tập hoặc rời máy có thể thêm thủ công.

## Dữ liệu

Dữ liệu thật: `~/Library/Application Support/Nhip/journal.sqlite`. SQLite lưu snapshot JSON có phiên bản trong một giao dịch nguyên tử; dùng WAL và synchronous FULL. Heartbeat chỉ ghi checkpoint nhỏ thay vì ghi lại toàn bộ lịch sử. Dữ liệu gồm danh mục, khoảng theo dõi, bản ghi, mục tiêu, cài đặt và checkpoint phiên. Không tự ghi nhận khoảng chưa trả lời, không gửi dữ liệu ra mạng. Khóa file ngăn hai tiến trình ghi cùng bộ dữ liệu.

**Sao lưu JSON** lưu toàn bộ dữ liệu. **Khôi phục** kiểm tra dữ liệu, hiển thị số bản ghi và tạo bản sao trước khi thay thế. CSV xuất các bản ghi của kỳ đang xem, giữ nguyên phần thời gian giao với kỳ đó.

Mở một bộ dữ liệu minh họa riêng, không trộn với dữ liệu thật:

```sh
open -n dist/Nhip.app --args --demo
```

`--data-dir /đường/dẫn` dùng thư mục dữ liệu riêng cho kiểm tra. Không mở hai tiến trình trên cùng một thư mục dữ liệu.

## Giới hạn vận hành

- Bảng nhắc nhanh là cửa sổ riêng của Nhịp, không phải banner Notification Center; không cần quyền thông báo và có thể hiển thị khi Focus bật. Tạm dừng Nhịp khi không muốn bảng hiện. Banner macOS là tùy chọn, vẫn chịu quyền thông báo và Focus/Do Not Disturb.
- Nhịp cần chạy nền để tự đóng cửa sổ sau 60 giây và lặp âm mỗi 10 giây. Đóng dashboard vẫn giữ app chạy. Khi đang chạy, nhắc ngủ dùng cửa sổ nổi riêng, không đặt thêm banner trùng. Khi **Thoát Nhịp** bình thường, app đặt lại bốn thông báo macOS lặp hằng ngày để giữ lời nhắc ngủ; khi mở lại, app hủy các lịch macOS đó và tiếp tục dùng cửa sổ riêng. Thoát cưỡng bức/crash không bảo đảm đặt được lịch dự phòng.
- Khi đã thoát hẳn app, thông báo ngủ dự phòng cần quyền Notifications và chịu Focus/cài đặt macOS; thời gian hiện và âm thanh do macOS quyết định, không có lặp âm 10 giây hoặc tự đóng 60 giây của Nhịp. Mở cùng đăng nhập là tùy chọn. App không có chức năng đánh thức phần cứng khi máy ngủ, gập nắp hoặc tắt.
- Bản build ký ad hoc để dùng cục bộ; chưa ký Developer ID/notarize để phân phối công khai. Khi thay app đang dùng, thoát app trước rồi build lại cùng vị trí để giảm thay đổi nhận diện quyền hệ thống.
- Nếu thư mục Desktop được File Provider quản lý, Finder có thể tự thêm metadata vào bundle và làm `codesign --verify --strict` báo lỗi. Bản trong `~/Applications` được sao chép không kèm extended attributes và dùng làm bản cài đặt chính.
- Thời lượng phản ánh hoạt động đã tự ghi nhận, không đo tự động toàn bộ ngày. Khoảng không trả lời được bỏ qua trong giao diện và không tự cộng vào hoạt động khác.
- Một số sự kiện khóa màn hình dựa trên thông báo phiên macOS; cần kiểm tra trên máy thật khi cập nhật hệ điều hành.

Đặc tả gốc: [SPEC.md](SPEC.md).
