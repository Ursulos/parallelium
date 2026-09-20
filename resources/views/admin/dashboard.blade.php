<x-layouts.admin title="Dashboard">
    <div class="mb-5">
        <h1 class="text-xl font-bold text-slate-900">Vue d'ensemble</h1>
        <p class="text-sm text-slate-500">Toute la plateforme Parallelium, en un coup d'œil.</p>
    </div>

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <x-stat-card label="Entreprises" :value="$stats['companies']" icon="customers" />
        <x-stat-card label="Actives" :value="$stats['active_companies']" icon="success" />
        <x-stat-card label="Suspendues" :value="$stats['suspended_companies']" icon="warning" />
        <x-stat-card label="Utilisateurs (total)" :value="$stats['total_users']" icon="products" />
    </div>

    <div class="mt-3 grid grid-cols-2 gap-3">
        <x-stat-card label="MRR estimatif" :value="\App\Support\Money::format($mrr)" icon="money" tone="brand" />
        <x-stat-card label="Ventes ce mois (toutes entreprises)" :value="$stats['sales_this_month']" icon="sales" />
    </div>

    <p class="mt-2 text-xs text-slate-400">
        Le MRR est une estimation basée sur les abonnements actifs et leurs prix catalogue — aucun prélèvement réel n'est encore connecté (§32).
    </p>

    <div class="mt-6 grid gap-4 lg:grid-cols-3">
        <x-card class="lg:col-span-2">
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Inscriptions — 14 derniers jours</h3>
            @if ($signupsByDay->sum('count') > 0)
                <canvas id="chart-signups" height="180"></canvas>
            @else
                <p class="py-8 text-center text-sm text-slate-400">Aucune inscription récente.</p>
            @endif
        </x-card>

        <x-card>
            <h3 class="mb-3 text-sm font-semibold text-slate-700">Répartition par plan</h3>
            <div class="space-y-2">
                @forelse ($planBreakdown as $plan => $count)
                    <div class="flex items-center justify-between text-sm">
                        <span class="text-slate-600">{{ $plans[$plan]['label'] ?? $plan }}</span>
                        <span class="font-semibold text-slate-800">{{ $count }}</span>
                    </div>
                @empty
                    <p class="text-sm text-slate-400">Aucun abonnement pour le moment.</p>
                @endforelse
            </div>
        </x-card>
    </div>

    <x-card class="mt-4">
        <h3 class="mb-3 text-sm font-semibold text-slate-700">Top 5 entreprises (CA ce mois)</h3>
        @if ($topCompanies->isEmpty() || $topCompanies->first()->month_revenue == 0)
            <p class="text-sm text-slate-400">Aucune vente enregistrée ce mois-ci.</p>
        @else
            <div class="divide-y divide-slate-100">
                @foreach ($topCompanies as $company)
                    @if ($company->month_revenue > 0)
                        <a href="{{ route('admin.companies.show', $company) }}" class="flex items-center justify-between py-2.5 text-sm hover:bg-slate-50">
                            <span class="font-medium text-slate-800">{{ $company->name }}</span>
                            <span class="font-semibold text-slate-900">{{ \App\Support\Money::format($company->month_revenue, $company->currency) }}</span>
                        </a>
                    @endif
                @endforeach
            </div>
        @endif
    </x-card>

    @if ($signupsByDay->sum('count') > 0)
        <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js" integrity="sha512-e3nkTaqZ4qhAtI22fMPCH7ELiC4qhBQCiCTgKXWBTx6jHU0y3TKO5+ez+IEK9nnMx7DdMg0jZQBcwSj2Hn45Sw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const data = @json($signupsByDay);
                new Chart(document.getElementById('chart-signups'), {
                    type: 'bar',
                    data: {
                        labels: data.map(d => d.label),
                        datasets: [{ data: data.map(d => d.count), backgroundColor: '#6a35c2', borderRadius: 6 }],
                    },
                    options: {
                        plugins: { legend: { display: false } },
                        scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                    },
                });
            });
        </script>
    @endif
</x-layouts.admin>
