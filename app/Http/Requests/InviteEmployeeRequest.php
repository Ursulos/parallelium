<?php

namespace App\Http\Requests;

use App\Support\Tenant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class InviteEmployeeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('employees.manage');
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:30'],
            // Le rôle "owner" n'est jamais assignable depuis ce formulaire
            // (réservé au flux d'inscription) : seuls manager/seller/
            // accountant peuvent être invités.
            'role' => ['required', Rule::in(['manager', 'seller', 'accountant'])],
        ];
    }

    public function attributes(): array
    {
        return ['role' => 'rôle'];
    }
}
