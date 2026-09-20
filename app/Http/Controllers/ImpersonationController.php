<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/**
 * Fin de la session "se connecter en tant que" démarrée depuis le
 * panneau admin plateforme (voir Admin\CompanyController::impersonate).
 * La session du guard "admin" cohabite avec celle du guard "web" dans le
 * même cookie de session : on ne fait ici que fermer la session "web" et
 * nettoyer les indicateurs, la session admin reste intacte.
 */
class ImpersonationController extends Controller
{
    public function stop(Request $request)
    {
        $companyId = session('impersonating_company_id');

        session()->forget(['impersonating_admin_id', 'impersonating_admin_name', 'impersonating_company_id']);

        // Guard::logout() ne retire QUE la clé de session propre au guard
        // "web" — jamais session()->invalidate(), qui effacerait aussi la
        // session du guard "admin" logée dans le même cookie.
        Auth::guard('web')->logout();
        $request->session()->regenerateToken();

        return $companyId
            ? redirect()->route('admin.companies.show', $companyId)
            : redirect()->route('admin.companies.index');
    }
}
