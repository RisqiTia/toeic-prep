<?php
require_once 'config.php';

$action = $_GET['action'] ?? '';

// ─── SIMPAN JAWABAN + HITUNG SKOR ────────────────────────────
if ($action === 'save' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    $attempt_id = $data['attempt_id'] ?? null;
    $answers    = $data['answers']    ?? []; // array of {question_id, user_answer, is_correct}

    if (!$attempt_id || empty($answers)) {
        echo json_encode(["status" => "error", "message" => "attempt_id dan answers diperlukan"]);
        exit();
    }

    // Tandai attempt selesai
    $stmt = $pdo->prepare("UPDATE test_attempts SET finished_at = NOW() WHERE id = ?");
    $stmt->execute([$attempt_id]);

    // Simpan semua jawaban user ke user_answers
    $stmtAns = $pdo->prepare("
        INSERT INTO user_answers (attempt_id, question_id, user_answer, is_correct)
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

    // Ambil info attempt (type-nya apa: latihan atau simulasi)
    $stmt = $pdo->prepare("SELECT * FROM test_attempts WHERE id = ?");
    $stmt->execute([$attempt_id]);
    $attempt = $stmt->fetch();

    // Hitung skor berdasarkan type
    $totalQuestions  = count($answers);
    $correctAnswers  = count(array_filter($answers, fn($a) => $a['is_correct']));
    $accuracy        = $totalQuestions > 0 ? round(($correctAnswers / $totalQuestions) * 100, 2) : 0;

    if ($attempt['type'] === 'simulasi') {
        // Hitung listening score dan reading score secara terpisah
        // Listening = part 1-4, Reading = part 5-7
        $listeningCorrect = 0;
        $listeningTotal   = 0;
        $readingCorrect   = 0;
        $readingTotal     = 0;

        foreach ($answers as $ans) {
            // Cek part_id soal ini
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

        // Konversi ke skala TOEIC (maks 495 per bagian)
        $listeningScore = $listeningTotal > 0
            ? (int)round(($listeningCorrect / $listeningTotal) * 495) : 0;
        $readingScore   = $readingTotal > 0
            ? (int)round(($readingCorrect / $readingTotal) * 495) : 0;
        $totalScore     = $listeningScore + $readingScore;

        // Simpan ke tabel scores
        $stmt = $pdo->prepare("
            INSERT INTO scores (attempt_id, listening_score, reading_score, total_score, accuracy)
            VALUES (?, ?, ?, ?, ?)
        ");
        $stmt->execute([$attempt_id, $listeningScore, $readingScore, $totalScore, $accuracy]);

        // Ambil pesan motivasi dari tabel feedbacks
        $motivation = getMotivation($pdo, $totalScore, $listeningScore, $readingScore);

        echo json_encode([
            "status"          => "success",
            "type"            => "simulasi",
            "attempt_id"      => (int)$attempt_id,
            "total_questions" => $totalQuestions,
            "correct_answers" => $correctAnswers,
            "accuracy"        => $accuracy,
            "listening_score" => $listeningScore,
            "reading_score"   => $readingScore,
            "total_score"     => $totalScore,
            "motivation"      => $motivation
        ]);

    } else {
        // Latihan: cukup simpan accuracy saja, score = jumlah benar
        $stmt = $pdo->prepare("
            INSERT INTO scores (attempt_id, listening_score, reading_score, total_score, accuracy)
            VALUES (?, 0, 0, ?, ?)
        ");
        $stmt->execute([$attempt_id, $correctAnswers, $accuracy]);

        echo json_encode([
            "status"          => "success",
            "type"            => "latihan",
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
        SELECT ta.id AS attempt_id, ta.type, ta.started_at, ta.finished_at,
               s.listening_score, s.reading_score, s.total_score, s.accuracy,
               tp.name AS part_name
        FROM test_attempts ta
        LEFT JOIN scores s ON s.attempt_id = ta.id
        LEFT JOIN toeic_parts tp ON ta.part_id = tp.id
        WHERE ta.user_id = ?
        ORDER BY ta.started_at DESC
        LIMIT 20
    ");
    $stmt->execute([$user_id]);

    echo json_encode(["status" => "success", "data" => $stmt->fetchAll()]);
}

else {
    echo json_encode(["status" => "error", "message" => "Action tidak dikenali"]);
}

// ─── FUNGSI AMBIL MOTIVASI DARI TABEL feedbacks ──────────────
function getMotivation($pdo, $totalScore, $listeningScore, $readingScore) {
    // Tentukan score_category
    if ($totalScore < 400) {
        $scoreCategory = 'rendah';
    } elseif ($totalScore <= 700) {
        $scoreCategory = 'sedang';
    } else {
        $scoreCategory = 'tinggi';
    }

    // Tentukan listening_level
    if ($listeningScore < 165) {
        $listeningLevel = 'lemah';
    } elseif ($listeningScore <= 330) {
        $listeningLevel = 'cukup';
    } else {
        $listeningLevel = 'kuat';
    }

    // Tentukan reading_level
    if ($readingScore < 165) {
        $readingLevel = 'lemah';
    } elseif ($readingScore <= 330) {
        $readingLevel = 'cukup';
    } else {
        $readingLevel = 'kuat';
    }

    // Cari motivasi yang cocok dari tabel feedbacks, ambil 1 secara acak
    $stmt = $pdo->prepare("
        SELECT motivations FROM feedbacks
        WHERE score_category = ?
          AND listening_level = ?
          AND reading_level = ?
        ORDER BY RAND()
        LIMIT 1
    ");
    $stmt->execute([$scoreCategory, $listeningLevel, $readingLevel]);
    $row = $stmt->fetch();

    // Fallback kalau tidak ada yang cocok
    return $row['motivations'] ?? "Kerja bagus! Terus berlatih untuk meningkatkan skormu. Semangat!";
}
?>
