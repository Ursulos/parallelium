<?php

namespace App\Http\Requests;

use App\Enums\StockMovementType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class AdjustStockRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('stock.manage');
    }

    public function rules(): array
    {
        return [
            'type' => ['required', Rule::in(['purchase', 'loss', 'correction'])],
            // Toujours saisie en positif par l'utilisateur ; le sens
            // (entrée/sortie) est déterminé par le type, jamais par le
            // signe envoyé par le navigateur.
            'quantity' => ['required', 'integer', 'min:1'],
            'reason' => ['nullable', 'string', 'max:255'],
        ];
    }
}
