<?php
/**
 * recommendation.php
 * Mengambil soal rekomendasi berdasarkan section yang lemah.
 *
 * GET params:
 *   action=get_questions
 *   user_id=1
 *   section=listening | reading | both
 *   limit=30   (total soal yang diambil)
 */

// Bersihkan output buffer agar tidak ada warning/notice PHP yang bocor ke JSON
ob_start();

require_once 'config.php';

// Bersihkan apapun yang mungkin sudah dicetak oleh config.php
ob_clean();

header('Content-Type: application/json');

$action  = $_GET['action']  ?? '';
$user_id = (int)($_GET['user_id'] ?? 0);
$section = $_GET['section'] ?? 'both'; // listening | reading | both
$limit   = (int)($_GET['limit'] ?? 30);

// Gunakan variabel biasa, bukan const, agar aman saat di-include ulang
$listeningParts = [1, 2, 3, 4];
$readingParts   = [5, 6, 7];

if ($action === 'get_questions' && $user_id > 0) {

    // Tentukan part id yang diambil berdasarkan section
    switch ($section) {
        case 'listening':
            $partIds = $listeningParts;
            break;
        case 'reading':
            $partIds = $readingParts;
            break;
        case 'both':
        default:
            $partIds = array_merge($listeningParts, $readingParts);
            break;
    }

    // Ambil skill_level user
    $stmt = $pdo->prepare("SELECT skill_level FROM users WHERE id = ?");
    $stmt->execute([$user_id]);
    $user       = $stmt->fetch(PDO::FETCH_ASSOC);
    $skillLevel = $user ? ($user['skill_level'] ?? 'beginner') : 'beginner';

    // Distribusi soal merata antar part:
    // floor(limit / jumlahPart) per part, sisa dibagikan ke part-part pertama
    $jumlahPart = count($partIds);
    $perPart    = (int) floor($limit / $jumlahPart);
    $sisa       = $limit - ($perPart * $jumlahPart);

    // Kocok urutan part SEBELUM assign indeks agar distribusi sisa acak
    shuffle($partIds);

    $allQuestions = [];

    foreach ($partIds as $idx => $pid) {
        $partLimit = $perPart + ($idx < $sisa ? 1 : 0);
        if ($partLimit <= 0) continue;

        $stmt = $pdo->prepare("
            SELECT
                q.id,
                q.part_id,
                q.question_text,
                q.option_a,
                q.option_b,
                q.option_c,
                q.option_d,
                q.correct_answer,
                q.explanation,
                q.image_file,
                q.audio_file,
                q.difficulty_level,
                tp.name AS part_name,
                tp.type AS part_type
            FROM questions q
            JOIN toeic_parts tp ON q.part_id = tp.id
            WHERE q.part_id = ?
              AND q.difficulty_level = ?
            ORDER BY RAND()
            LIMIT ?
        ");
        $stmt->bindValue(1, (int) $pid,        PDO::PARAM_INT);
        $stmt->bindValue(2,       $skillLevel,  PDO::PARAM_STR);
        $stmt->bindValue(3, (int) $partLimit,   PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($rows as $row) {
            $allQuestions[] = $row;
        }
    }

    // Kelompokkan berdasarkan part_id, urut Part 1→7
    $grouped = [];
    foreach ($allQuestions as $q) {
        $pid = (int) $q['part_id'];
        if (!isset($grouped[$pid])) {
            $grouped[$pid] = [
                'part_id'   => $pid,
                'part_name' => $q['part_name'],
                'part_type' => $q['part_type'],
                'questions' => [],
            ];
        }
        $grouped[$pid]['questions'][] = $q;
    }

    ksort($grouped);

    foreach ($grouped as &$part) {
        $part['total'] = count($part['questions']);
    }
    unset($part);

    // Bersihkan buffer sekali lagi sebelum output JSON
    ob_clean();
    echo json_encode([
        'status'      => 'success',
        'section'     => $section,
        'skill_level' => $skillLevel,
        'total_soal'  => count($allQuestions),
        'parts'       => array_values($grouped),
    ]);

} else {
    ob_clean();
    echo json_encode([
        'status'  => 'error',
        'message' => 'Parameter tidak lengkap atau action tidak dikenal',
    ]);
}