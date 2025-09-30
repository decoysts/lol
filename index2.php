<?php
session_start();

// Подключение к базе данных
$host = "localhost";
$user = "root";
$password = "";
$database = "test";

$conn = new mysqli($host, $user, $password, $database);

if ($conn->connect_error) {
    die("Ошибка подключения: " . $conn->connect_error);
}

// Авторизация
if (isset($_POST['login'])) {
    $username = $conn->real_escape_string($_POST['username']);
    $password = $conn->real_escape_string($_POST['password']);
    $sql = "SELECT * FROM users WHERE username = '$username' AND password = '$password'";
    $result = $conn->query($sql);

    if ($result->num_rows > 0) {
        $_SESSION['loggedin'] = true;
        $_SESSION['username'] = $username;
    } else {
        $error = "Неверное имя пользователя или пароль!";
    }
}

// Выход
if (isset($_POST['logout'])) {
    session_destroy();
    header("Location: index.php");
    exit();
}

// Проверка авторизации
if (!isset($_SESSION['loggedin'])) {
    include 'login.php';
    exit();
}

// Обработка добавления записи
if (isset($_POST['add'])) {
    $lastname = $conn->real_escape_string($_POST['lastname']);
    $firstname = $conn->real_escape_string($_POST['firstname']);
    $middlename = $conn->real_escape_string($_POST['middlename']);
    $department = $conn->real_escape_string($_POST['department']);
    $salary = (int)$_POST['salary'];

    $sql = "INSERT INTO employees (lastname, firstname, middlename, department, salary) 
            VALUES ('$lastname', '$firstname', '$middlename', '$department', $salary)";
    $conn->query($sql);
}

// Обработка удаления записи
if (isset($_POST['delete'])) {
    $id = (int)$_POST['id'];
    $sql = "DELETE FROM employees WHERE id = $id";
    $conn->query($sql);
}

// Обработка редактирования записи
if (isset($_POST['edit'])) {
    $id = (int)$_POST['id'];
    $lastname = $conn->real_escape_string($_POST['lastname']);
    $firstname = $conn->real_escape_string($_POST['firstname']);
    $middlename = $conn->real_escape_string($_POST['middlename']);
    $department = $conn->real_escape_string($_POST['department']);
    $salary = (int)$_POST['salary'];

    $sql = "UPDATE employees SET lastname='$lastname', firstname='$firstname', middlename='$middlename', 
            department='$department', salary=$salary WHERE id=$id";
    $conn->query($sql);
}

// Получение данных из базы
$result = $conn->query("SELECT * FROM employees ORDER BY id");
?>

<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Управление сотрудниками</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <style>
        body {
            background-color: #f8f9fa;
            padding-top: 20px;
        }
        .card {
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .table-actions {
            white-space: nowrap;
        }
        .btn-group-sm > .btn {
            padding: 0.25rem 0.5rem;
        }
        .login-card {
            max-width: 400px;
            margin: 0 auto;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-lg-10">
                <div class="card">
                    <div class="card-header bg-primary text-white d-flex justify-content-between align-items-center">
                        <h1 class="mb-0">Управление сотрудниками</h1>
                        <form method="post">
                            <button type="submit" name="logout" class="btn btn-danger btn-sm">Выход</button>
                        </form>
                    </div>
                    <div class="card-body">
                        <!-- Форма добавления -->
                        <h2>Добавление сотрудника</h2>
                        <form method="post" class="row g-3">
                            <div class="col-md-4">
                                <label for="lastname" class="form-label">Фамилия</label>
                                <input type="text" class="form-control" name="lastname" required>
                            </div>
                            <div class="col-md-4">
                                <label for="firstname" class="form-label">Имя</label>
                                <input type="text" class="form-control" name="firstname" required>
                            </div>
                            <div class="col-md-4">
                                <label for="middlename" class="form-label">Отчество</label>
                                <input type="text" class="form-control" name="middlename" required>
                            </div>
                            <div class="col-md-4">
                                <label for="department" class="form-label">Отдел</label>
                                <input type="text" class="form-control" name="department" required>
                            </div>
                            <div class="col-md-4">
                                <label for="salary" class="form-label">Зарплата</label>
                                <input type="number" class="form-control" name="salary" required min="0">
                            </div>
                            <div class="col-12">
                                <button type="submit" name="add" class="btn btn-primary">Добавить</button>
                            </div>
                        </form>

                        <!-- Таблица сотрудников -->
                        <h2 class="mt-4">Список сотрудников</h2>
                        <table class="table table-striped table-hover">
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
                                <?php while ($row = $result->fetch_assoc()) {
                                    $salaryBeforeTax = $row['salary'];
                                    $taxRate = 0.13; // НДФЛ 13%
                                    $salaryAfterTax = $salaryBeforeTax * (1 - $taxRate);
                                ?>
                                    <tr>
                                        <td><?php echo $row['id']; ?></td>
                                        <td><?php echo htmlspecialchars($row['lastname']); ?></td>
                                        <td><?php echo htmlspecialchars($row['firstname']); ?></td>
                                        <td><?php echo htmlspecialchars($row['middlename']); ?></td>
                                        <td><?php echo htmlspecialchars($row['department']); ?></td>
                                        <td><?php echo number_format($salaryBeforeTax, 2); ?> руб.</td>
                                        <td><?php echo number_format($salaryAfterTax, 2); ?> руб.</td>
                                        <td class="table-actions text-center">
                                            <form method="post" style="display:inline;">
                                                <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                                <button type="submit" name="delete" class="btn btn-danger btn-sm" onclick="return confirm('Вы уверены?')">Удалить</button>
                                            </form>
                                            <form method="post" style="display:inline;">
                                                <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                                <input type="hidden" name="lastname" value="<?php echo htmlspecialchars($row['lastname']); ?>">
                                                <input type="hidden" name="firstname" value="<?php echo htmlspecialchars($row['firstname']); ?>">
                                                <input type="hidden" name="middlename" value="<?php echo htmlspecialchars($row['middlename']); ?>">
                                                <input type="hidden" name="department" value="<?php echo htmlspecialchars($row['department']); ?>">
                                                <input type="hidden" name="salary" value="<?php echo $row['salary']; ?>">
                                                <button type="submit" name="edit" class="btn btn-warning btn-sm">Редактировать</button>
                                            </form>
                                        </td>
                                    </tr>
                                <?php } ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

<?php
$conn->close();
?>

<?php
// Файл login.php (создайте отдельный файл)
if (isset($_POST['login'])) {
    $username = $conn->real_escape_string($_POST['username']);
    $password = $conn->real_escape_string($_POST['password']);
    $sql = "SELECT * FROM users WHERE username = '$username' AND password = '$password'";
    $result = $conn->query($sql);

    if ($result->num_rows > 0) {
        $_SESSION['loggedin'] = true;
        $_SESSION['username'] = $username;
        header("Location: index.php");
        exit();
    } else {
        $error = "Неверное имя пользователя или пароль!";
    }
}
?>

<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Авторизация</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .login-card {
            max-width: 400px;
            margin: 0 auto;
            margin-top: 100px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="card login-card">
            <div class="card-header bg-primary text-white">
                <h2 class="mb-0">Вход</h2>
            </div>
            <div class="card-body">
                <?php if (isset($error)) echo "<div class='alert alert-danger'>$error</div>"; ?>
                <form method="post">
                    <div class="mb-3">
                        <label for="
