function Standard_Vivaldi_GUI()
    % =====================================================================
    % CHƯƠNG TRÌNH TỰ ĐỘNG HÓA THIẾT KẾ ANTEN VIVALDI (HFSS-MATLAB API)
    % CƠ SỞ LÝ THUYẾT: BALANIS ANTENNA THEORY STANDARD
    % TÁC GIẢ: Nguyễn Trung Kiên
    % CẬP NHẬT: Tích hợp Module Thư viện Vật liệu (Có tính năng Tìm kiếm)
    % =====================================================================
    
    lblStatus = []; 
    
    % --- BIẾN ẨN LƯU TRỮ TRẠNG THÁI NỀN (HIDDEN VARIABLES) ---
    % Mặc định sử dụng vật liệu FR4_epoxy khi khởi động chương trình
    current_eps_r = 4.4;   
    current_loss = 0.02;   
    
    % --- CƠ SỞ DỮ LIỆU VẬT LIỆU MẶC ĐỊNH (MATERIAL DATABASE) ---
    % Cấu trúc: {Tên vật liệu, Hằng số điện môi (eps_r), Tiếp tuyến góc tổn hao (tan_delta)}
    matDatabase = {
        'FR4_epoxy', 4.4, 0.0200;
        'Rogers RO4350 (tm)', 3.48, 0.0037;
        'Rogers RT/duroid 5880 (tm)', 2.2, 0.0009;
        'Arlon AD250', 2.5, 0.0018;
        'Taconic TLC-30', 3.0, 0.0030;
        'Teflon (PTFE)', 2.1, 0.0002;
        'Glass', 5.5, 0.0000;
        'Vacuum', 1.0, 0.0000
    };

    % =====================================================================
    % PHÂN HỆ 1: XÂY DỰNG GIAO DIỆN NGƯỜI DÙNG (FRONT-END GUI)
    % =====================================================================
    fig = uifigure('Name', 'Vivaldi Antenna (Balanis Standard) - Nguyễn Trung Kiên', 'Position', [100 50 950 780]);
    pnl = uipanel(fig, 'Title', 'Tham số Hình học (Đơn vị: mm)', 'Position', [20 20 280 740]);
    
    % ---------------------------------------------------------------------
    % KHU VỰC 1: THIẾT LẬP THÔNG SỐ ĐẦU VÀO (INPUT PARAMETERS)
    % ---------------------------------------------------------------------
    uilabel(pnl, 'Position', [10 690 170 22], 'Text', 'Tần số tâm fc (GHz):', 'FontWeight', 'bold', 'FontColor', [0 0.45 0.74]);
    edtFc = uieditfield(pnl, 'numeric', 'Position', [180 690 90 22], 'Value', 4.0, 'ValueDisplayFormat', '%.1f');
    
    uilabel(pnl, 'Position', [10 655 170 22], 'Text', 'Tần số thấp nhất f_min(GHz):', 'FontWeight', 'bold', 'FontColor', [0.85 0.33 0.1]);
    edtFmin = uieditfield(pnl, 'numeric', 'Position', [180 655 90 22], 'Value', 2.0, 'ValueDisplayFormat', '%.1f');
    
    uilabel(pnl, 'Position', [10 620 90 22], 'Text', 'Vật liệu:', 'FontWeight', 'bold');
    edtMatName = uieditfield(pnl, 'text', 'Position', [65 620 125 22], 'Value', 'FR4_epoxy', 'Editable', 'off', 'FontWeight', 'bold', 'FontColor', [0.47 0.67 0.19]);
    uibutton(pnl, 'push', 'Text', 'Thư viện', 'Position', [195 620 75 22], 'BackgroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) openMatLibrary());
    
    uilabel(pnl, 'Position', [10 585 170 22], 'Text', 'Độ dày Substrate (h):');
    edth = uieditfield(pnl, 'numeric', 'Position', [180 585 90 22], 'Value', 1.6, 'ValueDisplayFormat', '%.3f'); 
    
    uilabel(pnl, 'Position', [10 550 170 22], 'Text', 'Chiều rộng đường khe (w_s):', 'FontWeight', 'bold');
    wsItems = {'0.1', '0.2', '0.3', '0.4', '0.5', '0.6', '0.7', '0.8', '0.9', '1.0'};
    ddlWs = uidropdown(pnl, 'Items', wsItems, 'Position', [180 550 90 22], 'Value', '0.1'); 
    
    % NÚT KÍCH HOẠT THUẬT TOÁN TÍNH TOÁN
    uibutton(pnl, 'push', 'Text', 'TÍNH TOÁN KÍCH THƯỚC', 'Position', [15 480 250 40], ...
        'BackgroundColor', [0 0.45 0.74], 'FontColor', 'w', 'FontWeight', 'bold', 'FontSize', 14, ...
        'ButtonPushedFcn', @(btn,event) autoCalculateBalanis());
    
    % ---------------------------------------------------------------------
    % KHU VỰC 2: HIỂN THỊ KẾT QUẢ GIẢI TÍCH TOÁN HỌC (OUTPUT PARAMETERS)
    % ---------------------------------------------------------------------
    uilabel(pnl, 'Position', [15 440 250 22], 'Text', '---------- KẾT QUẢ TÍNH TOÁN ----------', 'FontWeight', 'bold', 'FontColor', [0.4 0.4 0.4]);
    
    uilabel(pnl, 'Position', [10 405 170 22], 'Text', 'Chiều rộng khẩu độ (w_a):');
    edtwa = uieditfield(pnl, 'numeric', 'Position', [180 405 90 22], 'Editable', 'off', 'ValueDisplayFormat', '%.1f');
    uilabel(pnl, 'Position', [10 370 170 22], 'Text', 'Chiều dài loe (l_t):');
    edtlt = uieditfield(pnl, 'numeric', 'Position', [180 370 90 22], 'Editable', 'off', 'ValueDisplayFormat', '%.1f');
    uilabel(pnl, 'Position', [10 335 185 22], 'Text', 'Đường kính Hốc cộng hưởng (d):');
    edtd = uieditfield(pnl, 'numeric', 'Position', [195 335 75 22], 'ValueDisplayFormat', '%.1f');
    uilabel(pnl, 'Position', [10 292 185 35], 'Text', {'Khoảng cách từ hốc cộng', 'hưởng đến phần loe (s):'});
    edts = uieditfield(pnl, 'numeric', 'Position', [195 300 75 22], 'ValueDisplayFormat', '%.1f');
    uilabel(pnl, 'Position', [10 265 170 22], 'Text', 'Chiều dài lớp Substrate (l):', 'FontWeight', 'bold');
    edtl = uieditfield(pnl, 'numeric', 'Position', [180 265 90 22], 'Editable', 'off', 'FontWeight', 'bold', 'ValueDisplayFormat', '%.1f');
    uilabel(pnl, 'Position', [10 230 170 22], 'Text', 'Chiều rộng lớp Substrate(w):', 'FontWeight', 'bold', 'FontColor', 'r');
    edtw = uieditfield(pnl, 'numeric', 'Position', [180 230 90 22], 'Editable', 'off', 'FontWeight', 'bold', 'FontColor', 'r', 'ValueDisplayFormat', '%.1f');
    uilabel(pnl, 'Position', [10 195 170 22], 'Text', 'Hệ số Biên độ (A):', 'FontWeight', 'bold', 'FontColor', 'b');
    edtA = uieditfield(pnl, 'numeric', 'Position', [180 195 90 22], 'Editable', 'off', 'ValueDisplayFormat', '%.2f'); 
    uilabel(pnl, 'Position', [10 160 170 22], 'Text', 'Hằng số flare (p):', 'FontWeight', 'bold', 'FontColor', 'b');
    edtP = uieditfield(pnl, 'numeric', 'Position', [180 160 90 22], 'Editable', 'off', 'ValueDisplayFormat', '%.4f');
    
    % ---------------------------------------------------------------------
    % KHU VỰC 3: KHÔNG GIAN ĐỒ HỌA TRỰC QUAN & LOG TRẠNG THÁI (VISUALIZATION)
    % ---------------------------------------------------------------------
    tabgp = uitabgroup(fig, 'Position', [320 130 600 620]);
    tab0 = uitab(tabgp, 'Title', 'Cấu trúc anten');
    axImg = uiaxes(tab0, 'Position', [10 10 580 580]); axImg.XColor = 'none'; axImg.YColor = 'none'; 
    axtoolbar(axImg, {'zoomin', 'zoomout', 'pan', 'restore'});
    img_path = 'C:\hfss-api-master\examples\Vivaldi\Đồ án 1\Screenshot 2026-04-10 112851.png';
    if isfile(img_path), imshow(imread(img_path), 'Parent', axImg); else
        uilabel(tab0, 'Position', [150 280 300 22], 'Text', 'LỖI: Không tìm thấy file ảnh!', 'FontColor', 'r', 'FontWeight', 'bold');
    end
    
    tab1 = uitab(tabgp, 'Title', 'Đồ thị S11'); 
    axS11 = uiaxes(tab1, 'Position', [10 10 570 570]); grid(axS11, 'on'); xlabel(axS11, 'Freq (GHz)'); ylabel(axS11, 'S11 (dB)');
    tab2 = uitab(tabgp, 'Title', 'Đồ thị Trở kháng (Z)'); 
    axZ = uiaxes(tab2, 'Position', [10 10 570 570]); grid(axZ, 'on'); xlabel(axZ, 'Freq (GHz)'); ylabel(axZ, 'Impedance (\Omega)');
    
    lblStatus = uilabel(fig, 'Position', [320 20 600 80], 'Text', 'Sẵn sàng... Hãy thiết lập thông số rồi nhấn nút "TÍNH TOÁN KÍCH THƯỚC".', 'FontWeight', 'bold', 'WordWrap', 'on', 'FontColor', [0 0.5 0]);
    
    % NÚT KÍCH HOẠT GIAO TIẾP API HFSS
    uibutton(fig, 'push', 'Text', 'CHẠY MÔ PHỎNG HFSS', 'Position', [40 20 250 60], 'BackgroundColor', [0.85 0.33 0.1], 'FontColor', 'w', 'FontWeight', 'bold', 'FontSize', 14, 'ButtonPushedFcn', @(btn,event) runSimulation());
    
    % =====================================================================
    % PHÂN HỆ 2: MODULE QUẢN LÝ THƯ VIỆN VẬT LIỆU (MATERIAL MANAGER)
    % =====================================================================
    function openMatLibrary()
        dlg = uifigure('Name', 'Select Definition - Vật liệu', 'Position', [300 200 650 400], 'WindowStyle', 'modal');
        
        uilabel(dlg, 'Position', [20 360 200 22], 'Text', 'Tìm kiếm theo Tên (Search):', 'FontWeight', 'bold');
        
        % Chức năng lọc tìm kiếm vật liệu
        edtSearch = uieditfield(dlg, 'text', 'Position', [20 335 250 25], 'ValueChangedFcn', @(src, event) filterTable(src.Value));
        uibutton(dlg, 'push', 'Text', 'Tìm kiếm', 'Position', [280 335 80 25], 'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) filterTable(edtSearch.Value));
        
        tb = uitable(dlg, 'Position', [20 80 610 240], ...
                     'Data', matDatabase, ...
                     'ColumnName', {'Tên Vật liệu (Name)', 'Hằng số điện môi ', 'Tổn hao '}, ...
                     'ColumnWidth', {250, 150, 150}, ...
                     'RowName', [], 'SelectionType', 'row');
        
        uibutton(dlg, 'push', 'Text', 'Add Material...', 'Position', [20 20 120 30], 'ButtonPushedFcn', @(btn,event) addCustomMaterial());
        uibutton(dlg, 'push', 'Text', 'OK', 'Position', [430 20 90 30], 'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) selectAndClose());
        uibutton(dlg, 'push', 'Text', 'Cancel', 'Position', [540 20 90 30], 'ButtonPushedFcn', @(btn,event) close(dlg));
        
        function filterTable(searchTerm)
            if isempty(searchTerm)
                tb.Data = matDatabase; 
            else
                idx = contains(lower(matDatabase(:,1)), lower(searchTerm));
                tb.Data = matDatabase(idx, :);
            end
        end

        % Thêm vật liệu tùy chỉnh vào cơ sở dữ liệu tạm thời
        function addCustomMaterial()
            prompt = {'Tên vật liệu mới:', 'Hằng số điện môi (\epsilon_r):', 'Tổn hao (tan\delta):'};
            dlgtitle = 'Tạo Vật liệu (Add Material)';
            dims = [1 50]; definput = {'My_Custom_Mat', '4.4', '0.02'}; 
            answer = inputdlg(prompt, dlgtitle, dims, definput); 
            if ~isempty(answer) 
                newName = answer{1}; newEps = str2double(answer{2}); newLoss = str2double(answer{3});
                matDatabase(end+1, :) = {newName, newEps, newLoss};
                tb.Data = matDatabase; edtSearch.Value = ''; 
                lblStatus.Text = ['Đã thêm vật liệu: ' newName];
            end
        end

        % Xác nhận chọn vật liệu và truyền biến trở lại GUI chính
        function selectAndClose()
            selIdx = tb.Selection;
            if isempty(selIdx)
                uialert(dlg, 'Vui lòng chọn một vật liệu từ danh sách!', 'Cảnh báo'); return;
            end
            
            edtMatName.Value = tb.Data{selIdx, 1};
            current_eps_r = tb.Data{selIdx, 2};
            current_loss = tb.Data{selIdx, 3};
            
            close(dlg); 
            lblStatus.Text = sprintf('Đã áp dụng vật liệu: %s. Vui lòng nhấn "TÍNH TOÁN KÍCH THƯỚC"!', edtMatName.Value);
        end
    end

    % =====================================================================
    % PHÂN HỆ 3: THUẬT TOÁN GIẢI TÍCH TOÁN HỌC (MATHEMATICAL KERNEL)
    % =====================================================================
    function autoCalculateBalanis()
        % 1. Đọc thông số đầu vào từ GUI
        fc = edtFc.Value * 1e9; fmin = edtFmin.Value * 1e9; 
        eps_r = current_eps_r; 
        w_s_val = str2double(ddlWs.Value); c = 3e8; 
        
        % 2. Tính toán các hằng số truyền sóng (Bước sóng hữu dụng)
        eps_eff = (eps_r + 1) / 2; lambda_g_fc = (c / (fc * sqrt(eps_eff))) * 1000; 
        wa_val = (c / ( fmin * sqrt(eps_eff))) * 1000; edtwa.Value = round(wa_val, 1);
        lambda_min_dielectric = (c / (fmin * sqrt(eps_eff))) * 1000; lt_val = lambda_min_dielectric * 1.2; edtlt.Value = round(lt_val, 1); 
        
        % 3. Khai triển phương trình hàm mũ cho biên dạng bức xạ (Flare)
        A_val = w_s_val / 2; p_val = (1 / lt_val) * log(wa_val / w_s_val);
        edtA.Value = round(A_val, 2); edtP.Value = round(p_val, 4);
        
        % 4. Tính toán kích thước hốc cộng hưởng và giới hạn nền
        d_val = lambda_g_fc / 4; s_val = lambda_g_fc / 4; pad_back = 10.0; 
        edtd.Value = round(d_val, 1); edts.Value = round(s_val, 1); edtl.Value = round(pad_back + d_val + s_val + lt_val, 1); 
        margin_total = lambda_g_fc / 2; edtw.Value = round(wa_val + margin_total, 1); 
        
        lblStatus.Text = 'Đã tính toán xong kích thước. Sẵn sàng chạy mô phỏng HFSS!';
    end

    % =====================================================================
    % PHÂN HỆ 4: KỊCH BẢN GIAO TIẾP HFSS-MATLAB API (CO-SIMULATION)
    % =====================================================================
    function runSimulation()
        % Nạp các đường dẫn thư viện API
        addpath('hfssapi/boundary/'); addpath('hfssapi/3dmodeler/'); addpath('hfssapi/analysis/'); 
        addpath('hfssapi/general/'); addpath('hfssapi/radiation/'); addpath('hfssapi/reporter/');
        
        if edtwa.Value == 0
            uialert(fig, 'Bạn chưa tính toán kích thước! Hãy nhấn nút "TÍNH TOÁN KÍCH THƯỚC" trước khi chạy mô phỏng.', 'Lỗi mô phỏng');
            return;
        end
        
        try
            % --- 1. TIẾP NHẬN BỘ THÔNG SỐ VẬT LÝ ---
            l = edtl.Value; w = edtw.Value; h = edth.Value; 
            fC = edtFc.Value * 1e9; f_min_val = edtFmin.Value * 1e9; 
            d = edtd.Value; s = edts.Value; w_s = str2double(ddlWs.Value); 
            l_t = edtlt.Value; w_a = edtwa.Value; A = edtA.Value; p = edtP.Value; 
            
            mat_name_hfss = edtMatName.Value; 
            eps_r_val = current_eps_r; 
            loss_val = current_loss;   
            
            % --- 2. KHỞI TẠO TỆP LỆNH VBSCRIPT (.vbs) ---
            hfssExePath = 'D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe';
            tmpDataFile = fullfile(pwd, 'tmpDataVivaldi.m'); tmpScriptFile = fullfile(pwd, 'vivaldi_run.vbs'); tmpPrjFile = fullfile(pwd, 'tmpVivaldiStandard.aedt');
            if isfile(tmpDataFile), delete(tmpDataFile); end
            
            fid = fopen(tmpScriptFile, 'wt'); hfssNewProject(fid); hfssInsertDesign(fid, 'Vivaldi_Balanis');
            
            % Định nghĩa vật liệu tùy chỉnh trong không gian HFSS
            fprintf(fid, 'Set oDefinitionManager = oProject.GetDefinitionManager()\n');
            fprintf(fid, 'oDefinitionManager.AddMaterial Array("NAME:%s", "CoordinateSystemType:=", "Cartesian", Array("NAME:AttachedData"), Array("NAME:ModifierData"), "permittivity:=", "%f", "dielectric_loss_tangent:=", "%f")\n', mat_name_hfss, eps_r_val, loss_val);
            
            fprintf(fid, 'Set oEditor = oDesign.SetActiveEditor("3D Modeler")\n');
            fprintf(fid, 'oEditor.SetModelUnits Array("NAME:Units Parameter", "Units:=", "mm", "Rescale:=", false)\n');
            
            % --- 3. NỘI SUY MẢNG TỌA ĐỘ RỜI RẠC ĐỂ VẼ BIÊN DẠNG 3D ---
            pad_back = l - d - s - l_t; if pad_back < 0, error('Chiều dài nền (l) quá ngắn!'); end
            xc = pad_back + d/2; x_slot_start = pad_back + d; x_flare_start = x_slot_start + s; 
            x_local = linspace(0, l_t, 100)'; y_flare_top = A * exp(p * x_local); y_flare_top(end) = w_a / 2; 
            x_flare_global = round(x_flare_start + x_local, 2); y_flare_top = round(y_flare_top, 2); y_flare_bot = -y_flare_top;
            x_cut_end = max(x_flare_global(end), l + 5); 
            
            % Đóng gói tọa độ thành mảng Polygon khép kín
            PtsFlare = [x_flare_start, w_s/2, 0; x_flare_global, y_flare_top, zeros(100,1); x_cut_end, y_flare_top(end), 0; x_cut_end, y_flare_bot(end), 0; flipud(x_flare_global), flipud(y_flare_bot), zeros(100,1); x_flare_start, -w_s/2, 0; x_flare_start, w_s/2, 0];
            
            % --- 4. ĐIỀU KHIỂN HFSS DỰNG KHỐI HÌNH HỌC VÀ CẮT KHỐI (BOOLEAN) ---
            hfssBox(fid, 'Substrate', [0, -w/2, 0], [l, w, -h], 'mm');
            fprintf(fid, 'oEditor.AssignMaterial Array("NAME:Selections", "Selections:=", "Substrate"), Array("NAME:Attributes", "MaterialValue:=", """%s""", "SolveInside:=", true)\n', mat_name_hfss);
            
            hfssRectangle(fid, 'GroundPlane', 'Z', [0, -w/2, 0], l , w, 'mm'); hfssCircle(fid, 'Cavity', 'Z', [xc, 0, 0], d/2, 'mm'); hfssRectangle(fid, 'Slot', 'Z', [xc, -w_s/2, 0], d/2 + s, w_s, 'mm');
            hfssPolyline(fid, 'FlareCut', PtsFlare, 'mm'); fprintf(fid, 'oEditor.CoverLines Array("NAME:Selections", "Selections:=", "FlareCut")\n');
            
            % Phép trừ khối: Mặt phẳng đồng trừ đi phần rỗng (Cavity, Slot, FlareCut)
            hfssSubtract(fid, {'GroundPlane'}, {'Cavity', 'Slot', 'FlareCut'});
            fprintf(fid, 'oEditor.ChangeProperty Array("NAME:AllTabs", Array("NAME:Geometry3DAttributeTab", Array("NAME:PropServers", "GroundPlane"), Array("NAME:ChangedProps", Array("NAME:Color", "R:=", 255, "G:=", 128, "B:=", 0))))\n');
            
            % --- 5. THIẾT LẬP CỔNG KÍCH THÍCH (LUMPED PORT) ---
            Feed_Loc = x_slot_start; Port_W = w_s; 
            hfssRectangle(fid, 'PortRect', 'Z', [Feed_Loc, -w_s/2, 0], Port_W, w_s, 'mm');
            fprintf(fid, 'Set oModule = oDesign.GetModule("BoundarySetup")\n');
            fprintf(fid, 'oModule.AssignFiniteCond Array("NAME:FiniteCond_Ground", "Objects:=", Array("GroundPlane"), "UseMaterial:=", true, "Material:=", "copper", "UseThickness:=", false, "Roughness:=", "0um")\n');
            hfssAssignLumpedPort(fid, 'Port1', 'PortRect', [Feed_Loc + Port_W/2, -w_s/2, 0], [Feed_Loc + Port_W/2, w_s/2, 0], 'mm');
            
            % --- 6. CẤU HÌNH DẢI QUÉT TẦN SỐ (SWEEP & ANALYSIS SETUP) ---
            f_start = f_min_val *0.5/ 1e9; f_stop = (fC/1e9)*2  - (f_min_val / 1e9)+2; f_step = (f_stop - f_start) / 200; 
            fprintf(fid, 'Set oModule = oDesign.GetModule("ModelSetup")\n'); fprintf(fid, 'oModule.CreateOpenRegion Array("NAME:Settings", "OpFreq:=", "%fGHz", "Boundary:=", "Radiation", "ApplyInfiniteGP:=", false)\n', f_start);
            fprintf(fid, 'Set oModule = oDesign.GetModule("AnalysisSetup")\n'); fprintf(fid, 'oModule.InsertSetup "HfssDriven", Array("NAME:Setup_Auto", "AdaptMultipleFreqs:=", true, Array("NAME:MultipleAdaptiveFreqsSetup", "Low:=", "%fGHz", "High:=", "%fGHz"), "MaxDeltaS:=", 0.02, "MaximumPasses:=", 50, "MinimumPasses:=", 5, "MinimumConvergedPasses:=", 3, "PercentRefinement:=", 10)\n', f_start, f_stop);
            fprintf(fid, 'oModule.InsertFrequencySweep "Setup_Auto", Array("NAME:SweepDisc", "IsEnabled:=", true, "RangeType:=", "LinearStep", "RangeStart:=", "%fGHz", "RangeEnd:=", "%fGHz", "RangeStep:=", "%fGHz", "Type:=", "Interpolating", "SaveFields:=", true, "SaveRadFields:=", true, "ExtrapToDC:=", false)\n', f_start, f_stop, f_step);
            
            hfssSaveProject(fid, tmpPrjFile, true); hfssSolveSetup(fid, 'Setup_Auto'); hfssExportNetworkData(fid, tmpDataFile, 'Setup_Auto', 'SweepDisc');
            fclose(fid);
            
            % --- 7. THỰC THI NGẦM (BATCH MODE EXECUTION) ---
            lblStatus.Text = 'Đang chạy mô phỏng HFSS ở chế độ ngầm... (Vui lòng đợi)'; drawnow;
            system(['"', hfssExePath, '" /RunScriptAndExit "', tmpScriptFile, '"']);
            
            % --- 8. ĐỌC KẾT QUẢ VÀ TRỰC QUAN HÓA (DATA EXTRACTION & PLOTTING) ---
            if isfile(tmpDataFile)
                evalin('base', sprintf('run(''%s'');', tmpDataFile));
                f_data = evalin('base','f') / 1e9; S_data = evalin('base','S');        
                
                % Vẽ đồ thị S11
                plot(axS11, f_data, 20*log10(abs(S_data)), 'LineWidth', 2, 'Color', '#0072BD');
                
                % Tính toán và vẽ đồ thị Trở kháng (Z-Parameter)
                Z0 = 50; Z_data = Z0 .* (1 + S_data) ./ (1 - S_data);
                plot(axZ, f_data, real(Z_data), 'LineWidth', 2, 'Color', '#D95319'); hold(axZ, 'on'); 
                plot(axZ, f_data, imag(Z_data), 'LineWidth', 2, 'Color', '#EDB120', 'LineStyle', '--'); 
                yline(axZ, 50, 'k-', '50\Omega', 'LabelHorizontalAlignment', 'left'); 
                yline(axZ, 0, 'k--', '0\Omega', 'LabelHorizontalAlignment', 'left'); 
                legend(axZ, {'Phần thực (R)', 'Phần ảo (X)'}, 'Location', 'best'); hold(axZ, 'off');
                
                lblStatus.Text = 'Hoàn thành mô phỏng HFSS! Dữ liệu đã được cập nhật trên đồ thị.'; 
            else
                lblStatus.Text = 'Lỗi: Không tìm thấy file dữ liệu S11 trả về từ HFSS.';
            end
        catch ME
            lblStatus.Text = ['LỖI TIẾN TRÌNH: ' ME.message];
        end
    end
end