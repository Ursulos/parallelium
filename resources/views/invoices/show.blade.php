<x-layouts.app title="{{ $invoice->invoice_number }}">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-3 print:hidden">
        <div>
            <h2 class="text-xl font-bold text-slate-900">{{ $invoice->invoice_number }}</h2>
            <p class="text-sm text-slate-500">Émise le {{ $invoice->issued_at->format('d/m/Y') }}</p>
        </div>

        <div class="flex items-center gap-2">
            <x-button :href="route('invoices.download', $invoice)" variant="secondary" size="sm">Télécharger le PDF</x-button>
            <x-button variant="ghost" size="sm" onclick="window.print()">Imprimer</x-button>
            <x-button :href="route('sales.show', $invoice->sale)" variant="ghost" size="sm">Voir la vente</x-button>
        </div>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4 print:hidden">{{ session('status') }}</x-alert>
    @endif

    <x-card>
        <div class="flex items-start justify-between border-b border-slate-100 pb-4">
            <div>
                <p class="text-lg font-bold text-slate-900">{{ auth()->user()->company->name }}</p>
                @if (auth()->user()->company->address)
                    <p class="text-xs text-slate-400">{{ auth()->user()->company->address }}</p>
                @endif
                @if (auth()->user()->company->phone)
                    <p class="text-xs text-slate-400">{{ auth()->user()->company->phone }}</p>
                @endif
            </div>
            <div class="text-right">
                <p class="font-bold text-brand-700">FACTURE</p>
                <p class="text-sm text-slate-500">{{ $invoice->invoice_number }}</p>
                <x-badge :tone="$invoice->status->tone()" class="mt-1">{{ $invoice->status->label() }}</x-badge>
            </div>
        </div>

        <div class="border-b border-slate-100 py-4 text-sm">
            <p class="font-medium text-slate-600">Facturé à</p>
            <p class="text-slate-800">{{ $invoice->sale->customer?->name ?? 'Client de passage' }}</p>
            @if ($invoice->sale->customer?->phone)
                <p class="text-xs text-slate-400">{{ $invoice->sale->customer->phone }}</p>
            @endif
            @if ($invoice->sale->customer?->address)
                <p class="text-xs text-slate-400">{{ $invoice->sale->customer->address }}</p>
            @endif
        </div>

        <div class="divide-y divide-slate-100 py-2">
            @foreach ($invoice->sale->items as $item)
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
                <span><x-money :amount="$invoice->sale->subtotal" /></span>
            </div>
            @if ($invoice->sale->discount > 0)
                <div class="flex justify-between text-slate-500">
                    <span>Remise</span>
                    <span>- <x-money :amount="$invoice->sale->discount" /></span>
                </div>
            @endif
            <div class="flex justify-between text-base font-bold text-slate-900">
                <span>Total</span>
                <span><x-money :amount="$invoice->sale->total_amount" /></span>
            </div>
            <div class="flex justify-between text-slate-500">
                <span>Payé</span>
                <span><x-money :amount="$invoice->sale->paid_amount" /></span>
            </div>
            @if ($invoice->sale->remaining_amount > 0)
                <div class="flex justify-between font-semibold text-amber-600">
                    <span>Reste à payer</span>
                    <span><x-money :amount="$invoice->sale->remaining_amount" /></span>
                </div>
            @endif
        </div>
    </x-card>
</x-layouts.app>
