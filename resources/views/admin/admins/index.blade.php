<x-layouts.admin title="Administrateurs">
    <div class="mb-5 flex items-center justify-between">
        <div>
            <h1 class="text-xl font-bold text-slate-900">Administrateurs</h1>
            <p class="text-sm text-slate-500">Comptes ayant accès au panneau d'administration plateforme.</p>
        </div>
        <x-button :href="route('admin.admins.create')" size="sm"><x-icon name="plus" /> Ajouter</x-button>
    </div>

    <x-card :padded="false">
        <div class="divide-y divide-slate-100">
            @foreach ($admins as $admin)
                <div class="flex items-center justify-between px-5 py-3">
                    <div>
                        <p class="text-sm font-semibold text-slate-800">
                            {{ $admin->name }}
                            @if ($admin->id === auth('admin')->id())
                                <span class="text-xs font-normal text-slate-400">(vous)</span>
                            @endif
                        </p>
                        <p class="text-xs text-slate-400">{{ $admin->email }}</p>
                    </div>
                    @if ($admin->id !== auth('admin')->id())
                        <form method="POST" action="{{ route('admin.admins.destroy', $admin) }}" onsubmit="return confirm('Supprimer ce compte administrateur ?');">
                            @csrf
                            @method('DELETE')
                            <button type="submit" class="text-sm font-medium text-red-500 hover:underline">Supprimer</button>
                        </form>
                    @endif
                </div>
            @endforeach
        </div>
    </x-card>

    <div class="mt-5">{{ $admins->links() }}</div>
</x-layouts.admin>
