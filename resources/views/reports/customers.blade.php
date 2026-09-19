<x-layouts.app title="Rapport clients">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport clients</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <x-button :href="route('reports.customers', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
    </div>

    <x-report-period-filter route="reports.customers" />

    <div class="grid grid-cols-2 gap-3">
        <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($report['totalRevenue'])" icon="money" />
        <x-stat-card label="Reste dû (impayés)" :value="\App\Support\Money::format($report['totalRemaining'])" icon="credit" />
    </div>

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="customers" title="Aucun client actif sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $customer)
                        <a href="{{ route('customers.show', $customer) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                            <div class="min-w-0">
                                <p class="truncate text-sm font-semibold text-slate-800">{{ $customer->name }}</p>
                                <p class="text-xs text-slate-400">{{ $customer->period_sales_count }} vente{{ $customer->period_sales_count > 1 ? 's' : '' }}</p>
                            </div>
                            <div class="shrink-0 text-right">
                                <p class="text-sm font-bold text-slate-900"><x-money :amount="$customer->period_revenue ?? 0" /></p>
                                @if (($customer->period_remaining ?? 0) > 0)
                                    <x-badge tone="warning"><x-money :amount="$customer->period_remaining" /> dû</x-badge>
                                @endif
                            </div>
                        </a>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
