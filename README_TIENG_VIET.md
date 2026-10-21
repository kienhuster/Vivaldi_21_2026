# Vivaldi Dual-Pol — MATLAB → VBScript → HFSS 2021 R2

Công cụ dựng **một phần tử hai phân cực trực giao**, lấy `17_10_2026_vivaldi.aedt` làm chuẩn. Không phải mảng anten; không dùng COM trực tiếp từ MATLAB. Mỗi lần dựng sinh một project mới; solver chỉ chạy khi người dùng bấm **Chạy mô phỏng**.

**Trạng thái nghiệm thu:** đã triển khai và chạy kiểm thử lõi bằng Octave, đã kiểm tra cú pháp MATLAB. **Chưa chạy MATLAB desktop hoặc HFSS thật** trong môi trường phát triển này. Các chuỗi API, quy tắc đặt tên bản sao và hành vi CAD trên HFSS 2021 R2 còn cần kiểm chứng thực tế. Chưa thể cam kết CAD/Boolean/port đạt nghiệm thu chỉ từ các kiểm thử này.

## Yêu cầu và cách chạy

- Windows, MATLAB **R2021a trở lên**, ANSYS Electronics Desktop **2021 R2** và giấy phép HFSS hợp lệ.
- Không cần toolbox MATLAB ngoài các chức năng GUI, polyshape và đọc bảng chuẩn. Octave chỉ dùng cho smoke test lõi, **không chạy GUI này**.
- Bốn tệp tham chiếu ở gốc được giữ nguyên. Thư viện trong ZIP đã được giải nén vào `third_party/hfss-api`, 89 tệp giữ nguyên byte, có `COPYING` của upstream (GPL, xem tệp đó).

```matlab
addpath('D:\duong_dan\Vivaldi_21_2026'); % thay bằng checkout của bạn
Vivaldi_GUI
```

Không cần Current Folder trùng thư mục repository. Không tạo project khi chỉ mở GUI.

| Tệp | Trách nhiệm |
|---|---|
| `Vivaldi_GUI.m` | Năm tab tiếng Việt, vật liệu, preview và nhật ký |
| `Vivaldi_Calculation.m` | 19 đầu vào, công thức, CS, biến đổi, giới hạn giải tích |
| `Vivaldi_HFSS_Builder.m` | Nạp API, sinh VBS, dựng CAD, Validate, Save, khởi chạy HFSS |
| `Vivaldi_HFSS_Simulation.m` | Port, nguồn, Region, setup, sweep, solver và CSV |
| `tests/` | Kiểm thử MATLAB, smoke lõi, kiểm tra nguồn, probe HFSS |
| `outputs/` | Script, manifest, log, AEDT, CSV sinh ra; được Git bỏ qua |

## Thao tác trong GUI

1. **Thông số anten:** nhập 19 số thực theo đơn vị hiển thị. Bấm **Tính toán / Xem trước** để cập nhật biến dẫn xuất. Cấu hình mặc định dùng `L_flare_1=40 mm`, không dùng bản ngày 16/10. Các biến `lamda`, `scan_phi`, `scan_theta`, `c2` được giữ; không tạo mảng quét.
2. **Thư viện:** cửa sổ riêng có tìm kiếm không phân biệt hoa/thường, chọn dòng rồi **OK**, **Cancel**, **Add Material...**. Aluminum mặc định (σ=3.8e7 S/m, μr=1.000021); coax Copper. Điện môi được hiển thị để tham khảo nhưng bị từ chối cho thân kim loại. Vật liệu thêm được lưu vào `fullfile(prefdir,'Vivaldi_DualPol_custom_materials.mat')`. Lỗi nạp không xóa tệp người dùng. Vật liệu kim loại được tạo trong HFSS với tên nội bộ `VD_Body`, truyền đủ εr, μr, σ, tanδ; PEC được xử lý riêng.
3. **Xem trước 3D:** biên dạng lấy mẫu có flare, transition, cavity, hai tấm, khối nối, đế, coax và port. Dùng toolbar Rotate/Zoom/Pan. **Preview không xác nhận topology hay Boolean của CAD HFSS.**
4. **Tạo anten HFSS:** chọn `ansysedt.exe` và thư mục xuất. Tên cuối chứa ID duy nhất, được hiển thị sau khi sinh script. Tùy chọn **Chỉ sinh VBScript** không khởi chạy HFSS và không tạo AEDT. Bấm **Tạo anten HFSS** để chạy `/RunScriptAndExit`; MATLAB chờ HFSS hoàn tất. Có thể xem log trên đĩa trong lúc chờ. Bấm **Mở AEDT** để kiểm tra model đã lưu.
5. **Mô phỏng:** chỉnh dải tần, adaptive, Delta S, số passes, chế độ kích Port 1/Port 2/hai port, công suất và pha độc lập. Bấm **Chạy mô phỏng** sau khi dựng thành công. Nếu thay hình học/vật liệu, phải dựng lại. Hai nguồn cùng pha hoặc lệch 90° không tự chứng minh phân cực tròn.
6. Chọn loại đồ thị hoặc **Đọc thư mục CSV** để đọc dữ liệu HFSS thực. Không sinh dữ liệu solver mẫu. Mỗi lần mô phỏng SaveAs sang project mới trong thư mục riêng, không ghi đè project dựng CAD.

