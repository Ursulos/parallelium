<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        then: function () {
            // Groupe "web" (session, cookies, CSRF, en-têtes de sécurité)
            // appliqué, mais SANS les middlewares tenant (onboarding,
            // EnsureCompanyIsActive ne s'applique qu'aux sessions du
            // guard "web" par entreprise — no-op ici, voir routes/admin.php).
            \Illuminate\Support\Facades\Route::middleware('web')
                ->group(__DIR__.'/../routes/admin.php');
        },
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'tenant.active' => \App\Http\Middleware\EnsureCompanyIsActive::class,
            'onboarding' => \App\Http\Middleware\RedirectIfOnboardingIncomplete::class,
        ]);

        $middleware->appendToGroup('web', [
            \App\Http\Middleware\EnsureCompanyIsActive::class,
            \App\Http\Middleware\SecurityHeaders::class,
        ]);

        // Un visiteur non connecté sur /admin/* doit atterrir sur la page
        // de connexion ADMIN, jamais sur celle des entreprises (et
        // inversement) — les deux guards ne doivent jamais se mélanger.
        $middleware->redirectGuestsTo(fn (Request $request) => $request->is('admin/*')
            ? route('admin.login')
            : route('login'));

        // Symétriquement : un admin déjà connecté qui rouvre /admin/login
        // repart vers la liste des entreprises, pas vers le dashboard tenant.
        $middleware->redirectUsersTo(fn (Request $request) => $request->is('admin/*')
            ? route('admin.companies.index')
            : route('dashboard'));
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
