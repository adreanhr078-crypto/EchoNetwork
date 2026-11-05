"""Build the source-locked P01/P05/P06 editorial packet; never writes gameplay state."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

APP = Path(__file__).resolve().parents[2]
PACKET = APP / "art/production/signature-slice-20261104"
PRODUCTION = APP / "docs/internal/production"
PUBLICATION = APP / "public/manhwa/echo-network-final-2026-09-v1"

# PDF/global page numbers include the cover. Printed folios are not these IDs.
# 'support' is contextual evidence, never a claim that the action is drawn there.
EVENTS = [
    ("E01", [3], "support", "الحياة المدرسية مرسومة؛العودة المحددة من المدرسة توسعة المالك."),
    ("E02", [5], "direct", "دخول بوابة المختبر مع الحقيبة."),
    ("E03", [4, 6], "support", "العالم والتجربة موجودان؛توقيت أسئلة الابن ورد الأب من توجيه المالك والـBible."),
    ("E04", [6], "direct", "جلوس إيكو في جهاز التجربة؛حركة الاقتراب والجلوس تحتاج تأليف تماس."),
    ("E05", [6, 7], "support", "التجربة والعد التنازلي؛فشل المعايرة القابل للإعادة توجيه لعب،لا نهاية بديلة مرسومة."),
    ("E06", [7], "direct", "تفعيل التجربة والساعة11:11."),
    ("E07", [8], "direct", "فتح العينين داخل النظام وسؤال المكان."),
    ("R01", [10, 11, 12], "support", "التعرف والأرشيف والسجلات؛مهمة الغرفة الأولى وتوصيلها توسعة لعب."),
    ("R02", [11, 38, 39], "support", "صور الذكريات والعلاقة؛هوية شيزوكا منBible،ولا ينسخ اختبار المختبر مبكرًا."),
    ("R03", [], "owner", "تعليق أثناء المشي من السجل المعتمد؛لا لوحة مباشرة أو حوار نهائي بعد."),
    ("R04", [27, 28], "support", "يوكي والذاكرة المستقبلية؛مرجع هوية فقط،لا تصريح بكشف مضمون المستقبل مبكرًا."),
    ("R05", [], "owner", "تذكر مستقل ليوكي من توجيه المالك،لا إعادة لفيلم شيزوكا."),
    ("R06", [12, 16, 24, 26], "support", "سجلاتSubjects والمشارك السابق؛EX-011على الجلد يتبع توجيه الهوية الأحدث."),
    ("P01", [], "owner", "عبور نار بشري من توجيه الباركور؛ليس حدث قوة أو لوحة بعينها."),
    ("P02", [], "owner", "عبور كهرباء بقراءة الدورة؛الخطر بيئي ولا يمنح قوة."),
    ("P03", [], "owner", "عبور رياح بقرار حركة وكاميرا تكشف الهبوط."),
    ("P04", [], "owner", "تركيب مهارات وعودة قريبة؛لا مكافأة أو كشف جديد مخترع."),
    ("M01", [9], "direct", "انعكاس إيكو ومحاولة لمس السطح."),
    ("M02", [9, 28], "support", "الانعكاس/المستقبل وBibleقسم المرآة؛النسخة المستقبلية الحية ليست شرحًا لكل الأسرار."),
    ("M03", [9, 15], "support", "انكسار/بيانات غير مؤكدة؛عودة السيطرة تأليف إخراجي."),
    ("L01", [34, 36, 37], "direct", "المختبر ومواجهة الأب بعد فشل العودة."),
    ("L02", [37, 52], "support", "مواجهة كينجا ثم كرسي العودة بعد العقد؛التقييد قبل الانهيار من توجيه المالك،لا إعادة ترتيب للصفحتين."),
    ("L03", [38, 39], "direct", "اختبار الذاكرة القسري وألم إيكو."),
    ("L04", [39, 42], "direct", "طلب التوقف ورفض الاختيار."),
    ("L05", [38, 39, 41, 42], "support", "تفتت الذكريات/العلاقات؛تخصيص ذاكرة شيزوكا منBibleوالسجل،بلا اختراع موت جديد."),
    ("L06", [41, 42, 43], "support", "يوكي والمواجهة والتفتت؛لقطته القسرية مستقلة ضمن الاختبار الحالي."),
    ("L07", [41, 42], "direct", "طلب الاختيار ورفض إيكو الصريح."),
    ("L08", [43], "direct", "تلاشي المشهد وسقوط إيكو داخل الماء."),
    ("O01", [43, 44], "direct", "غرق ووصول الضوء البعيد فوقه."),
    ("O02", [44], "support", "الماء الداكن والهبوط؛قاع المحيط المكاني من توجيه المالك،لا تضاريس مؤلفة في الصفحة."),
    ("O03", [45, 46, 48], "direct", "حضور الكيان ثم كشف هيئته الحقيقية."),
    ("O04", [46, 47, 48, 49, 50], "direct", "حوار العرض والاعتراض والثمن؛لا نسخ ثمن أستا أو مؤقته."),
    ("O05", [50], "direct", "طلب القوة بعد عرض الثمن؛في اللعب قرار صريح لا يقبله المؤقت أو التخطي."),
    ("O06", [51], "direct", "تم العقد؛هذه النتيجة تأتي بعد قرارO05المملوك للاعب فقط."),
    ("T01", [52], "direct", "عودة إلى المختبر وكرسي كينجا بعد العقد."),
    ("T02", [52, 53], "direct", "ضحكة متصاعدة ورد كينجا؛التنفس والتناقض من دراسةR128كتوجيه أداء أصلي."),
    ("T03", [53, 54, 55, 56], "direct", "تغير العين والشعر والجسد/الجناح؛هويةSchool/Pactالأحدث تتقدم على اللباس المرسوم."),
    ("T04", [56, 57], "support", "الجسد متحرر ويتحرك؛كسر الكرسي والقيود يحتاج مصدر تماس مؤلفًا من توجيه المالك."),
    ("T05", [56, 57, 58], "direct", "تقدم إيكو واتصال الهجوم الأول بكينجا."),
    ("C01", [57, 58], "support", "مرجع أول اتصال؛تسليم الإدخال للقتال فعل لعبة وليس لوحة مطابقة."),
    ("C02", [58, 59], "support", "ضربات وانتقام مرسوم؛سلسلة اليدين ووظائفها تأليف لعب وتماس."),
    ("C03", [58, 59], "support", "ردود الأب ومخاطبته؛مقاومة اللعب وقراءتها لا تثبت من صورة وحدها."),
    ("C04", [], "owner", "الحبل وتقييدكينجا من توجيه المالك؛لا صفحة مباشرة مؤكدة،ولا اختراع عقدة/أداة قبل تأهيلها."),
    ("C05", [59], "direct", "أدوات المختبر والحقن أثناء الانتقام؛لا تطبيق خارج القتال المكتسب."),
    ("C06", [60, 61], "support", "إيكو فوقكينجا ثم التجميد؛تماس الجلوس والضربات الأخيرة من الإخراج المعتمد."),
    ("S01", [61], "direct", "تجميد/قفل النظام المفاجئ."),
    ("S02", [61], "direct", "إدراك إيكو العجز أمام النظام."),
    ("S03", [61], "direct", "سؤال الأمنية وطلب الخروج."),
    ("S04", [62], "direct", "ألم الرأس والانهيار بعد معالجةالأمنية."),
    ("H01", [62, 63], "support", "القطع إلى المستشفى؛السواد المقصود جسر إخراجي،لا فشل تحميل."),
    ("H02", [63], "direct", "العينان والسرير والمراقبة الطبية."),
    ("H03", [63, 64], "direct", "إدراك الجسد والآثار واستعادة الحركة؛لا خروج من نطاق المستشفى الحالي."),
    ("H04", [63, 64], "support", "أثر العين والجسد؛مرآة المستشفى الحية من توجيه المالك ولا تُدّعى لوحة مباشرة."),
]

# Reviewed source-panel crops are normalized to the immutable 1800x2700 canvas.
# These are editorial choices, not final camera or timing acceptance.
SHOTS = [
    ("L02", 37, [0.02, .04, .98, .34], 4.0, "الأب مقابل الابن", "نثبت محور النظر؛ الأب يسأل من خلف بروده، والابن ما زال ينتظر أباه.", "ضجيج الأجهزة، نفس قريب؛ الحوار النهائي مؤجل"),
    ("L03", 38, [.02, .48, .98, .79], 4.5, "ذاكرة تقاوم", "الصورة الدافئة لا تطمئن؛ عين إيكو تسبق التفكك.", "صمت قصير ثم خلل جهاز غير موسيقي"),
    ("L04", 39, [.02, .51, .98, .80], 3.0, "طلب التوقف", "رد جسدي قصير؛ لا اهتزاز كامل للجسم أو ضغط أزرار مطول.", "نفس ينقطع، وطلب قصير من النص بعد اعتماده"),
    ("L07", 42, [.02, .29, .98, .68], 4.5, "الرفض", "يبقى الرفض فعلًا ذا معنى؛ لا زر يوهم بإنقاذ غير موجود في القصة.", "تنسحب طبقة الأجهزة لحظة الرفض"),
    ("L08", 43, [.02, .74, .98, .97], 3.0, "فقدان السند", "الأرض تفقد معناها؛ لا قطع يغير وضع الجسم اعتباطيًا.", "من جاف إلى مكتوم، بلا موسيقى"),
    ("O01", 44, [.02, .02, .98, .38], 4.0, "اليد نحو السطح", "يد تصل للضوء ثم تتباطأ؛ العجز يقرأ من الفعل.", "ماء مكتوم وفقاعات قليلة"),
    ("O02", 44, [.02, .38, .98, .98], 4.5, "يبتعد السطح", "اتساع صامت؛ الكتلة تهبط والكاميرا تترك لها الفراغ.", "انخفاض الضجيج؛ لا نبض موسيقي"),
    ("O03", 45, [.02, .02, .98, .22], 2.5, "شيء ينتظر", "نلمح العينين؛ لا نكشف تفاصيل الجسد كلها دفعة واحدة.", "ماء يتوقف حسيًا ثم صوت حضور منخفض"),
    ("O03", 45, [.02, .22, .98, .66], 4.0, "مسافة العلاقة", "إيكو والحضور على محور واحد؛ ليس بطلًا خارقًا بعد.", "وقفة ورد سؤال؛ الأداء غير مسجل بعد"),
    ("O04", 47, [.02, .22, .98, .59], 5.0, "العرض والاعتراض", "لكل جملة نية وللمستمع فعل؛ لا مونولوج بوجه مجمد.", "صوتان أصليان باليابانية لاحقًا؛ لا نقل لصوت المراجع"),
    ("O04", 48, [.02, .26, .98, .72], 4.5, "الكشف", "تتسع الكتلة وتضيق مساحة إيكو؛ نحفظ اتجاه النظر.", "حضور غير موسيقي؛ بديل ثابت للحركة المخفضة"),
    ("O04", 50, [.02, .08, .98, .26], 4.5, "الثمن", "لا يعرض النظام قبولًا مسبقًا؛ نفهم أن العودة لن تمحو ما حدث.", "الكلام والوقفة واضحان؛ الصوت النهائي غير مؤهل"),
    ("O05", 50, [.02, .44, .98, .61], 0.0, "قرار إيكو", "قرار بلا مؤقت؛ افحص أو أجّل أو ارفض أو اقبل. لا افتراض للقبول.", "الصمت لا يضغط على الاختيار"),
    ("O06", 51, [.02, .23, .98, .45], 3.0, "بعد القبول وحده", "تتطلب اللقطة قبولًا صريحًا في هذه المعاينة؛ لا تمنح حالة حقيقية.", "أثر عقد غير موسيقي، مرة واحدة"),
    ("T01", 52, [.02, .02, .98, .34], 3.5, "عودة الجسد", "نعود لنفس وضع الكرسي والقيود؛ نثبت استمرارية اليد والكتف.", "عودة الأجهزة ونفس غير منتظم"),
    ("T02", 52, [.52, .35, .98, .66], 2.5, "الشق الأول", "ضحكة واحدة قصيرة، ووجه ليس سعيدًا؛ الكتفان ما زالا مقيدين.", "نفس يحمل الضحكة دون تكرار آلي"),
    ("T02", 52, [.02, .35, .52, .66], 2.0, "الأب يسمع الفرق", "نقطع إلى رد كينجا قبل الذروة؛ يتغير الميزان.", "نترك فراغًا لصدى الضحكة ثم رده"),
    ("T02", 53, [.02, .02, .98, .40], 4.0, "تصاعد من أثر الألم", "الفم والعين والصدر لا يتحركون بإيقاع واحد؛ الانفعال متصل بسببه.", "موجتان مختلفتان من الأداء الأصلي ثم قطع"),
    ("T02", 54, [.02, .69, .98, .98], 2.0, "استعادة النظر", "انقطاع مقصود ثم اتصال نظر؛ السيطرة تقرأ قبل العرض الكبير.", "وقفة وضوح، لا زئير مستمر"),
    ("T03", 55, [.02, .02, .98, .40], 3.5, "التحول المكتسب", "هيئة School/Pact المعتمدة والجناح الأيسر وEX-011. اللوحة مرجع للحدث فقط.", "جلد وقماش وتوتر ظلي؛ لا موسيقى"),
    ("T04", 57, [.02, .02, .98, .44], 2.5, "قطع القيد", "كسر الكرسي والقيود يحتاج تماسًا لم يؤهل بعد. اللوحة مرجع لحرية الحركة فقط.", "تماس مادي؛ لا انفجار يلغي السبب"),
    ("T05", 58, [.02, .06, .98, .39], 2.0, "الاتصال الأول", "ضربة قصيرة تثبت مدى واتصالًا وردًا؛ لا نمد الفيلم على حساب اللعب.", "اتصال جسم وثقل ورد فعل"),
    ("C01", 58, [.02, .39, .98, .69], 0.0, "هنا يعود التحكم", "تنتهي اللوحات؛ المطلوب خصم ومدى ومقاومة وقرار حي. لا فيلم آخر.", "صوت القتال يملكه الفعل الحقيقي"),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build() -> None:
    publication = json.loads((PUBLICATION / "publication-manifest.json").read_text(encoding="utf-8-sig"))
    pages = publication["output"]["files"]
    locks = {}
    for page in pages:
        path = PUBLICATION / page["file"]
        actual = sha(path)
        if actual.lower() != page["sha256"].lower():
            raise ValueError(f"Approved publication page changed: {path.name}")
        locks[path.relative_to(APP).as_posix()] = actual
    ledger_path = PRODUCTION / "CINEMATIC_EXPERIENCE_SCENE_LEDGER_2026-11-03.json"
    ledger = json.loads(ledger_path.read_text(encoding="utf-8-sig"))
    sources = {s["id"]: s for s in ledger["scenes"]}
    if len(EVENTS) != 53 or set(sources) != {e[0] for e in EVENTS}:
        raise ValueError("Event coverage must equal the existing 53-event ledger")
    rows = []
    for event_id, page_ids, relation, note in EVENTS:
        rows.append({"event_id": event_id, "event_ar": sources[event_id]["event_ar"],
                     "global_pdf_pages": page_ids, "relation": relation, "source_note_ar": note,
                     "source_event_ledger": ledger_path.relative_to(APP).as_posix(),
                     "visual_review": "CONTACT_SHEET_STRUCTURAL_MAPPING_NOT_LINE_TRANSCRIPTION",
                     "runtime_exposure_authorized_by_this_file": False,
                     "final_dialogue_and_native_implementation": "OPEN"})
    for path in [ledger_path, APP / "docs/internal/narrative/current/ar/manifest.json",
                 APP / "docs/internal/narrative/current/ar/story-bible--echo-network.ar.md",
                 APP / "docs/internal/narrative/current/ar/narrative-master--echo-network.ar.md",
                 PUBLICATION / "publication-manifest.json"]:
        locks[path.relative_to(APP).as_posix()] = sha(path)
    motion_reference = PACKET / "flow/ocean-omni-camera-study-01.mp4"
    if motion_reference.is_file():
        locks[motion_reference.relative_to(APP).as_posix()] = sha(motion_reference)
    write_json(PACKET / "event-source-matrix.json", {
        "schema": 1, "phase": "P01", "status": "STRUCTURAL_SOURCE_MAPPING_REVIEW_DRAFT",
        "publication_id": publication["publicationId"], "page_numbering": "GLOBAL_PDF_INCLUDING_COVER",
        "printed_folio_warning": "Printed folio often differs by one;use global page IDs only.",
        "source_precedence": "Latest owner identity/scene direction;approved Manhwa;Bible;Narrative Master",
        "counts": {"events": 53, "publication_pages": 70},
        "relation_definitions": {"direct": "Observed event motif;not an approved shot/dialogue/asset.",
                                 "support": "Contextual page;literal action/placement additionally relies on Owner/Bible.",
                                 "owner": "No direct page asserted;existing Owner-directed event;content detail remains open."},
        "events": rows})
    shots, clock = [], 0.0
    for i, (event, page, crop, duration, title, acting, sound) in enumerate(SHOTS):
        gate = "explicit_preview_consent" if event == "O05" else "gameplay_handoff" if event == "C01" else ""
        shots.append({"id": f"SH{i+1:02}", "event_id": event, "global_pdf_page": page,
                      "page_path": f"public/manhwa/echo-network-final-2026-09-v1/page-{page:03}.webp",
                      "crop_normalized": crop, "duration_seconds": duration, "editorial_start_seconds": clock,
                      "title_ar": title, "acting_ar": acting, "audio_direction_ar": sound,
                      "gate": gate, "earned_preview_only": i > 12,
                      "source_kind": "REUSED_APPROVED_MANHWA_PANEL_EDITORIAL_REFERENCE",
                      "camera": "STATIC_RM_OR_GENTLE_2PERCENT_PUSH", "native_contact_acceptance": "OPEN"})
        if event in ["O01", "O02"] and motion_reference.is_file():
            shots[-1]["motion_reference"] = {
                "path": motion_reference.relative_to(APP).as_posix(),
                "start_seconds": 0.0 if event == "O01" else 4.0,
                "role": "GENERIC_CAMERA_BUOYANCY_STUDY_NOT_ECHO_IDENTITY_ACCEPTANCE",
                "audio": "MUTED_IN_EDITORIAL_EXPORT;audition remains OPEN"}
        clock += duration
    write_json(PACKET / "editorial-timeline.json", {
        "schema": 1, "phases": ["P05", "P06", "P36", "P37", "P38"],
        "status": "INTERNAL_PANEL_ANIMATIC_NOT_FINAL_GAMEPLAY_OR_ANIMATION",
        "title_ar": "إيكو: من الرفض إلى القرار", "timed_seconds_excluding_player_decisions": clock,
        "dialogue": "No invented final dialogue;approved page text is reference only;JP/localization/voice OPEN.",
        "audio": "Silent editorial;SFX_ONLY directions,not produced or auditioned audio.",
        "authority": "No SaveManager,network,rewards,contract or progression mutations;preview consent is volatile.",
        "requires_before_final": ["P04 original voice and native motion/contact sample", "P05 final dialogue/localization approval", "Owner acting/identity review", "real gameplay handoff/playtest"],
        "shots": shots})
    write_json(PACKET / "source-lock.json", {"schema": 1, "files": locks,
               "protected": "No Golden,body,rig,source keys,Canon pages,production player or default-avatar edits."})
    print(json.dumps({"events": len(rows), "shots": len(shots), "seconds": clock,
                      "source_locks": len(locks), "packet": str(PACKET)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    build()
