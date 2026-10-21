function g = Vivaldi_Calculation(p)
% Tính hình học dual-pol theo tệp 17/10/2026; tất cả chiều dài dùng mm.
names = {'L_flare_1','aperture_w','slot_feed_w','deg_slot_t', ...
    'h3_slot_feed','h2','cavity_w','cavity_L','h_de','r_cabin', ...
    'positionx','r_cabmid','r_cabout','lamda','scan_phi','scan_theta', ...
    'thickness','them','c2'};
values = [40 20 .5 21 1 2.6 1.4 5 2 .15 .15 .35 .5 60 0 0 2 0 0];
defaults = cell2struct(num2cell(values),names,2);
if nargin == 0, p = defaults; end
assert(isstruct(p) && isscalar(p),'Vivaldi:Input','Cần một struct tham số.');
assert(isempty(setdiff(fieldnames(p),names)),'Vivaldi:Input','Có tham số không được hỗ trợ.');
for k = 1:numel(names)
    n = names{k};
    if ~isfield(p,n), p.(n) = defaults.(n); end
    validateattributes(p.(n),{'numeric'},{'scalar','real','finite'},mfilename,n);
end
positive = {'L_flare_1','slot_feed_w','h3_slot_feed','h2','cavity_w', ...
    'cavity_L','h_de','thickness','lamda'};
for k = 1:numel(positive)
    assert(p.(positive{k})>0,'Vivaldi:Geometry','%s phải dương.',positive{k});
end
assert(p.aperture_w>p.slot_feed_w,'Vivaldi:Geometry','Khẩu độ phải lớn hơn khe cấp.');
assert(0<p.r_cabin && p.r_cabin<p.r_cabmid && p.r_cabmid<p.r_cabout, ...
    'Vivaldi:Geometry','Cần 0 < r_cabin < r_cabmid < r_cabout.');
assert(p.deg_slot_t>=0 && p.deg_slot_t<90,'Vivaldi:Geometry','Góc transition phải trong [0,90) độ.');
g = p; g.parameters = p; g.defaults = defaults;
g.slot_t_L = 6.4+p.them;
assert(g.slot_t_L>0,'Vivaldi:Geometry','slot_t_L phải dương.');
g.L_flare = p.L_flare_1+g.slot_t_L;
g.r_flare = log(p.aperture_w/p.slot_feed_w)/g.L_flare;
g.a = p.slot_feed_w/2*exp(g.slot_t_L*g.r_flare);
g.z_feed = (g.a+p.slot_feed_w/2)*sind(p.deg_slot_t)+g.slot_t_L*(1-cosd(p.deg_slot_t));
g.x_feed = (g.a+p.slot_feed_w/2)*cosd(p.deg_slot_t)+g.slot_t_L*sind(p.deg_slot_t)-g.a;
g.L_patch = g.L_flare-g.z_feed+p.h3_slot_feed+p.slot_feed_w+p.h_de;
g.z_base = g.L_flare-g.L_patch;
g.de_L = p.aperture_w+p.thickness; g.de_W = g.de_L;
g.h_box = p.lamda/2+g.L_patch;
g.h_cabin = p.h_de+p.slot_feed_w; g.h_cabout = p.h_de; g.h_cabmid = p.h_de;
g.cs.slot_t_td = [g.a 0 g.slot_t_L];
g.cs.slot_feed_td = [-g.x_feed 0 g.z_feed];
g.cs.patch_td = [p.aperture_w/2 0 g.L_flare];
g.cs.RelativeCS1 = [p.aperture_w/2 -p.thickness/2 g.L_flare];
g.secondRotation = [0 1 0;-1 0 0;0 0 1];
g.secondTranslation = g.cs.RelativeCS1' - g.secondRotation*g.cs.RelativeCS1' + [0;p.thickness;0];
g.port1 = [-g.x_feed-p.positionx+p.slot_feed_w+p.h2,0,g.z_base];
g.port2 = (g.secondRotation*g.port1'+g.secondTranslation)';
% Đường tích phân từ vỏ vào lõi; dùng tọa độ, không tái dùng Edge IDs.
g.line1 = [g.port1+[p.r_cabmid 0 0];g.port1+[p.r_cabin 0 0]];
g.line2 = (g.secondRotation*g.line1'+g.secondTranslation)';
g.bounds = [-p.aperture_w/2,-p.thickness/2,g.z_base; ...
    p.aperture_w/2+p.thickness,p.aperture_w+p.thickness/2,g.L_flare];
% Giới hạn giải tích cần thiết; topology/Boolean vẫn phải Validate trong HFSS.
assert(g.L_patch>0 && all(isfinite([g.r_flare g.x_feed g.z_feed g.L_patch])), ...
    'Vivaldi:Geometry','Hình học suy biến hoặc tràn số.');
xleft=-g.x_feed; xright=xleft+p.slot_feed_w+p.h2+p.cavity_w;
assert(xleft>-p.aperture_w/2 && xright<p.aperture_w/2, ...
    'Vivaldi:Geometry','Feed/cavity vượt mép tấm kim loại.');
assert(g.z_feed-p.h3_slot_feed-p.slot_feed_w+p.cavity_L<g.L_flare, ...
    'Vivaldi:Geometry','Cavity vượt miệng anten.');
assert(abs(g.port1(1))+p.r_cabout<p.aperture_w/2 && p.r_cabout<p.thickness/2, ...
    'Vivaldi:Geometry','Coax vượt bề rộng/độ dày tấm.');
assert(abs(p.positionx)<p.r_cabin+p.slot_feed_w, ...
    'Vivaldi:Geometry','Lõi coax không tiếp xúc vùng cấp nguồn.');
% Biên dạng lấy mẫu chỉ dành cho preview, không dùng dựng CAD HFSS.
u=linspace(g.slot_t_L,g.L_flare,241)'; w=p.slot_feed_w/2*exp(g.r_flare*u);
g.flare=[w u;flipud(-w) flipud(u)];
u=linspace(0,g.slot_t_L,121)';w=p.slot_feed_w/2*exp(g.r_flare*u);
q=[w u;flipud(-w) flipud(u)];
R=[cosd(p.deg_slot_t) sind(p.deg_slot_t);-sind(p.deg_slot_t) cosd(p.deg_slot_t)];
g.transition=(R*(q-[g.a g.slot_t_L])')'+[g.a g.slot_t_L];
g.rectangles={rect(0,0,p.slot_feed_w,-p.h3_slot_feed), ...
    rect(0,-p.h3_slot_feed,p.slot_feed_w+p.h2+p.cavity_w,-p.slot_feed_w), ...
    rect(p.slot_feed_w+p.h2,-p.h3_slot_feed-p.slot_feed_w,p.cavity_w,p.cavity_L)};
for k=1:3, g.rectangles{k}=g.rectangles{k}+[-g.x_feed g.z_feed]; end
end
function q=rect(x,z,w,h)
q=[x z;x+w z;x+w z+h;x z+h];
end
