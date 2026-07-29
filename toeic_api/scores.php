<?php
/**
 * scores.php  — versi diperbarui
 *
 * Perubahan utama:
 *  - Perhitungan skor simulasi kini menggunakan tabel konversi
 *    `toeic_score_conversion` (raw_score → scaled_score) sebagai
 *    pengganti rumus tetap sebelumnya.
 *  - Simulasi mengembalikan `weak_parts` (daftar part_id
 *    yang skornya rendah, diurutkan dari yang terlemah) beserta
 *    `weak_parts_info` (nama part) untuk kebutuhan rekomendasi latihan.
 *  - Threshold naik level: >= 500 naik level.
 */

require_once 'config.php';

error_reporting(E_ALL);
ini_set('display_errors', 1);

$action = $_GET['action'] ?? '';

// ─── SIMPAN JAWABAN + HITUNG SKOR ────────────────────────────
if ($action === 'save' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    $attempt_id = $data['attempt_id'] ?? null;
    $answers    = $data['answers']    ?? [];

    if (!$attempt_id || empty($answers)) {
        echo json_encode(["status" => "error", "message" => "attempt_id dan answers diperlukan"]);
        exit();
    }

    $stmt = $pdo->prepare("SELECT * FROM user_exam_results WHERE id = ?");
    $stmt->execute([$attempt_id]);
    $attempt = $stmt->fetch();

    if (!$attempt) {
        echo json_encode(["status" => "error", "message" => "Attempt tidak ditemukan"]);
        exit();
    }

    // Simpan jawaban user ke user_answers
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

        // Statistik per part: [part_id => ['correct'=>x,'total'=>y,'name'=>z,'type'=>w]]
        $partStats = [];

        foreach ($answers as $ans) {
            $stmtQ = $pdo->prepare("
                SELECT q.part_id, tp.type AS part_type, tp.name AS part_name
                FROM questions q
                JOIN toeic_parts tp ON q.part_id = tp.id
                WHERE q.id = ?
            ");
            $stmtQ->execute([$ans['question_id']]);
            $qInfo = $stmtQ->fetch();

            if (!$qInfo) continue;

            $pid = (int)$qInfo['part_id'];

            if (!isset($partStats[$pid])) {
                $partStats[$pid] = [
                    'part_id'   => $pid,
                    'part_name' => $qInfo['part_name'],
                    'part_type' => $qInfo['part_type'],
                    'correct'   => 0,
                    'total'     => 0,
                ];
            }

            $partStats[$pid]['total']++;
            if ($ans['is_correct']) $partStats[$pid]['correct']++;

            if ($qInfo['part_type'] === 'listening') {
                $listeningTotal++;
                if ($ans['is_correct']) $listeningCorrect++;
            } else {
                $readingTotal++;
                if ($ans['is_correct']) $readingCorrect++;
            }
        }

        // // Hitung akurasi per part & urutkan dari yang paling lemah
        // foreach ($partStats as &$ps) {
        //     $ps['accuracy'] = $ps['total'] > 0
        //         ? round(($ps['correct'] / $ps['total']) * 100, 1)
        //         : 0;
        // }
        // unset($ps);

        // uasort($partStats, fn($a, $b) => $a['accuracy'] <=> $b['accuracy']);
        // $weakPartsOrdered = array_values($partStats);

        // ── HITUNG SKOR DENGAN TABEL KONVERSI ──────────────────
        $stmtConvL = $pdo->prepare("
            SELECT scaled_score
            FROM toeic_score_conversion
            WHERE section = 'listening' AND raw_score = ?
        ");
        $stmtConvL->execute([$listeningCorrect]);
        $rowL = $stmtConvL->fetch();
        $listeningScore = $rowL ? (int)$rowL['scaled_score'] : 5;

        $stmtConvR = $pdo->prepare("
            SELECT scaled_score
            FROM toeic_score_conversion
            WHERE section = 'reading' AND raw_score = ?
        ");
        $stmtConvR->execute([$readingCorrect]);
        $rowR = $stmtConvR->fetch();
        $readingScore = $rowR ? (int)$rowR['scaled_score'] : 5;

        $totalScore = $listeningScore + $readingScore;
        // ────────────────────────────────────────────────────────

        // Kategori skor keseluruhan (untuk memilih pesan motivasi)
        if ($totalScore < 500) {
            $scoreCategory = 'rendah';
        } elseif ($totalScore < 700) {
            $scoreCategory = 'sedang';
        } else {
            $scoreCategory = 'tinggi';
        }

        // Level per section (untuk memilih pesan motivasi)
        // Listening: lemah < 275 | cukup 275–400 | kuat > 400
        // Reading  : lemah < 275 | cukup 275–385 | kuat > 385
        $listeningLevel = $listeningScore < 275 ? 'lemah' : ($listeningScore <= 400 ? 'cukup' : 'kuat');
        $readingLevel   = $readingScore   < 275 ? 'lemah' : ($readingScore   <= 385 ? 'cukup' : 'kuat');

        // Durasi
        $stmtDurasi = $pdo->prepare("
            SELECT TIMESTAMPDIFF(MINUTE, started_at, NOW())
            FROM user_exam_results WHERE id = ?
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
            $totalScore, $listeningScore, $readingScore,
            $scoreCategory, $listeningLevel, $readingLevel,
            $durationMinutes, $attempt_id
        ]);

        // Motivasi
        $motivation = getMotivation($pdo, $scoreCategory, $listeningLevel, $readingLevel);

        $weakParts = array_map(fn($p) => [
            'part_id'   => $p['part_id'],
            'part_name' => $p['part_name'],
            'part_type' => $p['part_type'],
            'accuracy'  => $p['accuracy'],
            'correct'   => $p['correct'],
            'total'     => $p['total'],
        ], $weakPartsOrdered);

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
            "motivation"      => $motivation,
            "weak_parts"      => $weakParts,
        ]);

    // ── LATIHAN ───────────────────────────────────────────────
    } else {
        $stmt = $pdo->prepare("
            UPDATE user_exam_results SET
                total_score = ?,
                finished_at = NOW()
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

// ─── Motivasi dari tabel feedbacks ───────────────────────────
function getMotivation($pdo, $scoreCategory, $listeningLevel, $readingLevel) {
    $stmt = $pdo->prepare("
        SELECT motivations FROM feedbacks
        WHERE score_category  = ?
          AND listening_level = ?
          AND reading_level   = ?
        ORDER BY RAND()
        LIMIT 1
    ");
    $stmt->execute([$scoreCategory, $listeningLevel, $readingLevel]);
    $row = $stmt->fetch();
    return $row['motivations'] ?? "Kerja bagus! Terus berlatih untuk meningkatkan skormu. Semangat!";
}
?>