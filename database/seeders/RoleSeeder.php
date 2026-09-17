<?php

namespace Database\Seeders;

use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Seeder;

/**
 * Rôles "système" (company_id = null), partagés par toutes les entreprises.
 * Voir §23 du cahier des charges pour le détail des accès par rôle.
 */
class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $all = Permission::pluck('slug');

        $owner = Role::updateOrCreate(
            ['company_id' => null, 'slug' => 'owner'],
            ['name' => 'Propriétaire', 'is_system' => true]
        );
        $owner->permissions()->sync(Permission::pluck('id'));

        $manager = Role::updateOrCreate(
            ['company_id' => null, 'slug' => 'manager'],
            ['name' => 'Manager', 'is_system' => true]
        );
        $manager->permissions()->sync(
            Permission::where('slug', '!=', 'settings.manage')
                ->where('slug', '!=', 'employees.manage')
                ->pluck('id')
        );

        $seller = Role::updateOrCreate(
            ['company_id' => null, 'slug' => 'seller'],
            ['name' => 'Vendeur', 'is_system' => true]
        );
        $seller->permissions()->sync(
            Permission::whereIn('slug', [
                'dashboard.view',
                'products.view',
                'customers.view',
                'customers.create',
                'customers.update',
                'sales.view',
                'sales.create',
            ])->pluck('id')
        );

        $accountant = Role::updateOrCreate(
            ['company_id' => null, 'slug' => 'accountant'],
            ['name' => 'Comptable', 'is_system' => true]
        );
        $accountant->permissions()->sync(
            Permission::whereIn('slug', [
                'dashboard.view',
                'reports.view',
                'expenses.view',
                'invoices.view',
                'sales.view',
            ])->pluck('id')
        );
    }
}
