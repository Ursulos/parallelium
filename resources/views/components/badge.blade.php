@props(['tone' => 'neutral']) {{-- neutral | success | warning | danger | brand --}}

@php
    $tones = [
        'neutral' => 'bg-slate-100 text-slate-600',
        'success' => 'bg-emerald-50 text-emerald-700',
        'warning' => 'bg-amber-50 text-amber-700',
        'danger' => 'bg-red-50 text-red-700',
        'brand' => 'bg-brand-50 text-brand-700',
    ];
@endphp

<span {{ $attributes->merge(['class' => 'inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ' . ($tones[$tone] ?? $tones['neutral'])]) }}>
    {{ $slot }}
</span>
