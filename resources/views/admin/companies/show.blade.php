<x-layouts.admin title="{{ $company->name }}">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div>
            <a href="{{ route('admin.companies.index') }}" class="text-xs font-medium text-brand-600 hover:underline">&larr; Toutes les entreprises</a>
            <h1 class="mt-1 text-xl font-bold text-slate-900">
                {{ $company->name }}
                <x-badge :tone="$company->status === 'active' ? 'success' : 'danger'">{{ ucfirst($company->status) }}</x-badge>
            </h1>
            <p class="text-sm text-slate-500">Inscrite le {{ $company->created_at->format('d/m/Y') }} · {{ $company->city ?? 'Ville non renseignée' }}</p>
        </div>

        <div class="flex items-center gap-2">
            <x-button :href="route('admin.companies.edit', $company)" variant="secondary" size="sm">Modifier</x-button>

            @if ($company->status === 'active')
                <form method="POST" action="{{ route('admin.companies.suspend', $company) }}" onsubmit="return confirm('Suspendre cette entreprise ? Ses utilisateurs seront déconnectés.');">
                    @csrf
                    <x-button type="submit" variant="danger" size="sm">Suspendre</x-button>
                </form>
            @else
                <form method="POST" action="{{ route('admin.companies.activate', $company) }}">
                    @csrf
                    <x-button type="submit" variant="secondary" size="sm">Réactiver</x-button>
                </form>
            @endif

            @if ($company->status !== 'closed')
                <form method="POST" action="{{ route('admin.companies.close', $company) }}" onsubmit="return confirm('Fermer définitivement cette entreprise ? Cette action est difficilement réversible.');">
                    @csrf
                    <x-button type="submit" variant="ghost" size="sm">Fermer définitivement</x-button>
                </form>
            @endif
        </div>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Utilisateurs" :value="$company->users_count" icon="customers" />
        <x-stat-card label="Produits" :value="$company->products_count" icon="products" />
        <x-stat-card label="Clients" :value="$company->customers_count" icon="customers" />
        <x-stat-card label="Ventes ce mois" :value="\App\Support\Money::format($salesThisMonth->revenue ?? 0, $company->currency)" icon="money" />
    </div>

    <div class="mt-6 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Coordonnées</h3>
            <dl class="space-y-2 text-sm">
                <div class="flex justify-between"><dt class="text-slate-400">E-mail</dt><dd class="text-slate-700">{{ $company->email ?? '—' }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-400">Téléphone</dt><dd class="text-slate-700">{{ $company->phone ?? '—' }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-400">Devise</dt><dd class="text-slate-700">{{ $company->currency }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-400">Type d'activité</dt><dd class="text-slate-700">{{ $company->business_type ?? '—' }}</dd></div>
            </dl>
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Abonnement</h3>
            <p class="text-sm text-slate-500">
                Plan actuel : <span class="font-semibold text-brand-700">{{ $plans[$company->subscription?->plan]['label'] ?? '—' }}</span>
                · Statut : {{ $company->subscription?->status ?? '—' }}
            </p>

            <form method="POST" action="{{ route('admin.companies.plan', $company) }}" class="mt-3 flex items-center gap-2">
                @csrf
                <select name="plan" class="flex-1 rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
                    @foreach ($plans as $slug => $plan)
                        <option value="{{ $slug }}" @selected($company->subscription?->plan === $slug)>{{ $plan['label'] }}</option>
                    @endforeach
                </select>
                <x-button type="submit" size="sm">Appliquer</x-button>
            </form>
        </x-card>
    </div>

    <div class="mt-4 grid gap-4 lg:grid-cols-2">
        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Utilisateurs</h3>
            <div class="divide-y divide-slate-100">
                @foreach ($company->users as $user)
                    <div class="flex items-center justify-between py-2 text-sm">
                        <div>
                            <p class="font-medium text-slate-800">{{ $user->name }}</p>
                            <p class="text-xs text-slate-400">{{ $user->email }}</p>
                        </div>
                        <div class="flex items-center gap-2">
                            <x-badge tone="brand">{{ $user->role?->name ?? '—' }}</x-badge>
                            @unless ($user->is_active)
                                <x-badge tone="danger">Inactif</x-badge>
                            @endunless
                            @if ($user->is_active)
                                <form method="POST" action="{{ route('admin.companies.impersonate', [$company, $user]) }}">
                                    @csrf
                                    <button type="submit" class="text-xs font-medium text-brand-600 hover:underline">
                                        Se connecter en tant que
                                    </button>
                                </form>
                            @endif
                        </div>
                    </div>
                @endforeach
            </div>
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Activité récente</h3>
            @if ($recentActivity->isEmpty())
                <p class="text-sm text-slate-400">Aucune action administrative enregistrée pour l'instant.</p>
            @else
                <div class="divide-y divide-slate-100">
                    @foreach ($recentActivity as $log)
                        <div class="py-2 text-sm">
                            <p class="text-slate-700">{{ str_replace('admin.', '', $log->action) }}</p>
                            <p class="text-xs text-slate-400">
                                {{ $log->created_at->format('d/m/Y H:i') }}
                                @if ($log->properties['admin_email'] ?? null) · {{ $log->properties['admin_email'] }} @endif
                            </p>
                        </div>
                    @endforeach
                </div>
            @endif
        </x-card>
    </div>
</x-layouts.admin>
