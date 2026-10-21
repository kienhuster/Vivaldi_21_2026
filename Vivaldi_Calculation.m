function [g, p] = Vivaldi_Calculation(input)
% SPDX-License-Identifier: GPL-2.0-or-later
% VIVALDI_CALCULATION Tính hình học dual-pol theo mô hình ngày 17/10/2026.
% [g,p] = Vivaldi_Calculation() trả về hình học và 19 tham số mặc định.
% [g,p] = Vivaldi_Calculation(struct(...)) cho phép thay từng tham số, đơn vị mm/độ.
% Các đa giác lấy mẫu chỉ dành cho preview; CAD dùng EquationBasedSurface thật.
p = struct('L_flare_1',40,'aperture_w',20,'slot_feed_w',0.5, ...
    'deg_slot_t',21,'h3_slot_feed',1,'h2',2.6,'cavity_w',1.4, ...
    'cavity_L',5,'h_de',2,'r_cabin',0.15,'positionx',0.15, ...
    'r_cabmid',0.35,'r_cabout',0.5,'lamda',60,'scan_phi',0, ...
    'scan_theta',0,'thickness',2,'them',0,'c2',0);
if nargin > 0
    assert(isstruct(input) && isscalar(input), 'Vivaldi:Parameters', ...
        'Đầu vào phải là một struct tham số.');
    names = fieldnames(input);
    for k = 1:numel(names)
        assert(isfield(p,names{k}), 'Vivaldi:Parameters', ...
            'Tham số không được hỗ trợ: %s',names{k});
        p.(names{k}) = input.(names{k});
    end
end
names = fieldnames(p);
for k = 1:numel(names)
    validateattributes(p.(names{k}),{'numeric'},{'real','finite','scalar'}, ...
        mfilename,names{k});
end
positive = {'L_flare_1','aperture_w','slot_feed_w','h3_slot_feed', ...
    'h2','cavity_w','cavity_L','h_de','r_cabin','r_cabmid','r_cabout', ...
    'lamda','thickness'};
for k = 1:numel(positive)
    assert(p.(positive{k}) > 0, 'Vivaldi:Geometry', ...
        '%s phải lớn hơn 0.',positive{k});
end
assert(p.aperture_w > p.slot_feed_w,'Vivaldi:Geometry', ...
    'aperture_w phải lớn hơn slot_feed_w.');
assert(p.r_cabin < p.r_cabmid && p.r_cabmid < p.r_cabout, ...
    'Vivaldi:Geometry','Cần 0 < r_cabin < r_cabmid < r_cabout.');
assert(p.deg_slot_t >= 0 && p.deg_slot_t < 90,'Vivaldi:Geometry', ...
    'Topology transition hiện hỗ trợ 0 <= deg_slot_t < 90 độ.');
assert(p.positionx >= 0 && p.positionx < p.h2,'Vivaldi:Geometry', ...
    'positionx phải nằm trong [0,h2) để giữ vị trí cấp coax.');
g.slot_t_L = 6.4+p.them;
assert(g.slot_t_L > 0,'Vivaldi:Geometry','6.4 + them phải lớn hơn 0.');
g.L_flare = p.L_flare_1+g.slot_t_L;
g.r_flare = log(p.aperture_w/p.slot_feed_w)/g.L_flare;
a = (p.slot_feed_w/2)*exp(g.slot_t_L*g.r_flare);
s = sind(p.deg_slot_t); c = cosd(p.deg_slot_t);
g.x_feed = (a+p.slot_feed_w/2)*c+g.slot_t_L*s-a;
g.z_feed = (a+p.slot_feed_w/2)*s+g.slot_t_L*(1-c);
g.L_patch = g.L_flare-g.z_feed+p.h3_slot_feed+p.slot_feed_w+p.h_de;
g.z_base = g.L_flare-g.L_patch;
g.de_L = p.aperture_w+p.thickness; g.de_W = g.de_L;
g.h_box = p.lamda/2+g.L_patch;
g.h_cabin = p.h_de+p.slot_feed_w;
g.h_cabout = p.h_de; g.h_cabmid = p.h_de;
assert(all(isfinite([g.r_flare,g.x_feed,g.z_feed,g.L_patch])) && g.L_patch>0, ...
    'Vivaldi:Geometry','Hình học dẫn xuất không hữu hạn hoặc L_patch <= 0.');