Dải mặc định Discrete 5–20 GHz, bước 0.25 GHz (61 điểm), lưu fields và radiation fields; adaptive 5 GHz, Delta S 0.02, min 5 / max 50 passes. Bước quét phải chia hết dải. Không tự chạy Optimetrics.

## Chuỗi hình học được phát trong script

- `dual_pol_vivaldi_patch_Wflare_20`, DrivenModal; không sửa/mở project nguồn để dựng CAD.
- CS `slot_t_td`, `slot_feed_td`, `patch_td`; `RelativeCS1` có parent `patch_td`.
- Hai EquationBasedSurface chính xác; clone cutter ngắn, Subtract giữ tool rồi dọn tool; xoay transition quanh Y tại `slot_t_td`.
- Ba Rectangle normal Y với Width theo Z, Height theo X; Unite cutter rồi Subtract `Vivaldi_1`; thicken `BothSides=true`.
- DuplicateAroundAxis −90° tại `RelativeCS1`, hai bản tính cả gốc (`NumClones=2`), Move +thickness theo Y. Thêm Box1 và De, Unite thân kim loại.
- Hai lõi, hai vỏ rỗng, hai tool trung gian và port; duplicate cùng phép biến đổi. Tạo sáu cutter riêng, Subtract thân với KeepOriginals=true rồi dọn cutter/tool trung gian. Không thêm PTFE/substrate.
- Hai Lumped Ports tên `1`, `2`, 50 Ω; đường tích phân dùng tọa độ từ biên ngoài khe coax vào lõi và biến đổi cứng sang port2. **Hướng/thực thể tiếp xúc phải kiểm chứng trong HFSS**, không tái dùng Edge IDs cũ.
- Region `RadiatingSurface`, absolute padding 20 mm sáu hướng, boundary `Open1`; setup/sweep, nguồn 1 W / 0 W mặc định, ba sphere `3D`, `Elevation`, `Azimuth`. Không gọi Array Setup.
- Kiểm tra tồn tại đối tượng bằng `GetObjectIDByName`, gọi `ValidateDesign`, chỉ lưu AEDT đích sau khi kết quả Validate bằng 0. Marker hoàn tất chỉ ghi sau khi lưu thật.

Giới hạn giải tích từ chối kích thước không hữu hạn, bán kính sai thứ tự, feed/cavity vượt tấm, coax vượt tấm và một số suy biến. **Chúng là điều kiện cần; không thay thế kiểm tra giao hình/contact/topology trong HFSS.** Với mặc định, bao danh nghĩa X −10..12, Y −1..21, Z −2.836303290..46.4 mm.

## API và các bổ sung cục bộ

Builder kiểm tra tám thư mục tồn tại, rồi gọi trực tiếp:

```matlab
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'third_party','hfss-api','boundary'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','3dmodeler'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','analysis'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','general'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','radiation'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','reporter'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','mesh'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','fieldsCalculator'),'-begin');
```

