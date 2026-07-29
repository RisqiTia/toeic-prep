<?php

require_once 'config.php';

$action = $_GET['action'] ?? '';


// ============================================================
// MELIHAT & MENCARI PENGGUNA
// ============================================================

if ($action === 'users') {

    $search = trim($_GET['search'] ?? '');

    try {

        $sql = "
            SELECT
                u.id,
                u.name,
                u.email,
                u.skill_level,
                u.foto_profil,

                CASE
                    WHEN EXISTS (
                        SELECT 1
                        FROM password_reset_requests pr
                        WHERE pr.user_id = u.id
                        AND pr.status = 'pending'
                    )
                    THEN 1
                    ELSE 0
                END AS reset_requested

            FROM users u
            WHERE u.role = 'user'
        ";

        $params = [];

        if (!empty($search)) {

            $sql .= "
                AND (
                    u.name LIKE ?
                    OR u.email LIKE ?
                )
            ";

            $keyword = '%' . $search . '%';

            $params[] = $keyword;
            $params[] = $keyword;
        }

        $sql .= "
            ORDER BY
                reset_requested DESC,
                u.id DESC
        ";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);

        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode([
            "status" => "success",
            "data" => $users
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal mengambil data pengguna"
        ]);
    }
}


// ============================================================
// VERIFIKASI / SETUJUI PERMINTAAN RESET PASSWORD
// ============================================================

