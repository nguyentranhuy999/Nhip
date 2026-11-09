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

Bộ kiểm tra chạy bằng chương trình Swift độc lập (`NhipChecks`), không yêu cầu XCTest hoặc cài Xcode đầy đủ. Có 170 tình huống, gồm phiên thể thao/sinh hoạt và sửa giờ, lọc lời nhắc 5 phút, ghi nhận ngủ/thức, mục tiêu, thời hạn/âm báo 3 giây và 10 giây, điều hướng kỳ, tương thích dữ liệu cũ và dữ liệu một năm với 105.120 khoảng.

Sau khi mở, bấm **Bắt đầu**. Nhịp nằm trên thanh menu (biểu tượng đường sóng); đóng dashboard vẫn tiếp tục theo dõi. Chọn **Thoát Nhịp** ở thanh menu mới dừng ứng dụng. Có thể kéo Nhip.app vào Applications nếu muốn tự cài đặt.

## Tùy chỉnh giờ nhắc ngủ

Từ 1.16.0, vào **Cài đặt → Nhắc & lịch → Nhắc nhở ngủ**, chỉnh giờ/phút cho Ngủ đêm, Thức dậy buổi sáng, Ngủ trưa, Thức dậy sau ngủ trưa rồi bấm **Lưu giờ nhắc**. Nút **Lưu cài đặt** cuối trang cũng lưu giờ đang chỉnh. **Giờ mặc định** đưa về 00:00 / 07:00 / 12:30 / 13:30, bấm lưu để áp dụng.

Giờ đã lưu cập nhật lịch nhắc khi app chạy và lịch macOS khi thoát app bình thường; đổi giờ sẽ đóng lời nhắc cũ đang hiện. Bật/tắt nhắc ngủ giữ các giờ đã chọn. Giờ thức trưa phải sau giờ ngủ trưa; ngủ đêm sau nửa đêm thì giờ dậy sáng phải sau đó; bốn giờ nhắc cần khác nhau. Lỗi chỉnh giờ hiển thị trong Cài đặt.

Phiên ngủ mới dùng giờ mục tiêu mới; phiên đang ngủ và các lần đã ghi giữ giờ mục tiêu lúc bắt đầu. Lịch sử cũ dùng các giờ mặc định ban đầu. Ngủ đêm trước nửa đêm tính vào ngày đó, còn từ 00:00 đến trước 12:00 thuộc buổi tối hôm trước; thức dậy thuộc sáng hôm sau. Thời lượng Nghỉ ngơi vẫn tính bằng thời điểm ngủ và dậy thực tế.

## Thêm và đổi tên hoạt động

Từ 1.15.1, Cài đặt → Hoạt động chặn thêm hoặc đổi tên trùng hoạt động đã có, kể cả mục lưu trữ. Tên được so khớp không phân biệt hoa/thường, dấu tiếng Việt, khoảng trắng thừa. Khi bị trùng, app báo tên đã có ngay dưới ô thêm trong Cài đặt và giữ nội dung bạn nhập để sửa. Từ 1.15.2, lỗi này không đẩy vào thông báo chung của giao diện chính; sửa nội dung sẽ xóa lỗi tại ô nhập.

Hoạt động mới là hoạt động thường: tên hoặc icon không tự gán vai trò ngủ/nghỉ/thể thao/sinh hoạt. Bạn chọn Nhắc định kỳ/Tự ghi nhận/Cả hai như bình thường. Hoạt động Nghỉ ngơi đặc biệt đang dùng cho giấc ngủ giữ vai trò khi đổi tên; ghi ngủ chọn theo ID/vai trò, tránh dùng nhầm một hoạt động thường cùng tên. Các mục cũ và lịch sử không tự xóa/gộp.

## Âm thanh xác nhận ghi nhận

Từ 1.14.1, chọn thành công hoạt động hoặc Lặp lại trong lời nhắc nhanh sẽ phát một tiếng ting-ting ngắn khoảng 0,7 giây, sau khi lưu nhật ký thành công. Âm xác nhận bật mặc định, độc lập âm nhắc mỗi 3 giây. Vào **Cài đặt → Nhắc & lịch → Âm thanh khi ghi nhận thành công** để bật/tắt rồi bấm **Lưu cài đặt**; nút **Nghe thử** phát ngay mà không tạo bản ghi.

