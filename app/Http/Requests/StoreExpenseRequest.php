<?php

namespace App\Http\Requests;

use App\Enums\ExpenseCategory;
use App\Enums\PaymentMethod;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreExpenseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('expenses.create');
    }

    public function rules(): array
    {
        return [
            'category' => ['required', Rule::in(array_column(ExpenseCategory::cases(), 'value'))],
            'supplier_name' => ['nullable', 'string', 'max:255'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'payment_method' => ['required', Rule::in(array_column(PaymentMethod::cases(), 'value'))],
            'description' => ['nullable', 'string', 'max:1000'],
            'expense_date' => ['required', 'date', 'before_or_equal:today'],
            // Justificatif : type MIME et taille strictement limités
            // (cahier des charges §33).
            'receipt' => ['nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
        ];
    }

    public function attributes(): array
    {
        return [
            'supplier_name' => 'fournisseur',
            'expense_date' => 'date de la dépense',
            'receipt' => 'justificatif',
        ];
    }
}
