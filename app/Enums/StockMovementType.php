<?php

namespace App\Enums;

enum StockMovementType: string
{
    case Purchase = 'purchase';
    case Sale = 'sale';
    case Return = 'return';
    case Adjustment = 'adjustment';
    case Loss = 'loss';
    case Correction = 'correction';

    public function label(): string
    {
        return match ($this) {
            self::Purchase => 'Entrée stock (achat)',
            self::Sale => 'Vente',
            self::Return => 'Retour / Annulation',
            self::Adjustment => 'Ajustement',
            self::Loss => 'Perte',
            self::Correction => 'Correction',
        };
    }

    /**
     * Sens naturel du mouvement, utilisé pour l'affichage (+/-).
     * La quantité réelle stockée en base est toujours signée
     * explicitement par l'appelant (voir StockService::record).
     */
    public function isInbound(): bool
    {
        return in_array($this, [self::Purchase, self::Return], true);
    }
}
