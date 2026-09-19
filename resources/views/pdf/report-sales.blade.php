<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Rapport des ventes</title>
    <style>
        body { font-family: DejaVu Sans, sans-serif; color: #1e293b; font-size: 12px; }
        h1 { font-size: 16px; color: #1f1650; margin-bottom: 2px; }
        .muted { color: #64748b; font-size: 10px; margin-bottom: 15px; }
        table.summary { width: 100%; margin-bottom: 20px; border-collapse: collapse; }
        table.summary td { width: 25%; padding: 8px; text-align: center; border: 1px solid #e2e8f0; }
        table.summary .label { display: block; color: #64748b; font-size: 9px; }
        table.summary .value { display: block; font-weight: bold; font-size: 13px; margin-top: 2px; }
        table.rows { width: 100%; border-collapse: collapse; }
        table.rows th { text-align: left; font-size: 10px; color: #64748b; border-bottom: 1px solid #e2e8f0; padding: 6px 4px; }
        table.rows td { padding: 6px 4px; border-bottom: 1px solid #f1f5f9; font-size: 11px; }
    </style>
</head>
<body>
    <h1>Rapport des ventes</h1>
    <p class="muted">{{ ucfirst($periodLabel) }} — du {{ $from->format('d/m/Y') }} au {{ $to->format('d/m/Y') }}</p>

    <table class="summary">
        <tr>
            <td><span class="label">Ventes</span><span class="value">{{ $report['count'] }}</span></td>
            <td><span class="label">Chiffre d'affaires</span><span class="value">{{ \App\Support\Money::format($report['revenue']) }}</span></td>
            <td><span class="label">Payé</span><span class="value">{{ \App\Support\Money::format($report['paid']) }}</span></td>
            <td><span class="label">Reste à payer</span><span class="value">{{ \App\Support\Money::format($report['remaining']) }}</span></td>
        </tr>
    </table>

    <table class="rows">
        <thead>
            <tr>
                <th>Date</th>
                <th>Numéro</th>
                <th>Client</th>
                <th>Statut</th>
                <th style="text-align: right;">Total</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($report['rows'] as $sale)
                <tr>
                    <td>{{ $sale->sold_at->format('d/m/Y H:i') }}</td>
                    <td>{{ $sale->sale_number }}</td>
                    <td>{{ $sale->customer?->name ?? 'Client de passage' }}</td>
                    <td>{{ $sale->payment_status->label() }}</td>
                    <td style="text-align: right;">{{ \App\Support\Money::format($sale->total_amount) }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>
</body>
</html>
