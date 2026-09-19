<x-layouts.app title="Factures">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Factures</h2>
        <p class="text-sm text-slate-500">{{ $invoices->total() }} facture{{ $invoices->total() > 1 ? 's' : '' }} émise{{ $invoices->total() > 1 ? 's' : '' }}.</p>
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif

    @if ($invoices->isEmpty())
        <x-empty-state icon="invoices" title="Aucune facture pour le moment." description="Générez une facture depuis le détail d'une vente." />
    @else
        <x-card :padded="false">
            <div class="divide-y divide-slate-100">
                @foreach ($invoices as $invoice)
                    <a href="{{ route('invoices.show', $invoice) }}" class="flex items-center justify-between gap-3 px-5 py-3 hover:bg-slate-50">
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">{{ $invoice->invoice_number }}</p>
                            <p class="text-xs text-slate-400">
                                {{ $invoice->sale->customer?->name ?? 'Client de passage' }} · {{ $invoice->issued_at->format('d/m/Y') }}
                            </p>
                        </div>
                        <div class="shrink-0 text-right">
                            <p class="text-sm font-bold text-slate-900"><x-money :amount="$invoice->sale->total_amount" /></p>
                            <x-badge :tone="$invoice->status->tone()">{{ $invoice->status->label() }}</x-badge>
                        </div>
                    </a>
                @endforeach
            </div>
        </x-card>

        <div class="mt-5">{{ $invoices->links() }}</div>
    @endif
</x-layouts.app>
