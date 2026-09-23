<x-layouts.app title="Tableau de bord">
    @php
        $canSeeRevenue = auth()->user()->can('dashboard.revenue');
        $canSeeExpenses = auth()->user()->can('expenses.view');
    @endphp

    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Bonjour {{ explode(' ', auth()->user()->name)[0] }}</h2>
        <p class="text-sm text-slate-500">Voici un aperçu de {{ $company->name }}.</p>
    </div>

    @if ($canSeeRevenue || $canSeeExpenses)
        <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
            @can('dashboard.revenue')
                <x-stat-card label="Chiffre d'affaires (jour)" :value="\App\Support\Money::format($kpis['revenue_today'])" icon="money">
                    @if (! is_null($kpis['revenue_today_change']))
                        <x-slot:trend>
                            <span class="{{ $kpis['revenue_today_change'] >= 0 ? 'text-emerald-600' : 'text-red-500' }}">
                                {{ $kpis['revenue_today_change'] >= 0 ? '+' : '' }}{{ $kpis['revenue_today_change'] }}% vs hier
                            </span>
                        </x-slot:trend>
                    @endif
                </x-stat-card>
                <x-stat-card label="Chiffre d'affaires (mois)" :value="\App\Support\Money::format($kpis['revenue_month'])" icon="revenue">
                    @if (! is_null($kpis['revenue_month_change']))
                        <x-slot:trend>
                            <span class="{{ $kpis['revenue_month_change'] >= 0 ? 'text-emerald-600' : 'text-red-500' }}">
                                {{ $kpis['revenue_month_change'] >= 0 ? '+' : '' }}{{ $kpis['revenue_month_change'] }}% vs mois dernier
                            </span>
                        </x-slot:trend>
                    @endif
                </x-stat-card>
            @endcan
            @can('expenses.view')
                <x-stat-card label="Dépenses (mois)" :value="\App\Support\Money::format($kpis['expenses_month'])" icon="expenses" />
            @endcan
            @can('dashboard.revenue')
                <x-stat-card label="Résultat estimé" :value="\App\Support\Money::format($kpis['estimated_result'])" tone="brand" icon="result" />
            @endcan
        </div>

        @can('dashboard.revenue')
            <p class="mt-3 text-xs text-slate-400">
                Le résultat affiché est un indicateur de gestion interne, pas un résultat comptable officiel.
            </p>
        @endcan
    @endif

    <div class="mt-6 grid gap-4 lg:grid-cols-3">
        <x-card class="lg:col-span-2" :padded="false">
            <div class="flex items-center justify-between px-5 pt-5">
                <h3 class="text-sm font-semibold text-slate-700">Dernières ventes</h3>
                @can('sales.view')
                    <a href="{{ route('sales.index') }}" class="text-xs font-medium text-brand-600 hover:underline">Voir tout</a>
                @endcan
            </div>

            @if ($recentSales->isEmpty())
                <x-empty-state
                    class="m-5"
                    icon="sales"
                    title="Aucune vente pour le moment."
                    description="Vos ventes récentes apparaîtront ici automatiquement.">
                    @can('sales.create')
                        <x-slot:action>
                            <x-button :href="route('sales.create')">Nouvelle vente</x-button>
                        </x-slot:action>
                    @endcan
                </x-empty-state>
            @else
                <div class="mt-2 divide-y divide-slate-100">
                    @foreach ($recentSales as $sale)
                        <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between px-5 py-2.5 text-sm hover:bg-slate-50">
                            <div class="min-w-0">
                                <p class="truncate font-medium text-slate-800">{{ $sale->customer?->name ?? 'Client de passage' }}</p>
                                <p class="text-xs text-slate-400">{{ $sale->sale_number }} · {{ $sale->sold_at->format('d/m H:i') }}</p>
                            </div>
                            <p class="shrink-0 font-semibold text-slate-800"><x-money :amount="$sale->total_amount" /></p>
                        </a>
                    @endforeach
                </div>
                <div class="h-2"></div>
            @endif
        </x-card>

        <x-card>
            <h3 class="text-sm font-semibold text-slate-700">Stock faible</h3>
            @if ($lowStockProducts->isEmpty())
                <x-empty-state
                    class="mt-4"
                    icon="package"
                    title="Aucune alerte de stock."
                    description="Vous serez averti ici dès qu'un produit passera sous son seuil minimum." />
            @else
                <div class="mt-3 space-y-2">
                    @foreach ($lowStockProducts as $product)
                        <a href="{{ route('stock.index', ['product_id' => $product->id]) }}" class="flex items-center justify-between rounded-xl border border-amber-100 bg-amber-50 px-3 py-2 text-sm">
                            <span class="font-medium text-amber-900">{{ $product->name }}</span>
                            <span class="text-amber-700">{{ $product->stock_quantity }} / {{ $product->minimum_stock }}</span>
                        </a>
                    @endforeach
                </div>
                <a href="{{ route('products.index', ['low_stock' => 1]) }}" class="mt-3 block text-center text-xs font-medium text-brand-600 hover:underline">
                    Voir tous les produits en stock faible
                </a>
            @endif
        </x-card>
    </div>

    @if ($canSeeRevenue || $canSeeExpenses)
        <div class="mt-4 grid gap-4 lg:grid-cols-2">
            @can('dashboard.revenue')
                <x-card>
                    <h3 class="text-sm font-semibold text-slate-700">Créances clients</h3>
                    @if ($kpis['receivables'] > 0)
                        <p class="mt-3 text-2xl font-bold text-amber-600"><x-money :amount="$kpis['receivables']" /></p>
                        <p class="mt-1 text-xs text-slate-400">Montant restant à encaisser sur les ventes à crédit.</p>
                    @elseif ($kpis['customers_count'] > 0)
                        <div class="mt-3 flex items-center justify-between rounded-xl border border-slate-100 bg-slate-50 px-3 py-2 text-sm">
                            <span class="text-slate-600">{{ $kpis['customers_count'] }} client{{ $kpis['customers_count'] > 1 ? 's' : '' }} enregistré{{ $kpis['customers_count'] > 1 ? 's' : '' }}, aucune créance en cours.</span>
                        </div>
                    @else
                        <x-empty-state class="mt-4" icon="customers" title="Aucun client pour le moment." description="Ajoutez votre premier client pour commencer." />
                    @endif
                </x-card>
            @endcan

            @can('expenses.view')
                <x-card>
                    <h3 class="text-sm font-semibold text-slate-700">Dernières dépenses</h3>
                    @if ($recentExpenses->isEmpty())
                        <x-empty-state class="mt-4" icon="expenses" title="Aucune dépense pour le moment." description="Enregistrez votre première dépense pour la voir apparaître ici." />
                    @else
                        <div class="mt-3 space-y-2">
                            @foreach ($recentExpenses as $expense)
                                <a href="{{ route('expenses.index') }}" class="flex items-center justify-between rounded-xl border border-slate-100 px-3 py-2 text-sm hover:bg-slate-50">
                                    <span class="text-slate-600">{{ $expense->category->label() }}</span>
                                    <span class="font-semibold text-slate-800"><x-money :amount="$expense->amount" /></span>
                                </a>
                            @endforeach
                        </div>
                        <a href="{{ route('expenses.index') }}" class="mt-3 block text-center text-xs font-medium text-brand-600 hover:underline">
                            Voir toutes les dépenses
                        </a>
                    @endif
                </x-card>
            @endcan
        </div>
    @endif

    @if ($canSeeRevenue || $canSeeExpenses || count($charts['topProducts']) > 0)
        <div class="mt-6 grid gap-4 lg:grid-cols-2">
            @can('dashboard.revenue')
                <x-card>
                    <h3 class="mb-3 text-sm font-semibold text-slate-700">Chiffre d'affaires — 7 derniers jours</h3>
                    @if (collect($charts['salesLast7Days'])->sum('total') > 0)
                        <canvas id="chart-sales-7d" height="180"></canvas>
                    @else
                        <p class="py-8 text-center text-sm text-slate-400">Pas encore de ventes cette semaine.</p>
                    @endif
                </x-card>
            @endcan

            <x-card>
                <h3 class="mb-3 text-sm font-semibold text-slate-700">Top produits vendus (ce mois-ci)</h3>
                @if (count($charts['topProducts']) > 0)
                    <canvas id="chart-top-products" height="180"></canvas>
                @else
                    <p class="py-8 text-center text-sm text-slate-400">Aucune vente ce mois-ci.</p>
                @endif
            </x-card>

            @can('dashboard.revenue')
                <x-card>
                    <h3 class="mb-3 text-sm font-semibold text-slate-700">Ventes par catégorie (ce mois-ci)</h3>
                    @if (count($charts['salesByCategory']) > 0)
                        <canvas id="chart-sales-category" height="200"></canvas>
                    @else
                        <p class="py-8 text-center text-sm text-slate-400">Aucune vente ce mois-ci.</p>
                    @endif
                </x-card>
            @endcan

            @can('expenses.view')
                <x-card>
                    <h3 class="mb-3 text-sm font-semibold text-slate-700">Dépenses par catégorie (ce mois-ci)</h3>
                    @if (count($charts['expensesByCategory']) > 0)
                        <canvas id="chart-expenses-category" height="200"></canvas>
                    @else
                        <p class="py-8 text-center text-sm text-slate-400">Aucune dépense ce mois-ci.</p>
                    @endif
                </x-card>
            @endcan
        </div>
    @endif

    @if (($canSeeRevenue && collect($charts['salesLast7Days'])->sum('total') > 0) || count($charts['topProducts']) > 0 || ($canSeeRevenue && count($charts['salesByCategory']) > 0) || ($canSeeExpenses && count($charts['expensesByCategory']) > 0))
        <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js" integrity="sha512-e3nkTaqZ4qhAtI22fMPCH7ELiC4qhBQCiCTgKXWBTx6jHU0y3TKO5+ez+IEK9nnMx7DdMg0jZQBcwSj2Hn45Sw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const brand = '#6a35c2';
                const palette = ['#6a35c2', '#c22fb0', '#8760d1', '#dd5ed0', '#481f89', '#f5bff0'];

                // Les données financières (CA, dépenses) ne sont sérialisées
                // dans la page QUE si l'utilisateur a la permission
                // correspondante — jamais envoyées "cachées" dans le HTML
                // pour un rôle qui ne devrait pas les voir.
                const sales7d = {!! $canSeeRevenue ? \Illuminate\Support\Js::from($charts['salesLast7Days']) : '[]' !!};
                const topProducts = @json($charts['topProducts']);
                const salesByCategory = {!! $canSeeRevenue ? \Illuminate\Support\Js::from($charts['salesByCategory']) : '[]' !!};
                const expensesByCategory = {!! $canSeeExpenses ? \Illuminate\Support\Js::from($charts['expensesByCategory']) : '[]' !!};

                const el7d = document.getElementById('chart-sales-7d');
                if (el7d) {
                    new Chart(el7d, {
                        type: 'bar',
                        data: {
                            labels: sales7d.map(d => d.label),
                            datasets: [{ data: sales7d.map(d => d.total), backgroundColor: brand, borderRadius: 6 }],
                        },
                        options: {
                            plugins: { legend: { display: false } },
                            scales: { y: { beginAtZero: true } },
                        },
                    });
                }

                const elTop = document.getElementById('chart-top-products');
                if (elTop) {
                    new Chart(elTop, {
                        type: 'bar',
                        data: {
                            labels: topProducts.map(p => p.label),
                            datasets: [{ data: topProducts.map(p => p.quantity), backgroundColor: palette, borderRadius: 6 }],
                        },
                        options: {
                            indexAxis: 'y',
                            plugins: { legend: { display: false } },
                            scales: { x: { beginAtZero: true, ticks: { precision: 0 } } },
                        },
                    });
                }

                const elCat = document.getElementById('chart-sales-category');
                if (elCat) {
                    new Chart(elCat, {
                        type: 'doughnut',
                        data: {
                            labels: salesByCategory.map(c => c.label),
                            datasets: [{ data: salesByCategory.map(c => c.total), backgroundColor: palette }],
                        },
                        options: { plugins: { legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 11 } } } } },
                    });
                }

                const elExp = document.getElementById('chart-expenses-category');
                if (elExp) {
                    new Chart(elExp, {
                        type: 'doughnut',
                        data: {
                            labels: expensesByCategory.map(c => c.label),
                            datasets: [{ data: expensesByCategory.map(c => c.total), backgroundColor: palette }],
                        },
                        options: { plugins: { legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 11 } } } } },
                    });
                }
            });
        </script>
    @endif
</x-layouts.app>
