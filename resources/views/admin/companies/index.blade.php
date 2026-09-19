<x-layouts.admin title="Entreprises">
    <div class="mb-5">
        <h1 class="text-xl font-bold text-slate-900">Entreprises</h1>
        <p class="text-sm text-slate-500">Toutes les entreprises inscrites sur Parallelium.</p>
    </div>

    <div class="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Entreprises" :value="$stats['total']" icon="customers" />
        <x-stat-card label="Actives" :value="$stats['active']" icon="success" />
        <x-stat-card label="Suspendues" :value="$stats['suspended']" icon="warning" />
        <x-stat-card label="Sur un plan payant" :value="$stats['paying']" icon="money" tone="brand" />
    </div>

    <form method="GET" class="mb-4 flex flex-wrap items-center gap-2">
        <x-input name="q" value="{{ request('q') }}" placeholder="Rechercher une entreprise..." class="max-w-xs" />
        <select name="status" class="rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400" onchange="this.form.submit()">
            <option value="">Tous les statuts</option>
            <option value="active" @selected(request('status') === 'active')>Active</option>
            <option value="suspended" @selected(request('status') === 'suspended')>Suspendue</option>
            <option value="closed" @selected(request('status') === 'closed')>Fermée</option>
        </select>
        <x-button type="submit" variant="ghost" size="sm">Filtrer</x-button>
    </form>

    @if ($companies->isEmpty())
        <x-empty-state icon="customers" title="Aucune entreprise trouvée." />
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($companies as $company)
                    <a href="{{ route('admin.companies.show', $company) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">
                                {{ $company->name }}
                                @if ($company->status !== 'active')
                                    <x-badge tone="danger" class="ml-1">{{ ucfirst($company->status) }}</x-badge>
                                @endif
                            </p>
                            <p class="text-xs text-slate-400">
                                {{ $company->users_count }} utilisateur{{ $company->users_count > 1 ? 's' : '' }} ·
                                {{ $company->products_count }} produits ·
                                {{ $company->customers_count }} clients
                            </p>
                        </div>
                        <x-badge tone="brand">{{ $plans[$company->subscription?->plan]['label'] ?? $company->subscription?->plan ?? '—' }}</x-badge>
                    </a>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $companies->links() }}</div>
    @endif
</x-layouts.admin>
