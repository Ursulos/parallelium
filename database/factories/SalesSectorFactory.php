<?php

namespace Database\Factories;

use App\Models\SalesSector;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<SalesSector> */
class SalesSectorFactory extends Factory
{
    protected $model = SalesSector::class;

    public function definition(): array
    {
        return ['name' => fake()->unique()->word(), 'is_active' => true];
    }
}
