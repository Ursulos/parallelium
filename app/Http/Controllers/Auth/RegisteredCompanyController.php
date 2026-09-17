<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\RegisterCompanyRequest;
use App\Services\RegistrationService;
use Illuminate\Auth\Events\Registered;
use Illuminate\Support\Facades\Auth;

class RegisteredCompanyController extends Controller
{
    public function create()
    {
        return view('auth.register');
    }

    public function store(RegisterCompanyRequest $request, RegistrationService $registrationService)
    {
        $user = $registrationService->register($request->validated());

        event(new Registered($user));

        Auth::login($user);

        return redirect()->route('onboarding.show');
    }
}
