# Fish Market

Market cố định ở (2190,980), bên phải FishingSpot (2020,980), trong Fishing Area
x >=1940. Nhìn thấy từ đầu, chỉ tương tác khi Fishing Area đã mở và Player
Level >=10. Không có giá mua, ownership hoặc position save riêng.

Area2D có Visual/Awning/Label và vùng tương tác 180x160. Dùng group
farm_interactables và Player dispatcher hiện tại: E chỉ chọn mục tiêu gần nhất.
Đứng quá xa không mở/bán được; rời area hoặc bị khóa level sẽ đóng panel.

## Bán cá

Giá nằm duy nhất trong FishingData.FISH (fishing_data.gd):

| Cá | Coins mỗi con |
|---|---:|
| Small Fish | 25 |
| River Fish | 40 |
| Golden Fish | 100 |

Inventory.sell_fish kiểm tra zone/level, loại item hợp lệ và quantity >0.
Sell 1 trừ một; Sell All đọc toàn bộ lượng hiện tại của đúng loại cá đó.
Trừ cá và cộng amount*sell_price trước khi emit inventory_changed một lần.
Không dựa vào quantity cũ hiển thị trên UI nên nhấn nhanh không bán trùng.
Quantity 0 thì nút disabled; callback gọi lại cũng không cộng tiền.

Barn usage là tổng số item thực tế, nên bán ba cá giảm đúng ba chỗ. HUD,
panel và save nhận cùng signal. Dùng save version 10 hiện có; không thay format,
không cần reset hoặc migrate ownership của Market. Save cũ giữ nguyên cá/Coins.

Không thêm nút bán cá vào Shop chính. Shop vẫn có nâng Fishing Rod.

## UI và Orders

FishMarketPanel nằm trong HUD CanvasLayer, cố định trên screen. Mở Market
đóng/hủy Fishing UI và panel cũ; panel đang mở khóa E/WASD/fishing. ESC hoặc
Close đóng; chuyển panel khác sẽ đóng Market, không chồng hai main panels.

Orders có thể chọn cá từ Level 10 khi Fishing đã mở/có rod. Giá cơ sở lấy từ
cùng FishingData, reward generator hiện có cộng 1.25–1.5 lần giá direct sale.
order_exp cơ sở của mỗi cá =5, sau đó dùng multiplier EXP Orders hiện có.
Ví dụ một River Fish có thể trả 50–60 Coins và EXP. Orders cũ hợp lệ giữ nguyên;
không ép thay Orders đang có chỉ để hiện cá ngay.

## Test

1. F3 đặt Level 9, đóng debug: Market nhìn thấy nhưng cầu/Market khóa. Dù test
   teleport tới Market, E cũng không mở. Cá trong Orders chưa khả dụng.
2. F3 đặt Level 10, đóng debug/tools popup: cầu mở, Rod Lv1 có sẵn, qua cầu.
3. Câu ở (2020,980), thắng mini-game; tới Market (2190,980), E.
4. Sell 1: cá -1, Coins cộng đúng giá; Barn/HUD/Owned cập nhật ngay.
5. Sell All: chỉ bán loại đã chọn; thử 3 Small Fish nhận tổng 75 Coins.
6. Khi hết cá, nút disabled; bấm E liên tục không bắt đầu fishing sau panel.
7. ESC đóng panel; thử vị trí giữa Spot/Market để kiểm tra nearest interaction.
8. Đóng rồi mở lại: Coins/cá sau sale phải được giữ, Market vẫn có sẵn.
9. OrderBoard ở main farm có thể sinh yêu cầu cá từ Level 10. Hoàn thành chỉ
   thưởng một lần; direct sale không tự cộng EXP.

Runner tests/run_core_stability.ps1 bổ sung market_core/market_read: kiểm tra
level gate, 3 mức giá, sell-all/empty/invalid item, Barn, nearest E, modal/ESC,
fish Orders multiplier/fulfillment, auto-save và load lại trong bản sao project.
Toàn bộ stability, Fishing và gameplay regression cũng được chạy cùng runner.
