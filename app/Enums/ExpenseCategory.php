<?php

namespace App\Enums;

enum ExpenseCategory: string
{
    case Merchandise = 'merchandise';
    case Transport = 'transport';
    case Rent = 'rent';
    case Salaries = 'salaries';
    case Electricity = 'electricity';
    case Internet = 'internet';
    case Supplies = 'supplies';
    case Marketing = 'marketing';
    case Maintenance = 'maintenance';
    case Other = 'other';

    public function label(): string
    {
        return match ($this) {
            self::Merchandise => 'Achat marchandises',
            self::Transport => 'Transport',
            self::Rent => 'Loyer',
            self::Salaries => 'Salaires',
            self::Electricity => 'Électricité',
            self::Internet => 'Internet',
            self::Supplies => 'Fournitures',
            self::Marketing => 'Marketing',
            self::Maintenance => 'Maintenance',
            self::Other => 'Autres',
        };
    }

    public static function options(): array
    {
        return array_combine(
            array_map(fn (self $c) => $c->value, self::cases()),
            array_map(fn (self $c) => $c->label(), self::cases()),
        );
    }
}
