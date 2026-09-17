<?php

namespace Database\Seeders;

use App\Models\Permission;
use Illuminate\Database\Seeder;

class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        $groups = [
            'dashboard' => ['view'],
            'products' => ['view', 'create', 'update', 'delete'],
            'stock' => ['view', 'manage'],
            'customers' => ['view', 'create', 'update', 'delete'],
            'sales' => ['view', 'create', 'cancel'],
            'expenses' => ['view', 'create', 'update', 'delete'],
            'invoices' => ['view', 'create'],
            'reports' => ['view'],
            'employees' => ['view', 'manage'],
            'settings' => ['manage'],
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
