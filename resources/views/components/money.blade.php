@props(['amount', 'currency' => null])

<span {{ $attributes }}>{{ \App\Support\Money::format($amount, $currency) }}</span>
