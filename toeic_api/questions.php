<?php
require_once 'config.php';

$action  = $_GET['action']  ?? '';
$part_id = $_GET['part_id'] ?? null;
$user_id = $_GET['user_id'] ?? null;

// ─── SOAL PRACTICE (10-12 soal per part, acak) ───────────────
if ($action === 'practice' && $part_id && $user_id) {

    // Buat test_attempt dulu dengan type='latihan' dan part_id
    $stmt = $pdo->prepare("
        INSERT INTO test_attempts (user_id, type, part_id, started_at)
        VALUES (?, 'latihan', ?, NOW())
    ");
    $stmt->execute([$user_id, $part_id]);
    $attempt_id = $pdo->lastInsertId();

    // Ambil soal acak untuk part ini
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
        LIMIT 12
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

    // Buat test_attempt dengan type='simulasi' (part_id = NULL)
    $stmt = $pdo->prepare("
        INSERT INTO test_attempts (user_id, type, part_id, started_at)
        VALUES (?, 'simulasi', NULL, NOW())
    ");
    $stmt->execute([$user_id]);
    $attempt_id = $pdo->lastInsertId();

    // Ambil soal per part sesuai proporsi
    $limits = [1 => 6, 2 => 10, 3 => 10, 4 => 10, 5 => 15, 6 => 8, 7 => 16];
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
        "message" => "Action tidak dikenali atau parameter kurang (butuh user_id)"
    ]);
}
?>
