<!DOCTYPE html>
<html>
<head>
    <title>Request Account Deletion</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; background:#f4f6f9; }
        .container {
            max-width: 600px;
            margin: 50px auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 8px 20px rgba(0,0,0,0.08);
        }
        input, textarea {
            width:100%;
            padding:12px;
            margin-top:8px;
            margin-bottom:15px;
            border-radius:8px;
            border:1px solid #ccc;
        }
        button {
            width:100%;
            padding:12px;
            background:#1a73e8;
            color:white;
            border:none;
            border-radius:8px;
            font-size:16px;
            cursor:pointer;
        }
        button:hover { background:#155ec4; }
        .info {
            background:#eef5ff;
            padding:15px;
            border-left:4px solid #1a73e8;
            margin-bottom:20px;
        }
    </style>
</head>
<body>

<div class="container">
    <h2>Request Account Deletion</h2>

    <div class="info">
        <strong>Data that will be deleted:</strong><br>
        • Profile Information<br>
        • Booking History<br>
        • Saved Passenger Details<br><br>
        Processing time: 3–7 working days.
    </div>

    <form action="submit_delete_request.php" method="POST">
        <label>Full Name</label>
        <input type="text" name="name" required>

        <label>Registered Email</label>
        <input type="email" name="email" required>

        <label>Reason (Optional)</label>
        <textarea name="reason"></textarea>

        <button type="submit">Submit Request</button>
    </form>
</div>

</body>
</html>