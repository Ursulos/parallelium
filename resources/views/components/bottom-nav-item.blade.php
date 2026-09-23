@props(['routeName', 'icon', 'label', 'permission' => null])

@php
    if ($permission && ! auth()->user()?->can($permission)) {
        return;
    }

    $active = request()->routeIs($routeName.'*');
    $enabled = \Illuminate\Support\Facades\Route::has($routeName);
    $href = $enabled ? route($routeName) : '#';
@endphp

@if ($enabled)
    <a href="{{ $href }}" class="flex flex-col items-center gap-0.5 rounded-lg py-1.5 text-[11px] font-medium {{ $active ? 'text-brand-700' : 'text-slate-500' }}">
        <x-icon :name="$icon" class="text-lg" />
        {{ $label }}
    </a>
@endif
