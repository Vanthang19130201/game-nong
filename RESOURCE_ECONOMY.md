# Resource economy

Coins mua khả năng sản xuất/kiếm tiền: seeds, động vật, công trình sản xuất
và máy. Wood + Stone dùng xây/nâng cấp farm. Không cần vật liệu để mua công
trình sản xuất lần đầu.

## Mua bằng Coins

| Đối tượng | Giá |
|---|---:|
| Wheat Seed / Corn Seed / Carrot Seed | 5 / 10 / 15 |
| Feed Mill | 500 |
| Chicken Coop | 800 |
| Cow Shed | 1500 |
| Chicken | 150 (bán lại 100) |
| Cow | 300 (bán lại 200) |
| Dog | 300 |

Level unlock và điều kiện sở hữu chuồng vẫn giữ nguyên. Dog không yêu cầu
Dog House. Wood/Stone là hai bộ đếm riêng, không chiếm Silo hoặc Barn.

## Upgrade trong Build & Animals

Chi phí là cho từng lần nâng, không phải tổng tích lũy:

| Đối tượng | Nâng lên | Wood | Stone | Coins | Kết quả |
|---|---:|---:|---:|---:|---|
| Chicken Coop | Lv2 | 20 | 10 | 500 | 5 con |
| Chicken Coop | Lv3 | 40 | 20 | 1000 | 8 con |
| Cow Shed | Lv2 | 30 | 15 | 800 | 5 con |
| Cow Shed | Lv3 | 60 | 30 | 1600 | 8 con |
| House | Lv2 | 30 | 15 | 500 | House Level 2 |
| House | Lv3 | 60 | 30 | 1500 | House Level 3 |
| House | Lv4 | 100 | 50 | 3500 | MAX LEVEL |
| Silo | Lv2 | 10 | 5 | 200 | 50 chỗ |
| Silo | Lv3 | 20 | 10 | 200 | 80 chỗ |
| Barn | Lv2 | 8 | 8 | 250 | 35 chỗ |
| Barn | Lv3 | 20 | 10 | 200 | 60 chỗ |
| Dog House | Xây một lần | 15 | 5 | 0 | Đổi tâm wandering của Dog |

Silo/Barn Lv1 vẫn là 30/20. Các bậc storage là thông số phát triển hiện tại,
đổi tại `progression_data.gd`. Không tự tăng sức chứa khi Player lên level.
Thiếu bất kỳ tài nguyên nào thì không trừ chi phí, không đổi level. Phải sở
hữu chuồng trước khi upgrade. Capacity lớn hơn từ save cũ không bị giảm.

House mặc định Lv1. `HOUSE_FUTURE_FEATURES` chỉ là dữ liệu chuẩn bị cho rooms,
wardrobe/furniture và couple/marriage; chưa triển khai các tính năng đó.
Đứng gần House (700,400), nhấn E để mở House Panel. Panel hiện tài nguyên
hiện có/chi phí, Upgrade House và Close; ESC đóng. Dùng chung bảng UPGRADES
và transaction Inventory với Build & Animals. Thiếu tài nguyên không trừ gì.
Nâng cấp phát một signal sau khi trừ đủ chi phí và đổi level, để save/HUD/
visual cùng cập nhật. Lv4 MAX LEVEL; chỉ House có Lv4, các upgrade khác giữ Lv3.
Save vẫn dùng [upgrades] house_level trong user://save.cfg, thiếu/sai kiểu
thì mặc định 1; reset về 1. Không cần reset save đang chơi.
Fences và cấu trúc nâng cấp tương lai chưa triển khai. Cầu Fishing Area hiện
có collision và mở ở Level 10, chưa yêu cầu vật liệu sửa cầu.

## Thu thập

- Từ Level 6, đến gần Tree/Rock và nhấn E để dùng Axe/Hammer. Tree cho 2–3 Wood; Rock cho 2 Stone sau khi thanh progress hoàn tất.
- Có 5 Tree ở phía Bắc/Đông và 3 Rock quanh farm. Tree gần House: (450,220),
  (700,180), (1000,200). Rock phía Tây Nam: (350,900).
- Tree hồi sau 60 giây, Rock sau 90 giây (development values).
- Mỗi node có ID cố định và timestamp respawn_at. Cooldown được lưu cùng vật
  liệu trước khi thao tác kết thúc; nhấn E liên tục không nhận thêm.
- Khi mở game, nếu đã qua timestamp thì node lại thu được. UI mở sẽ chặn E
  giống các tương tác farm khác. Không thêm Metal Scrap ở early game.

## Dog và Dog House

Dog House tại (550,700), chỉ hiện sau khi xây. Có thể xây trước hoặc sau khi
mua Dog. Chưa có nhà thì Dog dùng DogHomePoint; có nhà thì dùng DogHouse.
Dog đang đi sẽ dừng target cũ và chọn lại trong bán kính 180 quanh nhà mới.
Node home_point cũng là điểm tham chiếu để thêm idle/sleep sau này.

## Save và reset

Save version 7 ở `user://save.cfg` thêm:

- `inventory`: wood, stone.
- `upgrades`: chicken_coop_level, cow_shed_level, house_level, silo_level,
  barn_level.
- `buildings`: has_dog_house.
- `resources`: state + respawn_at của từng tree_1…tree_5, rock_1…rock_3.
- 	ools: has_axe, has_hammer, axe_level, hammer_level, unlock_notified.

Save cũ giữ Coins, ownership, vật phẩm, orders và production; level mới mặc
định 1, vật liệu 0, chưa có Dog House, resource nodes sẵn sàng thu. Khi load,
đọc level chuồng trước rồi mới kiểm tra số con để không mất đàn 5/8 con.
Reset đưa mọi upgrade về Lv1, vật liệu về 0, Dog House biến mất, resource
nodes hồi lại; các reset khác vẫn hoạt động như cũ.

## Test

1. F5 ở Level 1: thấy Tree/Rock nhưng E yêu cầu tool. Lên Level 6 nhận tool, rồi kiểm tra progress, hủy khi đi xa và chống bấm liên tục.
2. Đóng rồi mở lại trước thời gian hồi: node vẫn đang respawn. Đợi quá
   90 giây rồi mở lại: cả Tree và Rock thu được.
3. Đủ level và Coins, mua công trình/con vật khi Wood/Stone bằng 0.
4. Mở Build & Animals, kiểm tra từng chi phí upgrade. Thiếu 1 Stone thì cả
   Wood và Coins phải giữ nguyên. Đủ thì chỉ trừ đúng một lần.
5. Nâng chuồng lên Lv2/Lv3, thử mua 5/8 con và con vượt capacity. Save rồi
   mở lại phải giữ đủ số con. Production vẫn tính theo số con và kiểm tra
   đủ chỗ trong Barn cho cả mẻ.
6. Nâng House, Silo/Barn. Nhãn House, HUD capacity và giới hạn nhận item
   phải đổi ngay.
7. Mua Dog, xây Dog House và quan sát đổi tâm đi lại. Thử xây nhà trước Dog.
8. Reset, kiểm tra vật liệu 0, upgrades Lv1, không còn Dog House, và thu
   thấy resource nodes AVAILABLE ngay, nhưng cần Level 6 và tool để khai thác.

Chi tiết Tools: xem TOOLS_AND_GATHERING.md.
