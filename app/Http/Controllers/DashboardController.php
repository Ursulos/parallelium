<?php

namespace App\Http\Controllers;

use App\Services\DashboardService;
use App\Support\Tenant;

class DashboardController extends Controller
{
    public function __invoke(DashboardService $dashboardService)
    {
        $company = Tenant::current();

        $data = $dashboardService->summary();

        return view('dashboard', array_merge(['company' => $company], $data));
    }
}
