<?php

error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: text/plain; charset=utf-8');

echo "=== TEST PHP ===\n\n";

echo "exec tersedia: ";
echo function_exists('exec')
    ? "YA\n"
    : "TIDAK\n";

echo "\n=== TEST PYTHON ===\n";

$output = [];
$returnCode = 0;

exec(
    'python --version 2>&1',
    $output,
    $returnCode
);

echo "Return code: $returnCode\n";
echo "Output:\n";
echo implode("\n", $output);