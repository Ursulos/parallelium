<x-layouts.app title="Rapport des dépenses">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Rapport des dépenses</h2>
            <p class="text-sm text-slate-500">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>
        </div>
        <x-button :href="route('reports.expenses', array_merge(request()->query(), ['export' => 'csv']))" variant="secondary" size="sm">Export CSV</x-button>
    </div>

    <x-report-period-filter route="reports.expenses" />

    <div class="grid grid-cols-2 gap-3">
        <x-stat-card label="Total des dépenses" :value="\App\Support\Money::format($report['total'])" icon="expenses" />
        <x-stat-card label="Nombre de dépenses" :value="$report['count']" icon="money" />
    </div>

    @if ($report['byCategory']->isNotEmpty())
        <x-card class="mt-4">
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Répartition par catégorie</h3>
            <div class="space-y-2">
                @foreach ($report['byCategory'] as $cat)
                    <div class="flex items-center justify-between text-sm">
                        <span class="text-slate-600">{{ $cat['label'] }} <span class="text-slate-400">({{ $cat['count'] }})</span></span>
                        <span class="font-semibold text-slate-800"><x-money :amount="$cat['total']" /></span>
                    </div>
                @endforeach
            </div>
        </x-card>
    @endif

    <div class="mt-6">
        @if ($report['rows']->isEmpty())
            <x-empty-state icon="expenses" title="Aucune dépense sur cette période." />
        @else
            <x-card :padded="false">
                <div class="divide-y divide-slate-100">
                    @foreach ($report['rows'] as $expense)
                        <div class="flex items-center justify-between gap-3 px-5 py-3">
                            <div class="min-w-0">
                                <p class="truncate text-sm font-semibold text-slate-800">{{ $expense->category->label() }}</p>
                                <p class="text-xs text-slate-400">{{ $expense->supplier_name ?? 'Sans fournisseur' }} · {{ $expense->expense_date->format('d/m/Y') }}</p>
                            </div>
                            <p class="shrink-0 font-semibold text-slate-900"><x-money :amount="$expense->amount" /></p>
                        </div>
                    @endforeach
                </div>
            </x-card>
        @endif
    </div>
</x-layouts.app>
