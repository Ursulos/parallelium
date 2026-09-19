<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>{{ $invoice->invoice_number }}</title>
    <style>
        body { font-family: DejaVu Sans, sans-serif; color: #1e293b; font-size: 12px; }
        .header { width: 100%; margin-bottom: 20px; }
        .header td { vertical-align: top; }
        .company-name { font-size: 16px; font-weight: bold; color: #1f1650; }
        .muted { color: #64748b; font-size: 10px; }
        .invoice-title { font-size: 18px; font-weight: bold; color: #6a35c2; text-align: right; }
        .invoice-number { text-align: right; color: #64748b; }
        .status { display: inline-block; padding: 3px 10px; border-radius: 10px; font-size: 10px; font-weight: bold; float: right; margin-top: 4px; }
        .status-paid { background: #d1fae5; color: #065f46; }
        .status-partially_paid, .status-issued { background: #fef3c7; color: #92400e; }
        .status-cancelled { background: #fee2e2; color: #991b1b; }
        .section { border-top: 1px solid #e2e8f0; padding: 12px 0; }
        table.items { width: 100%; border-collapse: collapse; margin-top: 10px; }
        table.items th { text-align: left; font-size: 10px; color: #64748b; border-bottom: 1px solid #e2e8f0; padding: 6px 0; }
        table.items td { padding: 8px 0; border-bottom: 1px solid #f1f5f9; }
        table.totals { width: 260px; margin-left: auto; margin-top: 15px; }
        table.totals td { padding: 4px 0; }
        table.totals .label { color: #64748b; }
        table.totals .value { text-align: right; }
        .total-row td { font-weight: bold; font-size: 14px; border-top: 1px solid #e2e8f0; padding-top: 8px; }
        .remaining { color: #b45309; font-weight: bold; }
        .footer { margin-top: 40px; text-align: center; color: #94a3b8; font-size: 9px; }
    </style>
</head>
<body>
    <table class="header">
        <tr>
            <td style="width: 60%;">
                <div class="company-name">{{ $company->name }}</div>
                @if ($company->address)<div class="muted">{{ $company->address }}</div>@endif
                @if ($company->phone)<div class="muted">{{ $company->phone }}</div>@endif
                @if ($company->email)<div class="muted">{{ $company->email }}</div>@endif
            </td>
            <td style="width: 40%;">
                <div class="invoice-title">FACTURE</div>
                <div class="invoice-number">{{ $invoice->invoice_number }}</div>
                <div class="invoice-number">{{ $invoice->issued_at->format('d/m/Y') }}</div>
                <span class="status status-{{ $invoice->status->value }}">{{ $invoice->status->label() }}</span>
            </td>
        </tr>
    </table>

    <div class="section">
        <strong>Facturé à</strong><br>
        {{ $invoice->sale->customer?->name ?? 'Client de passage' }}<br>
        @if ($invoice->sale->customer?->phone)<span class="muted">{{ $invoice->sale->customer->phone }}</span><br>@endif
        @if ($invoice->sale->customer?->address)<span class="muted">{{ $invoice->sale->customer->address }}</span>@endif
    </div>

    <table class="items">
        <thead>
            <tr>
                <th>Produit</th>
                <th>Qté</th>
                <th>Prix unitaire</th>
                <th style="text-align: right;">Sous-total</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($invoice->sale->items as $item)
                <tr>
                    <td>{{ $item->product->name ?? 'Produit supprimé' }}</td>
                    <td>{{ $item->quantity }}</td>
                    <td>{{ \App\Support\Money::format($item->unit_price, $company->currency) }}</td>
                    <td style="text-align: right;">{{ \App\Support\Money::format($item->subtotal, $company->currency) }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <table class="totals">
        <tr>
            <td class="label">Sous-total</td>
            <td class="value">{{ \App\Support\Money::format($invoice->sale->subtotal, $company->currency) }}</td>
        </tr>
        @if ($invoice->sale->discount > 0)
            <tr>
                <td class="label">Remise</td>
                <td class="value">- {{ \App\Support\Money::format($invoice->sale->discount, $company->currency) }}</td>
            </tr>
        @endif
        <tr class="total-row">
            <td>Total</td>
            <td class="value">{{ \App\Support\Money::format($invoice->sale->total_amount, $company->currency) }}</td>
        </tr>
        <tr>
            <td class="label">Payé</td>
            <td class="value">{{ \App\Support\Money::format($invoice->sale->paid_amount, $company->currency) }}</td>
        </tr>
        @if ($invoice->sale->remaining_amount > 0)
            <tr>
                <td class="label remaining">Reste à payer</td>
                <td class="value remaining">{{ \App\Support\Money::format($invoice->sale->remaining_amount, $company->currency) }}</td>
            </tr>
        @endif
    </table>

    <div class="footer">
        Ce document est un indicateur de gestion interne, généré par Parallelium. Il ne constitue pas un document comptable officiel.
    </div>
</body>
</html>
