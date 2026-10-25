# Fishing v1: reaction mini-game

FishingSpot ở (2020,980), bên kia cầu trong Fishing Area. Cầu vẫn mở ở Level 10.
Đạt Level 10 được Rod Lv1 miễn phí (chưa có giá mua cần ban đầu trong yêu cầu).
Save cũ Level >=10 cũng tự nhận cần này, không cần reset.

## State machine

IDLE -> E/tap Fish -> WAITING_FOR_BITE (random mới 1–5 giây).

- WAITING_FOR_BITE: hiện Fishing...; E/REEL sớm -> FAILED, không có cá.
- Hết thời gian chờ -> BITE_WINDOW, hiện !!! FISH BITE !!! và thanh thời gian.
- E/REEL trong cửa sổ -> SUCCESS, nhận đúng một cá và save.
- Hết cửa sổ -> FAILED: The fish got away!, không có cá.
- SUCCESS/FAILED hiện kết quả 0.8 giây -> COOLDOWN 1.5 giây -> IDLE.
- Trong SUCCESS/FAILED/COOLDOWN, E và start không tạo phiên mới. Đóng panel kết
  quả cũng không bỏ qua cooldown. Giữ phím/echo không được tính thành Reel mới.

Không có đường timer nào tự cộng cá. Chỉ FishingSpot.reel() trong BITE_WINDOW
mới gọi _catch_fish(). Input kiểm tra deadline trước khi xét thành công, nên bấm
trễ không thắng chỉ vì frame/timer callback tới muộn. Thời gian phiên dùng
Time.get_ticks_msec(), không phụ thuộc việc chỉnh giờ hệ điều hành.

WASD vẫn hoạt động khi câu. Đi xa hơn 125 px từ Spot, ESC/Cancel hoặc mở một
panel chính khác sẽ hủy phiên chờ/đớp, trả slot Barn và dọn Fishing UI. E trong
phiên được Player route tới FishingUI rồi Spot.reel(), không tương tác ruộng/nhà
đằng sau. Nút REEL gọi cùng đường xử lý. Không có nhiều phiên cùng lúc.

## Barn và reward

Không bắt đầu nếu Barn không còn chỗ: Barn is full.
Khi thả câu, giữ trước một slot transient. can_add_item() tính cả slot này nên
feed/egg/milk collect không thể chiếm chỗ dành cho cá. Catch trả reservation rồi
add cá trong cùng callback; thất bại/cancel/reset trả slot. Reservation không save.

Fish nằm trong Barn và được hiển thị trên HUD:

| Item | Xác suất |
|---|---:|
| small_fish | 60% |
| river_fish | 30% |
| golden_fish | 10% |

Data ở fishing_data.gd, gồm rarity/difficulty để mở rộng sau này. V1 mọi cá dùng
cùng reaction mechanic. Cá bán tại Fish Market ở (2190,980), giá Small/River/Golden
= 25/40/100 Coins. Fish Orders mở từ Level 10, dùng giá direct sale và hệ số
thưởng Orders 1.25–1.5 lần + EXP. Bait và EXP trực tiếp khi câu chưa triển khai.

## Rod upgrades

Shop có Fishing Rod ở cuối danh sách. Chi phí là cho từng lần nâng:

| Level | Coins | Reaction window |
|---|---:|---:|
| 1 | Miễn phí khi mở Level 10 | 1.00 giây |
| 2 | 800 | 1.10 giây |
| 3 | 2000 | 1.20 giây |
| 4 | 5000 | 1.30 giây |

Lv4 MAX LEVEL. Nâng cấp không giảm random delay, không tự bắt cá. Window được
snapshot khi bắt đầu phiên. Mọi thông số chỉ định nghĩa ở fishing_data.gd.

## Save

Save version 10 vẫn ở user://save.cfg, dùng backup/atomic replace hiện có.

- [inventory]: small_fish, river_fish, golden_fish; mặc định 0, validate như item khác.
- [fishing]: has_fishing_rod, fishing_rod_level; mặc định false/0, level clamp 0–4.
- Level >=10 cấp Rod Lv1 nếu chưa có, giữ nguyên cần đã nâng.
- Không save WAITING/BITE/result/reservation. Đóng giữa phiên rồi mở lại: IDLE,
  không cá tự sinh. Cooldown mới chỉ là thời gian nghỉ runtime, không có offline
  production và không cần migrate cooldown cũ (trước đây chưa có FishingSpot).
- Reset xóa cá, cần, cấp cần và phiên câu; cầu trở về locked như trước.

## Test trong Godot

1. Với save hiện tại: dùng F3 -> Level 10 nếu cần, đóng F3 và popup tools.
2. Qua cầu (1870,850), tới Spot (2020,980). Nhấn E hoặc tap Fish.
3. Nhấn E/REEL ngay: Too early! The fish got scared., không thêm cá.
4. Đợi hết cooldown rồi thử lại, quan sát delay thay đổi 1–5 giây mỗi lần.
5. Khi !!! FISH BITE !!! hiện, không bấm: sau 1 giây The fish got away!.
6. Lần sau bấm đúng window: Caught: ..., chỉ tăng một cá và Barn/HUD cập nhật.
7. Spam/giữ E: không tránh được early failure hoặc nhận nhiều cá.
8. Thử cả nút Fish/REEL thay cho bàn phím; logic và kết quả giống nhau.
9. Barn đầy không thả câu được. Barn còn một chỗ: chỗ đó được giữ cho cá.
10. Đang chờ thì đi ra xa hoặc ESC/mở Shop: không cá, UI/reservation được dọn.
11. Shop nâng Rod Lv2 với 800 Coins, window hiện 1.10 giây; Lv3/Lv4 đúng giá.
12. Đóng khi đang chờ, mở lại: cá đã bắt và cấp cần được giữ, phiên cũ không tiếp tục.
13. Thử Reset trên save thử: cá/cần về mặc định và cầu khóa lại.

## Kiểm thử tự động

tests/run_core_stability.ps1 chạy thêm fishing_core, fishing_write, fishing_read
trên bản sao/save thử, cùng các stability/gameplay regression hiện có. fishing_core
kiểm tra cả chờ thực 1–5 giây, timeout thực 1 giây, thắng sau hơn 1 giây ở Rod Lv2,
E/REEL, spam/echo, reservation, walk-away, ESC/modal, rod costs, reset và bảng
reward qua 10,000 mẫu có seed cố định. Không ghi save thật để chạy các ca này.