elseif ($action === 'approve_password_reset') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $userId = intval(
        $data['user_id'] ?? 0
    );

    if ($userId <= 0) {

        echo json_encode([
            "status" => "error",
            "message" => "Pengguna tidak valid"
        ]);

        exit();
    }

    try {

        // Cek user
        $stmt = $pdo->prepare("
            SELECT id, name, email, role
            FROM users
            WHERE id = ?
            LIMIT 1
        ");

        $stmt->execute([$userId]);

        $user = $stmt->fetch(
            PDO::FETCH_ASSOC
        );

        if (!$user) {

            echo json_encode([
                "status" => "error",
                "message" => "Pengguna tidak ditemukan"
            ]);

            exit();
        }

        if ($user['role'] !== 'user') {

            echo json_encode([
                "status" => "error",
                "message" => "Permintaan akun admin tidak dapat diproses"
            ]);

            exit();
        }


        // Cari permintaan pending
        $stmt = $pdo->prepare("
            SELECT id
            FROM password_reset_requests
            WHERE user_id = ?
            AND status = 'pending'
            ORDER BY requested_at DESC
            LIMIT 1
        ");

        $stmt->execute([$userId]);

        $request = $stmt->fetch(
            PDO::FETCH_ASSOC
        );

        if (!$request) {

            echo json_encode([
                "status" => "error",
                "message" => "Tidak ada permintaan reset yang menunggu verifikasi"
            ]);

            exit();
        }


        // Ubah pending menjadi approved
        $stmt = $pdo->prepare("
            UPDATE password_reset_requests
            SET status = 'approved'
            WHERE id = ?
        ");

        $stmt->execute([
            $request['id']
        ]);

        echo json_encode([
            "status" => "success",
            "message" => "Permintaan reset kata sandi berhasil diverifikasi"
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal memverifikasi permintaan reset kata sandi"
        ]);
    }
}


// ============================================================
// HAPUS PENGGUNA
// ============================================================

elseif ($action === 'delete_user') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $userId = intval(
        $data['user_id'] ?? 0
    );

    if ($userId <= 0) {
        echo json_encode([
            "status" => "error",
            "message" => "Pengguna tidak valid"
        ]);
        exit();
    }

    try {

        // ====================================================
        // CEK DATA PENGGUNA
        // ====================================================

        $stmt = $pdo->prepare("
            SELECT
                id,
                name,
                email,
                role,
                foto_profil
            FROM users
            WHERE id = ?
            LIMIT 1
        ");

        $stmt->execute([$userId]);

        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user) {
            echo json_encode([
                "status" => "error",
                "message" => "Pengguna tidak ditemukan"
            ]);
            exit();
        }

        // ====================================================
        // ADMIN TIDAK BOLEH DIHAPUS
        // ====================================================

        if ($user['role'] !== 'user') {
            echo json_encode([
                "status" => "error",
                "message" => "Akun admin tidak dapat dihapus"
            ]);
            exit();
        }

        // ====================================================
        // SIMPAN PATH FOTO SEBELUM USER DIHAPUS
        // ====================================================

        $filePath = null;

        if (!empty($user['foto_profil'])) {

            $uploadDir =
                __DIR__ .
                '/../../toeic_dataset_generator/uploads/profil/';

            $filePath =
                $uploadDir .
                basename($user['foto_profil']);
        }

        // ====================================================
        // HAPUS USER
        // ====================================================

        $stmt = $pdo->prepare("
            DELETE FROM users
            WHERE id = ?
            AND role = 'user'
        ");

        $stmt->execute([$userId]);

        if ($stmt->rowCount() === 0) {
            echo json_encode([
                "status" => "error",
                "message" => "Pengguna gagal dihapus"
            ]);
            exit();
        }

        // ====================================================
        // HAPUS FOTO PROFIL
        // ====================================================

        if (
            $filePath !== null &&
            file_exists($filePath) &&
            is_file($filePath)
        ) {
            @unlink($filePath);
        }

        echo json_encode([
            "status" => "success",
            "message" => "Pengguna berhasil dihapus"
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal menghapus pengguna"
        ]);
    }
}

// ============================================================
// MELIHAT DAFTAR PART TOEIC
// ============================================================

elseif ($action === 'material_parts') {

    try {

        $stmt = $pdo->query("
            SELECT
                id,
                name,
                type
            FROM toeic_parts
            ORDER BY id ASC
        ");

        $parts = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode([
            "status" => "success",
            "data" => $parts
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal mengambil daftar part"
        ]);
    }
}


// ============================================================
// MELIHAT SEMUA MATERI / FILTER BERDASARKAN PART
// ============================================================

elseif ($action === 'materials') {

    $partId = intval(
        $_GET['part_id'] ?? 0
    );

    try {

        $sql = "
            SELECT
                m.id,
                m.part_id,
                m.title,
                m.text_content,
                m.image_file,
                m.audio_file,
                m.created_at,
                tp.name AS part_name,
                tp.type AS part_type
            FROM materials m
            INNER JOIN toeic_parts tp
                ON m.part_id = tp.id
        ";

        $params = [];

        // Filter berdasarkan part
        if ($partId > 0) {

            $sql .= "
                WHERE m.part_id = ?
            ";

            $params[] = $partId;
        }

        $sql .= "
            ORDER BY
                m.part_id ASC,
                m.id DESC
        ";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);

        $materials = $stmt->fetchAll(
            PDO::FETCH_ASSOC
        );

        echo json_encode([
            "status" => "success",
            "data" => $materials
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal mengambil data materi"
        ]);
    }
}

// ============================================================
// DETAIL MATERI
// ============================================================

elseif ($action === 'material_detail') {

    $materialId = intval(
        $_GET['id'] ?? 0
    );

    if ($materialId <= 0) {

        echo json_encode([
            "status" => "error",
            "message" => "ID materi tidak valid"
        ]);

        exit();
    }

    try {

        $stmt = $pdo->prepare("
            SELECT
                m.id,
                m.part_id,
                m.title,
                m.text_content,
                m.image_file,
                m.audio_file,
                m.created_at,
                tp.name AS part_name,
                tp.type AS part_type
            FROM materials m
            INNER JOIN toeic_parts tp
                ON m.part_id = tp.id
            WHERE m.id = ?
            LIMIT 1
        ");

        $stmt->execute([
            $materialId
        ]);

        $material = $stmt->fetch(
            PDO::FETCH_ASSOC
        );

        if (!$material) {

            echo json_encode([
                "status" => "error",
                "message" => "Materi tidak ditemukan"
            ]);

            exit();
        }

        echo json_encode([
            "status" => "success",
            "data" => $material
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal mengambil detail materi"
        ]);
    }
}

// ============================================================
// MELIHAT SOAL + FILTER + PAGINATION
// ============================================================

elseif ($action === 'questions') {

    $partId = intval($_GET['part_id'] ?? 0);
    $level  = trim($_GET['level'] ?? '');

    $page  = intval($_GET['page'] ?? 1);
    $limit = intval($_GET['limit'] ?? 20);

    if ($page < 1) {
        $page = 1;
    }

    if ($limit < 1) {
        $limit = 20;
    }

    // Batasi agar tidak mengambil terlalu banyak data
    if ($limit > 100) {
        $limit = 100;
    }

    $offset = ($page - 1) * $limit;

    $allowedLevels = [
        'beginner',
        'intermediate',
        'advanced'
    ];

    try {

        // ====================================================
        // WHERE
        // ====================================================

        $where = " WHERE 1 = 1 ";
        $params = [];

        if ($partId > 0) {
            $where .= " AND q.part_id = ? ";
            $params[] = $partId;
        }

        if (
            !empty($level) &&
            in_array($level, $allowedLevels)
        ) {
            $where .= " AND q.difficulty_level = ? ";
            $params[] = $level;
        }


        // ====================================================
        // HITUNG TOTAL SOAL
        // ====================================================

        $countSql = "
            SELECT COUNT(*) AS total
            FROM questions q
            $where
        ";

        $countStmt = $pdo->prepare($countSql);
        $countStmt->execute($params);

        $total = intval(
            $countStmt->fetchColumn()
        );


        // ====================================================
        // AMBIL SOAL
        // HANYA DATA YANG DIPERLUKAN TABEL
        // ====================================================

        $sql = "
            SELECT
                q.id,
                q.part_id,
                q.question_text,
                q.difficulty_level,

                tp.name AS part_name,
                tp.type AS part_type

            FROM questions q

            INNER JOIN toeic_parts tp
                ON q.part_id = tp.id

            $where

            ORDER BY
                q.part_id ASC,
                q.id ASC

            LIMIT $limit
            OFFSET $offset
        ";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);

        $questions = $stmt->fetchAll(
            PDO::FETCH_ASSOC
        );


        // ====================================================
        // TOTAL PAGE
        // ====================================================

        $totalPages = $total > 0
            ? (int) ceil($total / $limit)
            : 1;


        echo json_encode([
            "status" => "success",

            "data" => $questions,

            "pagination" => [
                "current_page" => $page,
                "limit" => $limit,
                "total" => $total,
                "total_pages" => $totalPages
            ]
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal mengambil data soal"
        ]);
    }
}

// ============================================================
// DETAIL SOAL
// ============================================================

elseif ($action === 'question_detail') {

    $questionId = intval(
        $_GET['id'] ?? 0
    );

    if ($questionId <= 0) {

        echo json_encode([
            "status" => "error",
            "message" => "ID soal tidak valid"
        ]);

        exit();
    }

    try {

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
            INNER JOIN toeic_parts tp
                ON q.part_id = tp.id
            WHERE q.id = ?
            LIMIT 1
        ");

        $stmt->execute([
            $questionId
        ]);

        $question = $stmt->fetch(
            PDO::FETCH_ASSOC
        );

        if (!$question) {

            echo json_encode([
                "status" => "error",
                "message" => "Soal tidak ditemukan"
            ]);

            exit();
        }

        echo json_encode([
            "status" => "success",
            "data" => $question
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal mengambil detail soal"
        ]);
    }
}

// ============================================================
// STATISTIK DASHBOARD
// ============================================================

elseif ($action === 'dashboard_stats') {

    try {

        // Jumlah pengguna biasa
        $stmt = $pdo->query("
            SELECT COUNT(*)
            FROM users
            WHERE role = 'user'
        ");

        $totalUsers = (int) $stmt->fetchColumn();


        // Jumlah materi
        $stmt = $pdo->query("
            SELECT COUNT(*)
            FROM materials
        ");

        $totalMaterials = (int) $stmt->fetchColumn();


        // Jumlah soal
        $stmt = $pdo->query("
            SELECT COUNT(*)
            FROM questions
        ");

        $totalQuestions = (int) $stmt->fetchColumn();


        echo json_encode([
            "status" => "success",

            "data" => [
                "users" => $totalUsers,
                "materials" => $totalMaterials,
                "questions" => $totalQuestions
            ]
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            "status" => "error",
            "message" => "Gagal mengambil statistik dashboard"
        ]);
    }
}

// ============================================================
// ACTION TIDAK DIKENALI
// ============================================================

else {

    echo json_encode([
        "status" => "error",
        "message" => "Action tidak dikenali"
    ]);
}

?>