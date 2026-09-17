<?php

namespace App\Http\Middleware;

use App\Support\Tenant;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Bloque l'accès si l'entreprise de l'utilisateur connecté est suspendue
 * ou fermée. Ne dépend jamais d'une donnée envoyée par le client : la
 * seule source est l'entreprise liée à l'utilisateur authentifié.
 */
class EnsureCompanyIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $company = Tenant::current();

        if ($company && $company->status !== 'active') {
            auth()->logout();

            return redirect()->route('login')
                ->withErrors(['email' => "Ce compte entreprise est actuellement {$company->status}. Contactez le support Parallelium."]);
        }

        return $next($request);
    }
}