Từ 1.14.2, chọn hoạt động trong **Xem thử bảng nhắc nhanh** cũng phát âm xác nhận (nếu bật), nhưng không tạo bản ghi. Bỏ qua/đóng/hết giờ, lỗi lưu và khoảng đã ghi nhận không phát âm xác nhận. File WAV được tổng hợp riêng, đóng gói cùng app, không cần mạng. Chạy executable Swift trực tiếp ngoài bundle dùng tiếng Glass dự phòng nếu thiếu WAV.

## Biểu tượng hoạt động và giao diện

Từ 1.14.0, bộ chọn có **9.184 icon hiển thị được trên máy hiện tại**, gồm các biến thể. Tìm theo tên, từ khóa tiếng Anh hoặc các từ khóa tiếng Việt phổ biến; lọc 22 nhóm. Catalog tên đóng gói cùng app, ảnh lấy từ macOS; icon không có trên phiên bản hệ điều hành đang dùng được ẩn. Lần đầu mở, thư viện tải ở nền và hiện tiến trình.

- **Cài đặt → Hoạt động → Sửa**: chọn icon hoạt động, Lưu để cập nhật các màn hình thống kê và ghi nhận.
- **Cài đặt → Giao diện → Sửa**: đổi **tên và icon** cho Ngày, Mục tiêu, Hoạt động, Tuần, Tháng, Năm, Tổng kết, Cài đặt. Bấm **Lưu** để cập nhật menu/tiêu đề và giữ qua lần mở sau; **Hủy** bỏ thay đổi chưa lưu. Để tên trống hoặc bấm **Mặc định** để lấy lại tên gốc. Nút mũi tên khôi phục tên/icon từng mục, nút bên dưới khôi phục tất cả. Tên dài giữ cùng cỡ chữ, hiện dấu … và có thể rê chuột xem tên đầy đủ.

Icon giao diện độc lập với hoạt động và dữ liệu thời gian. Sao lưu/khôi phục JSON bao gồm lựa chọn; bản sao lưu cũ dùng icon mặc định. Xóa toàn bộ dữ liệu đặt lại icon giao diện.

## Ghi nhận và xem lại

Giao diện rút gọn các dòng chú thích phụ: không có footer lưu trên máy/múi giờ, đoạn giải thích lặp mục tiêu, nhãn tự động đánh dấu hay hướng dẫn checkbox. Chức năng lưu dữ liệu, lịch nhắc, múi giờ và tự hoàn thành mục tiêu giữ nguyên; múi giờ vẫn có thể chỉnh trong Cài đặt.

