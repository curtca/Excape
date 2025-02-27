del /q "D:\Godot Demos\Godot Exports\Excape\*"
C:\Godot\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe --export-release "Web" "D:\Godot Demos\Godot Exports\Excape\index.html"
pushd "D:\Godot Demos\Godot Exports\Excape"
tar -a -c -f index.zip *
butler push index.zip curtc/excape:HTML5
popd