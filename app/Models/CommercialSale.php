<?php

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class CommercialSale extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $fillable = [
        'company_id', 'commercial_id', 'customer_id', 'sector_id', 'city_id',
        'sale_date', 'quantity', 'amount', 'is_exceptional', 'comment', 'entered_by',
    ];

    protected function casts(): array
    {
        return [
            'sale_date' => 'date',
            'amount' => 'decimal:2',
            'is_exceptional' => 'boolean',
        ];
    }

    public function commercial(): BelongsTo
    {
        return $this->belongsTo(Commercial::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function sector(): BelongsTo
    {
        return $this->belongsTo(SalesSector::class, 'sector_id');
    }

    public function city(): BelongsTo
    {
        return $this->belongsTo(SalesCity::class, 'city_id');
    }

    public function enteredBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'entered_by');
    }

    public function scopeBetweenDates(Builder $query, $from, $to): Builder
    {
        return $query->whereBetween('sale_date', [$from, $to]);
    }

    public function scopeForYearMonth(Builder $query, int $year, int $month): Builder
    {
        return $query->whereYear('sale_date', $year)->whereMonth('sale_date', $month);
    }
}
