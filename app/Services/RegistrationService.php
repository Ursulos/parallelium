<?php

namespace App\Services;

use App\Models\Company;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Flux d'inscription : Register -> Create User -> Create Company
 * -> Attach User to Company -> Owner role -> Dashboard.
 *
 * Encapsulé dans un Service pour garder le Controller léger et garantir
 * la cohérence via une transaction (tout ou rien).
 */
class RegistrationService
{
    public function register(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $company = Company::create([
                'name' => $data['company_name'],
                'currency' => config('parallelium.default_currency'),
                'timezone' => config('parallelium.default_timezone'),
                'invoice_prefix' => config('parallelium.document_prefixes.invoice'),
                'status' => 'active',
            ]);

            $ownerRole = Role::whereNull('company_id')->where('slug', 'owner')->firstOrFail();

            $user = User::create([
                'company_id' => $company->id,
                'role_id' => $ownerRole->id,
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'] ?? null,
                'password' => $data['password'],
                'is_active' => true,
            ]);

            Subscription::create([
                'company_id' => $company->id,
                'plan' => 'free',
                'status' => 'trialing',
                'trial_ends_at' => now()->addDays(config('parallelium.trial_days')),
            ]);

            return $user;
        });
    }
}
