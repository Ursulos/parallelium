<x-layouts.app title="{{ $customer->name }}">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div class="flex items-center gap-3">
            <span class="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-brand-50 text-lg font-semibold text-brand-700">
                {{ strtoupper(substr($customer->name, 0, 1)) }}
            </span>
            <div>
                <h2 class="text-xl font-bold text-slate-900">{{ $customer->name }}</h2>
                <p class="text-sm text-slate-500">{{ $customer->phone ?? 'Pas de téléphone' }} @if($customer->email) · {{ $customer->email }} @endif</p>
            </div>
        </div>

        <div class="flex items-center gap-2">
            @can('sales.create')
                <x-button :href="route('sales.create')" size="sm"><x-icon name="plus" /> Nouvelle vente</x-button>
            @endcan
            <x-button :href="route('customers.edit', $customer)" variant="secondary" size="sm">Modifier</x-button>
            <form method="POST" action="{{ route('customers.destroy', $customer) }}" onsubmit="return confirm('Supprimer ce client ?');">
                @csrf
                @method('DELETE')
                <x-button type="submit" variant="ghost" size="sm">Supprimer</x-button>
            </form>
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Total des achats" :value="\App\Support\Money::format($customer->totalPurchases())" icon="money" />
        <x-stat-card label="Montant payé" :value="\App\Support\Money::format($customer->totalPaid())" icon="revenue" />
        <x-stat-card label="Montant restant" :value="\App\Support\Money::format($customer->totalRemaining())" tone="brand" icon="credit" />
        <x-stat-card label="Dernière commande" :value="$customer->lastOrderAt()?->format('d/m/Y') ?? '—'" icon="sales" />
    </div>

    @if ($customer->credit_limit)
        <x-alert type="info" class="mt-4">
            Limite de crédit fixée à <x-money :amount="$customer->credit_limit" />.
        </x-alert>
    @endif

    @if ($customer->address || $customer->notes)
        <x-card class="mt-4">
            @if ($customer->address)
                <p class="text-sm"><span class="font-medium text-slate-600">Adresse :</span> {{ $customer->address }}</p>
            @endif
            @if ($customer->notes)
                <p class="mt-2 text-sm text-slate-500">{{ $customer->notes }}</p>
            @endif
        </x-card>
    @endif

    <div class="mt-6 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="mb-2 text-sm font-semibold text-slate-700">Historique des ventes</h3>
            @php($sales = $customer->sales()->latest('sold_at')->limit(8)->get())
            @if ($sales->isEmpty())
                <x-empty-state icon="sales" title="Aucune vente pour le moment." description="Les ventes de ce client apparaîtront ici." />
            @else
                <div class="divide-y divide-slate-100">
                    @foreach ($sales as $sale)
                        <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between py-2.5 text-sm hover:bg-slate-50">
                            <div>
                                <p class="font-medium text-slate-800">{{ $sale->sale_number }}</p>
                                <p class="text-xs text-slate-400">{{ $sale->sold_at->format('d/m/Y') }}</p>
                            </div>
                            <div class="text-right">
                                <p class="font-semibold text-slate-800"><x-money :amount="$sale->total_amount" /></p>
                                <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                            </div>
                        </a>
                    @endforeach
                </div>
            @endif
        </x-card>

        <x-card>
            <h3 class="mb-2 text-sm font-semibold text-slate-700">Factures</h3>
            <x-empty-state icon="invoices" title="Aucune facture pour le moment." description="Le module Facturation arrive en Phase 6." />
        </x-card>
    </div>
</x-layouts.app>
