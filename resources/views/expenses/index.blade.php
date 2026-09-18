<x-layouts.app title="Dépenses">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Dépenses</h2>
            <p class="text-sm text-slate-500">
                Total ce mois : <span class="font-semibold text-slate-700"><x-money :amount="$totalThisMonth" /></span>
            </p>
        </div>
        <x-button :href="route('expenses.create')" size="sm"><x-icon name="plus" /> Nouvelle dépense</x-button>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    <form method="GET" class="mb-4 flex flex-wrap items-center gap-2">
        <select name="category" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
            <option value="">Toutes les catégories</option>
            @foreach (\App\Enums\ExpenseCategory::options() as $value => $label)
                <option value="{{ $value }}" @selected(request('category') === $value)>{{ $label }}</option>
            @endforeach
        </select>
        <input type="date" name="from" value="{{ request('from') }}" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
        <input type="date" name="to" value="{{ request('to') }}" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
        <x-button type="submit" variant="ghost" size="sm">Filtrer</x-button>
    </form>

    @if ($expenses->isEmpty())
        <x-empty-state icon="expenses" title="Aucune dépense pour le moment." description="Enregistrez votre première dépense pour suivre vos sorties d'argent.">
            <x-slot:action>
                <x-button :href="route('expenses.create')">Nouvelle dépense</x-button>
            </x-slot:action>
        </x-empty-state>
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($expenses as $expense)
                    <div class="flex items-center justify-between gap-3 px-5 py-3">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">{{ $expense->category->label() }}</p>
                            <p class="truncate text-xs text-slate-400">
                                {{ $expense->supplier_name ?? 'Sans fournisseur' }} · {{ $expense->expense_date->format('d/m/Y') }}
                                @if ($expense->receipt_path) · <a href="{{ $expense->receiptUrl() }}" target="_blank" class="text-brand-600 hover:underline">Justificatif</a> @endif
                            </p>
                        </div>
                        <div class="flex shrink-0 items-center gap-3">
                            <p class="font-semibold text-slate-900"><x-money :amount="$expense->amount" /></p>
                            <a href="{{ route('expenses.edit', $expense) }}" class="text-sm font-medium text-brand-600 hover:underline">Modifier</a>
                            <form method="POST" action="{{ route('expenses.destroy', $expense) }}" onsubmit="return confirm('Supprimer cette dépense ?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="text-sm font-medium text-red-500 hover:underline">Supprimer</button>
                            </form>
                        </div>
                    </div>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $expenses->links() }}</div>
    @endif
</x-layouts.app>
