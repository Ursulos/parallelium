@csrf
@if ($expense ?? null)
    @method('PUT')
@endif

<div class="grid gap-4 sm:grid-cols-2">
    <div>
        <x-label for="category">Catégorie</x-label>
        <select id="category" name="category" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
            @foreach (\App\Enums\ExpenseCategory::options() as $value => $label)
                <option value="{{ $value }}" @selected(old('category', $expense->category->value ?? '') === $value)>{{ $label }}</option>
            @endforeach
        </select>
    </div>

    <div>
        <x-label for="amount">Montant</x-label>
        <x-input id="amount" type="number" step="0.01" min="0.01" name="amount" value="{{ old('amount', $expense->amount ?? '') }}" required />
    </div>

    <div>
        <x-label for="supplier_name">Fournisseur (optionnel)</x-label>
        <x-input id="supplier_name" name="supplier_name" value="{{ old('supplier_name', $expense->supplier_name ?? '') }}" />
    </div>

    <div>
        <x-label for="expense_date">Date</x-label>
        <x-input id="expense_date" type="date" name="expense_date" value="{{ old('expense_date', ($expense->expense_date ?? now())->format('Y-m-d')) }}" required />
    </div>

    <div>
        <x-label for="payment_method">Mode de paiement</x-label>
        <select id="payment_method" name="payment_method" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
            @foreach (\App\Enums\PaymentMethod::options() as $value => $label)
                <option value="{{ $value }}" @selected(old('payment_method', $expense->payment_method->value ?? 'cash') === $value)>{{ $label }}</option>
            @endforeach
        </select>
    </div>

    <div>
        <x-label for="receipt">Justificatif (optionnel)</x-label>
        <input id="receipt" type="file" name="receipt" accept=".jpg,.jpeg,.png,.pdf"
               class="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm text-slate-600 file:mr-3 file:rounded-lg file:border-0 file:bg-brand-50 file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-brand-700 focus:outline-none focus:ring-2 focus:ring-brand-400">
        <p class="mt-1 text-xs text-slate-400">JPG, PNG ou PDF, 5 Mo maximum.</p>
        @if (($expense->receipt_path ?? null))
            <a href="{{ $expense->receiptUrl() }}" target="_blank" class="mt-1 inline-block text-xs font-medium text-brand-600 hover:underline">Voir le justificatif actuel</a>
        @endif
    </div>

    <div class="sm:col-span-2">
        <x-label for="description">Description (optionnel)</x-label>
        <textarea id="description" name="description" rows="3" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">{{ old('description', $expense->description ?? '') }}</textarea>
    </div>
</div>

<div class="mt-6 flex items-center gap-3">
    <x-button type="submit">{{ ($expense ?? null) ? 'Enregistrer les modifications' : 'Ajouter la dépense' }}</x-button>
    <x-button :href="route('expenses.index')" variant="ghost" type="button">Annuler</x-button>
</div>