- Lần nhắc đầu sau 5 phút: bảng **Ghi nhận nhanh** tự hiện ở góc màn hình. Bấm vào bất kỳ chỗ nào trong ô hoạt động để ghi nhận ngay và đóng bảng, không cần checkbox hoặc nút Lưu. Nếu muốn ghi chú, bấm **Ghi chú**, nhập rồi chọn hoạt động; có thể Bỏ qua.
- Từ **1.9.1**, bảng nhắc là thẻ bo góc rộng 400 điểm, chiều cao tự vừa nội dung thay vì khung cố định 570 điểm. Hai hoạt động chỉ chiếm một hàng; danh sách dài giới hạn bốn hàng rồi cuộn. Ghi chú mở/thu gọn khi bấm, cửa sổ đổi chiều cao nhẹ và giữ nguyên góc trên phải. Có nút đóng ngay trên thẻ; nút Lặp lại vẫn ghi nhận giống lần trước. Nhắc tự động vẫn không giành bàn phím, tối đa 60 giây; từ **1.9.5** âm báo ghi nhận lặp mỗi **3 giây**.
- Bảng nhắc nổi trên các cửa sổ, không tự đưa dashboard ra trước hoặc giành bàn phím khi vừa hiện. Mỗi chu kỳ hỏi về khoảng vừa qua. Lượt bị bỏ qua không được nhắc lại hay đưa vào danh sách chờ; đến chu kỳ mới, bảng chuyển sang khoảng mới.
- **Cài đặt → Nhắc & lịch → Xem thử bảng nhắc nhanh** cho phép thử bấm ô hoạt động mà không tạo dữ liệu nhật ký.
- Màn hình Ngày chỉ hiển thị timeline và danh sách các hoạt động đã ghi nhận; có thể chỉnh sửa/tách khoảng.
- Mục **Tổng kết** thay nút Ghi nhận nhanh trên thanh bên: xem tổng số giờ, thời lượng và tỷ trọng của từng hoạt động trong toàn bộ lịch sử, không giới hạn ngày/tuần/tháng/năm. Bao gồm hoạt động đã lưu trữ; danh mục chưa có dữ liệu hiện 0 giờ. Lời chào dùng tên tại **Cài đặt → Cá nhân**; mặc định là tên tài khoản macOS.
- Nút **Thêm hoạt động** chỉ có ở trang Ngày. Các trang Tuần/Tháng/Năm/Tổng kết không có nút thêm; mọi nút chia sẻ trên dashboard được bỏ, xuất dữ liệu tập trung trong Cài đặt.
- Từ **1.17.0**, vào **Cài đặt → Dashboard**, chọn trang Ngày/Tuần/Tháng/Năm/Tổng kết rồi chọn **tối đa 6 hoạt động cho từng trang**. Bấm cả dòng để chọn/bỏ, dùng mũi tên để sắp xếp; thay đổi tự lưu ngay. Mỗi trang mặc định có 3 hoạt động, ưu tiên các mục được đánh sao rồi bổ sung từ danh sách hiện có nếu chưa đủ. Chọn lại 3 hoạt động mặc định chỉ đặt lại trang đang chỉnh. Có thể bỏ chọn hết; trang đó hiện nút mở lại phần chọn. Lựa chọn lưu theo ID nên đổi tên/icon/màu vẫn cập nhật đúng giờ; hoạt động mới không tự thêm vào dashboard. Các mục lưu trữ đã chọn vẫn hiện với nhãn trạng thái. Lựa chọn các ô độc lập với cờ ưu tiên dùng so sánh, bộ lọc biểu đồ, tổng cộng và bảng chi tiết.
- Đầu trang **Tổng kết**, ngay dưới lời chào, có **Nhiệm vụ đã hoàn thành**: hai ô ngày/tuần, số hoàn thành trên tổng số, tỷ lệ phần trăm và thanh tiến độ. Mỗi mục tiêu được tính một lần cho mỗi kỳ đã bắt đầu đến hiện tại; ngày gồm cả bốn nhiệm vụ ngủ khi bật nhắc ngủ. Chưa có nhiệm vụ thì tỷ lệ hiện “—”.
- **Tổng kết tất cả thời gian** là màn hình mặc định khi khởi động Nhịp và khi mở lại app từ Dock/Finder, kể cả lúc app vẫn đang chạy.
- Bảng ghi nhận tự hiện mỗi chu kỳ vẫn hoạt động như trước; mục Tổng kết chỉ thay lối mở thủ công trên thanh bên và thanh menu.
- **Mục tiêu** chia hai nhóm **Nhiệm vụ trong ngày** (mục tiêu bạn tạo) và **Ngủ & thức dậy**. Mục này nằm ngay dưới Tổng kết, không còn trong Cài đặt. Chọn hoạt động và số giờ tối thiểu mỗi ngày (ví dụ `1,5`). Mục tiêu tự lặp mỗi ngày, tiến độ tính lại từ 00:00 theo múi giờ báo cáo. Checkbox tự tích khi tổng thời gian đã ghi nhận trong ngày đạt mục tiêu; sửa/xóa hoạt động cũng cập nhật lại checkbox.
- **Nhắc nhở ngủ**: 00:00 ngủ đêm, 07:00 thức dậy buổi sáng, 12:30 ngủ trưa, 13:30 thức dậy sau ngủ trưa. Từ **1.9.4**, có nút **Tắt lời nhắc** để đóng ngay và dừng âm. Phát âm mỗi **3 giây**, tự dừng sau tối đa **60 giây** khi Nhịp chạy nền. Tắt một lượt nhắc vẫn giữ lịch các lượt tiếp theo; việc ghi ngủ/thức và tính mục tiêu thực hiện ở Hoạt động/Mục tiêu như trước.
- **Ngày → Tổng thời gian ưu tiên**: nằm ngay dưới Dòng thời gian, hiển thị tổng giờ các hoạt động đã đánh dấu sao trong ngày đang xem; dòng phía dưới là tổng cả ngày liền trước, dùng nhãn **Hôm nay / Hôm qua**. Cả hai có tỷ lệ trên 24 giờ; phía dưới có so sánh nhiều hơn/ít hơn/bằng ngày trước, kèm chênh lệch giờ và % khi ngày trước có dữ liệu. Đổi ngày sẽ cập nhật cả hai; dùng nhóm sao độc lập bộ lọc hoạt động.
- **Ưu tiên**: bấm ngôi sao cạnh hoạt động trong **Cài đặt → Hoạt động** (hoặc bật trong Sửa hoạt động). Ở Tuần/Tháng/Năm chỉ có một phần so sánh gọn dưới biểu đồ, cộng giờ các hoạt động ưu tiên để tính tăng/giảm, %, tổng kỳ này/kỳ trước và trung bình mỗi ngày. Phần này dùng lựa chọn sao riêng, độc lập bộ lọc biểu đồ. Thay đổi lưu ngay và áp dụng cùng danh sách cho cả hai kỳ.
- **Biểu tượng hoạt động**: tại **Cài đặt → Hoạt động → Sửa**, chọn trong thư viện 148 biểu tượng theo nhóm, tìm bằng tiếng Việt có dấu/không dấu hoặc từ khóa tiếng Anh. Có xem trước, đánh dấu biểu tượng đang chọn; chỉ lưu khi bấm Lưu. Đổi icon giữ cách ghi nhận, vai trò và lịch sử.
- **Cài đặt → Hoạt động**: mỗi hoạt động chọn **Nhắc định kỳ** (xuất hiện trong bảng hỏi), **Tự ghi nhận** (Bắt đầu/Kết thúc tại Hoạt động), hoặc **Cả hai**. Thay đổi được lưu ngay. Mặc định giữ cách ghi cũ: học/nghiên cứu/công việc/giải trí được nhắc; thể thao/sinh hoạt tự ghi. **Nghỉ ngơi** tiếp tục ghi qua giấc ngủ riêng.
- **Hoạt động** nằm ngay dưới Mục tiêu: chứa ghi nhận giấc ngủ và các hoạt động đã chọn Tự ghi nhận/Cả hai. Mục tiêu ngủ vẫn cố định ở trang Mục tiêu. Cả hai cách ghi dùng chung danh mục, tổng giờ và tiến độ mục tiêu; đổi chế độ không xóa lịch sử. Phiên đang chạy vẫn có thể kết thúc sau khi đổi chế độ hoặc lưu trữ danh mục. Nếu không còn hoạt động nhắc định kỳ, app không hiện bảng hỏi trống.
- **Hoạt động → Ghi nhận giấc ngủ**: hai hàng **Ngủ trưa** và **Ngủ đêm**, mỗi hàng có nút **Ngủ** (biểu tượng giường) và **Thức dậy** (biểu tượng mặt trời mọc). Bấm Ngủ khi đi ngủ, Thức dậy trên cùng hàng khi dậy. App lưu hai thời điểm và tự tạo một hoạt động **Nghỉ ngơi** đúng khoảng đó, cập nhật timeline/tổng giờ/biểu đồ. Giấc ngủ đang ghi nhận vẫn còn sau khi tắt/mở app; không cần để app chạy suốt giấc ngủ.
- **Tự ghi nhận hoạt động**: bấm **Bắt đầu** khi bắt đầu, **Kết thúc** khi về máy. Trong bảng kết thúc, có thể sửa cả giờ bắt đầu/kết thúc về giờ thực tế rồi bấm **Lưu và kết thúc**; ví dụ tập xong 18:00, về nhà 18:30 thì sửa giờ kết thúc thành 18:00. Các phiên đã lưu có nút **Sửa giờ** và xóa trong lịch sử, bấm Xem thêm để xem các phiên cũ hơn. Không cho giờ kết thúc trước bắt đầu, giờ tương lai hoặc chồng hoạt động khác. Sửa giờ cập nhật cùng bản ghi, không tạo bản sao hoặc xóa dữ liệu khác.
- Trong lúc ngủ hoặc đang ghi một phiên Bắt đầu/Kết thúc, app ngừng hỏi hoạt động 5 phút. Chỉ ghi nhận một phiên tại một thời điểm. Phiên đang mở được lưu qua đóng/mở app; lưu kết thúc hoặc hủy mới bắt đầu chu kỳ làm việc tiếp theo nếu trước đó đang theo dõi. Giữ trạng thái tạm dừng bằng tay/lịch, không bù giờ rời máy thành công việc. Nếu sửa giờ kết thúc về trước lúc về nhà, khoảng chênh không tự gán hoạt động.
- Bốn mục tiêu ngủ/thức dậy tự tích khi mốc thực tế đúng giờ hoặc sớm hơn; ghi muộn vẫn lưu Nghỉ ngơi, mục tiêu hiện Muộn. Ngủ trưa ≤12:30, dậy trưa ≤13:30; ngủ đêm thuộc buổi tối hôm đó, hạn 00:00 kế tiếp; dậy ≤07:00 thuộc sáng hôm sau. So sánh ở độ chính xác phút. Sau nửa đêm đến trước 12:00, giờ bắt đầu ngủ đêm thuộc tối hôm trước, không được coi là ngủ sớm cho tối hôm sau. Giờ mục tiêu giữ múi giờ lúc bắt đầu giấc ngủ.
- Có nút **Hủy lần ghi nhận** khi tích nhầm và thùng rác cho lịch sử ngủ. Xóa lần ngủ xóa bản Nghỉ ngơi tự tạo của lần đó; giữ các hoạt động khác và phần đã chỉnh sửa thủ công. Nếu khoảng ngủ chồng hoạt động đã có, app báo lỗi và giữ dữ liệu cũ. Dấu tích cũ từ phiên bản trước vẫn được giữ; các lần mới tính theo giờ ghi nhận.
- **Cài đặt → Nhắc & lịch → Bật nhắc nhở ngủ** bật/tắt ngay cả bốn lịch và bốn mục tiêu cố định. Tắt không xóa lịch sử, bật lại giữ dấu tích của ngày hiện tại. Nhắc ngủ có âm thanh riêng, độc lập với việc tạm dừng ghi nhận và lịch theo dõi. Nút **Thử lời nhắc ngủ** gửi thông báo sau 3 giây, không tích mục tiêu thật.
- Cả bảng ghi nhận và nhắc ngủ chỉ hiện tối đa **60 giây**. Từ **1.9.5**, cả hai đều phát âm mỗi **3 giây** (0, 3, 6…57), không phát thêm ở giây 60. Trả lời, Bỏ qua, đóng cửa sổ, tạm dừng ghi nhận hoặc Tắt lời nhắc ngủ sẽ dừng âm tương ứng ngay; tự đóng không ghi nhận hoạt động hay tích mục tiêu. Âm ghi nhận tuân theo công tắc **Phát âm báo**. Lượt mới thay lượt cũ và có thời hạn riêng, không nhắc dồn âm đã lỡ.
- Nút thùng rác trên mỗi mục tiêu cho phép xóa nhập nhầm; bấm **Hoàn tác xóa** để khôi phục. Xóa mục tiêu không xóa lịch sử hoạt động. Chọn lại hoạt động trong biểu mẫu để chỉnh mức mục tiêu hiện tại. Mục tiêu tuần cũ được giữ và quản lý trong màn hình Tuần.
- Trong **Tuần**, phần **Mục tiêu tuần** nằm ngay dưới ba ô tổng giờ: chọn hoạt động, số giờ mỗi tuần và bấm Lưu. Có checkbox tự tích, tiến độ, xóa và hoàn tác như mục tiêu ngày. Mục tiêu áp dụng từ tuần đang chọn và lặp sang các tuần sau; tiến độ tính riêng từng tuần từ thứ Hai. Thay mức ở tuần khác tạo một phiên bản riêng, không đổi mục tiêu các tuần trước; mục tiêu ngày không bị thay đổi.
- Ba ô thống kê đầu mỗi màn hình Ngày/Tuần/Tháng/Năm hiển thị tổng giờ **Học**, **Nghiên cứu**, **Tập thể thao** của kỳ đang xem, kèm thời lượng giờ/phút. Các ô này luôn tổng hợp cả ba danh mục, kể cả khi lọc biểu đồ theo một hoạt động khác.
- Tuần/tháng/năm có biểu đồ và phần so sánh thời gian ưu tiên với cùng phần kỳ trước; tháng có heatmap, năm có đường trung bình/ngày. Không hiển thị mục “Chưa xác định”, “Cần bổ sung” hoặc cảnh báo yêu cầu nhớ lại dữ liệu đã lỡ.
- Cài đặt có chu kỳ, lịch nhiều khung giờ/ngày, âm báo, mở cùng đăng nhập, múi giờ, danh mục và sao lưu.
- Ngày và tuần dùng múi giờ báo cáo, mặc định Việt Nam; tuần bắt đầu thứ Hai.
- Tiêu đề tuần hiển thị số tuần và khoảng ngày; tiêu đề tháng hiển thị tháng/năm, tiêu đề năm hiển thị năm đang xem. Mục đang chọn trên thanh bên dùng nền tím nhạt; không vẽ thêm viền focus mặc định trên macOS 14+.
- Bộ chọn thời gian theo đúng màn hình: Ngày chọn ngày, Tuần chọn số tuần/năm, Tháng chọn tháng/năm, Năm chỉ chọn năm. Nút về kỳ hiện tại lần lượt là **Hôm nay**, **Tuần này**, **Tháng này**, **Năm nay**; hai mũi tên lùi/tiến đúng một kỳ. Nhãn biểu đồ và so sánh cũng dùng cùng đơn vị thời gian.
- Khi sleep/khóa màn hình, app dừng theo dõi; thời gian đi tập hoặc rời máy có thể thêm thủ công.

