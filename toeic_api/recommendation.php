<?php
/**
 * recommendation.php
 * Mengambil soal rekomendasi latihan berdasarkan part yang lemah.
 * Tidak menyimpan apapun ke database — sesi latihan murni di sisi client.
 *
 * GET params:
 *   action=get_questions
 *   part_ids=3,4          (comma-separated part id yang lemah)
 *   user_id=1
 *   limit=20              (jumlah soal per part, default 20)
 */

require_once 'config.php';

header('Content-Type: application/json');

$action   = $_GET['action']   ?? '';
$user_id  = (int)($_GET['user_id'] ?? 0);
$partIds  = $_GET['part_ids'] ?? '';
$limit    = (int)($_GET['limit'] ?? 20);

// ─── Ambil soal rekomendasi (tidak simpan ke DB) ──────────────────────────────
if ($action === 'get_questions' && $user_id && $partIds) {

    // Sanitasi part_ids: hanya angka 1-7
    $rawIds = explode(',', $partIds);
    $validIds = array_filter(array_map('intval', $rawIds), fn($id) => $id >= 1 && $id <= 7);
    $validIds = array_values(array_unique($validIds));

    if (empty($validIds)) {
        echo json_encode(['status' => 'error', 'message' => 'part_ids tidak valid']);
        exit;
    }

    // Ambil skill_level user
    $stmt = $pdo->prepare("SELECT skill_level FROM users WHERE id = ?");
    $stmt->execute([$user_id]);
    $user = $stmt->fetch();
    $skillLevel = $user['skill_level'] ?? 'beginner';

    $result = [];

    foreach ($validIds as $pid) {

        // Ambil soal sesuai difficulty_level user
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
        ");
        $stmt->execute([$pid, $skillLevel]);
        $rows = $stmt->fetchAll();

        // Grup soal untuk Part 3, 4, 6, 7
        if ($pid == 3 || $pid == 4) {
            $groups = groupByAudio($rows);
        } elseif ($pid == 6 || $pid == 7) {
            $groups = groupByPassage($rows);
        } else {
            // Part 1, 2, 5 — shuffle dan ambil langsung
            shuffle($rows);
            $selected = array_slice($rows, 0, $limit);
            $result[] = [
                'part_id'    => $pid,
                'part_name'  => $rows[0]['part_name'] ?? "Part $pid",
                'part_type'  => $rows[0]['part_type'] ?? '',
                'total'      => count($selected),
                'questions'  => $selected,
            ];
            continue;
        }

        // Ambil grup secara acak sampai terpenuhi $limit soal
        $keys     = array_keys($groups);
        shuffle($keys);
        $selected = [];
        foreach ($keys as $key) {
            foreach ($groups[$key] as $item) {
                $selected[] = $item;
            }
            if (count($selected) >= $limit) break;
        }
        $selected = array_slice($selected, 0, $limit);

        $partName = !empty($selected) ? $selected[0]['part_name'] : "Part $pid";
        $partType = !empty($selected) ? $selected[0]['part_type'] : '';

        $result[] = [
            'part_id'   => $pid,
            'part_name' => $partName,
            'part_type' => $partType,
            'total'     => count($selected),
            'questions' => $selected,
        ];
    }

    echo json_encode([
        'status'      => 'success',
        'skill_level' => $skillLevel,
        'parts'       => $result,
    ]);

} else {
    echo json_encode(['status' => 'error', 'message' => 'Parameter tidak lengkap atau action tidak dikenal']);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function groupByAudio(array $rows): array {
    $groups = [];
    foreach ($rows as $row) {
        $key = trim($row['audio_file'] ?? '');
        $groups[$key][] = $row;
    }
    return $groups;
}

function groupByPassage(array $rows): array {
    $groups = [];
    foreach ($rows as $row) {
        $key = substr(trim($row['question_text'] ?? ''), 0, 200);
        $groups[$key][] = $row;
    }
    return $groups;
}
?>