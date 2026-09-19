<?php

namespace App\Services;

use App\Enums\InvoiceStatus;
use App\Models\Invoice;
use App\Models\Sale;
use App\Support\Tenant;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Génère une facture DEPUIS une vente existante (§18). Une vente ne peut
 * avoir qu'une seule facture (contrainte unique sale_id) : appeler ceci
 * une deuxième fois renvoie simplement la facture déjà émise plutôt que
 * d'en créer une autre — jamais de doublon.
 */
class InvoiceService
{
    public function generateFor(Sale $sale): Invoice
    {
        if ($sale->invoice) {
            return $sale->invoice;
        }

        if ($sale->isCancelled()) {
            throw new RuntimeException('Impossible de facturer une vente annulée.');
        }

        return DB::transaction(function () use ($sale) {
            $company = Tenant::current();

            $invoice = Invoice::create([
                'company_id' => $company->id,
                'sale_id' => $sale->id,
                'invoice_number' => $company->nextDocumentNumber('invoice'),
                'status' => InvoiceStatus::fromSale($sale->payment_status, $sale->sale_status),
                'issued_at' => now(),
            ]);

            $sale->update(['invoice_id' => $invoice->id]);

            return $invoice;
        });
    }
}
