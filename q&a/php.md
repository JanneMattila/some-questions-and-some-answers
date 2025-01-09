# PHP

Simple PHP code snippets.

```php
<?php
echo 'Current PHP version: ' . phpversion();
?>
```

## Redirect logic options

```php
<?php
header("Location: https://myapp.jannemattila.com/goto/here?id=123&path=/here", true, 301);
exit();
?>
```

```php
<?php
$headers = getallheaders();
$host = isset($headers['Host']) ? $headers['Host'] : '-';

switch ($host) {
    case 'myapp1.jannemattila.com':
        break;
    case 'myapp2.jannemattila.com':
        break;
    default:
        echo "Host: $host";
        break;
}
?>
```

```php
<?php
$go = isset($_GET['go']) ? $_GET['go'] : 'Parameter not found';

switch ($go) {
    case 'myapp1':
        break;
    case 'myapp2':
        break;
    default:
        echo "Host: $host";
        break;
}
?>
```
