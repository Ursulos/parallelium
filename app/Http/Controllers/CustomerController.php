<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreCustomerRequest;
use App\Http\Requests\UpdateCustomerRequest;
use App\Models\Customer;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('customers.view');

        $customers = Customer::search($request->string('q')->toString())
            ->orderBy('name')
            ->paginate(15)
            ->withQueryString();

        return view('customers.index', compact('customers'));
    }

    public function create()
    {
        $this->authorize('customers.create');

        return view('customers.create');
    }

    public function store(StoreCustomerRequest $request)
    {
        $customer = Customer::create($request->validated());

        return redirect()->route('customers.show', $customer)->with('status', 'Client ajouté.');
    }

    public function show(Customer $customer)
    {
        $this->authorize('customers.view');

        // Historique des ventes, montant payé et créances arriveront avec
        // le module Ventes (Phase 4) puis Facturation (Phase 6). Pas de
        // données fictives en attendant : tout reste explicitement vide.
        return view('customers.show', compact('customer'));
    }

    public function edit(Customer $customer)
    {
        $this->authorize('customers.update');

        return view('customers.edit', compact('customer'));
    }

    public function update(UpdateCustomerRequest $request, Customer $customer)
    {
        $customer->update($request->validated());

        return redirect()->route('customers.show', $customer)->with('status', 'Client mis à jour.');
    }

    public function destroy(Customer $customer)
    {
        $this->authorize('customers.delete');

        $customer->update(['is_active' => false]);
        $customer->delete();

        return redirect()->route('customers.index')->with('status', 'Client supprimé.');
    }
}
