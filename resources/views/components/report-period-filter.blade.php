@props(['route'])

<form method="GET" x-data="{ period: '{{ request('period', 'month') }}' }" class="mb-5 flex flex-wrap items-center gap-2">
    <div class="flex rounded-xl border border-slate-200 p-1">
        @foreach (['today' => "Aujourd'hui", 'week' => 'Cette semaine', 'month' => 'Ce mois', 'custom' => 'Personnalisé'] as $value => $label)
            <label class="cursor-pointer rounded-lg px-3 py-1.5 text-sm font-medium transition"
                   :class="period === '{{ $value }}' ? 'bg-brand-gradient text-white' : 'text-slate-500 hover:bg-slate-50'">
                <input type="radio" name="period" value="{{ $value }}" x-model="period" class="hidden" @change="$el.closest('form').submit()">
                {{ $label }}
            </label>
        @endforeach
    </div>

    <template x-if="period === 'custom'">
        <div class="flex items-center gap-2">
            <input type="date" name="from" value="{{ request('from') }}" class="rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
            <span class="text-slate-400"><x-icon name="chevron-right" class="text-xs" /></span>
            <input type="date" name="to" value="{{ request('to') }}" class="rounded-xl border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400">
            <x-button type="submit" size="sm" variant="ghost">Appliquer</x-button>
        </div>
    </template>
</form>
