<?php

namespace Database\Seeders;

use App\Models\Permission;
use Illuminate\Database\Seeder;

class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        $groups = [
            'dashboard' => ['view', 'revenue'],
            'products' => ['view', 'create', 'update', 'delete'],
            'stock' => ['view', 'manage'],
            'customers' => ['view', 'create', 'update', 'delete'],
            'sales' => ['view', 'create', 'cancel'],
            'expenses' => ['view', 'create', 'update', 'delete'],
            'invoices' => ['view', 'create'],
            'reports' => ['view'],
            'employees' => ['view', 'manage'],
            'settings' => ['manage'],
            // Module "Suivi commercial" : view = toute l'équipe (Owner/
            // Manager) ; view_own = seulement ses propres performances
            // (Vendeur/Commercial) ; manage = commerciaux/secteurs/villes/
            // objectifs ; enter_sales = saisir des ventes commerciales.
            'commercial' => ['view', 'view_own', 'manage', 'enter_sales'],
        ];

        foreach ($groups as $group => $actions) {
            foreach ($actions as $action) {
                Permission::updateOrCreate(
                    ['slug' => "{$group}.{$action}"],
                    ['name' => ucfirst($group)." — ".ucfirst($action), 'group' => $group]
                );
            }
        }
    }
}
