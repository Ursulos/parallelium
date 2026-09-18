<?php

namespace App\Http\Requests;

use App\Enums\ProductUnit;
use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('products.update');
    }

    public function rules(): array
    {
        return [
            'category_id' => [
                'nullable',
                Rule::exists('categories', 'id')->where('company_id', Tenant::id()),
            ],
            'name' => ['required', 'string', 'max:255'],
            'sku' => [
                'nullable', 'string', 'max:100',
                Rule::unique('products', 'sku')
                    ->where('company_id', Tenant::id())
                    ->whereNull('deleted_at')
                    ->ignore($this->route('product')),
            ],
            'barcode' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:2000'],
            'purchase_price' => ['required', 'numeric', 'min:0'],
            'selling_price' => ['required', 'numeric', 'min:0'],
            // Le stock ne se modifie pas ici : voir StockController@adjust.
            'minimum_stock' => ['nullable', 'integer', 'min:0'],
            'unit' => ['required', Rule::in(array_column(ProductUnit::cases(), 'value'))],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    public function attributes(): array
    {
        return [
            'category_id' => 'catégorie',
            'purchase_price' => "prix d'achat",
            'selling_price' => 'prix de vente',
            'minimum_stock' => 'stock minimum',
        ];
    }
}
