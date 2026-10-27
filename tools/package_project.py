"""Create a portable Godot source project without editor caches or exports."""
from pathlib import Path
import zipfile
root=Path(__file__).resolve().parents[1]
output=root/'exports'/'Titus_Godot_Project.zip'
output.parent.mkdir(exist_ok=True)
excluded={'.git','.godot','exports','__pycache__'}
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for source in sorted(root.rglob('*')):
        if not source.is_file() or any(part in excluded for part in source.relative_to(root).parts):continue
        if source.suffix in {'.log','.tmp'} or source.name.endswith('.blend1'):continue
        archive.write(source,'Titus_Bastion_VII/'+str(source.relative_to(root)))
print(output,round(output.stat().st_size/1048576,2),'MiB')
