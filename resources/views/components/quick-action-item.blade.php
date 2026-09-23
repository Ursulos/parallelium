@props(['routeName', 'icon', 'label', 'permission' => null])

@php
    if ($permission && ! auth()->user()?->can($permission)) {
        return;
    }

    $enabled = \Illuminate\Support\Facades\Route::has($routeName);
@endphp

@if ($enabled)
    <a href="{{ route($routeName) }}"
       class="flex flex-col items-center gap-2 rounded-2xl border border-slate-100 p-4 text-center active:scale-95 hover:bg-slate-50 transition">
        <x-icon :name="$icon" class="text-2xl" />
        <span class="text-xs font-medium text-slate-600">{{ $label }}</span>
    </a>
@endif
