# PHÂN TÍCH HÌNH HỌC HFSS — PHẦN TỬ VIVALDI DUAL-POL HOÀN CHỈNH

**Tệp chuẩn:** `17_10_2026_vivaldi.aedt` (669.840 byte; SHA-256 `631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619`).  
**Cách kiểm tra:** đọc và truy dấu cấu trúc văn bản `.aedt`, bao gồm lịch sử thao tác CAD, tham số, phép Boolean, tọa độ, vật liệu, nguồn, port và setup. **Chưa khởi chạy ANSYS HFSS để rebuild/validate hình học.**  
**Phạm vi:** một phần tử **dual-polarized**, không phải mô hình mảng M×N.

## 1. Chọn đúng design

File gồm hai mục `HFSSModel`:

- `HFSSDesign1`: gần như rỗng, không có các part hình học, preview ghi `IsSolved=false`.
- **`dual_pol_vivaldi_patch_Wflare_20`**: design thực sự chứa hình học Vivaldi, `SolutionType='DrivenModal'`, các boundary, port, setup và lịch sử Boolean.

Trong design thứ hai có **8 top-level parts**: `RadiatingSurface`, `cable_in`, `cable_out`, `port1`, `Vivaldi_1`, `cable_in_1`, `cable_out_1`, `port2`; và **17 operand parts** trung gian như `EquationSurface1`, `EquationSurface2`, `EquationSurface2_1`, `Rectangle1/2/3`, `Vivaldi_2`, `Box1`, `De`, các bản sao hình trụ. `Vivaldi_2` không còn là một top-level part **vì đã được Unite vào `Vivaldi_1`**; không được nhầm việc này với mất phân cực thứ hai.

## 2. Các biến gốc và công thức phụ thuộc

| Tham số | Biểu thức/lựa chọn lưu trong HFSS | Giá trị tại cấu hình hiện tại |
|---|---|---:|
| `L_flare_1` | `40mm` | 40 mm |
| `slot_t_L` | `6.4mm+them`, `them=0mm` | 6.4 mm |
| `L_flare` | `L_flare_1+slot_t_L` | 46.4 mm |
| `aperture_w` | `20mm` | 20 mm |
| `slot_feed_w` | `0.5mm` | 0.5 mm |
| `r_flare` | `(1/L_flare)*ln(aperture_w/slot_feed_w)` | 0.0795017124 mm⁻¹ |
| `deg_slot_t` | `21deg` | 21° |
| `x_feed` | biểu thức tham số theo góc xoay | 2.499330861 mm |
| `z_feed` | biểu thức tham số theo góc xoay | 0.663696710 mm |
| `h3_slot_feed` | `1mm` | 1 mm |
| `h2` | `2.6mm` | 2.6 mm |
| `cavity_w` | `1.4mm` | 1.4 mm |
| `cavity_L` | `5mm` | 5 mm |
| `thickness` | `2mm` | 2 mm |
| `h_de` | `2mm` | 2 mm |
| `L_patch` | `L_flare_1+slot_t_L-z_feed+h3_slot_feed+slot_feed_w+h_de` | **49.236303290 mm** |
| `de_L`,`de_W` | `aperture_w+thickness` | 22 mm × 22 mm |
| `r_cabin`,`r_cabmid`,`r_cabout` | `0.15mm`,`0.35mm`,`0.5mm` | 0.15/0.35/0.5 mm |
| `positionx` | `0.15mm` | 0.15 mm |
| `h_cabin` | `h_de+slot_feed_w` | 2.5 mm |
| `h_cabout`,`h_cabmid` | `h_cabin-slot_feed_w` | 2 mm |

Các biểu thức vị trí nguồn chính xác:

```text
z_feed = ((slot_feed_w/2)*exp(slot_t_L*r_flare)+slot_feed_w/2)*sin(deg_slot_t)
         +slot_t_L*(1-cos(deg_slot_t))

x_feed = ((slot_feed_w/2)*exp(slot_t_L*r_flare)+slot_feed_w/2)*cos(deg_slot_t)
         +slot_t_L*sin(deg_slot_t)-(slot_feed_w/2)*exp(slot_t_L*r_flare)
```

