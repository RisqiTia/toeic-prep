<?php
require_once 'config.php';

function groupQuestions($rows, $partId)
    {
        $groups = [];

        foreach ($rows as $row) {

            // Part 3 & 4 -> group audio
            if ($partId == 3 || $partId == 4) {

                $key = trim($row['audio_file'] ?? '');
            }

            // Part 6 & 7 -> group passage
            elseif ($partId == 6 || $partId == 7) {

                $key = substr(
                    trim($row['question_text'] ?? ''),
                    0,
                    200
                );
            }

            // Part lain
            else {

                $key = uniqid();
            }

            $groups[$key][] = $row;
        }

        // urutkan soal dalam setiap group
        foreach ($groups as &$group) {

            usort($group, function($a, $b) {
                return $a['id'] <=> $b['id'];
            });
        }

        return $groups;
    }

$action  = $_GET['action']  ?? '';
$part_id = $_GET['part_id'] ?? null;
$user_id = $_GET['user_id'] ?? null;

// ─── SOAL PRACTICE (acak per part) ───────────────────────────
if ($action === 'practice' && $part_id && $user_id) {

    // Buat attempt baru di user_exam_results dengan exam_type='practice'
    $attempt_code = uniqid('prc_', true);

    $stmt = $pdo->prepare("
        INSERT INTO user_exam_results
            (attempt_code, users_id, exam_type, parts_id, started_at)
        VALUES (?, ?, 'practice', ?, NOW())
    ");
    $stmt->execute([$attempt_code, $user_id, $part_id]);
    $attempt_id = $pdo->lastInsertId();

    // Ambil soal untuk part ini
    $stmt = $pdo->prepare("
        SELECT q.id, q.part_id, q.question_text,
               q.option_a, q.option_b, q.option_c, q.option_d,
               q.correct_answer, q.explanation,
               q.image_file, q.audio_file, q.difficulty_level,
               tp.name AS part_name, tp.type AS part_type
        FROM questions q
        JOIN toeic_parts tp ON q.part_id = tp.id
        WHERE q.part_id = ?
        ORDER BY q.id ASC
    ");
    $stmt->execute([$part_id]);
    $questions = $stmt->fetchAll();

    echo json_encode([
        "status"     => "success",
        "attempt_id" => (int)$attempt_id,
        "part_id"    => (int)$part_id,
        "total"      => count($questions),
        "data"       => $questions
    ]);
}

// ─── SOAL SIMULASI (semua part sesuai proporsi) ───────────────
//  elseif ($action === 'simulation' && $user_id) {

//      // Buat attempt baru di user_exam_results dengan exam_type='simulation'
//      $attempt_code = uniqid('sim_', true);

//      $stmt = $pdo->prepare("
//          INSERT INTO user_exam_results
//              (attempt_code, users_id, exam_type, parts_id, started_at)
//          VALUES (?, ?, 'simulation', NULL, NOW())
//      ");
//      $stmt->execute([$attempt_code, $user_id]);
//      $attempt_id = $pdo->lastInsertId();

//      // Ambil soal per part sesuai proporsi TOEIC
//      $limits = [1 => 6, 2 => 25, 3 => 39, 4 => 30, 5 => 30, 6 => 16, 7 => 54];
//      $allQuestions = [];

//      foreach ($limits as $pid => $limit) {
//          $stmt = $pdo->prepare("
//              SELECT q.id, q.part_id, q.question_text,
//                     q.option_a, q.option_b, q.option_c, q.option_d,
//                     q.correct_answer, q.explanation,
//                     q.image_file, q.audio_file, q.difficulty_level,
//                     tp.name AS part_name, tp.type AS part_type
//              FROM questions q
//              JOIN toeic_parts tp ON q.part_id = tp.id
//              WHERE q.part_id = ?
//              ORDER BY RAND()
//              LIMIT ?
//          ");
//          $stmt->execute([$pid, $limit]);
//          $allQuestions = array_merge($allQuestions, $stmt->fetchAll());
//      }

//      echo json_encode([
//          "status"     => "success",
//          "attempt_id" => (int)$attempt_id,
//          "total"      => count($allQuestions),
//          "data"       => $allQuestions
//      ]);
//  }

 // ─── SOAL SIMULASI (semua part sesuai proporsi) ───────────────
    elseif ($action === 'simulation' && $user_id) {

        // AMBIL LEVEL USER
        $stmt = $pdo->prepare("
            SELECT skill_level
            FROM users
            WHERE id = ?
        ");
        
        $stmt->execute([(int)$user_id]);
        $user = $stmt->fetch();
        $skillLevel = $user['skill_level'] ?? 'beginner';

        // BUAT ATTEMPT SIMULASI BARU
        $attempt_code = uniqid('sim_', true);
        
        $stmt = $pdo->prepare("
            INSERT INTO user_exam_results
            (attempt_code, users_id, exam_type, parts_id, started_at)
            VALUES
            (?, ?, 'simulation', NULL, NOW() )
        ");

        $stmt->execute([
            $attempt_code,
            (int)$user_id
        ]);

        $attempt_id = $pdo->lastInsertId();

        // PROPORSI TOEIC
        $limits = [1 => 6, 2 => 25, 3 => 39, 4 => 30, 5 => 30, 6 => 16, 7 => 54];
        $allQuestions = [];

        foreach ($limits as $pid => $limit) {
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
                JOIN toeic_parts tp
                    ON q.part_id = tp.id
                WHERE q.part_id = ?
                AND q.difficulty_level = ?
                ORDER BY q.id ASC
            ");

            $stmt->execute([
                $pid,
                $skillLevel
            ]);

            $rows = $stmt->fetchAll();

            // PART 3 & 4
            if ($pid == 3 || $pid == 4) {
                $groups = groupQuestions($rows, $pid);
                $keys = array_keys($groups);
                shuffle($keys);
                $selected = [];
                foreach ($keys as $key) {
                    foreach ($groups[$key] as $item) {
                        $selected[] = $item;
                    }
                }

                $selected = array_slice(
                    $selected,
                    0,
                    $limit
                );
            }

            // PART 6 & 7
            elseif ($pid == 6 || $pid == 7) {
                $groups = groupQuestions($rows, $pid);
                $keys = array_keys($groups);
                shuffle($keys);
                $selected = [];
                
                foreach ($keys as $key) {
                    foreach ($groups[$key] as $item) {
                        $selected[] = $item;
                    }
                }

                $selected = array_slice(
                    $selected,
                    0,
                    $limit
                );
            }

            // PART 1,2,5
            else {
                shuffle($rows);
                $selected = array_slice(
                    $rows,
                    0,
                    $limit
                );
            }

            $allQuestions = array_merge(
                $allQuestions,
                $selected
            );
        }

        echo json_encode([
            "status"      => "success",
            "attempt_id"  => (int)$attempt_id,
            "skill_level" => $skillLevel,
            "total"       => count($allQuestions),
            "data"        => $allQuestions
        ]);
    }

    else {
        echo json_encode([
            "status" => "error",
            "message" => "Action tidak dikenali atau parameter kurang"
        ]);
    }
  ?>