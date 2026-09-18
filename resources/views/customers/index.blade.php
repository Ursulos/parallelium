<x-layouts.app title="Clients">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Clients</h2>
            <p class="text-sm text-slate-500">{{ $customers->total() }} client{{ $customers->total() > 1 ? 's' : '' }}.</p>
        </div>

        <x-button :href="route('customers.create')" size="sm"><x-icon name="plus" /> Nouveau client</x-button>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    <form method="GET" class="mb-4 flex items-center gap-2">
        <div class="relative flex-1 max-w-sm">
            <x-icon name="search" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <x-input name="q" value="{{ request('q') }}" placeholder="Rechercher un client, téléphone, e-mail..." class="pl-10" />
        </div>
        <x-button type="submit" variant="ghost" size="sm">Rechercher</x-button>
    </form>

    @if ($customers->isEmpty())
        <x-empty-state icon="customers" title="Aucun client pour le moment." description="Ajoutez votre premier client pour suivre ses achats et ses créances.">
            <x-slot:action>
                <x-button :href="route('customers.create')">Ajouter un client</x-button>
            </x-slot:action>
        </x-empty-state>
    @else
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            @foreach ($customers as $customer)
                <a href="{{ route('customers.show', $customer) }}">
                    <x-card class="h-full transition hover:border-brand-200 hover:shadow-md">
                        <div class="flex items-center gap-3">
                            <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-50 text-sm font-semibold text-brand-700">
                                {{ strtoupper(substr($customer->name, 0, 1)) }}
                            </span>
                            <div class="min-w-0">
                                <p class="truncate font-semibold text-slate-800">{{ $customer->name }}</p>
                                <p class="truncate text-xs text-slate-400">{{ $customer->phone ?? $customer->email ?? 'Aucun contact' }}</p>
                            </div>
                        </div>
                    </x-card>
                </a>
            @endforeach
        </div>

        <div class="mt-5">{{ $customers->links() }}</div>
    @endif
</x-layouts.app>
