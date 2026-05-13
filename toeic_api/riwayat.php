<?php
require_once 'config.php';

$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;

if ($user_id === 0) {
    echo json_encode(['status' => 'error', 'message' => 'user_id tidak valid']);
    exit;
}

// ─── Ambil semua riwayat dari user_exam_results ───────────────
$stmt = $pdo->prepare("
    SELECT
        uer.id              AS id,
        uer.exam_type,
        uer.total_score,
        uer.listening_score,
        uer.reading_score,
        uer.score_category,
        uer.finished_at,
        uer.created_at,
        tp.name             AS part_name,
        tp.id               AS part_id
    FROM user_exam_results uer
    LEFT JOIN toeic_parts tp ON uer.parts_id = tp.id
    WHERE uer.users_id = ?
      AND uer.finished_at IS NOT NULL
    ORDER BY uer.created_at DESC
    LIMIT 50
");
$stmt->execute([$user_id]);
$rows = $stmt->fetchAll();

// Hitung nomor urut per tipe (simulasi ke-1, ke-2, dst)
// Karena sudah DESC, kita balik dulu untuk hitung nomor, lalu balik lagi
$simCount = 0;
$latCount = 0;

// Hitung total dulu untuk numbering dari bawah
$totalSim = 0;
$totalLat = 0;
foreach ($rows as $r) {
    if ($r['exam_type'] === 'simulation') $totalSim++;
    else $totalLat++;
}

$result = [];
$simIdx = $totalSim;
$latIdx = $totalLat;

foreach ($rows as $row) {
    $isSimulasi = $row['exam_type'] === 'simulation';

    // Judul dengan nomor urut
    if ($isSimulasi) {
        $title = 'Simulasi Test ' . $simIdx;
        $simIdx--;
    } else {
        $partName = $row['part_name'] ?? 'Part';
        $title    = 'Latihan ' . $partName;
        $latIdx--;
    }

    // Format tanggal
    $date = formatDate($row['created_at']);

    // Skor
    if ($isSimulasi) {
        $score      = (int)$row['total_score'];
        $scoreLabel = 'Skor';
    } else {
        // Hitung akurasi dari user_answers
        $stmtAcc = $pdo->prepare("
            SELECT COUNT(*) AS total, SUM(is_correct) AS correct
            FROM user_answers
            WHERE exam_result_id = ?
        ");
        $stmtAcc->execute([$row['id']]);
        $acc   = $stmtAcc->fetch();
        $total = (int)($acc['total'] ?? 0);
        $score = $total > 0
            ? (int)round(($acc['correct'] / $total) * 100)
            : 0;
        $scoreLabel = 'Akurasi';
    }

    $result[] = [
        'id'              => (int)$row['id'],
        'type'            => $isSimulasi ? 'simulasi' : 'latihan',
        'title'           => $title,
        'date'            => $date,
        'score'           => $score,
        'score_label'     => $scoreLabel,
        'part_name'       => $row['part_name'] ?? '',
        'listening_score' => $isSimulasi ? (int)$row['listening_score'] : null,
        'reading_score'   => $isSimulasi ? (int)$row['reading_score']   : null,
        'score_category'  => $row['score_category'] ?? null,
    ];
}

// Skor simulasi terakhir = simulasi pertama di list (sudah DESC)
$lastSimulasiScore = 0;
foreach ($result as $item) {
    if ($item['type'] === 'simulasi') {
        $lastSimulasiScore = $item['score'];
        break;
    }
}

echo json_encode([
    'status'              => 'success',
    'last_simulasi_score' => $lastSimulasiScore,
    'data'                => $result,
]);

// ─── Helper: format tanggal ───────────────────────────────────
function formatDate($datetime) {
    if (!$datetime) return '-';
    $ts = strtotime($datetime);

    $today     = date('Y-m-d');
    $yesterday = date('Y-m-d', strtotime('-1 day'));
    $dateOnly  = date('Y-m-d', $ts);
    $time      = date('h:i A', $ts);

    if ($dateOnly === $today) {
        return 'Hari ini, ' . $time;
    } elseif ($dateOnly === $yesterday) {
        return 'Kemarin, ' . $time;
    } else {
        $months = [
            '01'=>'Jan','02'=>'Feb','03'=>'Mar','04'=>'Apr',
            '05'=>'Mei','06'=>'Jun','07'=>'Jul','08'=>'Agu',
            '09'=>'Sep','10'=>'Okt','11'=>'Nov','12'=>'Des'
        ];
        $d = date('d', $ts);
        $m = $months[date('m', $ts)];
        return "$d $m, $time";
    }
}
?>