**Lưu ý:** Hàm lượng giác dùng góc **độ** trong biểu thức HFSS. `L_patch` là chiều cao tổng theo Z từ đáy đến miệng, **không phải** chiều dài trực tiếp của equation-based flare.

## 3. Hệ tọa độ (quy chiếu về Global)

| CS | Parent CS | Gốc Global (x,y,z), mm | Chức năng |
|---|---|---|---|
| `Global` | — | (0,0,0) | Mô hình 3D |
| `slot_t_td` | Global | (**0.415828068**, 0, **6.4**) | Trục xoay Y của đoạn loe ngắn |
| `slot_feed_td` | Global | (**−2.499330861**, 0, **0.663696710**) | Dựng khe/hốc và cấp coax |
| `patch_td` | Global | (10, 0, **46.4**) | Dựng tấm anten ban đầu |
| `RelativeCS1` | `patch_td` | (**10**, **−1**, **46.4**) | Sao chép và xoay phân cực thứ hai, dựng khối nối |

Cả bốn hệ tọa độ tương đối đều khai báo trục X/Y cùng hướng Global (không xoay trục khi tạo CS). Mục `ReferenceCoordSystemID` trong CAD rất quan trọng; chỉ chép các tọa độ nguyên văn sang Global sẽ dựng sai.

## 4. Chuỗi dựng hình xác minh được từ phụ thuộc CAD

> Phân biệt **chuỗi thao tác cần để tái dựng đúng mô hình** với thứ tự thời gian tuyệt đối khi người dùng click trong HFSS. File lưu lịch sử theo từng part/operand, chứ không lưu một nhật ký click tuần tự duy nhất.

### Pha A — Tạo vùng khoét loe có đoạn chuyển tiếp 21°

1. `EquationSurface1` — `EquationBasedSurface` (ID **5903**, CS Global):
   `x(_u,_v)=_v*(slot_feed_w/2)*exp(_u*r_flare)`, `y=0`, `z=_u`; `_u=0..L_flare`, `_v=−1..1`.
2. `EquationSurface2` — `EquationBasedSurface` (ID **5926**, Global): cùng phương trình, nhưng `_u=0..slot_t_L`.
3. `EquationSurface2_1` — `CloneFrom` (ID **5939**). Bản sao đoạn loe ngắn giữ lại để làm **công cụ Subtract**; dấu vết CloneTo của nguồn ID **5937** đứng trước Rotate ID 5938.
4. `EquationSurface1` — `Substract` (ID **5914**, `KeepOriginals=true`, tool part `EquationSurface2_1`): **trừ đoạn đầu 0..6.4 mm khỏi loe dài**. Vùng loe dài sau trừ bắt đầu tại biên `_u=slot_t_L`.
5. `EquationSurface2` — `Rotate` (ID **5938**, trục Y, `deg_slot_t=21deg`, tham chiếu `slot_t_td`): xoay **đoạn ngắn nguyên bản** quanh gốc (**0.415828,0,6.4**), không xoay quanh Global.

Hai mép đầu của đoạn ngắn sau xoay (tính từ công thức + phép biến đổi tọa độ) lần lượt khoảng **(x,z)=(-2.499331,0.663697)** và **(-2.032541,0.484513)** mm. Mép đầu tiên trùng với gốc `slot_feed_td`.

### Pha B — Tạo khe cấp nguồn và phần hốc, ghép vào tool khoét

Các Rectangle được dựng trong **CS `slot_feed_td`**, trên mặt phẳng có normal Y (`WhichAxis='Y'`). Trong kiểu Rectangle này, `Width` tác động theo hướng Z của hình và `Height` theo hướng X, nên không thể hiểu Width là độ rộng ngang mặc định.

| Đối tượng | ID tạo / CoverLines | (XStart, ZStart) local mm | Width (trục Z) | Height (trục X) | Biên global X / Z suy ra, mm |
|---|---|---|---|---|---|
| `Rectangle1` | 5950 / 5960 | (0,0) | `−h3_slot_feed` = −1 | `slot_feed_w` = 0.5 | X −2.4993..−1.9993; Z −0.3363..0.6637 |
| `Rectangle2` | 5962 / 5972 | (0,−1) | `−slot_feed_w` = −0.5 | `slot_feed_w+h2+cavity_w` = 4.5 | X −2.4993..2.0007; Z −0.8363..−0.3363 |
| `Rectangle3` | 5974 / 5984 | (3.1,−1.5) | `cavity_L` = +5 | `cavity_w` = 1.4 | X 0.6007..2.0007; Z −0.8363..4.1637 |