## Dữ liệu

Dữ liệu thật: `~/Library/Application Support/Nhip/journal.sqlite`. SQLite lưu snapshot JSON có phiên bản trong một giao dịch nguyên tử; dùng WAL và synchronous FULL. Heartbeat chỉ ghi checkpoint nhỏ thay vì ghi lại toàn bộ lịch sử. Dữ liệu gồm danh mục, khoảng theo dõi, bản ghi, mục tiêu, cài đặt và checkpoint phiên. Không tự ghi nhận khoảng chưa trả lời, không gửi dữ liệu ra mạng. Khóa file ngăn hai tiến trình ghi cùng bộ dữ liệu.

**Sao lưu JSON** lưu toàn bộ dữ liệu. **Khôi phục** kiểm tra dữ liệu, hiển thị số bản ghi và tạo bản sao trước khi thay thế. **Xuất CSV** tại **Cài đặt → Dữ liệu** xuất toàn bộ lịch sử.

Mở một bộ dữ liệu minh họa riêng, không trộn với dữ liệu thật:

```sh
open -n dist/Nhip.app --args --demo
```

`--data-dir /đường/dẫn` dùng thư mục dữ liệu riêng cho kiểm tra. Không mở hai tiến trình trên cùng một thư mục dữ liệu.

## Giới hạn vận hành

