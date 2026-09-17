<?php

namespace App\Http\Middleware;

use App\Support\Tenant;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RedirectIfOnboardingIncomplete
{
    public function handle(Request $request, Closure $next): Response
    {
        $company = Tenant::current();

        if ($company
            && ! $company->onboarding_completed
            && ! $request->routeIs('onboarding.*')
            && ! $request->routeIs('logout')) {
            return redirect()->route('onboarding.show');
        }

        return $next($request);
    }
}
