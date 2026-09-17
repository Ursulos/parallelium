@props(['routeName' => null, 'icon' => 'circle', 'label'])

@php
    $active = $routeName && request()->routeIs($routeName.'*');
    $href = $routeName && \Illuminate\Support\Facades\Route::has($routeName) ? route($routeName) : '#';
    $enabled = $routeName && \Illuminate\Support\Facades\Route::has($routeName);
@endphp

<a href="{{ $href }}"
   @unless($enabled) aria-disabled="true" tabindex="-1" @endunless
   {{ $attributes->merge([
        'class' => 'group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition '
            . ($active
                ? 'bg-brand-50 text-brand-700'
                : ($enabled ? 'text-slate-600 hover:bg-slate-100' : 'text-slate-300 cursor-not-allowed')),
   ]) }}>
    <x-icon :name="$icon" class="w-4 text-center text-base" />
    <span>{{ $label }}</span>
    @unless($enabled)
        <span class="ml-auto text-[10px] font-semibold uppercase text-slate-300">bientôt</span>
    @endunless
</a>