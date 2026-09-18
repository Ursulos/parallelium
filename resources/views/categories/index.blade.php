<x-layouts.app title="Catégories">
    <div class="mb-5 flex items-center justify-between">
        <div>
            <h2 class="text-xl font-bold text-slate-900">Catégories</h2>
            <p class="text-sm text-slate-500">Organisez vos produits par catégorie.</p>
        </div>

        <div x-data="{ open: false }">
            <x-button @click="open = true" size="sm">
                <x-icon name="plus" /> Nouvelle catégorie
            </x-button>

            <div x-show="open" x-cloak class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4">
                <div x-show="open" x-on:click.outside="open = false" x-transition class="w-full max-w-sm rounded-2xl bg-white p-5 shadow-xl">
                    <h3 class="mb-4 text-base font-semibold text-slate-800">Nouvelle catégorie</h3>
                    <form method="POST" action="{{ route('categories.store') }}" class="space-y-3">
                        @csrf
                        <div>
                            <x-label for="name">Nom</x-label>
                            <x-input id="name" name="name" required autofocus />
                        </div>
                        <div>
                            <x-label for="description">Description (optionnel)</x-label>
                            <x-input id="description" name="description" />
                        </div>
                        <div class="flex justify-end gap-2 pt-2">
                            <x-button type="button" variant="ghost" @click="open = false">Annuler</x-button>
                            <x-button type="submit">Enregistrer</x-button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    @if ($errors->any())
        <x-alert type="error" class="mb-4">{{ $errors->first() }}</x-alert>
    @endif

    @if ($categories->isEmpty())
        <x-empty-state
            icon="products"
            title="Aucune catégorie pour le moment."
            description="Créez votre première catégorie pour organiser vos produits." />
    @else
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            @foreach ($categories as $category)
                <x-card x-data="{ editing: false }">
                    <div x-show="!editing">
                        <div class="flex items-start justify-between">
                            <div>
                                <p class="font-semibold text-slate-800">{{ $category->name }}</p>
                                @if ($category->description)
                                    <p class="mt-0.5 text-sm text-slate-500">{{ $category->description }}</p>
                                @endif
                            </div>
                            <x-badge tone="brand">{{ $category->products_count }} produit{{ $category->products_count > 1 ? 's' : '' }}</x-badge>
                        </div>

                        <div class="mt-4 flex items-center gap-3 text-sm">
                            <button type="button" x-on:click="editing = true" class="font-medium text-brand-600 hover:underline">Modifier</button>
                            <form method="POST" action="{{ route('categories.destroy', $category) }}" onsubmit="return confirm('Supprimer cette catégorie ?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="font-medium text-red-500 hover:underline">Supprimer</button>
                            </form>
                        </div>
                    </div>

                    <form x-show="editing" x-cloak method="POST" action="{{ route('categories.update', $category) }}" class="space-y-2">
                        @csrf
                        @method('PUT')
                        <x-input name="name" value="{{ $category->name }}" required />
                        <x-input name="description" value="{{ $category->description }}" placeholder="Description" />
                        <div class="flex justify-end gap-2 pt-1">
                            <x-button type="button" variant="ghost" size="sm" x-on:click="editing = false">Annuler</x-button>
                            <x-button type="submit" size="sm">Enregistrer</x-button>
                        </div>
                    </form>
                </x-card>
            @endforeach
        </div>

        <div class="mt-5">{{ $categories->links() }}</div>
    @endif
</x-layouts.app>
