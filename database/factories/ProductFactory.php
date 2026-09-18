<?php

namespace Database\Factories;

use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    protected $model = Product::class;

    public function definition(): array
    {
        $purchase = fake()->numberBetween(1000, 20000);

        return [
            'name' => fake()->unique()->words(3, true),
            'sku' => strtoupper(fake()->bothify('SKU-####')),
            'purchase_price' => $purchase,
            'selling_price' => $purchase * 1.4,
            'stock_quantity' => fake()->numberBetween(0, 100),
            'minimum_stock' => 5,
            'unit' => 'unite',
            'is_active' => true,
        ];
    }

    public function lowStock(): static
    {
        return $this->state(fn () => [
            'stock_quantity' => 2,
            'minimum_stock' => 5,
        ]);
    }
}
