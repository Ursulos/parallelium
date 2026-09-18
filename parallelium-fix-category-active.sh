#!/usr/bin/env bash
#
# Parallelium - Correctif : "Call to undefined method Category::active()"
# A executer depuis la RACINE du projet Laravel (la ou se trouve artisan).
set -e
echo "Application du correctif..."

mkdir -p "app/Models"
cat > "app/Models/Category.php" << 'PARALLELIUM_FILE_EOF'
<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Category extends Model
{
    use BelongsToCompany, HasFactory, SoftDeletes;

    protected $fillable = ['company_id', 'name', 'description', 'is_active'];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }
}
PARALLELIUM_FILE_EOF

echo "Termine. Lance maintenant : php artisan view:clear"
