<x-layouts.admin title="Nouvel administrateur">
    <div class="mb-5">
        <h1 class="text-xl font-bold text-slate-900">Nouvel administrateur</h1>
    </div>

    <x-card>
        <form method="POST" action="{{ route('admin.admins.store') }}" class="space-y-4">
            @csrf
            <div>
                <x-label for="name">Nom</x-label>
                <x-input id="name" name="name" value="{{ old('name') }}" required autofocus />
            </div>
            <div>
                <x-label for="email">Adresse e-mail</x-label>
                <x-input id="email" type="email" name="email" value="{{ old('email') }}" required />
            </div>
            <div>
                <x-label for="password">Mot de passe</x-label>
                <x-input id="password" type="password" name="password" required />
            </div>
            <div>
                <x-label for="password_confirmation">Confirmer le mot de passe</x-label>
                <x-input id="password_confirmation" type="password" name="password_confirmation" required />
            </div>
            <div class="flex items-center gap-3 pt-2">
                <x-button type="submit">Créer le compte</x-button>
                <x-button :href="route('admin.admins.index')" variant="ghost" type="button">Annuler</x-button>
            </div>
        </form>
    </x-card>
</x-layouts.admin>
