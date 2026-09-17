@props(['type' => 'info']) {{-- info | success | warning | error --}}

@php
    $styles = [
        'info' => 'bg-brand-50 text-brand-800 border-brand-100',
        'success' => 'bg-emerald-50 text-emerald-800 border-emerald-100',
        'warning' => 'bg-amber-50 text-amber-800 border-amber-100',
        'error' => 'bg-red-50 text-red-800 border-red-100',
    ];
@endphp

<div {{ $attributes->merge(['class' => 'rounded-xl border px-4 py-3 text-sm ' . ($styles[$type] ?? $styles['info'])]) }}>
    {{ $slot }}
</div>
