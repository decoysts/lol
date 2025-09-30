<?php
// Подключение к базе данных
$host = "localhost";
$user = "root";
$password = "";
$database = "test";

$conn = new mysqli($host, $user, $password, $database);

if ($conn->connect_error) {
    die("Ошибка подключения: " . $conn->connect_error);
}

// Обработка добавления записи
if (isset($_POST['add'])) {
    $lastname = $conn->real_escape_string($_POST['lastname']);
    $salary = (int)$_POST['salary'];

    $sql = "INSERT INTO employees (lastname, salary) VALUES ('$lastname', $salary)";
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
    $salary = (int)$_POST['salary'];

    $sql = "UPDATE employees SET lastname='$lastname', salary=$salary WHERE id=$id";
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
    <!-- Bootstrap CSS -->
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
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-lg-10">
                <div class="card">
                    <div class="card-header bg-primary text-white">
                        <h1 class="mb-0">Управление сотрудниками</h1>
                    </div>
                    <div class="card-body">
                        <!-- Форма добавления -->
                        <h2>Добавление сотрудника</h2>
                        <form method="post" class="row g-3">
                            <div class="col-md-6">
                                <label for="lastname" class="form-label">Фамилия</label>
                                <input type="text" class="form-control" name="lastname" required>
                            </div>
                            <div class="col-md-6">
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
                                    <th scope="col">Зарплата</th>
                                    <th scope="col" class="text-center">Действия</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php while ($row = $result->fetch_assoc()) { ?>
                                    <tr>
                                        <td><?php echo $row['id']; ?></td>
                                        <td><?php echo htmlspecialchars($row['lastname']); ?></td>
                                        <td><?php echo $row['salary']; ?></td>
                                        <td class="table-actions text-center">
                                            <form method="post" style="display:inline;">
                                                <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                                <button type="submit" name="delete" class="btn btn-danger btn-sm" onclick="return confirm('Вы уверены?')">Удалить</button>
                                            </form>
                                            <form method="post" style="display:inline;">
                                                <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                                <input type="hidden" name="lastname" value="<?php echo htmlspecialchars($row['lastname']); ?>">
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

    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>

<?php
$conn->close();
?>
