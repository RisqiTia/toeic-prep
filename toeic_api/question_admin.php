<?php

// ============================================================
// CONFIG
// ============================================================

error_reporting(E_ALL);
ini_set('display_errors', '0');

// Generator AI + audio/gambar bisa memerlukan waktu cukup lama
set_time_limit(0);


// ============================================================
// CORS
// ============================================================

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}


// ============================================================
// RESPONSE HELPER
// ============================================================

function sendResponse($data, $statusCode = 200)
{
    http_response_code($statusCode);

    echo json_encode(
        $data,
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES
    );

    exit();
}


// ============================================================
// ACTION
// ============================================================

$action = $_GET['action'] ?? '';


// ============================================================
// GENERATE SOAL
// ============================================================

if ($action === 'generate') {

    // ========================================================
    // VALIDASI METHOD
    // ========================================================

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {

        sendResponse([
            'status' => 'error',
            'message' => 'Request harus menggunakan POST'
        ], 405);
    }


    // ========================================================
    // AMBIL BODY JSON
    // ========================================================

    $rawInput = file_get_contents('php://input');

    $data = json_decode(
        $rawInput,
        true
    );


    if (!is_array($data)) {

        sendResponse([
            'status' => 'error',
            'message' => 'Data request tidak valid'
        ], 400);
    }


    // ========================================================
    // AMBIL PARAMETER
    // ========================================================

    $partId = intval(
        $data['part_id'] ?? 0
    );

    $level = strtolower(
        trim(
            $data['level'] ?? ''
        )
    );

    $jumlah = intval(
        $data['jumlah'] ?? 10
    );


    // ========================================================
    // VALIDASI PART
    // ========================================================

    if ($partId < 1 || $partId > 7) {

        sendResponse([
            'status' => 'error',
            'message' => 'Part TOEIC harus antara 1 sampai 7'
        ], 400);
    }


    // ========================================================
    // VALIDASI LEVEL
    // ========================================================

    $allowedLevels = [
        'beginner',
        'intermediate',
        'advanced'
    ];


    if (!in_array(
        $level,
        $allowedLevels,
        true
    )) {

        sendResponse([
            'status' => 'error',
            'message' =>
                'Level harus beginner, intermediate, atau advanced'
        ], 400);
    }


    // ========================================================
    // VALIDASI JUMLAH SOAL
    // ========================================================

    if ($jumlah < 1 || $jumlah > 50) {

        sendResponse([
            'status' => 'error',
            'message' =>
                'Jumlah soal harus antara 1 sampai 50'
        ], 400);
    }


    // ========================================================
    // PATH GENERATOR
    // ========================================================

    $generatorDir =
        'C:\\xampp\\htdocs\\toeic_dataset_generator';

    $generatorFile =
        $generatorDir .
        '\\generate_questions_admin.py';


    // ========================================================
    // CEK FOLDER GENERATOR
    // ========================================================

    if (!is_dir($generatorDir)) {

        sendResponse([
            'status' => 'error',
            'message' =>
                'Folder generator tidak ditemukan',
            'path' =>
                $generatorDir
        ], 500);
    }


    // ========================================================
    // CEK FILE GENERATOR
    // ========================================================

    if (!file_exists($generatorFile)) {

        sendResponse([
            'status' => 'error',
            'message' =>
                'generate_questions_admin.py tidak ditemukan',
            'path' =>
                $generatorFile
        ], 500);
    }


    // ========================================================
    // PYTHON
    // ========================================================

    $python = 'python';


    // ========================================================
    // BUAT COMMAND
    //
    // Format:
    //
    // python generate_questions_admin.py
    //        PART LEVEL JUMLAH
    //
    // Contoh:
    //
    // python generate_questions_admin.py
    //        1 beginner 10
    // ========================================================

    $command =
        'cd /d ' .
        escapeshellarg($generatorDir) .
        ' && ' .
        $python . ' ' .
        escapeshellarg($generatorFile) . ' ' .
        escapeshellarg((string)$partId) . ' ' .
        escapeshellarg($level) . ' ' .
        escapeshellarg((string)$jumlah) .
        ' 2>&1';


    // ========================================================
    // JALANKAN PYTHON
    // ========================================================

    $output = [];
    $returnCode = null;


    try {

        exec(
            $command,
            $output,
            $returnCode
        );

    } catch (Throwable $e) {

        sendResponse([
            'status' => 'error',
            'message' =>
                'PHP gagal menjalankan Python',
            'error' =>
                $e->getMessage()
        ], 500);
    }


    // ========================================================
    // PYTHON GAGAL
    // ========================================================

    if ($returnCode !== 0) {

        sendResponse([
            'status' => 'error',

            'message' =>
                'Generator soal gagal dijalankan',

            'part_id' =>
                $partId,

            'level' =>
                $level,

            'jumlah' =>
                $jumlah,

            'return_code' =>
                $returnCode,

            'output' =>
                $output

        ], 500);
    }


    // ========================================================
    // AMBIL RESPONSE JSON TERAKHIR DARI PYTHON
    // ========================================================

    $pythonResult = null;

    if (!empty($output)) {

        // Generator bisa menghasilkan banyak print.
        // Response JSON berada pada output terakhir.

        for ($i = count($output) - 1; $i >= 0; $i--) {

            $line = trim($output[$i]);

            if ($line === '') {
                continue;
            }

            $decoded = json_decode(
                $line,
                true
            );

            if (
                is_array($decoded) &&
                isset($decoded['status'])
            ) {

                $pythonResult = $decoded;
                break;
            }
        }
    }


    // ========================================================
    // RESPONSE PYTHON TIDAK DITEMUKAN
    // ========================================================

    if ($pythonResult === null) {

        sendResponse([
            'status' => 'error',

            'message' =>
                'Generator selesai tetapi response Python tidak valid',

            'part_id' =>
                $partId,

            'level' =>
                $level,

            'jumlah' =>
                $jumlah,

            'output' =>
                $output

        ], 500);
    }


    // ========================================================
    // PYTHON MENGEMBALIKAN ERROR
    // ========================================================

    if (
        ($pythonResult['status'] ?? '') !==
        'success'
    ) {

        sendResponse([
            'status' => 'error',

            'message' =>
                $pythonResult['message']
                ?? 'Generate soal gagal',

            'part_id' =>
                $partId,

            'level' =>
                $level,

            'jumlah' =>
                $jumlah,

            'output' =>
                $output

        ], 500);
    }


    // ========================================================
    // AMBIL JUMLAH YANG BENAR-BENAR BERHASIL
    // ========================================================

    $generated = intval(
        $pythonResult['generated']
        ?? $jumlah
    );

    $requested = intval(
        $pythonResult['requested']
        ?? $jumlah
    );


    // ========================================================
    // BERHASIL
    // ========================================================

    sendResponse([
        'status' => 'success',

        'message' =>
            $pythonResult['message']
            ?? 'Generate soal berhasil',

        'part_id' =>
            $partId,

        'level' =>
            $level,

        'requested' =>
            $requested,

        'generated' =>
            $generated
    ]);
}


// ============================================================
// TEST API
// ============================================================

elseif ($action === 'test') {

    $generatorDir =
        'C:\\xampp\\htdocs\\toeic_dataset_generator';

    $generatorFile =
        $generatorDir .
        '\\generate_questions_admin.py';


    sendResponse([
        'status' => 'success',

        'message' =>
            'Question Admin API berjalan',

        'python' =>
            'Python dapat dijalankan melalui PHP',

        'generator_folder_exists' =>
            is_dir($generatorDir),

        'generator_file_exists' =>
            file_exists($generatorFile)
    ]);
}


// ============================================================
// ACTION TIDAK DIKENALI
// ============================================================

else {

    sendResponse([
        'status' => 'error',
        'message' => 'Action tidak dikenali'
    ], 404);
}