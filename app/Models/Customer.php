<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use BelongsToCompany, HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id', 'name', 'phone', 'email', 'address', 'notes', 'credit_limit', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'credit_limit' => 'decimal:2',
        ];
    }

    public function sales(): HasMany
    {
        return $this->hasMany(Sale::class);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function scopeSearch(Builder $query, ?string $term): Builder
    {
        if (! $term) {
            return $query;
        }

        return $query->where(function (Builder $q) use ($term) {
            $q->where('name', 'like', "%{$term}%")
                ->orWhere('phone', 'like', "%{$term}%")
                ->orWhere('email', 'like', "%{$term}%");
        });
    }

    public function totalPurchases(): float
    {
        return (float) $this->sales()->completed()->sum('total_amount');
    }

    public function totalPaid(): float
    {
        return (float) $this->sales()->completed()->sum('paid_amount');
    }

    public function totalRemaining(): float
    {
        return (float) $this->sales()->completed()->sum('remaining_amount');
    }

    public function lastOrderAt(): ?\Illuminate\Support\Carbon
    {
        return $this->sales()->completed()->latest('sold_at')->value('sold_at');
    }

    // Les factures (Phase 6) s'ajouteront ici de la même façon.
}
