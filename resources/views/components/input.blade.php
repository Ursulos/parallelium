@props(['error' => null])

<input {{ $attributes->merge([
    'class' => 'w-full rounded-xl border px-4 py-3 text-base text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-brand-400 focus:border-brand-400 transition '
        . ($error ? 'border-red-400' : 'border-slate-200'),
]) }}>
