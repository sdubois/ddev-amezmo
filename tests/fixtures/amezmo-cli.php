<?php

declare(strict_types=1);

$arguments = array_slice($argv, 1);
if ($arguments === ['instances', 'list', '--output=json']) {
    echo json_encode([
        [
            'id' => 4321,
            'name' => 'Example application',
            'environments' => [
                [
                    'name' => 'production',
                    'ssh_host' => 'production.example.amezmo.co',
                    'ssh_port' => 23456,
                    'app_type' => 'drupal',
                    'app_domain' => 'www.example.test',
                    'container_root_directory' => '/webroot',
                    'storage_directory' => '/webroot/storage',
                ],
                [
                    'name' => 'staging',
                    'ssh_host' => 'staging.example.amezmo.co',
                    'ssh_port' => 23456,
                    'app_type' => 'drupal',
                    'app_domain' => 'staging.example.amezmo.co',
                    'container_root_directory' => '/webroot/staging-example',
                    'storage_directory' => '/webroot/staging-example/storage',
                ],
            ],
        ],
    ], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT);
    exit(0);
}

fwrite(STDERR, 'Unexpected fixture arguments: ' . implode(' ', $arguments) . PHP_EOL);
exit(2);
