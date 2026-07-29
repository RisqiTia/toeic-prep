<?php

// ============================================================
// CORS - FLUTTER WEB
// ============================================================

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=utf-8');

// Browser Flutter Web akan mengirim OPTIONS terlebih dahulu
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}


// ============================================================
// ACTION
// ============================================================

$action = $_GET['action'] ?? '';


// ============================================================
// GENERATE MATERI
// ============================================================

if ($action === 'generate') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $partId = intval(
        $data['part_id'] ?? 0
    );

    // ========================================================
    // VALIDASI PART
    // ========================================================

    if ($partId < 1 || $partId > 7) {

        echo json_encode([
            "status" => "error",
            "message" => "Part TOEIC tidak valid"
        ]);

        exit();
    }


    // ========================================================
    // LOKASI GENERATOR
    // ========================================================

    $generatorDir =
        'C:\\xampp\\htdocs\\toeic_dataset_generator';

    $scriptPath =
        $generatorDir .
        '\\generate_material_admin.py';


    if (!file_exists($scriptPath)) {

        echo json_encode([
            "status" => "error",
            "message" => "File generator materi tidak ditemukan"
        ]);

        exit();
    }


    // ========================================================
    // JALANKAN PYTHON
    // ========================================================

    try {

        /*
         * Penting:
         *
         * cd ke folder generator terlebih dahulu supaya:
         *
         * import config
         * import db
         * folder materials/
         *
         * tetap menggunakan lokasi yang benar.
         */

        $command =
            'cd /d ' .
            escapeshellarg($generatorDir) .
            ' && python ' .
            escapeshellarg($scriptPath) .
            ' ' .
            escapeshellarg((string) $partId) .
            ' 2>&1';


        $output = [];
        $exitCode = 0;

        exec(
            $command,
            $output,
            $exitCode
        );


        // ====================================================
        // GENERATOR GAGAL
        // ====================================================

        if ($exitCode !== 0) {

            echo json_encode([
                "status" => "error",
                "message" => "Gagal generate materi",
                "error" => implode("\n", $output)
            ]);

            exit();
        }


        // ====================================================
        // BERHASIL
        // ====================================================

        echo json_encode([
            "status" => "success",
            "message" =>
                "Materi TOEIC Part $partId berhasil dibuat",
            "part_id" => $partId
        ]);

    } catch (Throwable $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Terjadi kesalahan saat menjalankan generator",
            "error" => $e->getMessage()
        ]);
    }

    exit();
}


// ============================================================
// ACTION TIDAK DIKENALI
// ============================================================

echo json_encode([
    "status" => "error",
    "message" => "Action tidak dikenali"
]);

?>