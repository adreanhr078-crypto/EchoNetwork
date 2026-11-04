# شجرة العمل — CP41 / 20 أكتوبر2026

المسارات نسبية إلى `artifacts/eleven-eleven/`. الحالة المختصرة فيCURRENT_WORK؛ لا تعتمد الصفوف التاريخية بدلها. لم تُنقل أصول أو ملفات لعب ضمن الترتيب.

| النظام/الغرفة | المصدر الأول | الدليل/الحد |
|---|---|---|
| التشغيل | godot/scripts/boot.gd → ui/title_entry.gd → native_journey.tscn | فيديو المالك أولًا؛ default محلي؛ الربط المهيأ اختياري |
| البداية00 | src/App.tsx + features/opening-recovery/TitleEntry.tsx | فيديو أولًا ثم لغز الغلاف/التشظي/الفيلم؛ cover_v1 خادمي؛ لا مكافأة من العرض |
| الربط | NativeEntryPanel.tsx + functions/api/player/_nativeEntry.ts + godot/scripts/systems/native_entry_gate.gd | migrations/0028؛ نموذج محلي؛ نشر/Firebaseحي OPEN |
| الافتتاح01 | godot/scripts/main.gd + cinematics/opening_inspection.gd | فحص/لغز/بوابة؛ حفظ محلي فقط |
| الصيانة02/الأمن03 | godot/scripts/systems/native_journey_controller.gd | إدخال عام وتسلق/غطاء/تشتيت |
| بقية الفصل | godot/scripts/systems/native_campaign_controller.gd | rooms[] + وصلات مستقلة؛ لا دمج غرف |
| العينات04 | environment/specimen_containment_wing.gd | غطاء فعلي وتوقيت كشاف؛ لم يضعف الكشاف |
| الأرشيف05 | environment/memory_archive_wing.gd |3ذكريات/سلم/فك ترميز |
| المفاعل06 | environment/core_reactor_room.gd | قاطعان/توقيت خطر |
| التطهير07 | environment/decontamination_quarantine_wing.gd | UV/سلم/تجاوز |
| المرآة08 | environment/mirror_chamber_room.gd | شرطا المرآة والتجاوز |
| المختبر09 | environment/dr_kinja_lab_room.gd + cinematics/lab_memory_trial.gd | محطات/حوار/رفض/مقاومة؛ تمثيل3D OPEN |
| العقد/المواجهة | cinematics/pact_revenge_presentation.gd + characters/kinja_revenge_actor.gd | قرارات صريحة/تلامس قتال؛ فن اليد/الجسد OPEN |
| المستشفى10 | environment/hospital_bedside_room.gd + native_campaign_controller.gd | الفيلم/الاستيقاظ/مرآةEX-011؛ الأداء النهائي OPEN |
| اللاعب | assets/characters/echo_v31_adopted_high.glb + scripts/player/ | High الحالي؛ لا استبدال من تجربةTripo |
| Golden | art/production/master-animation-library/golden/walk-v1/ |192ملفًا محميًا؛لا إعادةختم |
| الواجهات | godot/scripts/ui/ + src/ui/design-system/ | مكونات واحدة، AR/EN/RM/mute |
| مسار كامل | godot/tests/full_chapter_journey_review.gd | route/cp41-delivery/full-chapter.json؛340،0retry |
| حفظ مكتسب/مختبر | godot/tests/earned_campaign_resume_review.gd | route/cp37-current-lab/earned-resume.json؛45حاليًا |
| HTTP الربط | godot/tests/native_entry_transport_review.gd + src/__tests__/nativeEntry.test.ts | localfixture وليسحسابًاحيًا |
| فحص الحزمة | godot/scripts/systems/native_review_probe.gd | quality-cp38-20261019/packed-smoke-verified.log؛22شرطًا، ليسفصلًاكاملًا |
| الحرفة/المتبقي | docs/internal/production/CHAPTER_QUALITY_EXECUTION_PLAN_2026-10-16.ar.md | الخطة30مرحلة محفوظة؛ لا نسبةإنجازمصطنعة |

`environment/` و`cinematics/` و`characters/` فيالصفوفأعلاه تحت `godot/scripts/`. فهرسالمصدرالحاليSOURCE_INDEX.json. الأدلةالقريبةتحتaudits/evidence/pre-tripo-20261018/cp37؛ التاريخالكاملللشجرةقبلالترتيبفيarchive/before_cp37_20261018_WORK_TREE.ar.md. لا حذفشامللـ.tmpأوGodot/app_userdata.

CP38: المستشفى يضيف hospital_room_dressing.gd وward_floor/linen/rain_window وward_bed_original_v1.glb وward_visitor_chair_v1.glb وward_vanity_v1.glb. اختبارات hospital_visual_review/ward_light_scope_review/ward_objective_owner_review. كينجاP2معزول فيart/production/tripo-cp38-20261019 واختبارtripo_actor_candidate_review، لا يغيرactorالحالي. سجلالكريديتوالصورالمرجعيةفيالمجلدنفسه.


CP39: SystemWindow القائم + system_notice_queue_review32 + system_personal_window_review26؛ دليل الصور route/cp39-system-v10 والبصمات الحالية. tripo_character_visual_review يراجع المصدر المعزول بوقته الأصلي، ولا يغيّر اللاعب. أصل إيكو وسجل70كريديت ورفض محاولتيRun محفوظان في echo-tripo-cp39-20261019؛ الفعل التالي باركور غرفة02، دون محاولةRun ثالثة.

## CP40 — تعليق الغرفة02
مصدر V31 ثابت؛ hang_cp40.res ومحول العرض/SurfaceTraversalMotor، والدليل echo-parkour-cp40-20261019. تدلٍّ حر نهائي مرفوض عند الجدار؛ Frame0 ارتكاز ثابت فقط. CURRENT_WORK يحدد حالة regression والصعود المفتوح.

## CP41 — النواة البصرية الدائمة
`godot/engine_visuals/HyperAnimeWorldManager.gd` و`HyperMaterialAdapter.gd` و`camera/DynamicActionCameraRig.gd` و`vfx/KineticVFXOrchestrator.gd` و`shaders/`: مصدر البيئة/المواد/الكاميرا/المؤثرات. الربط في main/EchoPlayer/project.godot؛ الجودة في native_pause_menu. اختبارات hyper_anime_engine_review وhyper_anime_live_review؛ المصدر والدليل الحاليان في hyper-anime-cp41-20261019/verification-cp41.json.35+35 وحدات/19مشهد/19مستشفى/340مسار/31حزمة؛ الأداء High والفن والـmantle مفتوحة. صفوف CP38/39 أعلاه تاريخية حيث تعارض هذه الحالة.
