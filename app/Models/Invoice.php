<?php

namespace App\Models;

use App\Enums\InvoiceStatus;
use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Invoice extends Model
{
    use BelongsToCompany, SoftDeletes;

    protected $fillable = ['company_id', 'sale_id', 'invoice_number', 'status', 'issued_at'];

    protected function casts(): array
    {
        return [
            'status' => InvoiceStatus::class,
            'issued_at' => 'datetime',
        ];
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    /**
     * Le statut réel dépend toujours de l'état courant de la vente liée
     * (voir InvoiceStatus::fromSale) — ce champ stocké sert seulement à
     * afficher la liste rapidement sans recharger chaque vente.
     */
    public function refreshStatus(): void
    {
        $this->update([
            'status' => InvoiceStatus::fromSale($this->sale->payment_status, $this->sale->sale_status),
        ]);
    }
}
