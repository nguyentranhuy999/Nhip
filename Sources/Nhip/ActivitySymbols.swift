import AppKit
import Foundation

enum ActivitySymbolGroup: String, CaseIterable, Identifiable {
    case all, study, health, life, leisure, travel, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Tất cả"
        case .study: return "Học & công việc"
        case .health: return "Sức khỏe"
        case .life: return "Sinh hoạt"
        case .leisure: return "Giải trí"
        case .travel: return "Di chuyển"
        case .general: return "Khác"
        }
    }
}

struct ActivitySymbol: Identifiable {
    let name: String
    let title: String
    let keywords: String
    let group: ActivitySymbolGroup
    var id: String { name }
}

enum ActivitySymbols {
    static let all: [ActivitySymbol] = {
        let groups: [(ActivitySymbolGroup, [(String, String, String)])] = [
            (.study, [
                ("book.fill", "Sách", "học đọc study read"),
                ("books.vertical.fill", "Thư viện", "học sách đọc library"),
                ("text.book.closed.fill", "Giáo trình", "học sách bài tập textbook"),
                ("book.closed.fill", "Sổ tay", "ghi chép học notebook"),
                ("graduationcap.fill", "Tốt nghiệp", "học đại học trường graduation"),
                ("pencil", "Bút chì", "viết vẽ học write draw"),
                ("pencil.and.outline", "Viết bài", "học ghi chép write"),
                ("highlighter", "Bút đánh dấu", "học ghi chú highlight"),
                ("note.text", "Ghi chú", "viết học note"),
                ("doc.text.fill", "Tài liệu", "viết báo cáo document"),
                ("doc.richtext", "Soạn thảo", "viết tài liệu word"),
                ("folder.fill", "Thư mục", "công việc tài liệu folder"),
                ("archivebox.fill", "Hồ sơ", "công việc lưu trữ archive"),
                ("magnifyingglass", "Nghiên cứu", "tìm kiếm tìm hiểu research search"),
                ("lightbulb.fill", "Ý tưởng", "sáng tạo suy nghĩ idea"),
                ("brain.head.profile", "Tư duy", "học nghiên cứu trí nhớ brain"),
                ("function", "Toán học", "học tính toán math"),
                ("number", "Con số", "toán tính học number"),
                ("sum", "Tổng", "toán học thống kê math"),
                ("globe", "Ngoại ngữ", "học tiếng anh ngôn ngữ language english"),
                ("character.bubble.fill", "Luyện ngôn ngữ", "học tiếng ngoại ngữ language"),
                ("briefcase.fill", "Công việc", "làm việc văn phòng work"),
                ("laptopcomputer", "Máy tính xách tay", "học làm việc lập trình computer laptop"),
                ("desktopcomputer", "Máy tính bàn", "làm việc học computer"),
                ("keyboard.fill", "Bàn phím", "lập trình làm việc gõ keyboard"),
                ("terminal.fill", "Lập trình", "code phần mềm developer"),
                ("chevron.left.forwardslash.chevron.right", "Mã nguồn", "code lập trình software"),
                ("chart.bar.fill", "Phân tích", "nghiên cứu thống kê dữ liệu chart"),
                ("chart.pie.fill", "Thống kê", "dữ liệu báo cáo data chart"),
                ("person.2.fill", "Làm việc nhóm", "họp bạn bè team meeting"),
                ("person.3.fill", "Cuộc họp", "công việc nhóm team meeting"),
                ("envelope.fill", "Thư điện tử", "công việc email thư mail"),
                ("calendar", "Lên kế hoạch", "lịch công việc plan"),
                ("checklist", "Danh sách nhiệm vụ", "công việc mục tiêu task todo")
            ]),
            (.health, [
                ("figure.run", "Chạy bộ", "tập thể thao vận động running"),
                ("figure.walk", "Đi bộ", "tập thể thao vận động walking"),
                ("figure.hiking", "Đi bộ đường dài", "thể thao leo núi hiking"),
                ("figure.yoga", "Yoga", "tập thể thao thiền giãn cơ"),
                ("figure.mind.and.body", "Thiền", "sức khỏe thư giãn meditation"),
                ("figure.strengthtraining.traditional", "Tập tạ", "thể thao gym thể hình strength"),
                ("dumbbell.fill", "Tạ", "tập thể thao gym thể hình"),
                ("figure.core.training", "Tập cơ bụng", "thể thao gym core"),
                ("figure.flexibility", "Giãn cơ", "tập thể thao stretching"),
                ("figure.pool.swim", "Bơi lội", "tập thể thao swimming"),
                ("figure.outdoor.cycle", "Đạp xe", "tập thể thao bicycle cycling"),
                ("figure.basketball", "Bóng rổ", "tập thể thao basketball"),
                ("figure.soccer", "Bóng đá", "tập thể thao football soccer"),
                ("figure.tennis", "Quần vợt", "tập thể thao tennis"),
                ("figure.badminton", "Cầu lông", "tập thể thao badminton"),
                ("figure.dance", "Nhảy múa", "tập thể thao dance"),
                ("sportscourt.fill", "Sân thể thao", "tập bóng sân sport"),
                ("soccerball", "Quả bóng đá", "thể thao football soccer"),
                ("basketball.fill", "Quả bóng rổ", "thể thao basketball"),
                ("heart.fill", "Trái tim", "sức khỏe tình yêu health"),
                ("heart.text.square.fill", "Theo dõi sức khỏe", "khám bệnh health"),
                ("cross.case.fill", "Y tế", "bác sĩ khám bệnh thuốc medical"),
                ("pills.fill", "Uống thuốc", "sức khỏe y tế medicine"),
                ("stethoscope", "Khám bệnh", "bác sĩ sức khỏe doctor"),
                ("drop.fill", "Uống nước", "nước sức khỏe water")
            ]),
            (.life, [
                ("house.fill", "Nhà", "sinh hoạt gia đình home"),
                ("bed.double.fill", "Giường ngủ", "ngủ nghỉ ngơi sleep"),
                ("moon.zzz.fill", "Giấc ngủ", "ngủ đêm nghỉ ngơi sleep"),
                ("moon.stars.fill", "Ban đêm", "ngủ đêm nghỉ ngơi night"),
                ("sunrise.fill", "Thức dậy", "buổi sáng bình minh wake"),
                ("sun.max.fill", "Ban ngày", "buổi sáng nắng morning"),
                ("cup.and.saucer.fill", "Cà phê", "nghỉ ngơi đồ uống coffee"),
                ("mug.fill", "Cốc nước", "đồ uống trà nghỉ tea"),
                ("fork.knife", "Ăn uống", "bữa ăn sinh hoạt food"),
                ("carrot.fill", "Rau củ", "nấu ăn dinh dưỡng food"),
                ("birthday.cake.fill", "Sinh nhật", "bánh ăn tiệc birthday"),
                ("flame.fill", "Nấu ăn", "bếp lửa cooking"),
                ("refrigerator.fill", "Tủ lạnh", "nấu ăn bếp kitchen"),
                ("shower.fill", "Tắm", "vệ sinh cá nhân sinh hoạt shower"),
                ("bathtub.fill", "Bồn tắm", "vệ sinh thư giãn bath"),
                ("washer.fill", "Giặt quần áo", "sinh hoạt dọn nhà laundry"),
                ("tshirt.fill", "Quần áo", "thay đồ sinh hoạt clothes"),
                ("sparkles", "Dọn dẹp", "vệ sinh nhà sạch clean"),
                ("trash.fill", "Đổ rác", "dọn nhà sinh hoạt clean"),
                ("cart.fill", "Mua sắm", "đi chợ siêu thị shopping"),
                ("basket.fill", "Giỏ hàng", "đi chợ mua sắm shopping"),
                ("bag.fill", "Túi mua sắm", "mua đồ shopping"),
                ("leaf.fill", "Chăm cây", "thiên nhiên vườn cây garden"),
                ("pawprint.fill", "Chăm thú cưng", "chó mèo động vật pet"),
                ("person.crop.circle.fill", "Cá nhân", "bản thân sinh hoạt personal")
            ]),
            (.leisure, [
                ("gamecontroller.fill", "Chơi game", "giải trí trò chơi gaming"),
                ("play.tv.fill", "Xem phim", "giải trí truyền hình movie"),
                ("tv.fill", "Tivi", "giải trí xem phim television"),
                ("film.fill", "Phim ảnh", "giải trí điện ảnh movie"),
                ("popcorn.fill", "Rạp phim", "giải trí điện ảnh cinema"),
                ("music.note", "Âm nhạc", "giải trí nghe nhạc music"),
                ("music.note.list", "Danh sách nhạc", "nghe nhạc music"),
                ("headphones", "Tai nghe", "nghe nhạc podcast audio"),
                ("mic.fill", "Ca hát", "hát thu âm karaoke singing"),
                ("guitars.fill", "Đàn ghi ta", "âm nhạc nhạc cụ guitar"),
                ("pianokeys", "Đàn piano", "âm nhạc nhạc cụ piano"),
                ("radio.fill", "Radio", "nghe tin âm thanh radio"),
                ("camera.fill", "Chụp ảnh", "giải trí nhiếp ảnh photo"),
                ("photo.fill", "Hình ảnh", "ảnh chụp photo"),
                ("paintbrush.fill", "Vẽ tranh", "nghệ thuật sáng tạo art paint"),
                ("paintpalette.fill", "Hội họa", "vẽ tranh nghệ thuật art"),
                ("scissors", "Thủ công", "cắt dán sáng tạo craft"),
                ("puzzlepiece.fill", "Giải đố", "trò chơi giải trí puzzle"),
                ("dice.fill", "Xúc xắc", "trò chơi bạn bè board game"),
                ("theatermasks.fill", "Sân khấu", "giải trí diễn xuất theater"),
                ("bubble.left.and.bubble.right.fill", "Trò chuyện", "bạn bè giao tiếp chat"),
                ("phone.fill", "Gọi điện", "bạn bè gia đình call"),
                ("video.fill", "Gọi video", "bạn bè họp video call"),
                ("gift.fill", "Quà tặng", "bạn bè gia đình lễ gift")
            ]),
            (.travel, [
                ("bicycle", "Xe đạp", "di chuyển đạp xe bike"),
                ("car.fill", "Ô tô", "di chuyển lái xe car"),
                ("bus.fill", "Xe buýt", "di chuyển công cộng bus"),
                ("tram.fill", "Tàu điện", "di chuyển công cộng train"),
                ("train.side.front.car", "Tàu hỏa", "di chuyển công cộng train"),
                ("airplane", "Máy bay", "du lịch di chuyển flight"),
                ("ferry.fill", "Tàu thủy", "du lịch di chuyển boat"),
                ("scooter", "Xe tay ga", "di chuyển xe máy scooter"),
                ("sailboat.fill", "Thuyền buồm", "du lịch biển sail"),
                ("map.fill", "Bản đồ", "di chuyển du lịch map"),
                ("location.fill", "Vị trí", "di chuyển định vị location"),
                ("mappin.and.ellipse", "Địa điểm", "du lịch địa điểm place"),
                ("suitcase.fill", "Vali", "du lịch hành lý travel"),
                ("backpack.fill", "Ba lô", "du lịch đi học travel"),
                ("tent.fill", "Cắm trại", "du lịch dã ngoại camping"),
                ("mountain.2.fill", "Núi", "du lịch leo núi hiking"),
                ("beach.umbrella.fill", "Bãi biển", "du lịch nghỉ mát beach"),
                ("building.2.fill", "Thành phố", "di chuyển đô thị city"),
                ("building.columns.fill", "Bảo tàng", "du lịch văn hóa museum"),
                ("fuelpump.fill", "Đổ xăng", "di chuyển xe fuel")
            ]),
            (.general, [
                ("circle.fill", "Hình tròn", "đơn giản khác circle"),
                ("square.fill", "Hình vuông", "đơn giản khác square"),
                ("triangle.fill", "Tam giác", "đơn giản khác triangle"),
                ("diamond.fill", "Kim cương", "đơn giản khác diamond"),
                ("star.fill", "Ngôi sao", "ưu tiên yêu thích star"),
                ("flag.fill", "Lá cờ", "mục tiêu đánh dấu flag"),
                ("target", "Mục tiêu", "tập trung ưu tiên goal"),
                ("checkmark.circle.fill", "Hoàn thành", "nhiệm vụ xong done"),
                ("clock.fill", "Đồng hồ", "thời gian lịch time"),
                ("timer", "Bộ đếm giờ", "tập trung thời gian timer"),
                ("hourglass", "Đồng hồ cát", "thời gian chờ time"),
                ("bell.fill", "Chuông", "nhắc nhở thông báo reminder"),
                ("bolt.fill", "Năng lượng", "tập trung hiệu suất energy"),
                ("battery.100percent", "Pin", "năng lượng nghỉ ngơi battery"),
                ("trophy.fill", "Thành tích", "mục tiêu thành công trophy"),
                ("medal.fill", "Huy chương", "thành tích mục tiêu medal"),
                ("crown.fill", "Vương miện", "thành tích ưu tiên crown"),
                ("bookmark.fill", "Đánh dấu", "ghi nhớ sách bookmark"),
                ("tag.fill", "Nhãn", "phân loại ghi chú tag"),
                ("ellipsis.circle.fill", "Khác", "thêm khác other")
            ])
        ]
        var seen = Set<String>()
        return groups.flatMap { group, items in
            items.compactMap { name, title, keywords in
                guard seen.insert(name).inserted,
                      NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil else { return nil }
                return ActivitySymbol(name: name, title: title, keywords: keywords, group: group)
            }
        }
    }()

    static func matching(_ query: String, group: ActivitySymbolGroup) -> [ActivitySymbol] {
        let terms = normalized(query).split(whereSeparator: \.isWhitespace).map(String.init)
        return all.filter { item in
            (group == .all || item.group == group) && terms.allSatisfy {
                normalized(item.title + " " + item.keywords + " " + item.name + " " + item.group.title).contains($0)
            }
        }
    }
    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased().replacingOccurrences(of: "đ", with: "d")
    }
}
