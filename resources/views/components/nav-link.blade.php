@props(['routeName' => null, 'icon' => 'circle', 'label', 'permission' => null])

@php
    // Si l'utilisateur n'a pas la permission requise, l'élément de
    // navigation est totalement absent du rendu — jamais affiché grisé
    // ni cliquable pour finir sur un "non autorisé".
    if ($permission && ! auth()->user()?->can($permission)) {
        return;
    }

    $active = $routeName && request()->routeIs($routeName.'*');
    $enabled = $routeName && \Illuminate\Support\Facades\Route::has($routeName);
    $href = $enabled ? route($routeName) : '#';
@endphp

@if ($enabled)
    <a href="{{ $href }}"
       {{ $attributes->merge([
            'class' => 'group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition '
                . ($active ? 'bg-brand-50 text-brand-700' : 'text-slate-600 hover:bg-slate-100'),
       ]) }}>
        <x-icon :name="$icon" class="w-4 text-center text-base" />
        <span>{{ $label }}</span>
    </a>
@endif
