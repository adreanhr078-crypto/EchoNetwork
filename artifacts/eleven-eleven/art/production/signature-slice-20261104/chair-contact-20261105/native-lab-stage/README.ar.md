# مراجعة L02 داخل مختبر كينجا

لقطة صامتة من ثانيتين تُظهر الجلوس وإغلاق القيدين داخل المختبر الموجود. تبدأ بعد الجلوس. راجع `quality-report.json` ولقطات الفتح والإغلاق قبل إدراجها في المونتاج. تأليف الدخول وإسناد القدم والأداء البشري والتحرر المكتسب بوابات مفتوحة.

من جذر التطبيق، أعد المعاينة أو سلسلة الإطارات في مجلد مراجعة مخصص. الوسيط `--native-lab` يضع النموذج المعزول عند موضع الكرسي الفعلي من دون تشغيل مسار القصة.

```powershell
$packet = (Resolve-Path 'art/production/signature-slice-20261104/chair-contact-20261105').Path
$school = (Resolve-Path 'art/production/echo-school-rebuild-20261029/source/echo-school-rig-metric.glb').Path
$chair = (Resolve-Path 'godot/assets/environments/lab_clinical_cp45/neural_chair_tripo_20k.glb').Path
$review = (New-Item -ItemType Directory -Force '.tmp/l02-lab-review').FullName
& 'C:/Tools/Godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe' --resolution 1280x720 --path godot --rendering-method gl_compatibility --script ../tools/character-lab/chair_contact_review.gd -- "$packet/restrained-breath.glb" "$packet/blender-contact.json" $school $chair $review "$packet/cuff-closure/cuffs.glb" "$packet/cuff-closure/blender-cuff-review.json" --native-lab "--sequence-dir=$review/frames"
ffmpeg -framerate 30 -i "$review/frames/%03d.jpg" -frames:v 60 -an -c:v libx264 -pix_fmt yuv420p "$review/L02-restraint-contact-review.mp4"
```


## مراجعة صوت الإغلاق

الملف `foley/L02-restraint-foley-review.mp4` يضم نسخ الصورة نفسها مع مؤثرين ميكانيكيين. أُخذ التوقيت من أول إطار يغلق فيه كل قيد في التقرير المقاس. عينة الصوت مرجع استماع ومزج.

```powershell
$cuffs = "$packet/cuff-closure"
$stage = "$packet/native-lab-stage"
& 'C:/Tools/Godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe' --headless --path godot --script ../tools/cinematics/build_l02_foley.gd -- "$cuffs/blender-cuff-review.json" "$cuffs/cuffs.glb" "$review/foley"
ffmpeg -i "$stage/L02-restraint-contact-review.mp4" -i "$review/foley/L02-cuff-latch.wav" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac "$review/foley/L02-restraint-foley-review.mp4"
```
