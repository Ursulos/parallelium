<?php

namespace App\Http\Controllers;

use App\Support\Tenant;
use Illuminate\Http\Request;

class OnboardingController extends Controller
{
    public function show()
    {
        $company = Tenant::current();

        if ($company->onboarding_completed) {
            return redirect()->route('dashboard');
        }

        return view('onboarding.show', compact('company'));
    }

    public function update(Request $request)
    {
        $data = $request->validate([
            'business_type' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'currency' => ['nullable', 'string', 'in:'.implode(',', array_keys(config('parallelium.currencies')))],
        ]);

        Tenant::current()->update($data);

        return redirect()->route('onboarding.show');
    }

    public function finish()
    {
        Tenant::current()->update(['onboarding_completed' => true]);

        return redirect()->route('dashboard')->with('status', 'Votre entreprise est prête 🎉');
    }

    public function skip()
    {
        Tenant::current()->update(['onboarding_completed' => true]);

        return redirect()->route('dashboard');
    }
}
