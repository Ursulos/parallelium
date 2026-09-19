<x-layouts.app title="Rapport produits">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport produits</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <x-button :href="route('reports.products', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
    </div>

    <x-report-period-filter route="reports.products" />

    <div class="grid grid-cols-2 gap-3">
        <x-stat-card label="Quantité totale vendue" :value="$report['totalQuantity']" icon="products" />
        <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($report['totalRevenue'])" icon="money" />
    </div>

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="products" title="Aucun produit vendu sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $row)
                        <div class="flex items-center justify-between gap-3 px-5 py-3">
                            <p class="min-w-0 truncate text-sm font-semibold text-slate-800">{{ $row->name }}</p>
                            <div class="shrink-0 text-right">
                                <p class="text-sm font-bold text-slate-900"><x-money :amount="$row->revenue" /></p>
                                <p class="text-xs text-slate-400">{{ $row->quantity }} vendu{{ $row->quantity > 1 ? 's' : '' }}</p>
                            </div>
                        </div>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
