<?php

namespace Database\Factories;

use App\Models\SalesCity;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<SalesCity> */
class SalesCityFactory extends Factory
{
    protected $model = SalesCity::class;

    public function definition(): array
    {
        return ['name' => fake()->unique()->city(), 'is_active' => true];
    }
}
