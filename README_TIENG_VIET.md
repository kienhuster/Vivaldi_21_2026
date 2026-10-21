# Vivaldi Dual-Polarized — MATLAB và HFSS 2021 R2

Ứng dụng mới dựng **một phần tử hai phân cực** theo lịch sử CAD của
`17_10_2026_vivaldi.aedt`, design `dual_pol_vivaldi_patch_Wflare_20`.
Không sửa hoặc sao chép project nguồn để coi là dựng mới; không dùng MATLAB COM.

**Trạng thái nghiệm thu:** đã kiểm tra logic ngoại tuyến và sinh script.
MATLAB GUI, CAD kernel/Boolean, hướng integration line, ValidateDesign và solver
HFSS thật vẫn **PENDING**. Chưa có AEDT đầu ra hay kết quả điện từ được kiểm chứng.
Thông báo này áp dụng cả khi các kiểm thử ngoại tuyến đều qua.

## Chạy trên Windows

Cần MATLAB **R2021a trở lên**, desktop GUI và Ansys Electronics Desktop/HFSS
**2021 R2 (21.2)** có license hoạt động. Linux/Octave chỉ dùng để kiểm tra logic;
không thay thế HFSS hoặc MATLAB GUI. Không cần toolbox RF/Antenna.

1. Tải checkout đầy đủ, gồm `third_party/hfss-api`.
2. Trong MATLAB, thêm thư mục repository vào Path, rồi chạy:

   ```matlab
   addpath('D:\duong-dan-thuc-te\Vivaldi_21_2026');
   Vivaldi_GUI
   ```

3. Tab **Thông số anten**: nhập 19 biến (mm/độ), xem các biến dẫn xuất.
   Không làm tròn giá trị trước CAD. Khôi phục mặc định để về cấu hình 17/10.
   Miền transition hiện hỗ trợ `0 <= deg_slot_t < 90`; tham số làm cutter vượt
   biên, coax vượt đế/tấm hoặc hình học suy biến bị từ chối. Đây là kiểm tra
   giải tích bảo thủ; Boolean thật vẫn phải được HFSS kiểm tra.
4. **Thư viện** mở cửa sổ riêng, tìm theo tên không phân biệt hoa/thường.
   Chọn một dòng rồi OK; Cancel giữ lựa chọn trước. Add Material hỗ trợ metal,
   dielectric, PEC; không dùng điện môi làm thân kim loại. Vật liệu mới lưu tại
   `fullfile(prefdir,'Vivaldi_DualPol','custom_materials.mat')` và tồn tại qua phiên.
   Thân mặc định Aluminum (σ=3.8e7, μr=1.000021); coax vẫn copper.
5. Tab **Xem trước 3D** dùng polyshape từ các phương trình đang nhập, có khoét
   flare/transition/cavity, hai tấm, đế, coax và port. Rotate/Zoom/Pan bằng toolbar.
   Đây là preview MATLAB, **không phải CAD HFSS đã kiểm chứng**.
6. Tab **Tạo anten HFSS**: chọn `ansysedt.exe`, chọn thư mục xuất có quyền ghi.
   Có thể **Chỉ sinh VBScript** để xem trước mà không mở HFSS.
   **TẠO ANTEN HFSS** luôn sinh project/thư mục mới, dựng, kiểm tra và SaveAs
   với `overwrite=false`. Nút này **không chạy solver**.
7. Tab **Mô phỏng**: sau BUILD_COMPLETE, chỉnh sweep/adaptive/passes, công suất
   và pha độc lập. Pattern (GHz) phải trùng một điểm sweep. Mặc định port1=1W,
   port2=0W; các nút nguồn cho phép đổi sang port2 hoặc hai port.
   Lệch pha 90° không tự chứng minh phân cực tròn.
8. **Chạy mô phỏng** làm việc trên bản sao AEDT trong thư mục lượt chạy mới,
   không sửa file CAD đã dựng. Sau solver, đọc CSV thực để vẽ S11/S22/S21/S12,
   VSWR, phần thực/ảo ma trận Z11/Z22, realized gain, Elevation, Azimuth,
   pattern 3D và axial ratio nếu HFSS xuất được. Z11/Z22 là trở kháng ma trận,
   không gắn nhãn là Zin với cổng còn lại được tải 50Ω.

Không có kết quả mẫu trong ứng dụng. Gain theo tần số được lấy tại
**theta=90°, phi=0°**, không gọi là peak gain. Pattern dùng tần số do người dùng
chọn. Chưa triển khai tự tính efficiency/HPBW/sidelobe/front-to-back; không tạo
chỉ tiêu khi thiếu dữ liệu. Axial ratio là báo cáo tùy chọn: lỗi được ghi rõ,
không giả số liệu. CSV bắt buộc bị thiếu, sai cột hoặc thiếu điểm sweep sẽ bị từ chối.

## Cấu trúc và thư viện

