<?php

namespace App\Services;

use App\Models\Role;
use App\Models\User;
use App\Support\Tenant;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Invitation et gestion des employés (§23). Le rôle "owner" n'est jamais
 * assignable ici — un seul propriétaire par entreprise, défini à
 * l'inscription (voir RegistrationService).
 */
class EmployeeService
{
    public function __construct(protected SubscriptionService $subscriptionService)
    {
    }

    public function invite(array $data): User
    {
        $company = Tenant::current();

        // Vérification de limite centralisée (§32) — voir SubscriptionService.
        $this->subscriptionService->assertCanCreate($company, 'users');

        return DB::transaction(function () use ($data, $company) {
            $role = Role::whereNull('company_id')->where('slug', $data['role'])->firstOrFail();

            $user = User::create([
                'company_id' => $company->id,
                'role_id' => $role->id,
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'] ?? null,
                // Mot de passe temporaire aléatoire : l'employé le
                // redéfinit via le lien "mot de passe oublié" envoyé
                // juste après (jamais communiqué en clair).
                'password' => Str::random(32),
                'is_active' => true,
            ]);

            Password::sendResetLink(['email' => $user->email]);

            return $user;
        });
    }

    public function update(User $employee, array $data): User
    {
        $role = Role::whereNull('company_id')->where('slug', $data['role'])->firstOrFail();

        $employee->update([
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'role_id' => $role->id,
            'is_active' => $data['is_active'] ?? $employee->is_active,
        ]);

        return $employee->fresh('role');
    }

    public function deactivate(User $employee, User $actingUser): void
    {
        if ($employee->id === $actingUser->id) {
            throw new RuntimeException('Vous ne pouvez pas désactiver votre propre compte.');
        }

        if ($employee->isOwner()) {
            throw new RuntimeException('Le propriétaire de l\'entreprise ne peut pas être désactivé.');
        }

        $employee->update(['is_active' => false]);
        $employee->delete();
    }
}
