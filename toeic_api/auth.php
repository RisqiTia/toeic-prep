<?php

require_once 'config.php';

$action = $_GET['action'] ?? '';


// ============================================================
// REGISTER
// ============================================================

if ($action === 'register') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $name = trim($data['name'] ?? '');
    $email = trim($data['email'] ?? '');
    $password = trim($data['password'] ?? '');

    if (
        empty($name) ||
        empty($email) ||
        empty($password)
    ) {
        echo json_encode([
            "status" => "error",
            "message" => "Semua field harus diisi"
        ]);
        exit();
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode([
            "status" => "error",
            "message" => "Format email tidak valid"
        ]);
        exit();
    }

    if (strlen($password) < 6) {
        echo json_encode([
            "status" => "error",
            "message" => "Kata sandi minimal 6 karakter"
        ]);
        exit();
    }

    // Cek email
    $stmt = $pdo->prepare("
        SELECT id
        FROM users
        WHERE email = ?
        LIMIT 1
    ");

    $stmt->execute([$email]);

    if ($stmt->fetch()) {
        echo json_encode([
            "status" => "error",
            "message" => "Email sudah terdaftar"
        ]);
        exit();
    }

    $hashedPassword = password_hash(
        $password,
        PASSWORD_BCRYPT
    );

    $stmt = $pdo->prepare("
        INSERT INTO users
        (
            name,
            email,
            password
        )
        VALUES (?, ?, ?)
    ");

    $stmt->execute([
        $name,
        $email,
        $hashedPassword
    ]);

    echo json_encode([
        "status" => "success",
        "message" => "Registrasi berhasil!"
    ]);
}


// ============================================================
// UPDATE SKILL LEVEL
// ============================================================

elseif ($action === 'update_skill') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $email = trim(
        $data['email'] ?? ''
    );

    $skillLevel = trim(
        $data['skill_level'] ?? ''
    );

    $allowed = [
        'beginner',
        'intermediate',
        'advanced'
    ];

    if (empty($email)) {
        echo json_encode([
            "status" => "error",
            "message" => "Email harus diisi"
        ]);
        exit();
    }

    if (!in_array($skillLevel, $allowed, true)) {
        echo json_encode([
            "status" => "error",
            "message" => "Tingkat kemampuan tidak valid"
        ]);
        exit();
    }

    $stmt = $pdo->prepare("
        UPDATE users
        SET skill_level = ?
        WHERE email = ?
    ");

    $stmt->execute([
        $skillLevel,
        $email
    ]);

    echo json_encode([
        "status" => "success",
        "message" => "Tingkat kemampuan berhasil disimpan"
    ]);
}


// ============================================================
// LOGIN
// ============================================================

elseif ($action === 'login') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $email = trim(
        $data['email'] ?? ''
    );

    $password = $data['password'] ?? '';

    if (
        empty($email) ||
        empty($password)
    ) {
        echo json_encode([
            "status" => "error",
            "message" => "Email dan password harus diisi"
        ]);
        exit();
    }

    $stmt = $pdo->prepare("
        SELECT *
        FROM users
        WHERE email = ?
        LIMIT 1
    ");

    $stmt->execute([$email]);

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (
        !$user ||
        !password_verify(
            $password,
            $user['password']
        )
    ) {
        echo json_encode([
            "status" => "error",
            "message" => "Email atau password salah"
        ]);
        exit();
    }

    echo json_encode([
        "status" => "success",
        "message" => "Login berhasil",
        "user" => [
            "id" => $user['id'],
            "name" => $user['name'],
            "email" => $user['email'],
            "skill_level" =>
                $user['skill_level'] ?? 'beginner',
            "foto_profil" =>
                $user['foto_profil'] ?? '',
            "role" =>
                $user['role'] ?? 'user'
        ]
    ]);
}


// ============================================================
// UPDATE NAMA PENGGUNA
// ============================================================

elseif ($action === 'update_name') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $userId = intval(
        $data['user_id'] ?? 0
    );

    $name = trim(
        $data['name'] ?? ''
    );

    if ($userId <= 0) {
        echo json_encode([
            "status" => "error",
            "message" => "User tidak valid"
        ]);
        exit();
    }

    if (empty($name)) {
        echo json_encode([
            "status" => "error",
            "message" => "Nama tidak boleh kosong"
        ]);
        exit();
    }

    $stmt = $pdo->prepare("
        UPDATE users
        SET name = ?
        WHERE id = ?
    ");

    $stmt->execute([
        $name,
        $userId
    ]);

    echo json_encode([
        "status" => "success",
        "message" => "Nama berhasil diperbarui"
    ]);
}


// ============================================================
// UPDATE PASSWORD DARI PROFIL
// ============================================================
// Digunakan ketika user masih ingat password lama.
// Fitur ini berbeda dengan "Lupa Kata Sandi".

elseif ($action === 'update_password') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $userId = intval(
        $data['user_id'] ?? 0
    );

    $oldPassword =
        $data['old_password'] ?? '';

    $newPassword =
        $data['new_password'] ?? '';

    if ($userId <= 0) {
        echo json_encode([
            "status" => "error",
            "message" => "User tidak valid"
        ]);
        exit();
    }

    if (
        empty($oldPassword) ||
        empty($newPassword)
    ) {
        echo json_encode([
            "status" => "error",
            "message" => "Semua field harus diisi"
        ]);
        exit();
    }

    if (strlen($newPassword) < 6) {
        echo json_encode([
            "status" => "error",
            "message" => "Kata sandi baru minimal 6 karakter"
        ]);
        exit();
    }

    $stmt = $pdo->prepare("
        SELECT password
        FROM users
        WHERE id = ?
        LIMIT 1
    ");

    $stmt->execute([$userId]);

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode([
            "status" => "error",
            "message" => "User tidak ditemukan"
        ]);
        exit();
    }

    if (
        !password_verify(
            $oldPassword,
            $user['password']
        )
    ) {
        echo json_encode([
            "status" => "error",
            "message" => "Kata sandi lama tidak sesuai"
        ]);
        exit();
    }

    if (
        password_verify(
            $newPassword,
            $user['password']
        )
    ) {
        echo json_encode([
            "status" => "error",
            "message" =>
                "Kata sandi baru tidak boleh sama dengan yang lama"
        ]);
        exit();
    }

    $hashedPassword = password_hash(
        $newPassword,
        PASSWORD_BCRYPT
    );

    $stmt = $pdo->prepare("
        UPDATE users
        SET password = ?
        WHERE id = ?
    ");

    $stmt->execute([
        $hashedPassword,
        $userId
    ]);

    echo json_encode([
        "status" => "success",
        "message" => "Kata sandi berhasil diperbarui"
    ]);
}


// ============================================================
// UPDATE FOTO PROFIL
// ============================================================

elseif ($action === 'update_photo') {

    $userId = intval(
        $_POST['user_id'] ?? 0
    );

    if ($userId <= 0) {
        echo json_encode([
            "status" => "error",
            "message" => "User tidak valid"
        ]);
        exit();
    }

    if (
        !isset($_FILES['foto']) ||
        $_FILES['foto']['error'] !== UPLOAD_ERR_OK
    ) {
        echo json_encode([
            "status" => "error",
            "message" =>
                "File foto tidak ditemukan atau gagal diunggah"
        ]);
        exit();
    }

    $file = $_FILES['foto'];

    $allowed = [
        'image/jpeg',
        'image/png',
        'image/jpg',
        'image/webp'
    ];

    $mimeType = mime_content_type(
        $file['tmp_name']
    );

    if (!in_array($mimeType, $allowed, true)) {
        echo json_encode([
            "status" => "error",
            "message" =>
                "Format file harus JPG, PNG, atau WebP"
        ]);
        exit();
    }

    if ($file['size'] > 5 * 1024 * 1024) {
        echo json_encode([
            "status" => "error",
            "message" => "Ukuran file maksimal 5 MB"
        ]);
        exit();
    }

    $uploadDir =
        __DIR__ .
        '/../../toeic_dataset_generator/uploads/profil/';

    if (!is_dir($uploadDir)) {
        mkdir(
            $uploadDir,
            0755,
            true
        );
    }

    // Ambil foto lama
    $stmt = $pdo->prepare("
        SELECT foto_profil
        FROM users
        WHERE id = ?
        LIMIT 1
    ");

    $stmt->execute([$userId]);

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode([
            "status" => "error",
            "message" => "User tidak ditemukan"
        ]);
        exit();
    }

    if (!empty($user['foto_profil'])) {

        $oldFile =
            $uploadDir .
            $user['foto_profil'];

        if (file_exists($oldFile)) {
            unlink($oldFile);
        }
    }

    $extension = 'jpg';

    if ($mimeType === 'image/png') {
        $extension = 'png';
    } elseif ($mimeType === 'image/webp') {
        $extension = 'webp';
    }

    $namaFile =
        'user_' .
        $userId .
        '_' .
        time() .
        '.' .
        $extension;

    $tujuan =
        $uploadDir .
        $namaFile;

    if (
        !move_uploaded_file(
            $file['tmp_name'],
            $tujuan
        )
    ) {
        echo json_encode([
            "status" => "error",
            "message" => "Gagal menyimpan file"
        ]);
        exit();
    }

    $stmt = $pdo->prepare("
        UPDATE users
        SET foto_profil = ?
        WHERE id = ?
    ");

    $stmt->execute([
        $namaFile,
        $userId
    ]);

    echo json_encode([
        "status" => "success",
        "message" =>
            "Foto profil berhasil diperbarui",
        "foto_profil" => $namaFile
    ]);
}


// ============================================================
// HAPUS FOTO PROFIL
// ============================================================

elseif ($action === 'delete_photo') {

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
            "message" => "User tidak valid"
        ]);
        exit();
    }

    $stmt = $pdo->prepare("
        SELECT foto_profil
        FROM users
        WHERE id = ?
        LIMIT 1
    ");

    $stmt->execute([$userId]);

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode([
            "status" => "error",
            "message" => "User tidak ditemukan"
        ]);
        exit();
    }

    if (!empty($user['foto_profil'])) {

        $uploadDir =
            __DIR__ .
            '/../../toeic_dataset_generator/uploads/profil/';

        $filePath =
            $uploadDir .
            $user['foto_profil'];

        if (file_exists($filePath)) {
            unlink($filePath);
        }
    }

    $stmt = $pdo->prepare("
        UPDATE users
        SET foto_profil = NULL
        WHERE id = ?
    ");

    $stmt->execute([$userId]);

    echo json_encode([
        "status" => "success",
        "message" =>
            "Foto profil berhasil dihapus"
    ]);
}


