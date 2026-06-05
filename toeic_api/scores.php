<?php
require_once 'config.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);

$action = $_GET['action'] ?? '';

// ─── SIMPAN JAWABAN + HITUNG SKOR ────────────────────────────
if ($action === 'save' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    $attempt_id = $data['attempt_id'] ?? null;
    $answers    = $data['answers']    ?? []; // [{question_id, user_answer, is_correct}]

    if (!$attempt_id || empty($answers)) {
        echo json_encode(["status" => "error", "message" => "attempt_id dan answers diperlukan"]);
        exit();
    }

    // Ambil info attempt dari user_exam_results
    $stmt = $pdo->prepare("SELECT * FROM user_exam_results WHERE id = ?");
    $stmt->execute([$attempt_id]);
    $attempt = $stmt->fetch();

    if (!$attempt) {
        echo json_encode(["status" => "error", "message" => "Attempt tidak ditemukan"]);
        exit();
    }

    // Simpan jawaban user ke user_answers
    // Kolom: exam_result_id, questions_id, user_answers, is_correct
    $stmtAns = $pdo->prepare("
        INSERT INTO user_answers (exam_result_id, questions_id, user_answers, is_correct)
        VALUES (?, ?, ?, ?)
    ");
    foreach ($answers as $ans) {
        $stmtAns->execute([
            $attempt_id,
            $ans['question_id'],
            $ans['user_answer'],
            $ans['is_correct'] ? 1 : 0
        ]);
    }

    $totalQuestions = count($answers);
    $correctAnswers = count(array_filter($answers, fn($a) => $a['is_correct']));
    $accuracy       = $totalQuestions > 0 ? round(($correctAnswers / $totalQuestions) * 100, 2) : 0;

    // ── SIMULASI ──────────────────────────────────────────────
    if ($attempt['exam_type'] === 'simulation') {
        $listeningCorrect = 0;
        $listeningTotal   = 0;
        $readingCorrect   = 0;
        $readingTotal     = 0;

        foreach ($answers as $ans) {
            $stmtQ = $pdo->prepare("
                SELECT tp.type FROM questions q
                JOIN toeic_parts tp ON q.part_id = tp.id
                WHERE q.id = ?
            ");
            $stmtQ->execute([$ans['question_id']]);
            $partType = $stmtQ->fetchColumn();

            if ($partType === 'listening') {
                $listeningTotal++;
                if ($ans['is_correct']) $listeningCorrect++;
            } else {
                $readingTotal++;
                if ($ans['is_correct']) $readingCorrect++;
            }
        }

        // Skala TOEIC (maks 495 per bagian)
        $listeningScore = $listeningCorrect * 5;
        $readingScore   = $readingCorrect * 4;
        $totalScore     = $listeningScore + $readingScore;

        // Tentukan kategori
        if ($totalScore < 500) {
            $scoreCategory = 'rendah';
        } elseif ($totalScore < 700) {
            $scoreCategory = 'sedang';
        } else {
            $scoreCategory = 'tinggi';
        }
        $listeningLevel  = $listeningScore < 167 ? 'lemah' : ($listeningScore <= 334 ? 'cukup' : 'kuat');
        $readingLevel    = $readingScore < 165 ? 'lemah' : ($readingScore <= 330 ? 'cukup' : 'kuat');

        // Update user_exam_results dengan hasil skor simulasi
        $stmtDurasi = $pdo->prepare("
            SELECT TIMESTAMPDIFF(
                MINUTE,
                started_at,
                NOW()
            )
            FROM user_exam_results
            WHERE id = ?
        ");
        $stmtDurasi->execute([$attempt_id]);

        $durationMinutes = (int)$stmtDurasi->fetchColumn();
        $stmt = $pdo->prepare("
            UPDATE user_exam_results SET
                total_score      = ?,
                listening_score  = ?,
                reading_score    = ?,
                score_category   = ?,
                listening_level  = ?,
                reading_level    = ?,
                duration_minutes = ?,
                finished_at      = NOW()
            WHERE id = ?
        ");
        $stmt->execute([
            $totalScore, 
            $listeningScore, 
            $readingScore,
            $scoreCategory, 
            $listeningLevel, 
            $readingLevel, 
            $durationMinutes,
            $attempt_id
        ]);

        // Ambil motivasi dari tabel feedbacks
        $motivation = getMotivation($pdo, $scoreCategory, $listeningLevel, $readingLevel);

        echo json_encode([
            "status"          => "success",
            "type"            => "simulation",
            "attempt_id"      => (int)$attempt_id,
            "total_questions" => $totalQuestions,
            "correct_answers" => $correctAnswers,
            "accuracy"        => $accuracy,
            "listening_score" => $listeningScore,
            "reading_score"   => $readingScore,
            "total_score"     => $totalScore,
            "score_category"  => $scoreCategory,
            "listening_level" => $listeningLevel,
            "reading_level"   => $readingLevel,
            "motivation"      => $motivation
        ]);

    // ── LATIHAN ───────────────────────────────────────────────
    } else {
        // Untuk latihan: total_score = jumlah benar, listening/reading = 0
        $stmt = $pdo->prepare("
            UPDATE user_exam_results SET
                total_score  = ?,
                finished_at  = NOW()
            WHERE id = ?
        ");
        $stmt->execute([$correctAnswers, $attempt_id]);

        echo json_encode([
            "status"          => "success",
            "type"            => "practice",
            "attempt_id"      => (int)$attempt_id,
            "total_questions" => $totalQuestions,
            "correct_answers" => $correctAnswers,
            "accuracy"        => $accuracy
        ]);
    }
}

// ─── RIWAYAT SKOR USER ────────────────────────────────────────
elseif ($action === 'history') {
    $user_id = $_GET['user_id'] ?? null;
    if (!$user_id) {
        echo json_encode(["status" => "error", "message" => "user_id diperlukan"]);
        exit();
    }

    $stmt = $pdo->prepare("
        SELECT
            uer.id          AS attempt_id,
            uer.exam_type,
            uer.total_score,
            uer.listening_score,
            uer.reading_score,
            uer.score_category,
            uer.listening_level,
            uer.reading_level,
            uer.started_at,
            uer.finished_at,
            tp.name         AS part_name
        FROM user_exam_results uer
        LEFT JOIN toeic_parts tp ON uer.parts_id = tp.id
        WHERE uer.users_id = ?
        ORDER BY uer.created_at DESC
        LIMIT 20
    ");
    $stmt->execute([$user_id]);

    echo json_encode(["status" => "success", "data" => $stmt->fetchAll()]);
}

else {
    echo json_encode(["status" => "error", "message" => "Action tidak dikenali"]);
}

// ─── FUNGSI MOTIVASI DARI TABEL feedbacks ─────────────────────
function getMotivation($pdo, $scoreCategory, $listeningLevel, $readingLevel) {
    $stmt = $pdo->prepare("
        SELECT motivations FROM feedbacks
        WHERE score_category   = ?
          AND listening_level  = ?
          AND reading_level    = ?
        ORDER BY RAND()
        LIMIT 1
    ");
    $stmt->execute([$scoreCategory, $listeningLevel, $readingLevel]);
    $row = $stmt->fetch();

    return $row['motivations'] ?? "Kerja bagus! Terus berlatih untuk meningkatkan skormu. Semangat!";
}
?>