% Hệ tọa độ không xoay trục, RelativeCS1 có parent patch_td.
g.cs.slot_t_td = [a 0 g.slot_t_L];
g.cs.slot_feed_td = [-g.x_feed 0 g.z_feed];
g.cs.patch_td = [p.aperture_w/2 0 g.L_flare];
g.cs.RelativeCS1Local = [0 -p.thickness/2 0];
g.cs.RelativeCS1 = g.cs.patch_td+g.cs.RelativeCS1Local;
g.rotationZ = [0 1 0;-1 0 0;0 0 1];
g.translation = [0 p.thickness 0];
g.coax1 = [-g.x_feed-p.positionx+p.slot_feed_w+p.h2 0 g.z_base];
g.coax2 = transform(g.coax1,g);
% Đường tích phân: từ mặt trong vỏ ngoài tới mặt ngoài lõi; không tái dùng Edge IDs.
g.port1Line = [g.coax1+[p.r_cabmid 0 0];g.coax1+[p.r_cabin 0 0]];
g.port2Line = transform(g.port1Line,g);
g.bounds = [-p.aperture_w/2 -p.thickness/2 g.z_base; ...
    p.aperture_w/2+p.thickness p.aperture_w+p.thickness/2 g.L_flare];
% Mặt loe dài và transition đã quay quanh slot_t_td, lấy mẫu cho preview.
u = linspace(g.slot_t_L,g.L_flare,241)';
x = p.slot_feed_w/2*exp(g.r_flare*u);
g.flare = [x u;-flipud(x) flipud(u)];
u = linspace(0,g.slot_t_L,121)'; x = p.slot_feed_w/2*exp(g.r_flare*u);
short = [x u;-flipud(x) flipud(u)];
d = short-[a g.slot_t_L];
g.transition = d*[c -s;s c]+[a g.slot_t_L];
f = [-g.x_feed g.z_feed];
g.rectangles = {rect(f+[0 0],p.slot_feed_w,-p.h3_slot_feed), ...
    rect(f+[0 -p.h3_slot_feed],p.slot_feed_w+p.h2+p.cavity_w,-p.slot_feed_w), ...
    rect(f+[p.slot_feed_w+p.h2 -p.h3_slot_feed-p.slot_feed_w],p.cavity_w,p.cavity_L)};
% Kiểm tra bao hình học; CAD kernel vẫn phải Validate và kiểm tra topology thật.
tol = 1e-9*max(1,g.L_patch);
cut = vertcat(g.transition,g.rectangles{:});
assert(min(cut(:,1)) >= -p.aperture_w/2-tol && ...
       max(cut(:,1)) <= p.aperture_w/2+tol && ...
       min(cut(:,2)) > g.z_base && max(cut(:,2)) < g.L_flare, ...
    'Vivaldi:Geometry','Transition/cavity vượt biên tấm hoặc chạm đáy/miệng ngoài ý muốn.');
assert(abs(g.coax1(1))+p.r_cabout < p.aperture_w/2 && ...
       p.r_cabout < p.thickness/2, 'Vivaldi:Geometry', ...
    'Coax không nằm trong đế/tấm: kiểm tra bán kính, thickness và vị trí feed.');
g.parameters = p;
end

function v = rect(origin,w,h)
v = origin+[0 0;w 0;w h;0 h];
end

function q = transform(q,g)
q = (q-g.cs.RelativeCS1)*g.rotationZ'+g.cs.RelativeCS1+g.translation;
end