// ============================================================
// LUPA KATA SANDI
// AJUKAN PERMINTAAN RESET
// ============================================================

elseif ($action === 'forgot_password') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $email = trim(
        $data['email'] ?? ''
    );

    // --------------------------------------------------------
    // VALIDASI EMAIL
    // --------------------------------------------------------

    if (empty($email)) {
        echo json_encode([
            "status" => "error",
            "message" => "Email harus diisi"
        ]);
        exit();
    }

    if (
        !filter_var(
            $email,
            FILTER_VALIDATE_EMAIL
        )
    ) {
        echo json_encode([
            "status" => "error",
            "message" => "Format email tidak valid"
        ]);
        exit();
    }

    // --------------------------------------------------------
    // CARI USER
    // --------------------------------------------------------

    $stmt = $pdo->prepare("
        SELECT
            id,
            name,
            email
        FROM users
        WHERE email = ?
        AND role = 'user'
        LIMIT 1
    ");

    $stmt->execute([$email]);

    $user = $stmt->fetch(
        PDO::FETCH_ASSOC
    );

    if (!$user) {
        echo json_encode([
            "status" => "error",
            "message" => "Email tidak terdaftar"
        ]);
        exit();
    }

    // --------------------------------------------------------
    // CEK REQUEST AKTIF
    // --------------------------------------------------------

    $stmt = $pdo->prepare("
        SELECT
            id,
            status
        FROM password_reset_requests
        WHERE user_id = ?
        AND status IN (
            'pending',
            'approved'
        )
        ORDER BY requested_at DESC
        LIMIT 1
    ");

    $stmt->execute([
        $user['id']
    ]);

    $existingRequest =
        $stmt->fetch(
            PDO::FETCH_ASSOC
        );

    // Sudah pernah meminta dan masih menunggu admin
    if (
        $existingRequest &&
        $existingRequest['status'] === 'pending'
    ) {
        echo json_encode([
            "status" => "success",
            "reset_status" => "pending",
            "message" =>
                "Permintaan reset kata sandi Anda sedang menunggu verifikasi admin."
        ]);
        exit();
    }

    // Admin sudah menyetujui
    if (
        $existingRequest &&
        $existingRequest['status'] === 'approved'
    ) {
        echo json_encode([
            "status" => "success",
            "reset_status" => "approved",
            "message" =>
                "Permintaan reset kata sandi telah diverifikasi. Silakan buat kata sandi baru."
        ]);
        exit();
    }

    // --------------------------------------------------------
    // BUAT REQUEST BARU
    // --------------------------------------------------------

    $stmt = $pdo->prepare("
        INSERT INTO password_reset_requests
        (
            user_id,
            status,
            requested_at
        )
        VALUES
        (
            ?,
            'pending',
            NOW()
        )
    ");

    $stmt->execute([
        $user['id']
    ]);

    echo json_encode([
        "status" => "success",
        "reset_status" => "pending",
        "message" =>
            "Permintaan reset kata sandi berhasil dikirim. Silakan tunggu verifikasi admin."
    ]);
}


// ============================================================
// CEK STATUS RESET PASSWORD
// ============================================================

elseif ($action === 'check_reset_status') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $email = trim(
        $data['email'] ?? ''
    );

    // --------------------------------------------------------
    // VALIDASI EMAIL
    // --------------------------------------------------------

    if (empty($email)) {
        echo json_encode([
            "status" => "error",
            "message" => "Email harus diisi"
        ]);
        exit();
    }

    if (
        !filter_var(
            $email,
            FILTER_VALIDATE_EMAIL
        )
    ) {
        echo json_encode([
            "status" => "error",
            "message" => "Format email tidak valid"
        ]);
        exit();
    }

    // --------------------------------------------------------
    // CARI USER
    // --------------------------------------------------------

    $stmt = $pdo->prepare("
        SELECT id
        FROM users
        WHERE email = ?
        AND role = 'user'
        LIMIT 1
    ");

    $stmt->execute([$email]);

    $user = $stmt->fetch(
        PDO::FETCH_ASSOC
    );

    if (!$user) {
        echo json_encode([
            "status" => "error",
            "message" => "Email tidak terdaftar"
        ]);
        exit();
    }

    // --------------------------------------------------------
    // CARI REQUEST AKTIF
    // --------------------------------------------------------

    $stmt = $pdo->prepare("
        SELECT
            id,
            status,
            requested_at
        FROM password_reset_requests
        WHERE user_id = ?
        AND status IN (
            'pending',
            'approved'
        )
        ORDER BY requested_at DESC
        LIMIT 1
    ");

    $stmt->execute([
        $user['id']
    ]);

    $request = $stmt->fetch(
        PDO::FETCH_ASSOC
    );

    // Tidak ada pending/approved.
    // Berarti user belum request atau request sebelumnya selesai.
    if (!$request) {
        echo json_encode([
            "status" => "success",
            "reset_status" => "none",
            "message" =>
                "Belum ada permintaan reset kata sandi yang aktif."
        ]);
        exit();
    }

    // Masih menunggu admin
    if ($request['status'] === 'pending') {
        echo json_encode([
            "status" => "success",
            "reset_status" => "pending",
            "message" =>
                "Permintaan reset kata sandi sedang menunggu verifikasi admin."
        ]);
        exit();
    }

    // Sudah disetujui admin
    if ($request['status'] === 'approved') {
        echo json_encode([
            "status" => "success",
            "reset_status" => "approved",
            "message" =>
                "Permintaan reset kata sandi telah diverifikasi. Silakan buat kata sandi baru."
        ]);
        exit();
    }

    echo json_encode([
        "status" => "success",
        "reset_status" => "none",
        "message" =>
            "Tidak ada permintaan reset kata sandi yang aktif."
    ]);
}


// ============================================================
// COMPLETE PASSWORD RESET
// USER MEMBUAT PASSWORD BARU
// ============================================================

elseif ($action === 'complete_password_reset') {

    $data = json_decode(
        file_get_contents("php://input"),
        true
    );

    $email = trim(
        $data['email'] ?? ''
    );

    $newPassword =
        $data['new_password'] ?? '';

    // --------------------------------------------------------
    // VALIDASI
    // --------------------------------------------------------

    if (
        empty($email) ||
        empty($newPassword)
    ) {
        echo json_encode([
            "status" => "error",
            "message" =>
                "Email dan kata sandi baru harus diisi"
        ]);
        exit();
    }

    if (
        !filter_var(
            $email,
            FILTER_VALIDATE_EMAIL
        )
    ) {
        echo json_encode([
            "status" => "error",
            "message" =>
                "Format email tidak valid"
        ]);
        exit();
    }

    if (strlen($newPassword) < 6) {
        echo json_encode([
            "status" => "error",
            "message" =>
                "Kata sandi minimal 6 karakter"
        ]);
        exit();
    }

    try {

        // ----------------------------------------------------
        // CARI USER
        // ----------------------------------------------------

        $stmt = $pdo->prepare("
            SELECT
                id,
                password
            FROM users
            WHERE email = ?
            AND role = 'user'
            LIMIT 1
        ");

        $stmt->execute([$email]);

        $user = $stmt->fetch(
            PDO::FETCH_ASSOC
        );

        if (!$user) {
            echo json_encode([
                "status" => "error",
                "message" =>
                    "Pengguna tidak ditemukan"
            ]);
            exit();
        }

        // ----------------------------------------------------
        // CEK REQUEST APPROVED
        // ----------------------------------------------------

        $stmt = $pdo->prepare("
            SELECT
                id,
                status
            FROM password_reset_requests
            WHERE user_id = ?
            AND status = 'approved'
            ORDER BY requested_at DESC
            LIMIT 1
        ");

        $stmt->execute([
            $user['id']
        ]);

        $request = $stmt->fetch(
            PDO::FETCH_ASSOC
        );

        if (!$request) {
            echo json_encode([
                "status" => "error",
                "message" =>
                    "Permintaan reset kata sandi belum diverifikasi oleh admin."
            ]);
            exit();
        }

        // ----------------------------------------------------
        // CEK PASSWORD BARU
        // ----------------------------------------------------

        if (
            password_verify(
                $newPassword,
                $user['password']
            )
        ) {
            echo json_encode([
                "status" => "error",
                "message" =>
                    "Kata sandi baru tidak boleh sama dengan kata sandi sebelumnya."
            ]);
            exit();
        }

        // ----------------------------------------------------
        // TRANSACTION
        // ----------------------------------------------------

        $pdo->beginTransaction();

        // Hash password baru
        $hashedPassword = password_hash(
            $newPassword,
            PASSWORD_BCRYPT
        );

        // Update password user
        $stmt = $pdo->prepare("
            UPDATE users
            SET password = ?
            WHERE id = ?
        ");

        $stmt->execute([
            $hashedPassword,
            $user['id']
        ]);

        // Request selesai
        $stmt = $pdo->prepare("
            UPDATE password_reset_requests
            SET
                status = 'completed',
                completed_at = NOW()
            WHERE id = ?
            AND status = 'approved'
        ");

        $stmt->execute([
            $request['id']
        ]);

        $pdo->commit();

        echo json_encode([
            "status" => "success",
            "reset_status" => "completed",
            "message" =>
                "Kata sandi berhasil diperbarui. Silakan masuk menggunakan kata sandi baru."
        ]);

    } catch (PDOException $e) {

        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }

        echo json_encode([
            "status" => "error",
            "message" =>
                "Gagal memperbarui kata sandi."
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