<?php
// ==========================================
// БЛОК ФУНКЦИЙ ШИФРОВАНИЯ ДЛЯ V3 
// (Встроено сюда, чтобы не нужен был crypto.php)
// ==========================================
function generateEncryptionKey() { return base64_encode(random_bytes(32)); }
function getOrCreateKey($keyFile = 'encryption.key') {
    if (file_exists($keyFile)) return file_get_contents($keyFile);
    $key = generateEncryptionKey(); file_put_contents($keyFile, $key); chmod($keyFile, 0600); return $key;
}
function encryptData($data, $key = null) {
    if (empty($data)) return "";
    if ($key === null) $key = getOrCreateKey();
    $encryptionKey = base64_decode($key);
    $cipher = "AES-256-CBC";
    $ivLength = openssl_cipher_iv_length($cipher);
    $iv = openssl_random_pseudo_bytes($ivLength);
    $encrypted = openssl_encrypt($data, $cipher, $encryptionKey, OPENSSL_RAW_DATA, $iv);
    return base64_encode($iv . $encrypted);
}
function decryptData($encryptedData, $key = null) {
    if (empty($encryptedData)) return "";
    if ($key === null) $key = getOrCreateKey();
    $encryptionKey = base64_decode($key);
    $combined = base64_decode($encryptedData);
    $cipher = "AES-256-CBC";
    $ivLength = openssl_cipher_iv_length($cipher);
    $iv = substr($combined, 0, $ivLength);
    $encrypted = substr($combined, $ivLength);
    return openssl_decrypt($encrypted, $cipher, $encryptionKey, OPENSSL_RAW_DATA, $iv);
}
function encryptToFile($data, $filePath, $key = null) {
    return file_put_contents($filePath, encryptData($data, $key)) !== false;
}
function decryptFromFile($filePath, $key = null) {
    if (!file_exists($filePath)) return "";
    return decryptData(file_get_contents($filePath), $key);
}

// ==========================================
// МАРШРУТИЗАЦИЯ И МЕНЮ ВЫБОРА ВЕРСИИ
// ==========================================
$version = isset($_GET['v']) ? $_GET['v'] : '1';

// Единое меню навигации, которое мы будем выводить во всех версиях
$navMenu = '
<div style="background: #2c3e50; padding: 15px; text-align: center; font-family: Arial, sans-serif; margin-bottom: 20px;">
    <a href="?v=1" style="color: white; margin: 0 15px; text-decoration: none; font-size: 18px; font-weight: '.($version == '1' ? 'bold; border-bottom: 2px solid #4CAF50; padding-bottom: 3px;' : 'normal;').'">V1: Базовый</a>
    <a href="?v=2" style="color: white; margin: 0 15px; text-decoration: none; font-size: 18px; font-weight: '.($version == '2' ? 'bold; border-bottom: 2px solid #3498db; padding-bottom: 3px;' : 'normal;').'">V2: Bootstrap</a>
    <a href="?v=3" style="color: white; margin: 0 15px; text-decoration: none; font-size: 18px; font-weight: '.($version == '3' ? 'bold; border-bottom: 2px solid #e74c3c; padding-bottom: 3px;' : 'normal;').'">V3: Крипто</a>
</div>';

// ==========================================
// ЛОГИКА ВЕРСИИ 1 (Базовый чат)
// ==========================================
if ($version === '1') {
    $messagesFile = 'messages.txt';
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['name']) && isset($_POST['message'])) {
        $name = trim($_POST['name']);
        $message = trim($_POST['message']);
        if (!empty($name) && !empty($message)) {
            $time = date('H:i:s');
            $formattedMessage = "[$time] $name: $message\n";
            file_put_contents($messagesFile, $formattedMessage, FILE_APPEND);
        }
        header('Location: ?v=1');
        exit;
    }
    $messages = "";
    if (file_exists($messagesFile)) {
        $messages = file_get_contents($messagesFile);
    }
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>Easy chat - V1</title>
</head>
<body style="margin: 0; padding-bottom: 50px;">
    <?php echo $navMenu; ?>
    <div style="padding: 0 20px;">
        <h1>Easy chat V1</h1>
        <form method="POST" action="?v=1">
            <label for="name">Enter name:</label>
            <input type="text" name="name" id="name" required>
            <br><br>
            <label for="message">Message:</label>
            <input type="text" name="message" id="message" required>
            <br><br>
            <button type="submit">Send</button>
        </form>
        <hr>
        <h2>Message:</h2>
        <pre><?php echo htmlspecialchars($messages); ?></pre>
    </div>
</body>
</html>
<?php