`which()` xác minh các hàm quan trọng thuộc checkout này; xung đột dừng rõ ràng. Không gọi `restoredefaultpath`, `savepath`, `genpath`, hoặc tự sửa thư viện cũ.

Chữ ký upstream đã đọc và dùng (đối số `fid` đứng đầu nếu không ghi khác):

| Hàm | Các đối số còn lại |
|---|---|
| `hfssNewProject` | không có |
| `hfssInsertDesign` | designName, designType (`driven modal`) |
| `hfssSetVariable` | variable, value, units; truyền chuỗi đủ độ chính xác |
| `hfssSaveProject` | projectFile, Overwrite (`false`: không ghi đè) |
| `hfssExecuteScript` | **không có fid**: exe, script, iconMode=false, runAndExit=true |
| `hfssOpenProject`, `hfssSetDesign` | projectFile; designName |
| `hfssRectangle` | Name, Axis, Start, Width, Height, Units |
| `hfssBox` | Name, Start, Size, Units, Material, Solve |
| `hfssCircle` | Name, Axis, Center, Radius, Units, coverLines |
| `hfssCylinder` | Name, Axis, Center, Radius, Height, Units |
| `hfssSubtract` | blankParts, toolParts, Clone (`'true'`/`'false'`) |
| `hfssUnite` | cell danh sách đối tượng |
| `hfssRotate`, `hfssMove` | ObjectList, Axis, Degrees; ObjectList, tVector, Units |
| `hfssSetWCS`, `hfssRename` | Name; oldName, newName |
| `hfssAssignMaterial`, `hfssSetSolveInside` | Name, Material, warn=false; Object, flag |
| `hfssAssignLumpedPort` | Name, ObjName, iLStart, iLEnd, Units, Resistance, Reactance |
| `hfssAssignRadiation` | Name, BoxObject, UseIE=false |
| `hfssInsertSolution` | Name, fGHz, maxDeltaS, maxPass, minPass, minConvPass, MaxRef |
| `hfssSolveSetup` | SetupName |
| `hfssInsertFarFieldSphereSetup` | Name, Theta, Phi (bỏ WCS để dùng Global) |
| `hfssCreateReport` | ReportName, Type, Display, Solution, Sweep, Context, Domain, VarObj, DataObj |
| `hfssExportToFile` | ReportName, FileName không có đuôi, Type=`csv` |

Các local helper cần thiết: EquationSurface, CS có parent và biểu thức (API CS cũ làm tròn bốn chữ số), BothSides thicken (API cũ cố định false), Copy/Paste và DuplicateAroundAxis, Region absolute offset, định nghĩa vật liệu đầy đủ, Discrete sweep, excitation, family cố định cho far-field report, checkpoint và Unicode. Không có bộ API thay thế riêng.

Adapter `api` gọi hàm gốc vào tệp tạm rồi sửa **đầu ra**: PartCoordinateSystem theo CS đang dùng, khôi phục số gốc 17 chữ số thay `%f`, và tên report đời cũ `Modal S Parameter` → `Modal Solution Data`. Nếu hai giá trị khác nhau bị làm tròn trùng, dừng thay vì đoán. Thư viện vendor không bị sửa. ProgID cũ được đổi trong script sang `Ansoft.ElectronicsDesktop.2021.2`; cần kiểm tra đăng ký trên máy Windows đích.

VBS cuối là ASCII không BOM, xuống dòng LF; literal Unicode thành các đoạn ASCII ghép `ChrW` UTF-16. Đường dẫn thực thi Windows chứa dấu ngoặc kép, `%`, `!`, xuống dòng bị từ chối để tránh Windows shell diễn giải sai.

## Kết quả và nhật ký

Các CSV bắt buộc: `SParameters` (S11/S22/S21/S12 dB), `VSWR` hai port, `Impedance` Re/Im của Z11/Z22, `GainFrequency` (realized gain tại theta=0°, phi=0°, **không phải peak gain**), `Elevation`, `Azimuth`, `Pattern3D`. Hai lát cắt và pattern 3D dùng tần số đầu dải đã giải. Axial Ratio cùng hướng 0°/0° được thử xuất như chỉ tiêu tùy chọn; nếu không có quantity, ghi `OPTIONAL_FAILED`, không giả dữ liệu. Efficiency, HPBW, sidelobe và F/B chưa có bộ hậu xử lý tự động.

