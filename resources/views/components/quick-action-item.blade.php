@props(['routeName', 'icon', 'label'])

@php
    $enabled = \Illuminate\Support\Facades\Route::has($routeName);
@endphp

<a href="{{ $enabled ? route($routeName) : '#' }}"
   class="flex flex-col items-center gap-2 rounded-2xl border border-slate-100 p-4 text-center {{ $enabled ? 'active:scale-95 hover:bg-slate-50' : 'opacity-40' }} transition">
    <span class="text-2xl">{{ $icon }}</span>
    <span class="text-xs font-medium text-slate-600">{{ $label }}</span>
</a>
