<x-layouts.app title="Inviter un employé">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Inviter un employé</h2>
        <p class="text-sm text-slate-500">Un e-mail lui sera envoyé pour définir son mot de passe.</p>
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
        <form method="POST" action="{{ route('employees.store') }}" class="space-y-4">
            @csrf

            <div>
                <x-label for="name">Nom complet</x-label>
                <x-input id="name" name="name" value="{{ old('name') }}" required autofocus />
            </div>

            <div>
                <x-label for="email">Adresse e-mail</x-label>
                <x-input id="email" type="email" name="email" value="{{ old('email') }}" required />
            </div>

            <div>
                <x-label for="phone">Téléphone (optionnel)</x-label>
                <x-input id="phone" name="phone" value="{{ old('phone') }}" />
            </div>

            <div>
                <x-label for="role">Rôle</x-label>
                <select id="role" name="role" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400" required>
                    @foreach ($roles as $role)
                        <option value="{{ $role->slug }}" @selected(old('role') === $role->slug)>{{ $role->name }}</option>
                    @endforeach
                </select>
                <p class="mt-1 text-xs text-slate-400">
                    Manager : accès presque complet. Vendeur : ventes et clients uniquement. Comptable : rapports et données financières en lecture.
                </p>
            </div>

            <div class="flex items-center gap-3 pt-2">
                <x-button type="submit">Envoyer l'invitation</x-button>
                <x-button :href="route('employees.index')" variant="ghost" type="button">Annuler</x-button>
            </div>
        </form>
    </x-card>
</x-layouts.app>