```text
Vivaldi_GUI.m               GUI, preview, thư viện vật liệu và nhật ký
Vivaldi_Calculation.m       19 biến, công thức, tọa độ, kiểm tra đầu vào
Vivaldi_HFSS_Builder.m      VBScript CAD mới và kiểm tra runtime
Vivaldi_HFSS_Simulation.m   Setup/sweep/nguồn, solver, CSV và đồ thị
third_party/hfss-api/       thư viện gốc giải nén nguyên vẹn từ ZIP
  general/  3dmodeler/  boundary/  analysis/
  radiation/  reporter/  mesh/  fieldsCalculator/
tests/                     kiểm thử ngoại tuyến, GUI và probe HFSS
```

Bốn tệp nguồn tham chiếu được giữ nguyên byte. Thư viện lấy từ ZIP trong repo,
upstream [yuip/hfss-api](https://github.com/yuip/hfss-api), ZIP ghi commit
`a3fd32a418c726070f51e73273de93c5080bdb8d`. Không tải bản khác khi chạy.
Giữ COPYING/README/CHANGELOG gốc. Mã mới phân phối GPL-2.0-or-later phù hợp
với thư viện; xem LICENSE.

Builder tự nạp từng đường dẫn (root luôn theo vị trí file, không theo Current Folder):

```matlab
root = fileparts(which('Vivaldi_HFSS_Builder'));
addpath(fullfile(root,'third_party','hfss-api','boundary'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','3dmodeler'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','analysis'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','general'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','radiation'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','reporter'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','mesh'),'-begin');
addpath(fullfile(root,'third_party','hfss-api','fieldsCalculator'),'-begin');
which hfssNewProject
which hfssRectangle
which hfssSubtract
which hfssUnite
which hfssExecuteScript
```

`which` được kiểm tra cho toàn bộ hàm dùng. Không gọi `restoredefaultpath`,
`savepath`, `genpath` hoặc `hfssIncludePaths`.

## Chuỗi CAD và nhật ký

`BUILD_01`–`BUILD_18` lần lượt thực hiện: project DrivenModal, biến,
4 CS (RelativeCS1 có parent patch_td), hai EquationBasedSurface,
clone trước xoay, subtract đoạn ngắn, xoay transition quanh slot_t_td,
3 rectangle trong slot_feed_td, unite cutter, subtract tấm, thicken BothSides,
duplicate -90° quanh Z của RelativeCS1 + move thickness, Box1/De,
unite thân, hai coax có ống ngoài rỗng, subtract **6 bản sao cutter** với
KeepOriginals=true rồi dọn cutter, hai port 50Ω, region offset tuyệt đối 20mm,
Open1, Setup1, Discrete sweep và far-field, ValidateDesign, SaveAs.

Port integration line dùng tọa độ global **từ mặt trong vỏ tới mặt ngoài lõi**,
port2 là ảnh biến đổi cứng của port1; không tái dùng Edge IDs. Hướng này vẫn cần
nghiệm thu trong HFSS. Không thêm điện môi coax hay Array Setup.

Các checkpoint `API_COMPLETED` chỉ được ghi sau khi lời gọi không lỗi.
Script kiểm tra điểm rỗng trong khe, hai mép tấm, chiều dày, bản sao trực giao,
thân sau unite, khoét coax và lõi/vỏ, inventory cuối đúng **8 đối tượng**,
`ValidateDesign(...) == 1`, và AEDT đã tồn tại trước BUILD_COMPLETE.
Kiểm tra điểm không chứng minh toàn bộ topology; vẫn cần xem mặt cắt CAD thực.

Mỗi lượt có `.vbs`, `build_inputs.mat`, `build.log`, `validation.log`,
`launcher.log`, AEDT riêng. Lỗi dừng Main ngay, ghi checkpoint và Err.Number/
Description; có thể lưu `Vivaldi_DEBUG_INCOMPLETE_*.aedt`, không coi là thành công.
Log runtime UTF-16; VBScript **ASCII không BOM**, đường dẫn Unicode được biểu diễn
bằng `ChrW`, không thay ký tự bằng `?`. HFSS chạy `/RunScriptAndExit`; hãy lưu
các phiên HFSS khác trước khi chạy vì cách quản lý instance phụ thuộc cài đặt Ansys.
Tên file do thư mục duy nhất và thời gian tạo quyết định; không ghi đè kết quả trước.

## Chữ ký API dùng và các bổ sung cục bộ

| Hàm gốc | Tham số sau `fid` |
|---|---|
| hfssNewProject | không có |
| hfssInsertDesign | designName, designType |
| hfssSetVariable | variable, value, units |
| hfssCreateRelativeCS | Name, Origin, Units |
| hfssSetWCS | Name |
| hfssRectangle | Name, Axis, Start, Width, Height, Units |
| hfssBox | Name, Start, Size, Units, Material, Solve |
| hfssCircle | Name, Axis, Center, Radius, Units, coverLines |
| hfssCylinder | Name, Axis, Center, Radius, Height, Units |
| hfssRotate / hfssMove | ObjectList, Axis, Degrees / ObjectList, tVector, Units |
| hfssSubtract | blankParts, toolParts, Clone (`'true'`/`'false'`) |
| hfssUnite | cell danh sách đối tượng |
| hfssRename | oldName, newName |
| hfssAssignMaterial / hfssSetSolveInside | Name, Material, warn / Object, flag |
| hfssAssignLumpedPort | Name, ObjName, iLStart, iLEnd, Units, Resistance, Reactance |
| hfssAssignRadiation | Name, BoxObject, UseIE |
| hfssInsertSolution | Name, fGHz, maxDeltaS, maxPass, minPass, minConvPass, MaxRef |
| hfssInsertFarFieldSphereSetup | Name, Theta, Phi, WCS |
| hfssSaveProject | projectFile, Overwrite (`false`, không ghi đè) |
| hfssOpenProject / hfssSetDesign | projectFile / designName |
| hfssSolveSetup | SetupName (xuất `oDesign.Solve Array(...)`) |
| hfssCreateReport | ReportName, Type, Display, Solution, Sweep, Context, Domain, VarObj, DataObj |
| hfssExportToFile | ReportName, FileName (chưa có đuôi), Type |

`hfssExecuteScript(exe,script,false,true)` không có fid; truyền đủ cả hai tùy chọn.
Đường dẫn chạy bị từ chối nếu có ký tự cmd.exe có thể bị diễn giải (`% ! & | < > ^ "`).

Helper tự viết đều là local functions, không có custom_helpers/framework mới:
EquationBasedSurface, DuplicateAroundAxis, Copy/Paste + tìm tên thực bằng inventory
trước/sau, xóa cutter, thicken BothSides, Region, vật liệu mới, Discrete sweep,
nguồn, log/guard/kiểm tra điểm và mã hóa Unicode. API gốc thiếu biểu thức tham số,
ép PartCoordinateSystem về Global và làm tròn `%f`/`%.4f`: helper `api` lấy output
của hàm gốc rồi thay đúng literal bằng biểu thức/CS hoặc tọa độ đủ chính xác.
Không sửa thư viện. Tương tự reporter sửa tên category cũ thành Modal Solution Data
và cho phép fixed families, thay vì viết lại bộ report API.

## Kiểm thử và xử lý lỗi

Từ thư mục repository:

```matlab
addpath(fullfile(pwd,'tests'));
test_vivaldi          % logic/sinh script; chạy được bằng Octave 9.4
% Chỉ trên MATLAB desktop thật:
test_gui             % mở GUI, 5 tab, tham số, tìm vật liệu và Cancel
% Chỉ trên Windows có license HFSS:
r = hfss_probe('D:\duong-dan-thuc-te\ansysedt.exe',fullfile(pwd,'outputs'),true);
```

Probe tạo project riêng, Rectangle và EquationSurface, truy vấn Sheets SAFEARRAY,
kiểm tra điểm và SaveAs. Nếu lỗi 450 ở GetObjectsInGroup, xem `probe.log` trước;
không dùng `Set` để nhận SAFEARRAY. Không đánh dấu CAD PASS nếu probe thất bại.

Sau probe, dựng cấu hình mặc định bằng GUI và ít nhất hai bộ thập phân, ví dụ
`L_flare_1=42.125, aperture_w=22.75, them=0.375` và
`h2=2.775, cavity_L=4.125, deg_slot_t=17.25, thickness=2.25`.
Kiểm tra mặt cắt khe/cavity, hai tấm vuông góc, tiếp xúc đế/Box1,
lõi/vỏ không giao kim loại sai, hai port và hướng tích phân trước khi solver.
Mặc định bao danh nghĩa 22×22×49.236303290mm.

Đã chạy trong cloud: **11 nhóm test_vivaldi PASS**, **5 kiểm tra Python PASS**
(gồm script đã sinh), MISS_HIT với cú pháp MATLAB 2021a **PASS**.
Các fixture kiểm tra sinh script chỉ nằm trong thư mục tạm của test,
được ghi rõ không phải AEDT/kết quả thật và bị dọn sau test.

**PENDING:** GUI/preview trên MATLAB thật, probe và toàn bộ CAD trên HFSS 2021 R2,
CSV/đồ thị từ solver thật, tương thích launcher/license/Unicode trên Windows.
Không có `.aedtresults` nguồn, không đọc cached definitions thành kết quả.

Kiểm tra repository độc lập, Python stdlib:

```bash
python3 tests/check_repository.py
# Thêm thư mục chứa các script builder/simulation/probe đã sinh để kiểm tra lexical:
python3 tests/check_repository.py /duong/dan/thu-muc-script
```

- Lỗi Path: xem `which`, bỏ bản API cũ đang shadow hoặc `clear` hàm đó rồi thử lại;
  không reset toàn bộ Path.
- Lỗi CAD: xem BUILD_xx cuối, Err.Number và file debug/validation. Không dùng bản
  debug làm anten hoàn chỉnh.
- Lỗi license/executable: kiểm tra Ansys cài đặt và license hợp lệ; không nhập
  khóa license vào chat hoặc commit.
- Lỗi encoding: kiểm tra script không BOM, chạy probe ở thư mục đơn giản trước.
- Solver không có CSV: xem SIM_xx; ứng dụng không hiển thị số giả để che lỗi.