- Bảng nhắc nhanh là cửa sổ riêng của Nhịp, không phải banner Notification Center; không cần quyền thông báo và có thể hiển thị khi Focus bật. Tạm dừng Nhịp khi không muốn bảng hiện. Banner macOS là tùy chọn, vẫn chịu quyền thông báo và Focus/Do Not Disturb.
- Nhịp cần chạy nền để tự đóng cửa sổ sau 60 giây và lặp âm mỗi 3 giây. Đóng dashboard vẫn giữ app chạy. Khi đang chạy, nhắc ngủ dùng cửa sổ nổi riêng, không đặt thêm banner trùng. Khi **Thoát Nhịp** bình thường, app đặt lại bốn thông báo macOS lặp hằng ngày để giữ lời nhắc ngủ; khi mở lại, app hủy các lịch macOS đó và tiếp tục dùng cửa sổ riêng. Thoát cưỡng bức/crash không bảo đảm đặt được lịch dự phòng.
- Khi đã thoát hẳn app, thông báo ngủ dự phòng cần quyền Notifications và chịu Focus/cài đặt macOS; thời gian hiện và âm thanh do macOS quyết định, không có lặp âm 3 giây hoặc tự đóng 60 giây của Nhịp. Mở cùng đăng nhập là tùy chọn. App không có chức năng đánh thức phần cứng khi máy ngủ, gập nắp hoặc tắt.
- Bản build ký ad hoc để dùng cục bộ; chưa ký Developer ID/notarize để phân phối công khai. Khi thay app đang dùng, thoát app trước rồi build lại cùng vị trí để giảm thay đổi nhận diện quyền hệ thống.
- Nếu thư mục Desktop được File Provider quản lý, Finder có thể tự thêm metadata vào bundle và làm `codesign --verify --strict` báo lỗi. Bản trong `~/Applications` được sao chép không kèm extended attributes và dùng làm bản cài đặt chính.
- Thời lượng phản ánh hoạt động đã tự ghi nhận, không đo tự động toàn bộ ngày. Khoảng không trả lời được bỏ qua trong giao diện và không tự cộng vào hoạt động khác.
- Một số sự kiện khóa màn hình dựa trên thông báo phiên macOS; cần kiểm tra trên máy thật khi cập nhật hệ điều hành.

Đặc tả gốc: [SPEC.md](SPEC.md).