Mỗi run có `.vbs`, `.log`, manifest `.mat`, AEDT và marker riêng. `BUILD_01` đến `BUILD_18` chỉ ghi `OK_COMMAND` **sau lời gọi thực**, không đồng nghĩa kiểm tra topology PASS. Hàm `Check` trả false khiến `Main` thoát ngay; không tiếp tục dựng sau lỗi. Lỗi có stage, mã COM, mô tả. Debug SaveAs tách riêng `DEBUG_INCOMPLETE`, không được coi là anten hoàn chỉnh. Nếu solver/CSV bắt buộc lỗi, không ghi marker hoàn tất; CSV xuất thành công trước đó vẫn có thể đọc riêng.

Chỉ thấy EquationSurface1: xem checkpoint lỗi đầu tiên trong `build.log`; không coi đây là anten hoàn chỉnh. Lỗi 800a0408: kiểm tra script ASCII không BOM và ProgID. Lỗi 450 khi truy vấn Sheets: dùng probe bên dưới; Builder chính không phụ thuộc truy vấn đó. Thiếu giấy phép/không thấy executable: cấu hình máy Windows, không nhập giấy phép vào mã nguồn. Không có CSV: kiểm tra solver, sweep, save fields và log từng report; project nguồn không chứa `.aedtresults`.

## Kiểm thử và bước nghiệm thu còn lại

Đã chạy trong cloud:

- **PASS:** 31 assertion smoke lõi bằng Octave 9.4.0: số mặc định, ba bộ thập phân, biến đổi/feed, input sai, vật liệu mặc định, 61 điểm quét, sinh build/solve VBS, CS, độ chính xác, ASCII/Unicode và chuẩn hóa CRLF. Đây không phải thử MATLAB GUI hay HFSS. Fixture mô phỏng trong smoke là tệp thử tạm, không phải AEDT nghiệm.
- **PASS:** MISS_HIT kiểm tra cú pháp/lint cả bốn tệp chính và ba tệp kiểm thử MATLAB.
- **PASS:** Python xác minh bốn nguồn nguyên vẹn, 89 tệp vendor giống ZIP, kiểm tra kiến trúc và ngoặc/encoding script sinh ra. Kiểm tra chuỗi không xác nhận CAD.
- **PENDING:** bộ `matlab.unittest`, GUI/preview và thao tác cửa sổ vật liệu trên MATLAB R2021a.
- **PENDING:** chạy VBScript trong HFSS 2021 R2, các Boolean/thicken/duplicate/coax, integration lines/contact, ValidateDesign, Save thật, solver, CSV và đồ thị từ nghiệm thật.

Trên MATLAB:

```matlab
results = runtests('tests/test_Vivaldi.m');
assertSuccess(results);
run('tests/smoke_core.m');
```

Probe riêng cho HFSS (thêm đường dẫn tests):

```matlab
addpath(fullfile(fileparts(which('Vivaldi_GUI')),'tests'));
job = hfss_probe('D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe',tempdir);
```

Probe tạo project mới, Rectangle, lưu thử, EquationSurface, truy vấn SAFEARRAY bằng gán thường **không Set**, rồi lưu AEDT thử. Có thể truyền `''` cho exe để chỉ sinh script. Không chạy solver, không tuyên bố một probe là CAD anten đạt chuẩn.

Sau probe, dựng mặc định và ít nhất ba bộ kích thước thập phân. Trong HFSS, kiểm tra lỗ flare/cavity, hai mép kim loại, BothSides/độ dày thực, phép xoay/dịch, Box1/đế kết nối, vỏ coax rỗng và contact, số lượng đối tượng, hai port 50 Ω và hướng line; gọi Validate. Chỉ sau đó mới chạy solver và đối chiếu các CSV. Giữ nguyên bốn nguồn tham chiếu, không tự merge PR.
