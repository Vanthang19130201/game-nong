# Storage và progression

Thông số level, giá công trình/động vật, recipe và thời gian sản xuất nằm trong
`progression_data.gd`. Crop vẫn dùng `crop_data.gd`.

## Storage

- Silo: 30 chỗ, dùng chung cho sáu item hạt giống/nông sản.
- Barn: 20 chỗ, dùng chung cho Chicken Feed, Cow Feed, Egg và Milk.
- Mỗi đơn vị item chiếm một chỗ. Coins, động vật và pet không chiếm storage.
- Kho đầy thì không mua thêm seed hoặc thu hoạch/collect. Cây và mẻ sản phẩm
  vẫn READY. Cần đủ chỗ cho **cả mẻ** sản phẩm của chuồng.
- Bán hàng, giao orders, trồng cây và dùng feed sẽ giải phóng chỗ.
- Nếu Barn đầy toàn Feed, Shop có nút Discard 1 Chicken Feed / Cow Feed để
  chủ động bỏ một Feed, tránh bị kẹt không có chỗ collect. Không nhận Coins.
- Save cũ vượt capacity được giữ nguyên tài nguyên; không nhận thêm cho tới khi
  có đủ chỗ. Capacity không tự tăng khi lên level.

## Unlock khác ownership

| Level | Unlock |
|---|---|
| 1 | Wheat |
| 2 | Corn |
| 3 | Carrot |
| 4 | Feed Mill — 500 Coins |
| 5 | Chicken Coop — 800 Coins |
| 6 | Chicken — mua 150, bán 100; tặng Axe/Hammer Lv1 |
| 7 | Egg Orders |
| 8 | Cow Shed — 1500 Coins; recipe Cow Feed |
| 9 | Cow — mua 300, bán 200 |
| 10 | Milk và Milk Orders |
| 12 / 15 | Bakery / Dairy: chỉ thông báo future unlock |

Mở **Build & Animals** để mua công trình. Đạt level không tự tặng công trình
hoặc động vật. Công trình hiện ngay trên farm sau khi mua.

Chuồng Lv1 chứa 3 con, Lv2 chứa 5 con, Lv3 chứa 8 con. Không mua/bán động vật khi đang PRODUCING hoặc
READY; collect trước để không thay đổi số con trong một mẻ.

## Sản xuất

- Chicken Feed: 1 Wheat + 1 Corn, 10 giây.
- Cow Feed: 2 Corn + 1 Carrot, 15 giây.
- Feed Mill có một slot cho cả hai recipe.
- Chicken Coop: 1 Chicken Feed cho cả đàn, 20 giây, số Eggs = số gà.
- Cow Shed: 1 Cow Feed cho cả đàn, 30 giây, số Milk = số bò; cần Level 10.
- Không cho ăn nếu không có động vật. Thu Egg được 5 EXP/Egg; Milk 10 EXP/Milk.
- Shop bán Egg giá 18 Coins, Milk giá 30 Coins.

Orders chỉ yêu cầu Egg từ Level 7, Milk từ Level 10, và cần sở hữu Feed Mill,
chuồng tương ứng cùng ít nhất một con. Các order mất điều kiện sẽ được thay
riêng slot đó để tránh kẹt đơn.

## Save, offline và reset

Save version 8 vẫn dùng `user://save.cfg`:

- `inventory`: vật phẩm, Coins.
- `storage`: silo_capacity, barn_capacity.
- `buildings`: owns_feed_mill, owns_chicken_coop, owns_cow_shed.
- `animals`: chicken_count, cow_count.
- `feed_mill`, `chicken_coop`, `cow_shed`: state, production_type, started_at,
  ready_at; các phần player, orders và soil vẫn được giữ.

Các mốc thời gian là Unix timestamp. Khi mở lại, nếu đã qua ready_at thì mẻ
chuyển READY; nếu chưa thì timer tiếp tục phần còn lại. Mẻ READY vẫn được giữ
khi storage đầy.

Save trước version 5 giữ các công trình miễn phí vốn đã tồn tại và số gà cũ.
New game/reset bắt đầu không sở hữu công trình, không có động vật, Silo 30 và
Barn 20. Field mới bị thiếu/sai kiểu dùng default, số lượng động vật được giới
hạn theo level chuồng (3/5/8). Reset cũng dừng toàn bộ timer và bỏ ownership.

## Test trong Godot

1. F5, kiểm tra Silo/Barn và Build & Animals. Level 1 chỉ mua được Wheat.
2. Trồng/thu hoạch/giao Orders để lên Level 2, 3; kiểm tra Corn và Carrot.
3. Level 4: mua Feed Mill; tới máy, E, chọn Chicken Feed rồi Produce.
4. Level 5: mua Coop; chưa có gà nên chưa sản xuất được.
5. Level 6: mua 1–3 gà; thử con thứ 4, bán về 0, và cho ăn khi không có gà.
6. Collect Feed, cho gà ăn, đợi 20 giây; thu đúng số Eggs theo đàn.
7. Level 7: Egg Orders được phép xuất hiện khi đủ ownership/động vật.
8. Level 8: mua Cow Shed, sản xuất Cow Feed; Level 9 mua bò. Milk vẫn khóa.
9. Level 10: cho bò ăn, đợi 30 giây, collect Milk và bán trong Shop.
10. Làm đầy kho rồi thử mua/thu hoạch/collect. Giải phóng đủ chỗ và collect lại;
    không mất cây, mẻ hàng, nguyên liệu hoặc EXP khi thao tác thất bại.
11. Đóng khi đang sản xuất, chờ hơn 30 giây rồi mở lại: mẻ phải READY.
12. Thử ESC, Order Board, Dog, camera, WASD/E và Reset. Sau reset các công
    trình phải ẩn, counts về 0, kho về capacity ban đầu.

Để test nhanh, có thể tạm gọi `Inventory.add_exp(4500)` và
`Inventory.add_coins(10000)` một lần trong `farm.gd::_ready()`, chạy từ game
mới, rồi xóa hai dòng test. Không gọi chúng mỗi frame.

Wood/Stone và nâng cấp: xem RESOURCE_ECONOMY.md.

Tools, khai thác và map tự do: xem TOOLS_AND_GATHERING.md.

Farm grid 8→32 và Fishing Area Level 10: xem FARM_GRID_AND_ZONES.md.

Reaction fishing, fish Barn items và Rod upgrades: xem FISHING_V1.md.
