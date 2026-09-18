<?php

namespace App\Enums;

enum ProductUnit: string
{
    case Unite = 'unite';
    case Kg = 'kg';
    case G = 'g';
    case Litre = 'litre';
    case Ml = 'ml';
    case Metre = 'metre';
    case Boite = 'boite';
    case Paquet = 'paquet';
    case Autre = 'autre';

    public function label(): string
    {
        return match ($this) {
            self::Unite => 'Unité',
            self::Kg => 'Kilogramme (kg)',
            self::G => 'Gramme (g)',
            self::Litre => 'Litre (L)',
            self::Ml => 'Millilitre (mL)',
            self::Metre => 'Mètre (m)',
            self::Boite => 'Boîte',
            self::Paquet => 'Paquet',
            self::Autre => 'Autre',
        };
    }

    public static function options(): array
    {
        return array_combine(
            array_map(fn (self $u) => $u->value, self::cases()),
            array_map(fn (self $u) => $u->label(), self::cases()),
        );
    }
}
