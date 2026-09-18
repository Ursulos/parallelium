<?php

namespace App\Enums;

enum PaymentStatus: string
{
    case Unpaid = 'unpaid';
    case PartiallyPaid = 'partially_paid';
    case Paid = 'paid';

    public function label(): string
    {
        return match ($this) {
            self::Unpaid => 'Impayée',
            self::PartiallyPaid => 'Partiellement payée',
            self::Paid => 'Payée',
        };
    }

    public function tone(): string
    {
        return match ($this) {
            self::Unpaid => 'danger',
            self::PartiallyPaid => 'warning',
            self::Paid => 'success',
        };
    }

    public static function fromAmounts(float $total, float $paid): self
    {
        if ($paid <= 0) {
            return self::Unpaid;
        }

        return $paid >= $total ? self::Paid : self::PartiallyPaid;
    }
}
