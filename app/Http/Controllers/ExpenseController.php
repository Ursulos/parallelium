<?php

namespace App\Http\Controllers;

use App\Enums\ExpenseCategory;
use App\Http\Requests\StoreExpenseRequest;
use App\Http\Requests\UpdateExpenseRequest;
use App\Models\Expense;
use App\Support\Tenant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ExpenseController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('expenses.view');

        $expenses = Expense::with('user')
            ->when($request->filled('category'), fn ($q) => $q->where('category', $request->string('category')))
            ->when($request->filled('from'), fn ($q) => $q->whereDate('expense_date', '>=', $request->date('from')))
            ->when($request->filled('to'), fn ($q) => $q->whereDate('expense_date', '<=', $request->date('to')))
            ->latest('expense_date')
            ->paginate(15)
            ->withQueryString();

        $totalThisMonth = Expense::whereBetween('expense_date', [now()->startOfMonth(), now()->endOfMonth()])->sum('amount');

        return view('expenses.index', compact('expenses', 'totalThisMonth'));
    }

    public function create()
    {
        $this->authorize('expenses.create');

        return view('expenses.create');
    }

    public function store(StoreExpenseRequest $request)
    {
        $data = $request->validated();
        $data['user_id'] = $request->user()->id;
        $data['expense_number'] = Tenant::current()->nextDocumentNumber('expense');

        if ($request->hasFile('receipt')) {
            // Laravel génère un nom de fichier haché : jamais le nom
            // original envoyé par l'utilisateur (cahier des charges §33).
            $data['receipt_path'] = $request->file('receipt')->store('receipts/'.Tenant::id(), 'public');
        }

        Expense::create($data);

        return redirect()->route('expenses.index')->with('status', 'Dépense enregistrée.');
    }

    public function edit(Expense $expense)
    {
        $this->authorize('expenses.update');

        return view('expenses.edit', compact('expense'));
    }

    public function update(UpdateExpenseRequest $request, Expense $expense)
    {
        $data = $request->validated();

        if ($request->hasFile('receipt')) {
            if ($expense->receipt_path) {
                Storage::disk('public')->delete($expense->receipt_path);
            }
            $data['receipt_path'] = $request->file('receipt')->store('receipts/'.Tenant::id(), 'public');
        }

        $expense->update($data);

        return redirect()->route('expenses.index')->with('status', 'Dépense mise à jour.');
    }

    public function destroy(Expense $expense)
    {
        $this->authorize('expenses.delete');

        if ($expense->receipt_path) {
            Storage::disk('public')->delete($expense->receipt_path);
        }

        $expense->delete();

        return back()->with('status', 'Dépense supprimée.');
    }
}
