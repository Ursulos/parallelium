<?php

namespace App\Http\Controllers;

use App\Http\Requests\InviteEmployeeRequest;
use App\Http\Requests\UpdateEmployeeRequest;
use App\Models\Role;
use App\Models\User;
use App\Services\EmployeeService;
use App\Support\Tenant;
use RuntimeException;

class EmployeeController extends Controller
{
    public function index()
    {
        $this->authorize('employees.view');

        // Filtre explicite : User n'a jamais de scope tenant automatique
        // (voir la note dans app/Models/User.php).
        $employees = User::where('company_id', Tenant::id())->with('role')->orderBy('name')->paginate(20);
        $userLimit = auth()->user()->company->subscription?->limit('users');

        return view('employees.index', compact('employees', 'userLimit'));
    }

    public function create()
    {
        $this->authorize('employees.manage');

        $roles = Role::whereNull('company_id')->whereIn('slug', ['manager', 'seller', 'accountant'])->get();

        return view('employees.create', compact('roles'));
    }

    public function store(InviteEmployeeRequest $request, EmployeeService $employeeService)
    {
        try {
            $employeeService->invite($request->validated());
        } catch (RuntimeException $e) {
            return back()->withErrors(['role' => $e->getMessage()])->withInput();
        }

        return redirect()->route('employees.index')->with('status', "Invitation envoyée. L'employé peut définir son mot de passe via le lien reçu.");
    }

    public function edit(User $employee)
    {
        $this->authorize('employees.manage');
        $this->ensureSameCompany($employee);

        $roles = Role::whereNull('company_id')->whereIn('slug', ['manager', 'seller', 'accountant'])->get();

        return view('employees.edit', compact('employee', 'roles'));
    }

    public function update(UpdateEmployeeRequest $request, User $employee, EmployeeService $employeeService)
    {
        $this->ensureSameCompany($employee);

        if ($employee->isOwner()) {
            return back()->withErrors(['role' => "Le rôle du propriétaire ne peut pas être modifié ici."]);
        }

        $employeeService->update($employee, $request->validated());

        return redirect()->route('employees.index')->with('status', 'Employé mis à jour.');
    }

    public function destroy(User $employee, EmployeeService $employeeService)
    {
        $this->authorize('employees.manage');
        $this->ensureSameCompany($employee);

        try {
            $employeeService->deactivate($employee, auth()->user());
        } catch (RuntimeException $e) {
            return back()->withErrors(['employee' => $e->getMessage()]);
        }

        return back()->with('status', 'Employé désactivé.');
    }

    /**
     * User n'ayant pas de scope tenant automatique (voir app/Models/User.php),
     * le model binding de route peut résoudre un utilisateur de N'IMPORTE
     * QUELLE entreprise. Ce garde-fou est donc obligatoire sur toute action
     * ciblant un employé précis par son ID.
     */
    protected function ensureSameCompany(User $employee): void
    {
        abort_if($employee->company_id !== Tenant::id(), 404);
    }
}
