@csrf
@if ($customer ?? null)
    @method('PUT')
@endif

<div class="grid gap-4 sm:grid-cols-2">
    <div class="sm:col-span-2">
        <x-label for="name">Nom du client</x-label>
        <x-input id="name" name="name" value="{{ old('name', $customer->name ?? '') }}" required autofocus />
    </div>

    <div>
        <x-label for="phone">Téléphone</x-label>
        <x-input id="phone" name="phone" value="{{ old('phone', $customer->phone ?? '') }}" placeholder="034 xx xxx xx" />
    </div>

    <div>
        <x-label for="email">E-mail</x-label>
        <x-input id="email" type="email" name="email" value="{{ old('email', $customer->email ?? '') }}" placeholder="Optionnel" />
    </div>

    <div class="sm:col-span-2">
        <x-label for="address">Adresse</x-label>
        <x-input id="address" name="address" value="{{ old('address', $customer->address ?? '') }}" />
    </div>

    <div>
        <x-label for="credit_limit">Limite de crédit (optionnel)</x-label>
        <x-input id="credit_limit" type="number" step="0.01" min="0" name="credit_limit" value="{{ old('credit_limit', $customer->credit_limit ?? '') }}" placeholder="Aucune limite" />
    </div>

    <div class="sm:col-span-2">
        <x-label for="notes">Notes</x-label>
        <textarea id="notes" name="notes" rows="3" class="w-full rounded-xl border border-slate-200 px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-brand-400">{{ old('notes', $customer->notes ?? '') }}</textarea>
    </div>
</div>

<div class="mt-6 flex items-center gap-3">
    <x-button type="submit">{{ ($customer ?? null) ? 'Enregistrer les modifications' : 'Ajouter le client' }}</x-button>
    <x-button :href="($customer ?? null) ? route('customers.show', $customer) : route('customers.index')" variant="ghost" type="button">Annuler</x-button>
</div>