// ==========================================
// ЛОГИКА ВЕРСИИ 2 (Стиль Bootstrap)
// ==========================================
} elseif ($version === '2') {
    $messagesFile = 'messages.txt'; // Используем тот же файл, что и в V1
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['name']) && isset($_POST['message'])) {
        $name = trim($_POST['name']);
        $message = trim($_POST['message']);
        if (!empty($name) && !empty($message)) {
            $time = date('H:i:s');
            $formattedMessage = "[$time] $name: $message\n";
            file_put_contents($messagesFile, $formattedMessage, FILE_APPEND);
        }
        header('Location: ?v=2');
        exit;
    }
    $messages = "";
    if (file_exists($messagesFile)) {
        $messages = file_get_contents($messagesFile);
    }
    $messageLines = $messages ? explode("\n", trim($messages)) : [];
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0"> 
    <title>Easy chat - V2</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body style="margin: 0; background-color: #f8f9fa;">
    <?php echo $navMenu; ?>
    <div class="container mt-4">
        <div class="row justify-content-center">
            <div class="col-md-8">
                <div class="card shadow-sm mb-4">
                    <div class="card-header bg-primary text-white"> 
                        <h2 class="text-center mb-0">Easy chat V2</h2>
                    </div>
                </div>
                <div class="card shadow-sm mb-4">
                    <div class="card-body">
                        <form method="POST" action="?v=2">
                            <div class="row g-3">
                                <div class="col-md-4">
                                    <label for="name" class="form-label">Your name</label>
                                    <input type="text" class="form-control" id="name" name="name" required>
                                </div>
                                <div class="col-md-6">
                                    <label for="message" class="form-label">Message</label>
                                    <input type="text" class="form-control" id="message" name="message" required>
                                </div>
                                <div class="col-md-2 d-flex align-items-end">
                                    <button type="submit" class="btn btn-primary w-100">Send</button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
                <div class="card shadow-sm">
                    <div class="card-header bg-secondary text-white">
                        <h4 class="mb-0">Messages</h4>
                    </div>
                    <div class="card-body" style="max-height: 500px; overflow-y: auto;">
                        <?php if (empty($messageLines) || (count($messageLines) === 1 && empty($messageLines[0]))): ?>
                            <div class="alert alert-info text-center">Empty!</div>
                        <?php else: ?>
                            <div class="list-group">
                                <?php foreach (array_reverse($messageLines) as $line): ?>
                                    <?php if (!empty(trim($line))): ?>
                                        <?php
                                        if (preg_match('/^\[(.*?)\]\s*(.*?):\s*(.*)/', $line, $matches)) {
                                            $time = htmlspecialchars($matches[1]);
                                            $name = htmlspecialchars($matches[2]);
                                            $msg = htmlspecialchars($matches[3]);
                                        } else {
                                            $time = ''; $name = 'System'; $msg = htmlspecialchars($line);
                                        }
                                        ?>
                                        <div class="list-group-item">
                                            <div class="d-flex justify-content-between align-items-start">
                                                <div>
                                                    <strong class="text-primary"><?php echo $name; ?>:</strong> 
                                                    <span class="text-muted ms-2"><?php echo $msg; ?></span>
                                                </div>
                                                <small class="text-muted"><?php echo $time; ?></small>
                                            </div>
                                        </div>
                                    <?php endif; ?>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
<?php

// ==========================================
// ЛОГИКА ВЕРСИИ 3 (Крипто Чат)
// ==========================================
} elseif ($version === '3') {
    $messagesFile = 'messages_encrypted.txt'; // Свой файл для шифрования
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['name']) && isset($_POST['message'])) {
        $name = trim($_POST['name']);
        $message = trim($_POST['message']);
        if (!empty($name) && !empty($message)) {
            $time = date('Y-m-d H:i:s');
            $formattedMessage = "[$time] $name: $message\n";
            $existingMessages = decryptFromFile($messagesFile);
            $existingMessages .= $formattedMessage;
            encryptToFile($existingMessages, $messagesFile);
        }
        header('Location: ?v=3');
        exit;
    }
    $messages = decryptFromFile($messagesFile);
    $messageLines = $messages ? explode("\n", trim($messages)) : [];
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>Crypto Chat - V3</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f0f0f0; margin: 0; }
        .container { background-color: white; border-radius: 5px; padding: 20px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); max-width: 800px; margin: 20px auto; }
        .encrypted-badge { background-color: #e74c3c; color: white; padding: 5px 10px; border-radius: 3px; font-size: 12px; display: inline-block; margin-bottom: 10px; font-weight: bold; }
        input, button { padding: 8px; margin: 5px; border: 1px solid #ddd; border-radius: 3px; }
        button { background-color: #e74c3c; color: white; border: none; cursor: pointer; font-weight: bold;}
        button:hover { background-color: #c0392b; }
        .message { background-color: #f9f9f9; padding: 10px; margin: 5px 0; border-left: 3px solid #e74c3c; }
        .message strong { color: #e74c3c; }
        .message-time { color: #999; font-size: 12px; }
    </style>
</head>
<body>
    <?php echo $navMenu; ?>
    <div class="container">
        <div class="encrypted-badge">AES-256 ENCRYPTED</div>
        <h1>Crypto chat V3</h1>
        <form method="POST" action="?v=3">
            <label>NAME:</label>
            <input type="text" name="name" required>
            <br>
            <label>Message:</label>
            <input type="text" name="message" required size="50">
            <br>
            <button type="submit">Send (crypto)</button>
        </form>
        <div class="messages" style="margin-top: 20px; border-top: 2px solid #eee; padding-top: 20px;">
            <h2>Message:</h2>
            <?php if (empty($messageLines) || (count($messageLines) === 1 && empty($messageLines[0]))): ?>
                <p><em>NO MESSAGES</em></p>
            <?php else: ?>
                <?php foreach (array_reverse($messageLines) as $line): ?>
                    <?php if (!empty(trim($line))): ?>
                        <?php
                        if (preg_match('/^\[(.*?)\]\s*(.*?):\s*(.*)/', $line, $matches)) {
                            $time = htmlspecialchars($matches[1]);
                            $name = htmlspecialchars($matches[2]);
                            $msg = htmlspecialchars($matches[3]);
                        } else {
                            $time = ''; $name = 'Система'; $msg = htmlspecialchars($line);
                        }
                        ?>
                        <div class="message">
                            <strong><?php echo $name; ?>:</strong>
                            <?php echo $msg; ?>
                            <span class="message-time">(<?php echo $time; ?>)</span>
                        </div>
                    <?php endif; ?>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>
</body>
</html>
<?php } ?>
