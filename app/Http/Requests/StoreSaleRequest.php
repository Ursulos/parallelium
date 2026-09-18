<?php

namespace App\Http\Requests;

use App\Enums\PaymentMethod;
use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('sales.create');
    }

    public function rules(): array
    {
        return [
            'customer_id' => [
                'nullable',
                Rule::exists('customers', 'id')->where('company_id', Tenant::id()),
            ],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => [
                'required',
                Rule::exists('products', 'id')->where('company_id', Tenant::id()),
            ],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.discount' => ['nullable', 'numeric', 'min:0'],
            'discount' => ['nullable', 'numeric', 'min:0'],
            // paid_amount et payment_method sont saisis par l'utilisateur,
            // mais le TOTAL est toujours recalculé côté serveur (voir
            // SaleService) : on ne valide ici que la forme, pas le montant.
            'paid_amount' => ['required', 'numeric', 'min:0'],
            'payment_method' => ['required', Rule::in(array_column(PaymentMethod::cases(), 'value'))],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function attributes(): array
    {
        return [
            'customer_id' => 'client',
            'items' => 'produits',
            'paid_amount' => 'montant payé',
            'payment_method' => 'mode de paiement',
        ];
    }
}
