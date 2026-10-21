function test_gui()
% Smoke test GUI thật trên MATLAB desktop, không chạy trong Octave/headless.
assert(exist('OCTAVE_VERSION','builtin')==0,'Vivaldi:MatlabRequired', ...
    'PENDING: kiểm thử GUI cần MATLAB R2021a+ có desktop.');
assert(usejava('desktop'),'Vivaldi:DesktopRequired','PENDING: cần MATLAB desktop.');
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
fig=Vivaldi_GUI(); cleanup=onCleanup(@() close(fig)); drawnow;
assert(isvalid(fig));
tabs=findall(fig,'Type','uitab'); assert(numel(tabs)==5);
fields=findall(fig,'Type','uinumericeditfield'); assert(numel(fields)==31);
% Mở thư viện bằng callback thật; đóng Cancel không thay vật liệu.
buttons=findall(fig,'Type','uibutton');
library=buttons(strcmp({buttons.Text},'Thư viện')); assert(numel(library)==1);
callback=library.ButtonPushedFcn; callback(library,[]); drawnow;
dlg=findall(groot,'Type','figure','Name','Select Definition - Vật liệu');
assert(numel(dlg)==1); dlgCleanup=onCleanup(@() closeIfValid(dlg));
table=findall(dlg,'Type','uitable'); assert(size(table.Data,1)>=11);
search=findall(dlg,'Type','uieditfield'); search.Value='rogers';
callback=search.ValueChangedFcn; callback(search,[]); drawnow;
assert(size(table.Data,1)==2);
search.Value=''; callback=search.ValueChangedFcn; callback(search,[]); drawnow;
assert(size(table.Data,1)>=11);
buttons=findall(dlg,'Type','uibutton'); cancel=buttons(strcmp({buttons.Text},'Cancel'));
callback=cancel.ButtonPushedFcn; callback(cancel,[]); drawnow;
assert(~isvalid(dlg));
fprintf('MATLAB GUI smoke PASS; HFSS CAD/solver remains a separate acceptance test.\n');
end

function closeIfValid(fig)
if isvalid(fig), close(fig); end
end
