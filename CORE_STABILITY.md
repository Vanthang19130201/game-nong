# Core stability pass

Không đổi giá, thời gian sản xuất hoặc progression. Không thêm Bakery/Fishing
gameplay. Không cần reset save đang chơi.

## Những lỗi đã sửa

- Chưa có backup/fallback: save chính lỗi cú pháp trước đây lập tức về default.
- Cow Shed bị ép về default position sau mỗi inventory_changed, làm mất vị trí.
- Chỉ Cow Shed có cơ chế phục hồi instance thiếu; nay dùng chung cho cả ba
  production buildings và Dog House.
- Building chưa sở hữu vẫn còn CollisionShape2D hoạt động. Nay tắt cả monitoring
  và shape; can_interact không query overlaps khi monitoring đang tắt.
- Mua building ngay tại vị trí đứng có thể thiếu player_near. Nay query overlaps
  hiện tại khi tương tác, ngoài các body_entered/body_exited signal.
- Reset confirmation có thể chồng main panel; tools notification có thể mở
  trên House/Shop/Build/Orders. Nay đóng panel trước Reset, hoãn thông báo tools
  tới khi panel hiện tại đóng, từ chối panel khác khi native dialog đang mở.
- Recipe dropdown chưa được tính trong input lock.
- Tool ownership/level và animal ownership/count có thể mâu thuẫn trong save lỗi.
- Duplicate persistent IDs trước đây chỉ báo lỗi, node trùng vẫn có thể tương tác.
  Nay từ chối đăng ký, bỏ node trùng khỏi interaction group và hủy instance trùng.

## Save version 9

Vẫn dùng user://save.cfg, ghi đầy đủ snapshot vào save.cfg.tmp rồi rename.
Trước khi thay save chính hợp lệ, ghi snapshot trước đó vào
save_backup.cfg.tmp rồi rename thành save_backup.cfg. Nếu không ghi được backup
hoặc save tạm, báo warning và giữ save chính. Backup bắt đầu từ lần overwrite
save hợp lệ đầu tiên. Đây là một snapshot trước đó, không phải lịch sử nhiều bản.

Load: main đọc được thì validate từng field. Main thiếu/không đọc được thì thử
backup; cả hai lỗi thì default. Không thay backup tốt bằng nội dung main lỗi.
Field thiếu dùng default; số âm/sai kiểu dùng default, số lượng integer quá lớn
giới hạn ở 2147483647. Upgrade/tool/plot/animal có thêm giới hạn theo data.
Tool không owned có level 0; owned có ít nhất Lv1. Tools vẫn tự cấp ở Level 6.
Silo/Barn không nhỏ hơn 30/20 hoặc capacity của level đã nâng; giữ capacity cũ
lớn hơn và không cắt items trong kho đang quá đầy.

Thêm [building_positions] với Vector2 local theo ID:
house, feed_mill, chicken_coop, cow_shed, dog_house. Missing/invalid/NaN/outside
mainland/inside field -> default từ FarmData.BUILDINGS. Không đổi vị trí mỗi lần
inventory_changed. Project chưa có Edit Mode; không thêm công cụ move ở pass này.

Các section inventory/player/upgrades/tools/storage/buildings/animals/orders/
soil/resources/zones cũ vẫn được đọc. Soil alias soil_1…soil_6 tiếp tục migrate
thành soil_01…soil_06, không mất crop/timestamps. Resource IDs tree_1…tree_5,
rock_1…rock_3 đang ổn định nên giữ nguyên, không đổi tên chỉ để thêm số 0.

Reset xóa main, temp và cả backup trước khi reset dữ liệu. Đưa positions về
default, đóng UI, dừng crop/production/resource timers, xóa pet ownership,
upgrades/materials/tools, còn 8 ô EMPTY unlocked và khóa Fishing. Nếu đang ở
bên kia sông, đưa Player về mainland để không bị kẹt.

## Interaction và UI

Player là nơi duy nhất dispatch E. Chọn khoảng cách gần nhất trong group
farm_interactables rồi gọi interact(player), tối đa một mục tiêu. Bridge dùng
vị trí interaction area phía Tây làm điểm đo thay cho tâm cầu. Growing plots,
slot khóa chưa tới lượt mua và depleted resources không chặn mục tiêu hợp lệ.
Dog hiện chỉ wandering, không có tương tác E.

HUD quản lý Shop, Build, House, stations, Orders, Reset, plot purchase và debug.
Mở panel chính đóng panel cũ; native dialogs từ chối mở main panel khác.
Reset đóng panel cũ trước khi xác nhận. ESC chỉ đóng/cancel lớp đang mở, không
quit game. Main panel/dropdown/dialog/debug khóa WASD và E; mở panel hủy gathering.
Không có Edit Mode trong project hiện tại.

Inventory.inventory_changed tiếp tục là một signal refresh chung. Mọi transaction
trừ/cộng items và đổi state trước khi emit, để HUD và save nhận cùng snapshot.
Data giá/level vẫn ở CropData, Progression, ToolData, FarmData; không gom lại thành
một hệ thống mới. Giá Dog/Dog House trên UI lấy từ data thay vì ghi giá riêng.

