# Tools và resource gathering

Map 2400×1600: Farm, Forest, House, rocks và grassland mở từ Level 1. Fishing
Area bên kia river nhìn thấy sẵn nhưng chỉ qua cầu được từ Level 10. River
có collision, cầu là lối duy nhất sang Fishing Area. Chưa có gameplay câu cá.

## Level 6

Trước Level 6, tới Tree/Rock rồi E sẽ báo cần công cụ. Khi đạt Level 6, game
tặng Axe Lv1 và Hammer Lv1 miễn phí. Tool không nằm trong Silo/Barn.

`Inventory.normalize_exp()` gọi `ensure_tools_for_level()` nên hỗ trợ cả lên
nhiều level và migrate save cũ đã Level >=6. Tool đã nâng không bị hạ về Lv1.
HUD hiện TOOLS UNLOCKED! với nút OK. Cờ unlock_notified được lưu để popup không
lặp lại khi mở game. Popup được mở deferred sau transaction, tránh ghi save
khi order/harvest chưa cập nhật xong.

## Nâng cấp chỉ dùng Coins

Thông số ở `tool_data.gd`, UI nằm cuối Shop:

| Tool | Lv1 | Lên Lv2 | Lên Lv3 | Lên Lv4 |
|---|---|---|---|---|
| Axe | 3.0 giây, miễn phí | 500 Coins, 2.2 giây | 1500 Coins, 1.5 giây | 4000 Coins, 1.0 giây |
| Hammer | 3.5 giây, miễn phí | 600 Coins, 2.6 giây | 1800 Coins, 1.8 giây | 4500 Coins, 1.1 giây |

Tool chỉ tăng tốc. Tree luôn cho 2–3 Wood, Rock luôn cho 2 Stone. Không dùng
Wood/Stone nâng tool. Lv4 hiển thị MAX LEVEL.

Storage vẫn dùng vật liệu: Silo Lv2 = 10 Wood + 5 Stone + 200 Coins; Barn Lv2
= 8 Wood + 8 Stone + 250 Coins. Sức chứa và các bậc Lv3 khác giữ như bảng
RESOURCE_ECONOMY.md. House, Dog House và animal buildings giữ nguyên chi phí.

## Gathering và interaction

- Player xử lý E duy nhất tại `player.gd::_unhandled_input()`.
- Các node trong group farm_interactables có can_interact() và interact().
- Một lần E chỉ gọi node gần Player nhất trong số các node đang ở gần.
- Khi gathering, Player.active_resource khóa các tương tác E khác. Player
  vẫn đi được để chủ động rời vùng và hủy.
- Tree/Rock dùng HarvestTimer và ProgressBar. Snapshot tốc độ lúc bắt đầu;
  nhấn E liên tục không khởi động lại timer, không nhận thêm reward.
- Rời Area2D hoặc mở UI sẽ hủy, không có reward và không bắt đầu respawn.
- Chỉ khi timer hoàn tất mới cộng vật liệu và chuyển DEPLETED/STUMP.
- Tree respawn sau 60 giây; Rock sau 90 giây, dùng Unix timestamp.
- Cooldown và vật liệu được lưu cùng một snapshot để tránh khai thác lặp.

## Save và Reset

Save version 7 ở user://save.cfg:

- [tools]: has_axe, has_hammer, axe_level, hammer_level, unlock_notified.
- [resources]: mỗi ID lưu Dictionary {state, respawn_at}.
- Gathering đang làm dở được lưu là AVAILABLE, không có reward; mở game lại
  phải làm lại thao tác. Chỉ respawn tiếp tục offline.
- Save version 6 có timestamp resource dạng số vẫn load được.
- Field tool bị thiếu: default false/0, rồi tự cấp Lv1 nếu Player >=6.
- Reset: vật liệu 0, không tool, tool level 0, popup flag false, resource
  AVAILABLE; hủy mọi gathering đang chạy. Player về Level 1 nên chưa khai thác.

Fishing Rod, Shovel, rare resources và mine chưa triển khai; có thể bổ sung
metadata tool và node tương tác theo cùng cấu trúc sau này.

## Test

1. New game Level 1: WASD khám phá Forest/River/grassland. Thử E ở Tree/Rock:
   không nhận vật liệu, node vẫn hiện, báo cần công cụ.
2. Chơi tới Level 6: nhận hai tool và popup. Save, mở lại: không tặng/lặp popup.
3. E ở Tree: progress khoảng 3 giây. Đi ra xa trước khi xong: hủy, Wood giữ
   nguyên. Làm lại đủ thời gian: +2 hoặc +3 Wood, hiện STUMP.
4. Rock tương tự, khoảng 3.5 giây, nhận 2 Stone.
5. Mở Shop, cuộn tới TOOLS, nâng từng bậc. Kiểm tra chỉ Coins giảm, thời gian
   thay đổi theo bảng, reward giữ nguyên, Lv4 không nâng tiếp.
6. Thử thiếu Coins; thử E liên tục khi đang gathering; mở Shop để hủy.
7. Đóng khi depleted, mở lại trước hạn: vẫn depleted. Sau >90 giây: cả hai
   loại lại AVAILABLE. Save đang gathering không được tự nhận vật liệu.
8. Kiểm tra E ở ruộng, máy, Order Board. Khi panel mở, WASD/E vẫn bị khóa;
   ESC đóng như cũ. Khi nhiều Area2D chồng nhau, chỉ mục tiêu gần nhất nhận E.
9. Reset lúc đang gathering: không còn tool/vật liệu, timer dừng, resource
   AVAILABLE. Kiểm tra lại ở Level 1 không khai thác được.

Test nhanh trên một save thử mới: tạm gọi Inventory.add_exp(1500) một lần
trong farm.gd::_ready() để lên Level 6, Inventory.add_coins(20000) để thử
upgrade, rồi bỏ các dòng test. Không gọi mỗi frame hoặc để lại trong game.
