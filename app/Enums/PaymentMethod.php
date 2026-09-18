<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case Cash = 'cash';
    case Mvola = 'mvola';
    case OrangeMoney = 'orange_money';
    case AirtelMoney = 'airtel_money';
    case Card = 'card';
    case BankTransfer = 'bank_transfer';
    case Other = 'other';

    public function label(): string
    {
        return match ($this) {
            self::Cash => 'Espèces',
            self::Mvola => 'MVola',
            self::OrangeMoney => 'Orange Money',
            self::AirtelMoney => 'Airtel Money',
            self::Card => 'Carte',
            self::BankTransfer => 'Virement',
            self::Other => 'Autre',
        };
    }

    public static function options(): array
    {
        return array_combine(
            array_map(fn (self $m) => $m->value, self::cases()),
            array_map(fn (self $m) => $m->label(), self::cases()),
        );
    }
}
