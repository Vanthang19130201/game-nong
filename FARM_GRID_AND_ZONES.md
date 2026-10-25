# Farm grid và zones

`farm_data.gd` là nơi sửa số ô, giá, cách xếp grid và level Fishing.

## Grid

- Tối đa 32 ô, 8 cột × 4 hàng; visual 64×48, Area2D 68×52, khoảng cách visual
  10 px theo cả hai chiều.
- Bắt đầu 8 ô miễn phí thành 4×2 ở góc trên trái. Mua lần lượt 9→32, lấp
  thêm các block 4×2 để cuối cùng thành grid 8×4 gọn.
- Plot 1 có tâm (1100,520). Plot 9 tại (1396,520), bên phải block đầu.
- Tên node cũ SoilPlot/SoilPlot2…6 được giữ. SoilPlot7…32 dùng soil_plot.tscn.
- Tất cả vị trí lấy từ FarmData, cùng group fixed_farm_grid. Project hiện
  chưa có Edit Mode; hệ thống move tương lai cần bỏ qua group này. Các
  buildings không bị đưa vào group cố định.
- Slot khóa có màu xám, chữ LOCKED và giá. Không trồng/thu hoạch trên slot khóa.

| Ô | Giá mỗi ô |
|---|---:|
| 1–8 | Miễn phí |
| 9–12 | 100 Coins |
| 13–16 | 200 Coins |
| 17–20 | 350 Coins |
| 21–24 | 500 Coins |
| 25–28 | 750 Coins |
| 29–32 | 1000 Coins |

E ở slot kế tiếp mở NEW FARM PLOT, Buy/Cancel. Không đủ tiền thì popup giữ
mở, báo Not enough Coins. Không mua vượt thứ tự hoặc quá 32. Đổi count trước
khi phát signal để Coins, unlocked và crop được lưu trong cùng snapshot.

## ID và save migration

Save version 8 tại user://save.cfg:

- [farm]: unlocked_plot_count (default 8, max 32).
- [soil_01]…[soil_32]: plot_id, unlocked, state, crop_type, planted_at, ready_at.
- [zones]: fishing_unlocked.
- [resources]: state, respawn_at, zone_id cho từng resource ID.

Load sẽ đọc soil_1…soil_6 cũ nếu chưa có section soil_01…soil_06. Giữ crop,
timestamp và trạng thái; thêm 2 ô EMPTY để bắt đầu ít nhất 8. Nếu tìm thấy
crop ở slot cao hơn count đã lưu, tự mở đến slot đó để tránh mất cây. Save
tiếp theo ghi ID canonical hai chữ số, không dùng runtime instance ID.

## Fishing Area

- Fishing Area x=1940…2400, nhìn thấy từ đầu. River x=1800…1940 có hai đoạn
  collision kín tới hai mép map. Chỉ có lối cầu tại (1870,850), y=790…910.
- Trước Level 10, blocker chặn toàn bộ cầu. Đến phía Tây cầu, E ở sign để
  xem Fishing unlocks at Level 10.
- Level 10 đặt fishing_unlocked, bỏ blocker và cập nhật sign. Các đoạn sông
  khác vẫn không đi qua được. Save cũ đã Level >=10 tự nhận unlock.
- Fishing Area chỉ có decorative rock, không có Tree/Rock resource.
- Cow Shed ở (900,1020), bên trái Feed Mill; Tree/Rock phía Đông được chuyển về main
  để không nằm trên river hoặc trong Fishing Area.
- Reset khóa lại cầu. Nếu Player đang ở bên kia, đưa về điểm an toàn
  (1740,850) phía main để không bị kẹt.

## Resource activation

ResourceNode có zone_id export; scene quyết định zone, không để save cũ
ghi đè scene config. main/forest luôn mở, fishing cần Level 10 + unlock,
future/unknown zone mặc định khóa.

Zone khóa: node hidden, tắt process/monitoring/collision, không tương tác,
dừng HarvestTimer và RespawnTimer. Không tính lại respawn khi đọc save hoặc
khi cooldown hết trong zone khóa; giữ timestamp cho tới lúc zone mở.

Khi zone mở, node mới khởi tạo respawn: deadline đã qua thì AVAILABLE, chưa
qua thì tiếp tục phần thời gian còn lại. Không tạo thêm resource trong
Fishing Area; cơ chế zone dùng để bảo vệ các scene tương lai.

## Test

1. New game: 8 ô nâu thành 4×2, còn lại LOCKED, HUD hiện Plots: 8 / 32.
2. Có ít nhất 100 Coins, đứng tại (1396,520), E. Cancel/ESC phải giữ nguyên
   tiền; Buy trừ 100, HUD 9 / 32, ô mới EMPTY và có thể trồng ngay.
3. Thử mua khi thiếu tiền, mua Plot 20 trước Plot 9, mua trùng hoặc quá 32.
4. Trồng trên ô mới, Save rồi mở lại. Cây và timestamps phải giữ đúng.
5. Trước Level 10, đi tới (1750,850), E xem sign, thử qua cầu và vòng qua các
   đoạn river khác: đều bị chặn. Main/Forest vẫn đi lại được từ Level 1.
6. Level 10, đóng popup tool nếu đang hiện, qua cầu. Save rồi mở lại: vẫn mở.
7. Trong scene thử riêng, đặt ResourceNode.zone_id=future_2 trước khi chạy:
   node ẩn, collision disabled, không chạy timer. Zone fishing chỉ active
   khi unlock; không đặt resource thu hoạch thật vào Fishing Area của main.
8. Reset khi đứng bên kia cầu: trở về main, cầu khóa, 8 ô đầu EMPTY/unlocked,
   24 ô còn lại khóa. Các reset Inventory/tool/building vẫn giữ nguyên.

Kiểm thử tự động sử dụng bản sao project và file save thử riêng trong
workspace, không dùng save thật để chạy Reset hoặc migration fixtures.

