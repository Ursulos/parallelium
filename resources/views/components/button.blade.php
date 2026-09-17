@props([
    'variant' => 'primary', // primary | secondary | ghost | danger
    'size' => 'md', // sm | md | lg
    'type' => 'button',
    'href' => null,
])

@php
    $base = 'inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition active:scale-[0.98] disabled:opacity-50 disabled:pointer-events-none';

    $variants = [
        'primary' => 'bg-brand-gradient text-white shadow-sm shadow-brand-500/30 hover:brightness-110',
        'secondary' => 'bg-brand-50 text-brand-700 hover:bg-brand-100',
        'ghost' => 'bg-transparent text-slate-600 hover:bg-slate-100',
        'danger' => 'bg-red-600 text-white hover:bg-red-700',
    ];

    $sizes = [
        'sm' => 'text-sm px-3 py-2',
        'md' => 'text-sm px-4 py-2.5',
        'lg' => 'text-base px-5 py-3.5',
    ];

    $classes = $base . ' ' . ($variants[$variant] ?? $variants['primary']) . ' ' . ($sizes[$size] ?? $sizes['md']);
@endphp

@if ($href)
    <a href="{{ $href }}" {{ $attributes->merge(['class' => $classes]) }}>
        {{ $slot }}
    </a>
@else
    <button type="{{ $type }}" {{ $attributes->merge(['class' => $classes]) }}>
        {{ $slot }}
    </button>
@endif
