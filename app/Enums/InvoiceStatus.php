<?php

namespace App\Enums;

enum InvoiceStatus: string
{
    case Draft = 'draft';
    case Issued = 'issued';
    case PartiallyPaid = 'partially_paid';
    case Paid = 'paid';
    case Cancelled = 'cancelled';

    public function label(): string
    {
        return match ($this) {
            self::Draft => 'Brouillon',
            self::Issued => 'Émise',
            self::PartiallyPaid => 'Partiellement payée',
            self::Paid => 'Payée',
            self::Cancelled => 'Annulée',
        };
    }

    public function tone(): string
    {
        return match ($this) {
            self::Draft => 'neutral',
            self::Issued => 'warning',
            self::PartiallyPaid => 'warning',
            self::Paid => 'success',
            self::Cancelled => 'danger',
        };
    }

    /**
     * Le statut de la facture suit toujours celui de la vente liée
     * (source de vérité unique — §64) : jamais géré indépendamment.
     */
    public static function fromSale(PaymentStatus $paymentStatus, SaleStatus $saleStatus): self
    {
        if ($saleStatus === SaleStatus::Cancelled) {
            return self::Cancelled;
        }

        return match ($paymentStatus) {
            PaymentStatus::Paid => self::Paid,
            PaymentStatus::PartiallyPaid => self::PartiallyPaid,
            PaymentStatus::Unpaid => self::Issued,
        };
    }
}
