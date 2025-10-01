<?php
// Запускаем сессию для хранения данных пользователя, таких как статус авторизации
session_start();

// Определяем переменные для подключения к базе данных
// $host - хост базы данных, обычно "localhost" для локального сервера
$host = "localhost";
// $user - имя пользователя базы данных, по умолчанию "root" для разработки
$user = "root";
// $password - пароль пользователя базы данных, пустой для локальной разработки (не рекомендуется в продакшене)
$password = "";
// $database - имя базы данных, в данном случае "test"
$database = "test";

// Создаем новое соединение с MySQL/MariaDB с использованием предоставленных параметров
$conn = new mysqli($host, $user, $password, $database);

// Проверяем, есть ли ошибка подключения
if ($conn->connect_error) {
    // Если ошибка, выводим сообщение и прекращаем выполнение скрипта
    die("Ошибка подключения: " . $conn->connect_error);
}

// Обработка формы регистрации, если была отправлена POST-запросом с name="register"
if (isset($_POST['register'])) {
    // Экранируем имя пользователя для предотвращения SQL-инъекций
    $username = $conn->real_escape_string($_POST['username']);
    // Хэшируем пароль с использованием password_hash для безопасного хранения
    $password = password_hash($_POST['password'], PASSWORD_DEFAULT); // Шифрование пароля

    // Формируем SQL-запрос для вставки нового пользователя в таблицу users
    $sql = "INSERT INTO users (username, password) VALUES ('$username', '$password')";
    // Выполняем запрос и проверяем результат
    if ($conn->query($sql)) {
        // Если успешно, устанавливаем сообщение об успехе
        $reg_success = "Регистрация успешна! Теперь войдите.";
    } else {
        // Если ошибка, устанавливаем сообщение с текстом ошибки
        $reg_error = "Ошибка регистрации: " . $conn->error;
    }
}

// Обработка формы авторизации, если была отправлена POST-запросом с name="login"
if (isset($_POST['login'])) {
    // Экранируем имя пользователя для безопасности
    $username = $conn->real_escape_string($_POST['username']);
    // Получаем пароль из формы (не хэшируем здесь, так как проверим хэш позже)
    $password = $_POST['password'];
    // Формируем SQL-запрос для поиска пользователя по имени
    $sql = "SELECT * FROM users WHERE username = '$username'";
    // Выполняем запрос и сохраняем результат
    $result = $conn->query($sql);

    // Проверяем, найдена ли хотя бы одна запись
    if ($result->num_rows > 0) {
        // Извлекаем строку с данными пользователя
        $user_row = $result->fetch_assoc();
        // Проверяем, совпадает ли введенный пароль с хэшированным в БД
        if (password_verify($password, $user_row['password'])) {
            // Если да, устанавливаем сессию для авторизации
            $_SESSION['loggedin'] = true;
            // Сохраняем имя пользователя в сессии
            $_SESSION['username'] = $username;
        } else {
            // Если пароль неверный, устанавливаем сообщение об ошибке
            $error = "Неверное имя пользователя или пароль!";
        }
    } else {
        // Если пользователь не найден, устанавливаем сообщение об ошибке
        $error = "Неверное имя пользователя или пароль!";
    }
}

// Обработка выхода из системы, если была отправлена POST-запросом с name="logout"
if (isset($_POST['logout'])) {
    // Уничтожаем все данные сессии
    session_destroy();
    // Перенаправляем на главную страницу
    header("Location: index.php");
    // Прекращаем выполнение скрипта
    exit();
}

