@php
    // Liste de candidats classés par priorité, filtrée par permission ET
    // par existence de la route. On ne prend que les 4 premiers
    // autorisés : jamais d'emplacement vide grisé, la barre s'adapte
    // simplement au rôle de l'utilisateur (flex + justify-around, pas de
    // grille figée à 5 colonnes).
    $bottomNavCandidates = collect([
        ['route' => 'dashboard', 'icon' => 'home', 'label' => 'Accueil', 'permission' => 'dashboard.view'],
        ['route' => 'sales.index', 'icon' => 'sales', 'label' => 'Ventes', 'permission' => 'sales.view'],
        ['route' => 'stock.index', 'icon' => 'stock', 'label' => 'Stock', 'permission' => 'stock.view'],
        ['route' => 'customers.index', 'icon' => 'customers', 'label' => 'Clients', 'permission' => 'customers.view'],
        ['route' => 'expenses.index', 'icon' => 'expenses', 'label' => 'Dépenses', 'permission' => 'expenses.view'],
        ['route' => 'reports.index', 'icon' => 'reports', 'label' => 'Rapports', 'permission' => 'reports.view'],
    ])->filter(fn ($c) => auth()->user()?->can($c['permission']) && \Illuminate\Support\Facades\Route::has($c['route']))
      ->take(4)
      ->values();

    $bottomNavMid = (int) ceil($bottomNavCandidates->count() / 2);
    $bottomNavLeft = $bottomNavCandidates->slice(0, $bottomNavMid);
    $bottomNavRight = $bottomNavCandidates->slice($bottomNavMid);
@endphp

<nav class="fixed inset-x-0 bottom-0 z-30 border-t border-slate-100 bg-white/95 backdrop-blur pb-[env(safe-area-inset-bottom)] lg:hidden">
    <div class="relative mx-auto flex max-w-lg items-center justify-around px-2 py-2">
        @foreach ($bottomNavLeft as $item)
            <x-bottom-nav-item :route-name="$item['route']" :icon="$item['icon']" :label="$item['label']" />
        @endforeach

        @canany(['sales.create', 'expenses.create', 'customers.create', 'products.create'])
            <div class="flex items-center justify-center">
                <button
                    type="button"
                    x-data
                    @click="$dispatch('open-quick-actions')"
                    class="-mt-8 flex h-14 w-14 items-center justify-center rounded-full bg-brand-gradient text-xl text-white shadow-lg shadow-brand-500/40 active:scale-95 transition">
                    <x-icon name="plus" />
                </button>
            </div>
        @endcanany

        @foreach ($bottomNavRight as $item)
            <x-bottom-nav-item :route-name="$item['route']" :icon="$item['icon']" :label="$item['label']" />
        @endforeach
    </div>
</nav>
