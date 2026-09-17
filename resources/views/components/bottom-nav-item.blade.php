@props(['routeName', 'icon', 'label'])

@php
    $active = request()->routeIs($routeName.'*');
    $enabled = \Illuminate\Support\Facades\Route::has($routeName);
    $href = $enabled ? route($routeName) : '#';
@endphp

<a href="{{ $href }}" class="flex flex-col items-center gap-0.5 rounded-lg py-1.5 text-[11px] font-medium {{ $active ? 'text-brand-700' : ($enabled ? 'text-slate-500' : 'text-slate-300') }}">
    <x-icon :name="$icon" class="text-lg" />
    {{ $label }}
</a>