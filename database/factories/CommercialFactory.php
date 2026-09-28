<?php

namespace Database\Factories;

use App\Models\Commercial;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Commercial> */
class CommercialFactory extends Factory
{
    protected $model = Commercial::class;

    public function definition(): array
    {
        return [
            'first_name' => strtoupper(fake()->unique()->lastName()),
            'is_active' => true,
        ];
    }
}
