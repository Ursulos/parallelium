@props(['padded' => true])

<div {{ $attributes->merge(['class' => 'rounded-2xl bg-white border border-slate-100 shadow-sm ' . ($padded ? 'p-5' : '')]) }}>
    {{ $slot }}
</div>
