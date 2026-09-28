<?php

namespace App\Enums;

enum ObjectiveScope: string
{
    case Commercial = 'commercial';
    case Sector = 'sector';
    case City = 'city';
    case Global = 'global';

    public function label(): string
    {
        return match ($this) {
            self::Commercial => 'Par commercial',
            self::Sector => 'Par secteur',
            self::City => 'Par ville',
            self::Global => 'Global entreprise',
        };
    }
}
