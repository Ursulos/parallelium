<?php

namespace App\Support;

/**
 * Formatage centralisé des montants. Ne jamais coder "Ar" ou un
 * séparateur en dur dans une vue : passer par Money::format().
 */
class Money
{
    public static function format(float|int $amount, ?string $currency = null): string
    {
        $currency ??= Tenant::current()?->currency ?? config('parallelium.default_currency');
        $config = config("parallelium.currencies.{$currency}", ['symbol' => $currency, 'decimals' => 0]);

        $formatted = number_format($amount, $config['decimals'], ',', ' ');

        return "{$formatted} {$config['symbol']}";
    }
}
