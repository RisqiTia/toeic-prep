<?php
require_once 'config.php';

$action = $_GET['action'] ?? '';

// ─── SIMPAN HASIL SIMULASI ────────────────────────────────────
if ($action === 'save_simulation' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    $user_id         = $data['user_id']         ?? null;
    $listening_score = $data['listening_score']  ?? 0;
    $reading_score   = $data['reading_score']    ?? 0;
    $total_score     = $listening_score + $reading_score;

    if (!$user_id) {
        echo json_encode(["status" => "error", "message" => "User ID diperlukan"]);
        exit();
    }

    // Simpan ke tabel scores
    $stmt = $pdo->prepare("
        INSERT INTO scores (user_id, listening_score, reading_score, total_score, date_taken)
        VALUES (?, ?, ?, ?, NOW())
    ");
    $stmt->execute([$user_id, $listening_score, $reading_score, $total_score]);

    // Buat pesan motivasi berdasarkan skor
    $motivation = generateMotivation($listening_score, $reading_score);

    echo json_encode([
        "status"          => "success",
        "message"         => "Skor berhasil disimpan",
        "total_score"     => $total_score,
        "listening_score" => $listening_score,
        "reading_score"   => $reading_score,
        "motivation"      => $motivation
    ]);
}

// ─── AMBIL RIWAYAT SKOR USER ──────────────────────────────────
elseif ($action === 'history') {
    $user_id = $_GET['user_id'] ?? null;

    if (!$user_id) {
        echo json_encode(["status" => "error", "message" => "User ID diperlukan"]);
        exit();
    }

    $stmt = $pdo->prepare("
        SELECT * FROM scores
        WHERE user_id = ?
        ORDER BY date_taken DESC
        LIMIT 10
    ");
    $stmt->execute([$user_id]);
    $scores = $stmt->fetchAll();

    echo json_encode(["status" => "success", "data" => $scores]);
}

else {
    echo json_encode(["status" => "error", "message" => "Action tidak dikenali"]);
}

// ─── FUNGSI MOTIVASI ──────────────────────────────────────────
function generateMotivation($listening, $reading) {
    $total = $listening + $reading;

    // Tentukan bagian yang lemah
    if ($listening > $reading + 50) {
        return "Kemampuan listening kamu sudah bagus! Sekarang saatnya fokus tingkatkan kemampuan reading dan grammar kamu. Terus semangat! 💪";
    } elseif ($reading > $listening + 50) {
        return "Reading kamu sudah kuat! Kini fokuslah berlatih mendengarkan lebih banyak audio TOEIC untuk meningkatkan listening kamu. Kamu bisa! 🎧";
    } elseif ($total >= 800) {
        return "Luar biasa! Skor kamu sangat tinggi. Pertahankan dan terus asah kemampuanmu untuk hasil yang lebih sempurna! 🏆";
    } elseif ($total >= 600) {
        return "Bagus! Kamu sudah di jalur yang benar. Perbanyak latihan soal dan materi untuk mendorong skor lebih tinggi lagi! 🌟";
    } elseif ($total >= 400) {
        return "Kamu sudah cukup baik! Fokuskan latihan pada bagian yang masih kurang dan jangan lupa review setiap jawaban salahmu. Semangat! 📚";
    } else {
        return "Ini baru permulaan! Setiap ahli pernah menjadi pemula. Mulailah dengan mempelajari materi dan rutin berlatih setiap hari. Kamu pasti bisa! 🚀";
    }
}
?>