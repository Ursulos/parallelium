<?php

namespace Database\Factories;

use App\Models\Company;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Company>
 */
class CompanyFactory extends Factory
{
    protected $model = Company::class;

    public function definition(): array
    {
        return [
            'name' => fake()->company(),
            'currency' => 'MGA',
            'timezone' => 'Indian/Antananarivo',
            'invoice_prefix' => 'PAR',
            'onboarding_completed' => true,
            'status' => 'active',
        ];
    }
}
