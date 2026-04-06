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

    // Cek apakah email sudah terdaftar
    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        echo json_encode(["status" => "error", "message" => "Email sudah terdaftar"]);
        exit();
    }

    // Simpan user baru
    $hashed = password_hash($password, PASSWORD_BCRYPT);
    $stmt = $pdo->prepare("INSERT INTO users (name, email, password) VALUES (?, ?, ?)");
    $stmt->execute([$name, $email, $hashed]);

    echo json_encode([
        "status"  => "success",
        "message" => "Registrasi berhasil! Silakan login."
    ]);
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
            "id"    => $user['id'],
            "name"  => $user['name'],
            "email" => $user['email']
        ]
    ]);
}

else {
    echo json_encode(["status" => "error", "message" => "Action tidak dikenali"]);
}
?>