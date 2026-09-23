<x-layouts.app title="Comparer deux périodes">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Comparer deux périodes</h2>
            <p class="text-sm text-slate-500">Ventes de la période A face à la période B.</p>
        </div>
        <x-button :href="route('reports.sales')" variant="ghost" size="sm">Retour au rapport simple</x-button>
    </div>

    <x-card class="mb-5">
        <form method="GET" class="grid gap-4 sm:grid-cols-2">
            <input type="hidden" name="compare" value="1">

            <div>
                <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-brand-600">Période A</p>
                <div class="flex items-center gap-2">
                    <x-input type="date" name="from" value="{{ request('from', $fromA->format('Y-m-d')) }}" />
                    <x-icon name="chevron-right" class="shrink-0 text-xs text-slate-400" />
                    <x-input type="date" name="to" value="{{ request('to', $toA->format('Y-m-d')) }}" />
                </div>
            </div>

            <div>
                <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">Période B (référence)</p>
                <div class="flex items-center gap-2">
                    <x-input type="date" name="from_b" value="{{ request('from_b', $fromB->format('Y-m-d')) }}" />
                    <x-icon name="chevron-right" class="shrink-0 text-xs text-slate-400" />
                    <x-input type="date" name="to_b" value="{{ request('to_b', $toB->format('Y-m-d')) }}" />
                </div>
            </div>

            <div class="sm:col-span-2">
                <x-button type="submit">Comparer</x-button>
            </div>
        </form>
    </x-card>

    <div class="mb-3 flex flex-wrap items-center gap-3">
        @if (! is_null($comparison['revenue_change']))
            <x-badge :tone="$comparison['revenue_change'] >= 0 ? 'success' : 'danger'">
                CA : {{ $comparison['revenue_change'] >= 0 ? '+' : '' }}{{ $comparison['revenue_change'] }}% vs période B
            </x-badge>
        @endif
        @if (! is_null($comparison['count_change']))
            <x-badge :tone="$comparison['count_change'] >= 0 ? 'success' : 'danger'">
                Ventes : {{ $comparison['count_change'] >= 0 ? '+' : '' }}{{ $comparison['count_change'] }}% vs période B
            </x-badge>
        @endif
    </div>

    <div class="grid gap-4 sm:grid-cols-2">
        <x-card>
            <p class="mb-3 text-xs font-semibold uppercase tracking-wide text-brand-600">
                Période A — {{ $fromA->format('d/m/Y') }} au {{ $toA->format('d/m/Y') }}
            </p>
            <div class="grid grid-cols-2 gap-3">
                <x-stat-card label="Ventes" :value="$comparison['a']['count']" icon="sales" />
                <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($comparison['a']['revenue'])" icon="money" tone="brand" />
                <x-stat-card label="Payé" :value="\App\Support\Money::format($comparison['a']['paid'])" icon="revenue" />
                <x-stat-card label="Reste à payer" :value="\App\Support\Money::format($comparison['a']['remaining'])" icon="credit" />
            </div>
        </x-card>

        <x-card>
            <p class="mb-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
                Période B — {{ $fromB->format('d/m/Y') }} au {{ $toB->format('d/m/Y') }}
            </p>
            <div class="grid grid-cols-2 gap-3">
                <x-stat-card label="Ventes" :value="$comparison['b']['count']" icon="sales" />
                <x-stat-card label="Chiffre d'affaires" :value="\App\Support\Money::format($comparison['b']['revenue'])" icon="money" />
                <x-stat-card label="Payé" :value="\App\Support\Money::format($comparison['b']['paid'])" icon="revenue" />
                <x-stat-card label="Reste à payer" :value="\App\Support\Money::format($comparison['b']['remaining'])" icon="credit" />
            </div>
        </x-card>
    </div>
</x-layouts.app>
