<?php
require_once 'config.php';

$action  = $_GET['action']  ?? '';
$part_id = $_GET['part_id'] ?? null;

// ─── SOAL PRACTICE (10-12 soal per part, acak) ───────────────
if ($action === 'practice' && $part_id) {
    $stmt = $pdo->prepare("
        SELECT id, part_id, question_text, option_a, option_b, option_c, option_d,
               correct_answer, explanation, image_file, audio_file, difficulty_level
        FROM questions
        WHERE part_id = ?
        ORDER BY RAND()
        LIMIT 12
    ");
    $stmt->execute([$part_id]);
    $questions = $stmt->fetchAll();

    echo json_encode([
        "status" => "success",
        "part_id" => (int)$part_id,
        "total"  => count($questions),
        "data"   => $questions
    ]);
}

// ─── SOAL SIMULASI (semua part, sesuai proporsi real TOEIC) ──
elseif ($action === 'simulation') {
    /*
     * Proporsi soal simulasi per part (disederhanakan):
     * Part 1: 6 soal   | Part 2: 25 soal  | Part 3: 39 soal
     * Part 4: 30 soal  | Part 5: 40 soal  | Part 6: 16 soal
     * Part 7: 54 soal
     * Total: 200 soal (real TOEIC)
     *
     * Karena soal di DB terbatas, kita ambil sebanyak yang ada
     * per part dengan batas berikut:
     */
    $limits = [1 => 6, 2 => 10, 3 => 10, 4 => 10, 5 => 15, 6 => 8, 7 => 16];
    $allQuestions = [];

    foreach ($limits as $pid => $limit) {
        $stmt = $pdo->prepare("
            SELECT id, part_id, question_text, option_a, option_b, option_c, option_d,
                   correct_answer, explanation, image_file, audio_file, difficulty_level
            FROM questions
            WHERE part_id = ?
            ORDER BY RAND()
            LIMIT ?
        ");
        $stmt->execute([$pid, $limit]);
        $rows = $stmt->fetchAll();
        $allQuestions = array_merge($allQuestions, $rows);
    }

    echo json_encode([
        "status" => "success",
        "total"  => count($allQuestions),
        "data"   => $allQuestions
    ]);
}

else {
    echo json_encode(["status" => "error", "message" => "Action tidak dikenali atau part_id kosong"]);
}
?>