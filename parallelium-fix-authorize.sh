#!/usr/bin/env bash
#
# Parallelium - Correctif : "Call to undefined method authorize()"
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
set -e
echo "Application du correctif..."

mkdir -p "app/Http/Controllers"
cat > "app/Http/Controllers/Controller.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Http\Controllers;

use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

abstract class Controller
{
    use AuthorizesRequests;
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant : php artisan view:clear"
