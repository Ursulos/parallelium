<?php

namespace Database\Factories;

use App\Models\Sale;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Sale>
 */
class SaleFactory extends Factory
{
    protected $model = Sale::class;

    public function definition(): array
    {
        return [
            'sale_number' => 'SALE-'.now()->year.'-'.str_pad((string) fake()->unique()->numberBetween(1, 999999), 6, '0', STR_PAD_LEFT),
            'subtotal' => 0,
            'discount' => 0,
            'total_amount' => 0,
            'paid_amount' => 0,
            'remaining_amount' => 0,
            'payment_status' => 'unpaid',
            'sale_status' => 'completed',
            'payment_method' => 'cash',
            'sold_at' => now(),
        ];
    }
}