// Проверяем, авторизован ли пользователь (есть ли ключ 'loggedin' в сессии)
if (!isset($_SESSION['loggedin'])) {
    // Если не авторизован, выводим HTML-форму для входа и регистрации
    ?>
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Авторизация и Регистрация</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
        <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
        <style>
            body { background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); font-family: 'Arial', sans-serif; }
            .auth-card { max-width: 450px; margin: 100px auto; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); overflow: hidden; animation: fadeIn 1s ease-in-out; }
            .card-header { background: linear-gradient(90deg, #007bff, #6610f2); color: white; text-align: center; padding: 20px; }
            .btn-primary { background: #007bff; border: none; transition: transform 0.3s, box-shadow 0.3s; }
            .btn-primary:hover { transform: scale(1.05); box-shadow: 0 5px 15px rgba(0,123,255,0.4); }
            @keyframes fadeIn { from { opacity: 0; transform: translateY(-50px); } to { opacity: 1; transform: translateY(0); } }
            .tab-pane { padding: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="auth-card card">
                <div class="card-header">
                    <h2 class="mb-0">Добро пожаловать</h2>
                </div>
                <div class="card-body">
                    <ul class="nav nav-tabs" id="authTab" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link active" id="login-tab" data-bs-toggle="tab" data-bs-target="#login" type="button" role="tab">Вход</button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="register-tab" data-bs-toggle="tab" data-bs-target="#register" type="button" role="tab">Регистрация</button>
                        </li>
                    </ul>
                    <div class="tab-content" id="authTabContent">
                        <div class="tab-pane fade show active" id="login" role="tabpanel">
                            <?php if (isset($error)) echo "<div class='alert alert-danger mt-3'>$error</div>"; ?>
                            <form method="post" class="mt-3">
                                <div class="mb-3">
                                    <label for="username" class="form-label">Имя пользователя</label>
                                    <input type="text" class="form-control" name="username" required>
                                </div>
                                <div class="mb-3">
                                    <label for="password" class="form-label">Пароль</label>
                                    <input type="password" class="form-control" name="password" required>
                                </div>
                                <button type="submit" name="login" class="btn btn-primary w-100">Войти</button>
                            </form>
                        </div>
                        <div class="tab-pane fade" id="register" role="tabpanel">
                            <?php if (isset($reg_success)) echo "<div class='alert alert-success mt-3'>$reg_success</div>"; ?>
                            <?php if (isset($reg_error)) echo "<div class='alert alert-danger mt-3'>$reg_error</div>"; ?>
                            <form method="post" class="mt-3">
                                <div class="mb-3">
                                    <label for="username" class="form-label">Имя пользователя</label>
                                    <input type="text" class="form-control" name="username" required>
                                </div>
                                <div class="mb-3">
                                    <label for="password" class="form-label">Пароль</label>
                                    <input type="password" class="form-control" name="password" required>
                                </div>
                                <button type="submit" name="register" class="btn btn-primary w-100">Зарегистрироваться</button>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    </body>
    </html>
    <?php
    // Закрываем соединение с базой данных
    $conn->close();
    // Прекращаем выполнение скрипта, так как пользователь не авторизован
    exit();
}

// Обработка добавления новой записи сотрудника, если была отправлена POST-запросом с name="add"
if (isset($_POST['add'])) {
    // Экранируем фамилию для безопасности
    $lastname = $conn->real_escape_string($_POST['lastname']);
    // Экранируем имя
    $firstname = $conn->real_escape_string($_POST['firstname']);
    // Экранируем отчество
    $middlename = $conn->real_escape_string($_POST['middlename']);
    // Экранируем отдел
    $department = $conn->real_escape_string($_POST['department']);
    // Преобразуем зарплату в целое число
    $salary = (int)$_POST['salary'];

    // Формируем SQL-запрос для вставки новой записи в таблицу employees
    $sql = "INSERT INTO employees (lastname, firstname, middlename, department, salary) 
            VALUES ('$lastname', '$firstname', '$middlename', '$department', $salary)";
    // Выполняем запрос
    $conn->query($sql);
}

// Обработка удаления записи, если была отправлена POST-запросом с name="delete"
if (isset($_POST['delete'])) {
    // Преобразуем ID в целое число
    $id = (int)$_POST['id'];
    // Формируем SQL-запрос для удаления записи по ID
    $sql = "DELETE FROM employees WHERE id = $id";
    // Выполняем запрос
    $conn->query($sql);
}

// Обработка обновления записи, если была отправлена POST-запросом с name="update"
if (isset($_POST['update'])) {
    // Преобразуем ID в целое число
    $id = (int)$_POST['id'];
    // Экранируем фамилию
    $lastname = $conn->real_escape_string($_POST['lastname']);
    // Экранируем имя
    $firstname = $conn->real_escape_string($_POST['firstname']);
    // Экранируем отчество
    $middlename = $conn->real_escape_string($_POST['middlename']);
    // Экранируем отдел
    $department = $conn->real_escape_string($_POST['department']);
    // Преобразуем зарплату в целое число
    $salary = (int)$_POST['salary'];

    // Формируем SQL-запрос для обновления записи по ID
    $sql = "UPDATE employees SET lastname='$lastname', firstname='$firstname', middlename='$middlename', 
            department='$department', salary=$salary WHERE id=$id";
    // Выполняем запрос
    $conn->query($sql);
}

// Получаем все записи из таблицы employees, отсортированные по ID
$result = $conn->query("SELECT * FROM employees ORDER BY id");
?>

<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Управление сотрудниками</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
    <style>
        body { background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); padding-top: 40px; font-family: 'Arial', sans-serif; }
        .main-card { border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); overflow: hidden; animation: fadeIn 1s ease-in-out; }
        .card-header { background: linear-gradient(90deg, #007bff, #6610f2); color: white; padding: 20px; }
        .btn { transition: transform 0.3s, box-shadow 0.3s; }
        .btn:hover { transform: scale(1.05); box-shadow: 0 5px 15px rgba(0,0,0,0.3); }
        .table { border-radius: 10px; overflow: hidden; animation: slideUp 0.5s ease-in-out; }
        .table th, .table td { vertical-align: middle; text-align: center; }
        .table-hover tr:hover { background-color: #e9ecef; transform: scale(1.01); transition: transform 0.2s; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(-50px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes slideUp { from { opacity: 0; transform: translateY(50px); } to { opacity: 1; transform: translateY(0); } }
        .modal-content { border-radius: 15px; box-shadow: 0 5px 20px rgba(0,0,0,0.3); animation: zoomIn 0.3s; }
        @keyframes zoomIn { from { opacity: 0; transform: scale(0.8); } to { opacity: 1; transform: scale(1); } }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-lg-12">
                <div class="main-card card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h1 class="mb-0">Управление сотрудниками</h1>
                        <form method="post">
                            <button type="submit" name="logout" class="btn btn-danger"><i class="bi bi-box-arrow-right"></i> Выход</button>
                        </form>
                    </div>
                    <div class="card-body">
                        <!-- Форма добавления -->
                        <h2 class="mb-4 text-center">Добавление сотрудника</h2>
                        <form method="post" class="row g-3 justify-content-center">
                            <div class="col-md-2">
                                <label for="lastname" class="form-label">Фамилия</label>
                                <input type="text" class="form-control" name="lastname" required>
                            </div>
                            <div class="col-md-2">
                                <label for="firstname" class="form-label">Имя</label>
                                <input type="text" class="form-control" name="firstname" required>
                            </div>
                            <div class="col-md-2">
                                <label for="middlename" class="form-label">Отчество</label>
                                <input type="text" class="form-control" name="middlename" required>
                            </div>
                            <div class="col-md-2">
                                <label for="department" class="form-label">Отдел</label>
                                <input type="text" class="form-control" name="department" required>
                            </div>
                            <div class="col-md-2">
                                <label for="salary" class="form-label">Зарплата</label>
                                <input type="number" class="form-control" name="salary" required min="0">
                            </div>
                            <div class="col-md-2 d-flex align-items-end">
                                <button type="submit" name="add" class="btn btn-success w-100"><i class="bi bi-plus-circle"></i> Добавить</button>
                            </div>
                        </form>

                        <!-- Таблица сотрудников -->
                        <h2 class="mt-5 mb-4 text-center">Список сотрудников</h2>
                        <table class="table table-striped table-hover table-bordered">
                            <thead class="table-dark">
                                <tr>
                                    <th scope="col">ID</th>
                                    <th scope="col">Фамилия</th>
                                    <th scope="col">Имя</th>
                                    <th scope="col">Отчество</th>
                                    <th scope="col">Отдел</th>
                                    <th scope="col">Зарплата (до НДФЛ)</th>
                                    <th scope="col">Зарплата (после НДФЛ)</th>
                                    <th scope="col" class="text-center">Действия</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php 
                                // Цикл по результатам запроса, извлекаем каждую строку как ассоциативный массив
                                while ($row = $result->fetch_assoc()) {
                                    // Рассчитываем зарплату до НДФЛ (исходная)
                                    $salaryBeforeTax = $row['salary'];
                                    // Устанавливаем ставку НДФЛ 13%
                                    $taxRate = 0.13;
                                    // Рассчитываем зарплату после вычета НДФЛ
                                    $salaryAfterTax = $salaryBeforeTax * (1 - $taxRate);
                                ?>
                                    <tr>
                                        <td><?php echo htmlspecialchars($row['id']); ?></td>
                                        <td><?php echo htmlspecialchars($row['lastname']); ?></td>
                                        <td><?php echo htmlspecialchars($row['firstname']); ?></td>
                                        <td><?php echo htmlspecialchars($row['middlename']); ?></td>
                                        <td><?php echo htmlspecialchars($row['department']); ?></td>
                                        <td><?php echo number_format($salaryBeforeTax, 2); ?> руб.</td>
                                        <td><?php echo number_format($salaryAfterTax, 2); ?> руб.</td>
                                        <td class="text-center">
                                            <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#editModal<?php echo $row['id']; ?>"><i class="bi bi-pencil-square"></i> Редактировать</button>
                                            <form method="post" style="display:inline;">
                                                <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                                <button type="submit" name="delete" class="btn btn-danger btn-sm" onclick="return confirm('Вы уверены?')"><i class="bi bi-trash"></i> Удалить</button>
                                            </form>
                                        </td>
                                    </tr>

                                    <!-- Модальное окно для редактирования -->
                                    <div class="modal fade" id="editModal<?php echo $row['id']; ?>" tabindex="-1" aria-labelledby="editModalLabel<?php echo $row['id']; ?>" aria-hidden="true">
                                        <div class="modal-dialog modal-dialog-centered">
                                            <div class="modal-content">
                                                <div class="modal-header bg-warning text-dark">
                                                    <h5 class="modal-title" id="editModalLabel<?php echo $row['id']; ?>">Редактирование сотрудника ID: <?php echo $row['id']; ?></h5>
                                                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                                </div>
                                                <div class="modal-body">
                                                    <form method="post">
                                                        <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                                        <div class="mb-3">
                                                            <label for="lastname" class="form-label">Фамилия</label>
                                                            <input type="text" class="form-control" name="lastname" value="<?php echo htmlspecialchars($row['lastname']); ?>" required>
                                                        </div>
                                                        <div class="mb-3">
                                                            <label for="firstname" class="form-label">Имя</label>
                                                            <input type="text" class="form-control" name="firstname" value="<?php echo htmlspecialchars($row['firstname']); ?>" required>
                                                        </div>
                                                        <div class="mb-3">
                                                            <label for="middlename" class="form-label">Отчество</label>
                                                            <input type="text" class="form-control" name="middlename" value="<?php echo htmlspecialchars($row['middlename']); ?>" required>
                                                        </div>
                                                        <div class="mb-3">
                                                            <label for="department" class="form-label">Отдел</label>
                                                            <input type="text" class="form-control" name="department" value="<?php echo htmlspecialchars($row['department']); ?>" required>
                                                        </div>
                                                        <div class="mb-3">
                                                            <label for="salary" class="form-label">Зарплата</label>
                                                            <input type="number" class="form-control" name="salary" value="<?php echo $row['salary']; ?>" required min="0">
                                                        </div>
                                                        <button type="submit" name="update" class="btn btn-primary w-100"><i class="bi bi-save"></i> Сохранить изменения</button>
                                                    </form>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                <?php } ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

<?php
// Закрываем соединение с базой данных в конце скрипта
$conn->close();
?>
