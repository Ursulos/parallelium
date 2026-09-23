<?php

namespace App\Http\Controllers;

use App\Services\BusinessCatalogService;
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

        $businessTypes = BusinessCatalogService::options();

        return view('onboarding.show', compact('company', 'businessTypes'));
    }

    public function update(Request $request)
    {
        $data = $request->validate([
            'business_type' => ['nullable', 'string', 'max:255'],
            'business_type_other' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'currency' => ['nullable', 'string', 'in:'.implode(',', array_keys(config('parallelium.currencies')))],
        ]);

        // "Autre" : on stocke le texte libre plutôt que le mot-clé, pour
        // un affichage lisible ailleurs (Paramètres, panneau admin).
        if (($data['business_type'] ?? null) === 'autre') {
            $data['business_type'] = $data['business_type_other'] ?? null;
        } elseif (($data['business_type'] ?? null) === '') {
            $data['business_type'] = null;
        }
        unset($data['business_type_other']);

        Tenant::current()->update($data);

        return redirect()->route('onboarding.show');
    }

    /**
     * Ajoute au catalogue les produits standards du secteur choisi —
     * uniquement sur demande explicite du propriétaire (§40), jamais
     * silencieusement.
     */
    public function seedCatalog(Request $request, BusinessCatalogService $catalogService)
    {
        $company = Tenant::current();

        if (! array_key_exists($company->business_type, BusinessCatalogService::options())) {
            return redirect()->route('onboarding.show');
        }

        $result = $catalogService->seed($company, $company->business_type);

        $message = "{$result['created']} produit(s) standard ajouté(s) à votre catalogue.";
        if ($result['skipped_limit'] > 0) {
            $message .= " {$result['skipped_limit']} n'ont pas pu être ajoutés car votre plan actuel a atteint sa limite de produits.";
        }

        return redirect()->route('onboarding.show')->with('status', $message);
    }

    public function finish()
    {
        Tenant::current()->update(['onboarding_completed' => true]);

        return redirect()->route('dashboard')->with('status', 'Votre entreprise est prête');
    }

    public function skip()
    {
        Tenant::current()->update(['onboarding_completed' => true]);

        return redirect()->route('dashboard');
    }
}
