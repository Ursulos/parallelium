<x-layouts.app title="{{ $sale->sale_number }}">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-3 print:hidden">
        <div>
            <h2 class="text-xl font-bold text-slate-900">{{ $sale->sale_number }}</h2>
            <p class="text-sm text-slate-500">{{ $sale->sold_at->format('d/m/Y \à H:i') }} · Enregistrée par {{ $sale->user?->name ?? '—' }}</p>
        </div>

        <div class="flex items-center gap-2">
            @can('invoices.view')
                @if ($sale->invoice)
                    <x-button :href="route('invoices.show', $sale->invoice)" variant="secondary" size="sm">Voir la facture</x-button>
                @elseif (! $sale->isCancelled())
                    @can('invoices.create')
                        <form method="POST" action="{{ route('invoices.generate', $sale) }}">
                            @csrf
                            <x-button type="submit" variant="secondary" size="sm">Générer la facture</x-button>
                        </form>
                    @endcan
                @endif
            @endcan
            <x-button variant="ghost" size="sm" onclick="window.print()">Imprimer le reçu</x-button>
            @can('sales.cancel')
                @if (! $sale->isCancelled())
                    <form method="POST" action="{{ route('sales.cancel', $sale) }}" onsubmit="return confirm('Annuler cette vente ? Le stock sera restauré.');">
                        @csrf
                        <x-button type="submit" variant="danger" size="sm">Annuler la vente</x-button>
                    </form>
                @endif
            @endcan
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4 print:hidden">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4 print:hidden">{{ $errors->first() }}</x-alert>
    @endif

    @if ($sale->isCancelled())
        <x-alert type="warning" class="mb-4">Cette vente a été annulée. Le stock correspondant a été restauré.</x-alert>
    @endif

    <x-card>
        <div class="flex items-center justify-between border-b border-slate-100 pb-4">
            <div>
                <p class="font-bold text-slate-900">{{ auth()->user()->company->name }}</p>
                <p class="text-xs text-slate-400">{{ auth()->user()->company->phone }}</p>
            </div>
            <div class="text-right">
                <x-badge :tone="$sale->payment_status->tone()">{{ $sale->payment_status->label() }}</x-badge>
                <p class="mt-1 text-xs text-slate-400">{{ $sale->payment_method->label() }}</p>
            </div>
        </div>

        <div class="border-b border-slate-100 py-4 text-sm">
            <p class="font-medium text-slate-600">Client</p>
            <p class="text-slate-800">{{ $sale->customer?->name ?? 'Client de passage' }}</p>
            @if ($sale->customer?->phone)
                <p class="text-xs text-slate-400">{{ $sale->customer->phone }}</p>
            @endif
        </div>

        <div class="divide-y divide-slate-100 py-2">
            @foreach ($sale->items as $item)
                <div class="flex items-center justify-between py-2 text-sm">
                    <div>
                        <p class="font-medium text-slate-800">{{ $item->product->name ?? 'Produit supprimé' }}</p>
                        <p class="text-xs text-slate-400">{{ $item->quantity }} × <x-money :amount="$item->unit_price" /></p>
                    </div>
                    <p class="font-semibold text-slate-800"><x-money :amount="$item->subtotal" /></p>
                </div>
            @endforeach
        </div>

        <div class="space-y-1.5 border-t border-slate-100 pt-4 text-sm">
            <div class="flex justify-between text-slate-500">
                <span>Sous-total</span>
                <span><x-money :amount="$sale->subtotal" /></span>
            </div>
            @if ($sale->discount > 0)
                <div class="flex justify-between text-slate-500">
                    <span>Remise</span>
                    <span>- <x-money :amount="$sale->discount" /></span>
                </div>
            @endif
            <div class="flex justify-between text-base font-bold text-slate-900">
                <span>Total</span>
                <span><x-money :amount="$sale->total_amount" /></span>
            </div>
            <div class="flex justify-between text-slate-500">
                <span>Payé</span>
                <span><x-money :amount="$sale->paid_amount" /></span>
            </div>
            @if ($sale->remaining_amount > 0)
                <div class="flex justify-between font-semibold text-amber-600">
                    <span>Reste à payer</span>
                    <span><x-money :amount="$sale->remaining_amount" /></span>
                </div>
            @endif
        </div>

        @if ($sale->notes)
            <p class="mt-4 border-t border-slate-100 pt-3 text-sm text-slate-500">{{ $sale->notes }}</p>
        @endif
    </x-card>
</x-layouts.app>
