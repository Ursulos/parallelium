<?php

use App\Http\Controllers\Admin\AdminUserController;
use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\CompanyController;
use App\Http\Controllers\Admin\DashboardController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Routes ADMIN PLATEFORME
|--------------------------------------------------------------------------
|
| Complètement séparées des routes tenant (routes/web.php) : guard
| "admin" dédié, aucun chevauchement de session ni de permissions avec
| le système de rôles par entreprise (owner/manager/seller/accountant).
|
*/

Route::prefix('admin')->name('admin.')->group(function () {
    Route::middleware('guest:admin')->group(function () {
        Route::get('login', [AuthController::class, 'create'])->name('login');
        Route::post('login', [AuthController::class, 'store'])->middleware('throttle:10,1');
    });

    Route::middleware('auth:admin')->group(function () {
        Route::post('logout', [AuthController::class, 'destroy'])->name('logout');

        Route::redirect('/', '/admin/dashboard');
        Route::get('dashboard', DashboardController::class)->name('dashboard');

        Route::get('companies', [CompanyController::class, 'index'])->name('companies.index');
        Route::get('companies/{company}', [CompanyController::class, 'show'])->name('companies.show');
        Route::get('companies/{company}/edit', [CompanyController::class, 'edit'])->name('companies.edit');
        Route::put('companies/{company}', [CompanyController::class, 'update'])->name('companies.update');
        Route::post('companies/{company}/suspend', [CompanyController::class, 'suspend'])->name('companies.suspend');
        Route::post('companies/{company}/activate', [CompanyController::class, 'activate'])->name('companies.activate');
        Route::post('companies/{company}/close', [CompanyController::class, 'close'])->name('companies.close');
        Route::post('companies/{company}/plan', [CompanyController::class, 'changePlan'])->name('companies.plan');
        Route::post('companies/{company}/impersonate/{user}', [CompanyController::class, 'impersonate'])->name('companies.impersonate');

        Route::get('admins', [AdminUserController::class, 'index'])->name('admins.index');
        Route::get('admins/create', [AdminUserController::class, 'create'])->name('admins.create');
        Route::post('admins', [AdminUserController::class, 'store'])->name('admins.store');
        Route::delete('admins/{admin}', [AdminUserController::class, 'destroy'])->name('admins.destroy');
    });
});
