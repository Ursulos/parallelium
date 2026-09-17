@props(['title' => null])

<header class="sticky top-0 z-20 flex items-center justify-between border-b border-slate-100 bg-white/90 px-4 py-3 backdrop-blur lg:px-8 lg:py-4">
    <div>
        <h1 class="text-lg font-bold text-slate-900 lg:text-xl">{{ $title ?? 'Parallelium' }}</h1>
    </div>

    <div class="flex items-center gap-3">
        <button type="button" class="hidden h-10 w-10 items-center justify-center rounded-full text-slate-500 hover:bg-slate-100 sm:flex">
            🔔
        </button>

        <div x-data="{ open: false }" class="relative">
            <button type="button" x-on:click="open = !open" class="flex h-9 w-9 items-center justify-center rounded-full bg-brand-gradient text-sm font-semibold text-white">
                {{ strtoupper(substr(auth()->user()->name, 0, 1)) }}
            </button>

            <div x-show="open" x-on:click.outside="open = false" x-cloak
                 class="absolute right-0 mt-2 w-48 rounded-xl border border-slate-100 bg-white py-2 shadow-lg">
                <p class="truncate px-4 py-1 text-xs text-slate-400">{{ auth()->user()->email }}</p>
                <form method="POST" action="{{ route('logout') }}">
                    @csrf
                    <button type="submit" class="block w-full px-4 py-2 text-left text-sm text-red-600 hover:bg-red-50">
                        Se déconnecter
                    </button>
                </form>
            </div>
        </div>
    </div>
</header>
