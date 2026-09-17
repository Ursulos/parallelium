@props(['label', 'value', 'tone' => 'default', 'icon' => null]) {{-- default | brand --}}

<div {{ $attributes->merge(['class' => 'rounded-2xl border border-slate-100 bg-white p-5 shadow-sm']) }}>
    <div class="flex items-center justify-between">
        <p class="text-sm font-medium text-slate-500">{{ $label }}</p>
        @if ($icon)
            <span class="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-50 text-brand-600">
                <x-icon :name="$icon" />
            </span>
        @endif
    </div>
    <p class="mt-2 text-2xl font-bold {{ $tone === 'brand' ? 'text-brand-700' : 'text-slate-900' }}">
        {{ $value }}
    </p>
    @isset($trend)
        <div class="mt-1 text-xs">{{ $trend }}</div>
    @endisset
</div>