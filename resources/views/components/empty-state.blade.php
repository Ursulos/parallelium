@props(['icon' => 'package', 'title', 'description' => null])

<div {{ $attributes->merge(['class' => 'flex flex-col items-center justify-center rounded-2xl border border-dashed border-slate-200 bg-white px-6 py-14 text-center']) }}>
    <div class="mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-slate-50 text-2xl text-slate-400">
        <x-icon :name="$icon" />
    </div>
    <p class="text-base font-semibold text-slate-700">{{ $title }}</p>
    @if ($description)
        <p class="mt-1 max-w-sm text-sm text-slate-500">{{ $description }}</p>
    @endif
    @if (isset($action))
        <div class="mt-5">{{ $action }}</div>
    @endif
</div>