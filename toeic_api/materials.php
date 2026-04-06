<?php
require_once 'config.php';

$action  = $_GET['action']  ?? 'all';
$part_id = $_GET['part_id'] ?? null;

// ─── AMBIL SEMUA PART (untuk daftar menu materi) ─────────────
if ($action === 'parts') {
    $stmt = $pdo->query("SELECT * FROM toeic_parts ORDER BY id");
    $parts = $stmt->fetchAll();
    echo json_encode(["status" => "success", "data" => $parts]);
}

// ─── AMBIL MATERI BERDASARKAN PART ───────────────────────────
elseif ($action === 'by_part' && $part_id) {
    $stmt = $pdo->prepare("
        SELECT m.*, tp.name AS part_name
        FROM materials m
        JOIN toeic_parts tp ON m.part_id = tp.id
        WHERE m.part_id = ?
        ORDER BY m.id
    ");
    $stmt->execute([$part_id]);
    $materials = $stmt->fetchAll();

    echo json_encode(["status" => "success", "data" => $materials]);
}

// ─── AMBIL DETAIL SATU MATERI ─────────────────────────────────
elseif ($action === 'detail') {
    $id = $_GET['id'] ?? null;
    if (!$id) {
        echo json_encode(["status" => "error", "message" => "ID materi diperlukan"]);
        exit();
    }

    $stmt = $pdo->prepare("
        SELECT m.*, tp.name AS part_name
        FROM materials m
        JOIN toeic_parts tp ON m.part_id = tp.id
        WHERE m.id = ?
    ");
    $stmt->execute([$id]);
    $material = $stmt->fetch();

    if (!$material) {
        echo json_encode(["status" => "error", "message" => "Materi tidak ditemukan"]);
        exit();
    }

    echo json_encode(["status" => "success", "data" => $material]);
}

else {
    echo json_encode(["status" => "error", "message" => "Action tidak dikenali"]);
}
?>