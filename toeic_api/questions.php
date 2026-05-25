<?php
require_once 'config.php';

$action  = $_GET['action']  ?? '';
$part_id = $_GET['part_id'] ?? null;
$user_id = $_GET['user_id'] ?? null;

// ─── SOAL PRACTICE (acak per part) ───────────────────────────
if ($action === 'practice' && $part_id && $user_id) {

    // Buat attempt baru di user_exam_results dengan exam_type='practice'
    $attempt_code = uniqid('prc_', true);

    $stmt = $pdo->prepare("
        INSERT INTO user_exam_results
            (attempt_code, users_id, exam_type, parts_id, started_at)
        VALUES (?, ?, 'practice', ?, NOW())
    ");
    $stmt->execute([$attempt_code, $user_id, $part_id]);
    $attempt_id = $pdo->lastInsertId();

    // Ambil soal untuk part ini
    $stmt = $pdo->prepare("
        SELECT q.id, q.part_id, q.question_text,
               q.option_a, q.option_b, q.option_c, q.option_d,
               q.correct_answer, q.explanation,
               q.image_file, q.audio_file, q.difficulty_level,
               tp.name AS part_name, tp.type AS part_type
        FROM questions q
        JOIN toeic_parts tp ON q.part_id = tp.id
        WHERE q.part_id = ?
        ORDER BY q.id ASC
    ");
    $stmt->execute([$part_id]);
    $questions = $stmt->fetchAll();

    echo json_encode([
        "status"     => "success",
        "attempt_id" => (int)$attempt_id,
        "part_id"    => (int)$part_id,
        "total"      => count($questions),
        "data"       => $questions
    ]);
}

// ─── SOAL SIMULASI (semua part sesuai proporsi) ───────────────
elseif ($action === 'simulation' && $user_id) {

    // Buat attempt baru di user_exam_results dengan exam_type='simulation'
    $attempt_code = uniqid('sim_', true);

    $stmt = $pdo->prepare("
        INSERT INTO user_exam_results
            (attempt_code, users_id, exam_type, parts_id, started_at)
        VALUES (?, ?, 'simulation', NULL, NOW())
    ");
    $stmt->execute([$attempt_code, $user_id]);
    $attempt_id = $pdo->lastInsertId();

    // Ambil soal per part sesuai proporsi TOEIC
    $limits = [1 => 6, 2 => 25, 3 => 39, 4 => 30, 5 => 40, 6 => 16, 7 => 54];
    $allQuestions = [];

    foreach ($limits as $pid => $limit) {
        $stmt = $pdo->prepare("
            SELECT q.id, q.part_id, q.question_text,
                   q.option_a, q.option_b, q.option_c, q.option_d,
                   q.correct_answer, q.explanation,
                   q.image_file, q.audio_file, q.difficulty_level,
                   tp.name AS part_name, tp.type AS part_type
            FROM questions q
            JOIN toeic_parts tp ON q.part_id = tp.id
            WHERE q.part_id = ?
            ORDER BY RAND()
            LIMIT ?
        ");
        $stmt->execute([$pid, $limit]);
        $allQuestions = array_merge($allQuestions, $stmt->fetchAll());
    }

    echo json_encode([
        "status"     => "success",
        "attempt_id" => (int)$attempt_id,
        "total"      => count($allQuestions),
        "data"       => $allQuestions
    ]);
}

else {
    echo json_encode([
        "status"  => "error",
        "message" => "Action tidak dikenali atau parameter kurang"
    ]);
}
?>