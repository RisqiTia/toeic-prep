<?php
require_once 'config.php';

$action = $_GET['action'] ?? '';

// ─── REGISTER ────────────────────────────────────────────────
if ($action === 'register') {
    $data = json_decode(file_get_contents("php://input"), true);

    $name     = trim($data['name']     ?? '');
    $email    = trim($data['email']    ?? '');
    $password = trim($data['password'] ?? '');

    if (empty($name) || empty($email) || empty($password)) {
        echo json_encode(["status" => "error", "message" => "Semua field harus diisi"]);
        exit();
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode(["status" => "error", "message" => "Format email tidak valid"]);
        exit();
    }

    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        echo json_encode(["status" => "error", "message" => "Email sudah terdaftar"]);
        exit();
    }

    $hashed = password_hash($password, PASSWORD_BCRYPT);
    $stmt   = $pdo->prepare("INSERT INTO users (name, email, password) VALUES (?, ?, ?)");
    $stmt->execute([$name, $email, $hashed]);

    echo json_encode(["status" => "success", "message" => "Registrasi berhasil!"]);
}

// ─── UPDATE SKILL LEVEL ───────────────────────────────────────
elseif ($action === 'update_skill') {
    $data = json_decode(file_get_contents("php://input"), true);

    $email      = trim($data['email']       ?? '');
    $skillLevel = trim($data['skill_level'] ?? '');

    $allowed = ['beginner', 'intermediate', 'advanced'];
    if (!in_array($skillLevel, $allowed)) {
        echo json_encode(["status" => "error", "message" => "Tingkat kemampuan tidak valid"]);
        exit();
    }

    $stmt = $pdo->prepare("UPDATE users SET skill_level = ? WHERE email = ?");
    $stmt->execute([$skillLevel, $email]);

    echo json_encode(["status" => "success", "message" => "Tingkat kemampuan berhasil disimpan"]);
}

// ─── LOGIN ────────────────────────────────────────────────────
elseif ($action === 'login') {
    $data = json_decode(file_get_contents("php://input"), true);

    $email    = trim($data['email']    ?? '');
    $password = trim($data['password'] ?? '');

    if (empty($email) || empty($password)) {
        echo json_encode(["status" => "error", "message" => "Email dan password harus diisi"]);
        exit();
    }

    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ?");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password'])) {
        echo json_encode(["status" => "error", "message" => "Email atau password salah"]);
        exit();
    }

    echo json_encode([
        "status"  => "success",
        "message" => "Login berhasil",
        "user"    => [
            "id"          => $user['id'],
            "name"        => $user['name'],
            "email"       => $user['email'],
            "skill_level" => $user['skill_level'],
            "foto_profil" => $user['foto_profil'] ?? ''
        ]
    ]);
}

// ─── UPDATE NAMA PENGGUNA ─────────────────────────────────────
elseif ($action === 'update_name') {
    $data = json_decode(file_get_contents("php://input"), true);

    $userId = intval($data['user_id'] ?? 0);
    $name   = trim($data['name']      ?? '');

    if ($userId <= 0) {
        echo json_encode(["status" => "error", "message" => "User tidak valid"]);
        exit();
    }
    if (empty($name)) {
        echo json_encode(["status" => "error", "message" => "Nama tidak boleh kosong"]);
        exit();
    }

    $stmt = $pdo->prepare("UPDATE users SET name = ? WHERE id = ?");
    $stmt->execute([$name, $userId]);

    echo json_encode(["status" => "success", "message" => "Nama berhasil diperbarui"]);
}

