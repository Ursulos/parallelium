<x-layouts.app title="Ventes">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Ventes</h2>
            <p class="text-sm text-slate-500">{{ $sales->total() }} vente{{ $sales->total() > 1 ? 's' : '' }}.</p>
        </div>
        <x-button :href="route('sales.create')" size="sm"><x-icon name="plus" /> Nouvelle vente</x-button>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    @if ($sales->isEmpty())
        <x-empty-state icon="sales" title="Aucune vente pour le moment." description="Enregistrez votre première vente pour la voir apparaître ici.">
            <x-slot:action>
                <x-button :href="route('sales.create')">Nouvelle vente</x-button>
            </x-slot:action>
        </x-empty-state>
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($sales as $sale)
                    <a href="{{ route('sales.show', $sale) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">
                                {{ $sale->sale_number }}
                                @if ($sale->isCancelled())
                                    <x-badge tone="danger" class="ml-1">Annulée</x-badge>
                                @endif
                            </p>
                            <p class="text-xs text-slate-400">
                                {{ $sale->customer?->name ?? 'Client de passage' }} · {{ $sale->sold_at->format('d/m/Y H:i') }}
                            </p>
                        </div>
                        <div class="shrink-0 text-right">
                            <p class="text-sm font-bold text-slate-900"><x-money :amount="$sale->total_amount" /></p>
                            <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                        </div>
                    </a>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $sales->links() }}</div>
    @endif
</x-layouts.app>