`EquationSurface1` — **`Unite` ID 5918** gồm mặt loe dài sau trừ, **`EquationSurface2` đã xoay**, và **Rectangle1, Rectangle2, Rectangle3**. Kết quả là **một vùng khoét tổng hợp**, bao gồm loe + đoạn chuyển tiếp + khe/hốc. Không được trừ từng đường 2D rời rạc mà bỏ qua Unite này.

### Pha C — Dựng phần tử kim loại thứ nhất

6. `Vivaldi_1` — `Rectangle` ID **5724** trong `patch_td`: `XStart=YStart=ZStart=0`, `Width=−L_patch`, `Height=−aperture_w`, `WhichAxis='Y'`. Sau CoverLines ID **5734**, mặt phẳng anten thứ nhất có biên **X=−10..10**, **Z=−2.836303..46.4 mm**, **Y=0** trước tăng độ dày.
7. `Vivaldi_1` — `Substract` ID **5736**, tool part **EquationSurface1** (đã Unite vùng khoét), `KeepOriginals=false`: khoét toàn bộ vùng chức năng trong mặt phẳng anten.
8. `Vivaldi_1` — `SheetThicken` ID **5758**, `Thickness='thickness'`, **`BothSides=true`**: tăng thành vật thể kim loại 3D dày **2 mm**, phân bố khoảng **Y=−1..+1 mm**.

### Pha D — Tạo phân cực trực giao, khối nối và đế

9. `Vivaldi_1` — `DuplicateAroundAxis` (CloneTo ID **5845**): `WhichAxis='Z'`, `AngleStr='−90deg'`, `NumClones=2`, **CS `RelativeCS1`**, tạo `Vivaldi_2` (CloneFrom ID **5997**).
10. `Vivaldi_2` — `Move` ID **6085**: dịch theo trục Y của `RelativeCS1` một lượng `thickness` (**+2 mm**).
11. `Box1` — `Box` ID **6097**, CS `RelativeCS1`: `(XPosition,YPosition,ZPosition)=(0,0,0)`, `XSize=thickness`, `YSize=thickness`, `ZSize=−L_patch`. Biên global **X=10..12**, **Y=−1..1**, **Z=−2.836303..46.4**.
12. `De` — `Box` ID **6125**, CS Global: `XPosition=(de_L+thickness)/2`=12; `YPosition=−(de_W−aperture_w)/2`=−1; `ZPosition=z_feed−h3_slot_feed−slot_feed_w`≈−0.836303; kích thước `XSize=−22`, `YSize=+22`, `ZSize=−2`. Biên global **X=−10..12**, **Y=−1..21**, **Z=−2.836303..−0.836303**.
13. `Vivaldi_1` — **`Unite` ID 5846**, `KeepOriginals=false`, `ToolParts(5998,6098,6126)`: ghép **`Vivaldi_2` + `Box1` + `De`** vào **một thân nhôm `Vivaldi_1`**. Đây là thao tác ghép dual-pol hoàn chỉnh.

**Đối chiếu tọa độ arm thứ hai từ biến đổi cứng:** Sau khi xoay −90° và dịch +2 mm, tấm thứ hai có biên **X=10..12**, **Y=1..21**, **Z=−2.836303..46.4**; nó vuông góc với tấm đầu, tiếp xúc với `Box1`, và hai tấm cùng khối nối hợp thành phần tử dual-pol. Bản thứ hai **không xuất hiện top-level** vì đã Unite.

### Pha E — Cáp đồng trục, port và khoét cuối

14. `cable_in` — Cylinder ID **5689**, CS `slot_feed_td`:
    `XCenter=−positionx+slot_feed_w+h2`, `YCenter=0`, `ZCenter=−h3_slot_feed`, `Radius=r_cabin=0.15`, `Height=−h_cabin=−2.5`, trục Z; vật liệu **copper**.
