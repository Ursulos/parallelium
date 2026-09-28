<?php

namespace App\Models;

use App\Enums\ObjectiveScope;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CommercialObjective extends Model
{
    use BelongsToCompany;

    protected $fillable = [
        'company_id', 'year', 'month', 'scope', 'commercial_id', 'sector_id', 'city_id',
        'target_volume', 'target_amount',
    ];

    protected function casts(): array
    {
        return [
            'scope' => ObjectiveScope::class,
            'target_amount' => 'decimal:2',
        ];
    }

    public function commercial(): BelongsTo
    {
        return $this->belongsTo(Commercial::class);
    }

    public function sector(): BelongsTo
    {
        return $this->belongsTo(SalesSector::class, 'sector_id');
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(SalesCity::class, 'city_id');
    }

    public function scopeForYearMonth(Builder $query, int $year, int $month): Builder
    {
        return $query->where('year', $year)->where('month', $month);
    }

    public function scopeGlobal(Builder $query): Builder
    {
        return $query->where('scope', ObjectiveScope::Global->value);
    }
}