// ─── UPDATE PASSWORD ──────────────────────────────────────────
elseif ($action === 'update_password') {
    $data = json_decode(file_get_contents("php://input"), true);

    $userId      = intval($data['user_id']    ?? 0);
    $oldPassword = trim($data['old_password'] ?? '');
    $newPassword = trim($data['new_password'] ?? '');

    if ($userId <= 0) {
        echo json_encode(["status" => "error", "message" => "User tidak valid"]);
        exit();
    }
    if (empty($oldPassword) || empty($newPassword)) {
        echo json_encode(["status" => "error", "message" => "Semua field harus diisi"]);
        exit();
    }
    if (strlen($newPassword) < 6) {
        echo json_encode(["status" => "error", "message" => "Kata sandi baru minimal 6 karakter"]);
        exit();
    }

    $stmt = $pdo->prepare("SELECT password FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    if (!$user) {
        echo json_encode(["status" => "error", "message" => "User tidak ditemukan"]);
        exit();
    }
    if (!password_verify($oldPassword, $user['password'])) {
        echo json_encode(["status" => "error", "message" => "Kata sandi lama tidak sesuai"]);
        exit();
    }
    if (password_verify($newPassword, $user['password'])) {
        echo json_encode(["status" => "error", "message" => "Kata sandi baru tidak boleh sama dengan yang lama"]);
        exit();
    }

    $hashed = password_hash($newPassword, PASSWORD_BCRYPT);
    $stmt   = $pdo->prepare("UPDATE users SET password = ? WHERE id = ?");
    $stmt->execute([$hashed, $userId]);

    echo json_encode(["status" => "success", "message" => "Kata sandi berhasil diperbarui"]);
}

// ─── UPDATE FOTO PROFIL (multipart upload) ───────────────────
elseif ($action === 'update_photo') {
    $userId = intval($_POST['user_id'] ?? 0);

    if ($userId <= 0) {
        echo json_encode(["status" => "error", "message" => "User tidak valid"]);
        exit();
    }

    if (!isset($_FILES['foto']) || $_FILES['foto']['error'] !== UPLOAD_ERR_OK) {
        echo json_encode(["status" => "error", "message" => "File foto tidak ditemukan atau gagal diunggah"]);
        exit();
    }

    $file     = $_FILES['foto'];
    $allowed  = ['image/jpeg', 'image/png', 'image/jpg', 'image/webp'];
    $mimeType = mime_content_type($file['tmp_name']);

    if (!in_array($mimeType, $allowed)) {
        echo json_encode(["status" => "error", "message" => "Format file harus JPG, PNG, atau WebP"]);
        exit();
    }

    if ($file['size'] > 5 * 1024 * 1024) {
        echo json_encode(["status" => "error", "message" => "Ukuran file maksimal 5 MB"]);
        exit();
    }

    // Folder tujuan di toeic_dataset_generator/uploads/profil/
    $uploadDir = __DIR__ . '/../../toeic_dataset_generator/uploads/profil/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    // Hapus foto lama jika ada
    $stmt = $pdo->prepare("SELECT foto_profil FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();
    if ($user && !empty($user['foto_profil'])) {
        $oldFile = $uploadDir . $user['foto_profil'];
        if (file_exists($oldFile)) {
            unlink($oldFile);
        }
    }

    // Simpan file baru dengan nama unik: user_{id}_{timestamp}.jpg
    $namaFile = 'user_' . $userId . '_' . time() . '.jpg';
    $tujuan   = $uploadDir . $namaFile;

    if (!move_uploaded_file($file['tmp_name'], $tujuan)) {
        echo json_encode(["status" => "error", "message" => "Gagal menyimpan file"]);
        exit();
    }

    $stmt = $pdo->prepare("UPDATE users SET foto_profil = ? WHERE id = ?");
    $stmt->execute([$namaFile, $userId]);

    echo json_encode([
        "status"      => "success",
        "message"     => "Foto profil berhasil diperbarui",
        "foto_profil" => $namaFile
    ]);
}

// ─── HAPUS FOTO PROFIL ────────────────────────────────────────
elseif ($action === 'delete_photo') {
    $data   = json_decode(file_get_contents("php://input"), true);
    $userId = intval($data['user_id'] ?? 0);

    if ($userId <= 0) {
        echo json_encode(["status" => "error", "message" => "User tidak valid"]);
        exit();
    }

    $stmt = $pdo->prepare("SELECT foto_profil FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    if ($user && !empty($user['foto_profil'])) {
        $uploadDir = __DIR__ . '/../../toeic_dataset_generator/uploads/profil/';
        $filePath  = $uploadDir . $user['foto_profil'];
        if (file_exists($filePath)) {
            unlink($filePath);
        }
    }

    $stmt = $pdo->prepare("UPDATE users SET foto_profil = NULL WHERE id = ?");
    $stmt->execute([$userId]);

    echo json_encode(["status" => "success", "message" => "Foto profil berhasil dihapus"]);
}

else {
    echo json_encode(["status" => "error", "message" => "Action tidak dikenali"]);
}
?>