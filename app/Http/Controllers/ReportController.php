<?php

namespace App\Http\Controllers;

use App\Services\ReportService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    public function index()
    {
        $this->authorize('reports.view');

        return view('reports.index');
    }

    public function sales(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->salesReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-ventes', ['Date', 'Numéro', 'Client', 'Total', 'Payé', 'Reste', 'Statut'],
                $report['rows']->map(fn ($sale) => [
                    $sale->sold_at->format('d/m/Y H:i'),
                    $sale->sale_number,
                    $sale->customer?->name ?? 'Client de passage',
                    $sale->total_amount,
                    $sale->paid_amount,
                    $sale->remaining_amount,
                    $sale->payment_status->label(),
                ])
            );
        }

        if ($request->query('export') === 'pdf') {
            $pdf = Pdf::loadView('pdf.report-sales', compact('report', 'periodLabel', 'from', 'to'))->setPaper('a4');

            return $pdf->download('rapport-ventes.pdf');
        }

        return view('reports.sales', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function expenses(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->expensesReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-depenses', ['Date', 'Catégorie', 'Fournisseur', 'Montant', 'Paiement'],
                $report['rows']->map(fn ($expense) => [
                    $expense->expense_date->format('d/m/Y'),
                    $expense->category->label(),
                    $expense->supplier_name ?? '—',
                    $expense->amount,
                    $expense->payment_method->label(),
                ])
            );
        }

        return view('reports.expenses', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function products(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->productsReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-produits', ['Produit', 'Quantité vendue', 'Chiffre d\'affaires'],
                $report['rows']->map(fn ($row) => [$row->name, $row->quantity, $row->revenue])
            );
        }

        return view('reports.products', compact('report', 'periodLabel', 'from', 'to'));
    }

    public function customers(Request $request, ReportService $reportService)
    {
        $this->authorize('reports.view');

        [$from, $to, $periodLabel] = $reportService->resolvePeriod($request);
        $report = $reportService->customersReport($from, $to);

        if ($request->query('export') === 'csv') {
            return $this->csv('rapport-clients', ['Client', 'Ventes', 'Chiffre d\'affaires', 'Reste dû'],
                $report['rows']->map(fn ($c) => [$c->name, $c->period_sales_count, $c->period_revenue, $c->period_remaining ?? 0])
            );
        }

        return view('reports.customers', compact('report', 'periodLabel', 'from', 'to'));
    }

    /**
     * Génère un CSV en flux (pas de fichier temporaire sur le serveur).
     * Les montants restent des nombres bruts (pas de symbole monétaire)
     * pour rester exploitables dans un tableur.
     */
    protected function csv(string $filename, array $headers, iterable $rows): StreamedResponse
    {
        return response()->streamDownload(function () use ($headers, $rows) {
            $handle = fopen('php://output', 'w');
            fwrite($handle, "\xEF\xBB\xBF"); // BOM UTF-8 (Excel)
            fputcsv($handle, $headers, ';');
            foreach ($rows as $row) {
                fputcsv($handle, $row, ';');
            }
            fclose($handle);
        }, "{$filename}-".now()->format('Y-m-d').'.csv', ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
