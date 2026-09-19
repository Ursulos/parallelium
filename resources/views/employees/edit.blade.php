<x-layouts.app title="Modifier l'employé">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">{{ $employee->name }}</h2>
    </div>

    @if ($errors->any())
        <x-alert type="error" class="mb-4">
            <ul class="list-inside list-disc space-y-1">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </x-alert>
    @endif

    <x-card>
        <form method="POST" action="{{ route('employees.update', $employee) }}" class="space-y-4">
            @csrf
            @method('PUT')

            <div>
                <x-label for="name">Nom complet</x-label>
                <x-input id="name" name="name" value="{{ old('name', $employee->name) }}" required autofocus />
            </div>

            <div>
                <x-label for="email">Adresse e-mail</x-label>
                <x-input id="email" type="email" name="email" value="{{ old('email', $employee->email) }}" required />
            </div>

            <div>
                <x-label for="phone">Téléphone</x-label>
                <x-input id="phone" name="phone" value="{{ old('phone', $employee->phone) }}" />
            </div>

            <div>
                <x-label for="role">Rôle</x-label>
                <select id="role" name="role" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
                    @foreach ($roles as $role)
                        <option value="{{ $role->slug }}" @selected(old('role', $employee->role?->slug) === $role->slug)>{{ $role->name }}</option>
                    @endforeach
                </select>
            </div>

            <label class="flex items-center gap-2 text-sm text-slate-600">
                <input type="checkbox" name="is_active" value="1" @checked(old('is_active', $employee->is_active)) class="rounded border-slate-300 text-brand-600 focus:ring-brand-400">
                Compte actif (peut se connecter)
            </label>

            <div class="flex items-center gap-3 pt-2">
                <x-button type="submit">Enregistrer les modifications</x-button>
                <x-button :href="route('employees.index')" variant="ghost" type="button">Annuler</x-button>
            </div>
        </form>
    </x-card>
</x-layouts.app>
