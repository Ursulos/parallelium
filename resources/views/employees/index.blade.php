<x-layouts.app title="Employés">
    <div class="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Employés</h2>
            <p class="text-sm text-slate-500">
                {{ $employees->total() }} membre{{ $employees->total() > 1 ? 's' : '' }}
                @if ($userLimit) sur {{ $userLimit }} autorisé{{ $userLimit > 1 ? 's' : '' }} (plan actuel) @endif
            </p>
        </div>
        @can('employees.manage')
            <x-button :href="route('employees.create')" size="sm"><x-icon name="plus" /> Inviter un employé</x-button>
        @endcan
    </div>

    @if (session('status'))
        <x-alert type="success" class="mb-4">{{ session('status') }}</x-alert>
    @endif
    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    <x-card :padded="false">
        <div class="divide-y divide-slate-100">
            @foreach ($employees as $employee)
                <div class="flex items-center justify-between gap-3 px-5 py-3">
                    <div class="flex min-w-0 items-center gap-3">
                        <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-50 text-sm font-semibold text-brand-700">
                            {{ strtoupper(substr($employee->name, 0, 1)) }}
                        </span>
                        <div class="min-w-0">
                            <p class="truncate text-sm font-semibold text-slate-800">
                                {{ $employee->name }}
                                @if ($employee->id === auth()->id())
                                    <span class="text-xs font-normal text-slate-400">(vous)</span>
                                @endif
                            </p>
                            <p class="truncate text-xs text-slate-400">{{ $employee->email }}</p>
                        </div>
                    </div>

                    <div class="flex shrink-0 items-center gap-3">
                        <x-badge tone="brand">{{ $employee->role?->name ?? '—' }}</x-badge>
                        @if (! $employee->is_active)
                            <x-badge tone="danger">Désactivé</x-badge>
                        @endif
                        @can('employees.manage')
                            @unless ($employee->isOwner())
                                <a href="{{ route('employees.edit', $employee) }}" class="text-sm font-medium text-brand-600 hover:underline">Modifier</a>
                                @if ($employee->is_active)
                                    <form method="POST" action="{{ route('employees.resend-invite', $employee) }}">
                                        @csrf
                                        <button type="submit" class="text-sm font-medium text-slate-500 hover:underline">Renvoyer l'invitation</button>
                                    </form>
                                @endif
                                @if ($employee->id !== auth()->id())
                                    <form method="POST" action="{{ route('employees.destroy', $employee) }}" onsubmit="return confirm('Désactiver cet employé ?');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="text-sm font-medium text-red-500 hover:underline">Désactiver</button>
                                    </form>
                                @endif
                            @endunless
                        @endcan
                    </div>
                </div>
            @endforeach
        </div>
    </x-card>

    <div class="mt-5">{{ $employees->links() }}</div>
</x-layouts.app>
