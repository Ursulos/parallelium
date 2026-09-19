<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Models\Sale;
use App\Services\InvoiceService;
use Barryvdh\DomPDF\Facade\Pdf;

class InvoiceController extends Controller
{
    public function index()
    {
        $this->authorize('invoices.view');

        $invoices = Invoice::with(['sale.customer'])
            ->latest('issued_at')
            ->paginate(15);

        return view('invoices.index', compact('invoices'));
    }

    public function generate(Sale $sale, InvoiceService $invoiceService)
    {
        $this->authorize('invoices.create');

        $invoice = $invoiceService->generateFor($sale);

        return redirect()->route('invoices.show', $invoice)->with('status', 'Facture générée.');
    }

    public function show(Invoice $invoice)
    {
        $this->authorize('invoices.view');

        $invoice->load(['sale.items.product', 'sale.customer']);

        return view('invoices.show', compact('invoice'));
    }

    public function download(Invoice $invoice)
    {
        $this->authorize('invoices.view');

        $invoice->load(['sale.items.product', 'sale.customer']);
        $company = $invoice->company;

        $pdf = Pdf::loadView('pdf.invoice', compact('invoice', 'company'))->setPaper('a4');

        return $pdf->download("{$invoice->invoice_number}.pdf");
    }
}