15. `cable_out` — Cylinder ID **5700**, cùng CS: `XCenter=−positionx+h2+slot_feed_w`, `ZCenter=−h3_slot_feed−slot_feed_w`, `Radius=r_cabout=0.5`, `Height=−h_cabout=−2`; vật liệu **copper**. `Substract` ID **5711** bằng Cylinder `cable_mid` bán kính **0.35 mm** tạo **ống dẫn ngoài rỗng**.
16. `port1` — Circle ID **5717** + CoverLines ID **5721**: bán kính **0.35 mm**, tâm trên mặt phẳng **Z=z_feed−h3_slot_feed−h_cabin≈−2.836303 mm**; vật liệu đối tượng port là vacuum, được gán Lumped Port qua BoundarySetup.
17. Các đối tượng `cable_in_1`, `cable_out_1`, `port2` và operand `cable_mid_1` là những bản **DuplicateAroundAxis −90°** theo `RelativeCS1`, rồi dịch **+thickness** theo Y (đối với `cable_mid_1`, file lưu trị số trực tiếp `2mm`). Tâm port2 suy ra khoảng **(X,Y,Z)=(11,10.549331,−2.836303) mm**. Tâm port1 khoảng **(0.450669,0,−2.836303) mm**.
18. Tạo 6 bản sao cutter: hai `cable_in`, hai `cable_mid`, hai `cable_out` (OperandParts tương ứng `cable_in_2`, `cable_in_1_1`, `cable_mid_2`, `cable_mid_1_1`, `cable_out_2`, `cable_out_1_1`).
19. `Vivaldi_1` — **`Substract` ID 5858**: `NumToolParts=6`, tool IDs `6154,6163,6172,6181,6190,6199`, **`KeepOriginals=true`**, khoét vị trí coax trên thân nhôm đã Unite mà vẫn giữ các thành phần coax hoạt động. Đây là Boolean **không được bỏ qua** trong mô hình hoàn chỉnh.

**Trình tự trên là thứ tự phụ thuộc để tái dựng hình học.** Các Cylinder có ID lịch sử thấp hơn một số thao tác dựng kim loại, vì vậy không được lấy sắp xếp số ID làm nhật ký thời gian tuyệt đối.

## 5. Bảng quy chiếu hình học 3D ở trạng thái chuẩn

| Thành phần | X global (mm) | Y global (mm) | Z global (mm) |
|---|---:|---:|---:|
| Tấm thứ nhất sau thicken (bao kích thước) | −10..10 | −1..1 | −2.836303..46.4 |
| Tấm thứ hai sau Rotate/Move (bao kích thước) | 10..12 | 1..21 | −2.836303..46.4 |
| Trụ nối vuông `Box1` | 10..12 | −1..1 | −2.836303..46.4 |
| Đế `De` | −10..12 | −1..21 | −2.836303..−0.836303 |
| Tâm coax 1 | 0.450669 | 0 | trục Z, cao độ đáy −2.836303 |
| Tâm coax 2 | 11 | 10.549331 | trục Z, cao độ đáy −2.836303 |

Các miền của hai tấm nêu trên là **bounding boxes trước khi xét phần khoét**, không phải mô tả diện tích kim loại còn lại. Mô hình tổng thể danh nghĩa rộng **22 × 22 mm** theo X/Y và cao **49.236303 mm** theo Z.

## 6. Vật liệu, port, radiation, setup