## Offline timers

Crops, Feed Mill, Chicken/Cow và resources dùng Unix deadline. Load quá hạn chỉ
đổi READY/AVAILABLE, không tự cộng thưởng. Chưa quá hạn thì chạy phần còn lại.
Collect/harvest đổi state trước khi cộng item/signal để không nhận hai lần.
Production timestamps sai hoặc building không owned không được tạo batch miễn phí.
Resources trong zone khóa giữ timestamp, không chạy process/collision/respawn
cho tới khi zone mở. Fishing vẫn mở ở Level 10, không thêm resource thu hoạch ở đó.

## Dev panel

F3 mở/đóng, ESC/Close đóng. Chỉ tạo node trong OS.is_debug_build(); script và từng
mutation cũng có guard. Release không có node, không xử lý phím F3.

- +1000 Coins; +10 Wood; +10 Stone; +100 EXP.
- Set Player Level 1 / 6 / 8 / 10 / 12, EXP về 0, đồng bộ tools/crop selection/
  Fishing. Không tự tặng buildings hoặc animals.
- Các thao tác debug ảnh hưởng **save hiện tại**, HUD và auto-save như gameplay.
  Hạ level bằng debug có thể thay Orders không còn đủ điều kiện; đây không phải Undo.

## Kiểm thử tự động

PowerShell, chạy từ project, thay đường dẫn Godot nếu cần:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_core_stability.ps1 -Godot "C:\path\Godot_v4.7.2-stable_win64_console.exe"
```

Runner sao chép source và import cache vào .godot/core-stability-project, chỉ
trong bản sao mới đổi save paths sang res://test-save.cfg và test-backup.cfg.
Test scripts từ chối chạy Reset nếu SaveManager vẫn trỏ vào user:// thật.
Không sửa save thật. Cần mở project bằng Godot ít nhất một lần để có import cache.

Đã chạy Godot 4.7.2: 14 stages core/positions/legacy/invalid/offline/backup/defaults/
duplicates và một gameplay regression (8 ô, hai recipe feed, eggs/milk, Orders,
Dog, WASD/camera/HUD/Shop/ESC/Reset). Không có parser/node path/null/signal errors.
Fixture cố ý lỗi sẽ in ConfigFile parse errors; fixture duplicate cố ý in
Duplicate ID errors. Runner chỉ chấp nhận các lỗi dự kiến đó đúng stage tương ứng.

## Checklist test thủ công

1. F5 với save hiện tại: Coins/items/level/plots/owned buildings vẫn đúng, không Reset.
2. Một lần E gần hai đối tượng: chỉ mục tiêu hợp lệ gần nhất hoạt động.
3. Trồng, đóng khi GROWING, mở trước/sau deadline; thu một lần, không mất cây/seed.
4. Mua ô 9, thử thiếu tiền và mua vượt thứ tự; mua tiếp tới 32, không mua ô 33.
5. F3 cộng tiền/vật liệu, đặt Level 6/8/10. Đóng bằng ESC, kiểm tra HUD và save.
6. Mua building khi đứng sẵn ở vị trí nhà; E phải mở đúng panel ngay sau khi mua.
7. Sản xuất hai loại feed, cho gà/bò ăn; đóng/mở trước/sau deadline, collect chỉ một lần.
8. Kho đầy: collect/harvest bị từ chối, READY giữ nguyên. Bán hàng rồi thử lại.
9. Upgrade House tới Lv4, tools, chuồng, Silo/Barn; thiếu tài nguyên không bị trừ.
10. Mua Dog/xây Dog House, đóng/mở; đúng ownership và wandering center.
11. Đang gathering mở Shop/Build/F3: hủy gathering, không thưởng. Popup khóa WASD/E.
12. Chuyển Shop/Build/House/Orders; Reset confirmation chỉ một popup. Cancel/ESC không reset.
13. Trước Level 10 cầu bị chặn; Level 10 qua được; Reset trong Fishing đưa về mainland.
14. Reset: không còn cây, nhà đã mua, pet, vật liệu, upgrade, positions hoặc timer cũ.
    Đóng/mở lại cũng không phục hồi tiến trình từ backup trước Reset.

## Giới hạn còn lại

- Timestamp phụ thuộc đồng hồ hệ điều hành; chưa có server time/chống chỉnh giờ.
- Backup chỉ phục hồi file không parse được; field lỗi trong file parse được dùng
  validation/default của field đó. Lỗi ghi đĩa báo warning; không thể bảo đảm lưu
  nếu ổ đĩa đầy/mất quyền ghi.
- Chưa chạy export release thật; kiểm tra guard release bằng source, gameplay bằng
  console debug 4.7.2. Chưa có Edit Mode hoặc tự giải quyết hai building cố ý đặt chồng.
- Môi trường sandbox có cảnh báo certificate store/engine user log; không phải
  parser hoặc gameplay errors. Runner bỏ qua hai cảnh báo môi trường này.
