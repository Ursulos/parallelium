<x-layouts.app title="Rapport des ventes">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport des ventes</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <div class="flex items-center gap-2">
            <x-button :href="route('reports.sales', ['compare' => 1])" variant="secondary" size="sm">Comparer deux périodes</x-button>
            <x-button :href="route('reports.sales', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
            <x-button :href="route('reports.sales', array_merge(request()->query(), ['export' => 'pdf']))" variant="ghost" size="sm">Export PDF</x-button>
        </div>
    </div>

    <x-report-period-filter route="reports.sales" />

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Nombre de ventes" :value="$report['count']" icon="sales" />
        <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($report['revenue'])" icon="money" />
        <x-stat-card label="Montant payé" :value="\App\Support\Money::format($report['paid'])" icon="revenue" />
        <x-stat-card label="Reste à payer" :value="\App\Support\Money::format($report['remaining'])" icon="credit" />
    </div>

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="sales" title="Aucune vente sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $sale)
                        <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                            <div class="min-w-0">
                                <p class="truncate text-sm font-semibold text-slate-800">{{ $sale->sale_number }}</p>
                                <p class="text-xs text-slate-400">{{ $sale->customer?->name ?? 'Client de passage' }} · {{ $sale->sold_at->format('d/m/Y H:i') }}</p>
                            </div>
                            <div class="shrink-0 text-right">
                                <p class="text-sm font-bold text-slate-900"><x-money :amount="$sale->total_amount" /></p>
                                <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                            </div>
                        </a>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