- `Vivaldi_1` sau Unite: **aluminum**, `SolveInside=false`.
- `cable_in`, `cable_out` cùng cáp bản sao: **copper**, `SolveInside=false`.
- `port1`, `port2`, `RadiatingSurface`: **vacuum** (với port là sheet kích thích).
- `cable_mid` và bản sao là **operand hình trụ dùng để Subtract**, không phải một solid điện môi hữu hình được gán loại FR4/PTFE trong danh sách top-level. **Không tự mô phỏng lớp dielectric coax như đã có sẵn** nếu chưa bổ sung và kiểm tra.
- `Open1`: `BoundType=Radiation` trên đối tượng `RadiatingSurface`, Region padding **20 mm mỗi hướng**.
- Boundary `1` và `2`: `BoundType='Lumped Port'`, `Impedance='50ohm'`, 1 mode, **integration line gắn vào geometry edge IDs**. Khi rebuild phải xác minh lại cả **hướng đường tích phân**, không chỉ tên và bán kính port.
- Sources: **Port1=1 W ∠0°**, **Port2=0 W ∠0°** trong cấu hình đang lưu.
- `Setup1`: **Driven Modal**, adaptive **5 GHz**, `MaxDeltaS=0.02`, minimum 5 passes, max 50 passes.
- Sweep `Setup1`: **5–20 GHz**, **Discrete 0.25 GHz**, lưu trường.
- Far-field setup có `3D`, `Elevation`, `Azimuth`; lựa chọn array hiện thời **`UseOption='NoArray'`**.
- `scan_theta=0deg`, `scan_phi=0deg` ở biến thiết kế; các giá trị scan 45° nằm trong các thiết lập array/parametric lưu sẵn **không đồng nghĩa đang kích hoạt array**.
- Có **6 Optimetrics ParametricSetup** lưu sẵn, quét các biến `scan_theta`, `positionx`, `cavity_w/cavity_L`, `L_flare_1`, `them`, `h2`. Không tùy ý chạy tất cả trong chế độ thiết kế một phần tử.
- ProjectPreview ghi `IsSolved=true` cho design chính, nhưng **bản tải lên chỉ có file `.aedt`, không có bộ `.aedtresults` đi kèm**. Không thể khẳng định có thể lấy ngay số đo S11, S21, gain, axial ratio từ các cached plot definitions.

## 7. Các điểm ràng buộc bắt buộc khi tạo tool MATLAB (chưa phải prompt)

1. Phải chọn đúng design `dual_pol_vivaldi_patch_Wflare_20`, tránh design rỗng `HFSSDesign1`.
2. Giữ phân biệt **hai equation surfaces**: một loe dài, một loe ngắn, cùng **bản sao trước xoay** dùng làm cutter.
3. Xoay loe ngắn quanh **`slot_t_td`**, ghép **ba Rectangle** theo hệ **`slot_feed_td`** trước khi subtract tấm.
4. Dựng `Vivaldi_1` sheet trong **`patch_td`**, Subtract vùng khoét đã Unite, rồi mới `SheetThicken(BothSides=true)`.
5. Duplicating phân cực thứ hai phải xoay **−90° quanh trục Z của `RelativeCS1`** và Move **+thickness theo Y**; không xoay quanh Global.
6. Ghép **`Vivaldi_1`, `Vivaldi_2`, `Box1`, `De`** thành một solid nhôm rồi **Subtract 6 tool coax** (KeepOriginals=true).
7. Dựng đúng ống ngoài rỗng và lõi trong đồng thời giữ đúng cả hai port, integration lines, nguồn, boundary.
8. Khi thay biến chiều dài/độ mở/hốc, phải cập nhật mọi hệ tọa độ, vị trí rectangle/coax/đế theo công thức phụ thuộc; không kéo giãn một hình vẽ rời rạc.
9. Với file nguồn được thay đổi, luôn **Save As**, Validate và kiểm tra Boolean/port trước khi chạy mô phỏng.
10. GUI offline có thể dựng **preview dựa trên công thức** nhưng không được quảng cáo là tái tạo CAD HFSS chính xác nếu chưa rebuild được thật qua API.

## 8. Giới hạn xác minh và các bước kiểm tra còn lại

**Đã kiểm tra từ tệp:** tham số, các tên đối tượng/ID thao tác, thứ tự phụ thuộc, tọa độ đại số và số học, tên/material của top-level parts, các port, boundary, source, các thiết lập phân tích.

**Chưa thể xác minh chỉ bằng đọc `.aedt`:** toàn bộ Boolean có thực thi lại thành công khi cập nhật hàng loạt biến hay không; tiếp xúc vật lý/điện và lỗi giao hình tại các trường hợp biên; đúng hướng integration line sau thao tác rebuild; kết quả S11/S21/Gain; xuất CAD chế tạo thực tế. Để xác minh các điều này cần mở file trong ANSYS HFSS 2021 R2, `Validate`, sửa nếu cần và chạy nghiệm trong thư mục kết quả tương ứng.

**Nhận định:** File ngày 17/10 là nguồn chuẩn hợp lý cho **hình học dual-pol hoàn chỉnh**. Không được sử dụng thông số `L_flare_1=90 mm` của file 16/10 khi tái tạo phiên bản ngày 17/10.
