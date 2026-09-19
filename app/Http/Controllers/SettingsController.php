<?php

namespace App\Http\Controllers;

use App\Http\Requests\ChangeSubscriptionPlanRequest;
use App\Services\SubscriptionService;
use App\Support\Tenant;

class SettingsController extends Controller
{
    public function index(SubscriptionService $subscriptionService)
    {
        $company = Tenant::current();
        $usage = $subscriptionService->usage($company);
        $plans = config('parallelium.plans');

        return view('settings.index', compact('company', 'usage', 'plans'));
    }

    public function changePlan(ChangeSubscriptionPlanRequest $request, SubscriptionService $subscriptionService)
    {
        $subscriptionService->changePlan(Tenant::current(), $request->validated('plan'));

        return redirect()->route('settings.index')->with('status', 'Abonnement mis à jour.');
    }
}
