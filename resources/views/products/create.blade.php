<x-layouts.app title="Nouveau produit">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Nouveau produit</h2>
        <p class="text-sm text-slate-500">Le stock initial sera enregistré comme un mouvement traçable.</p>
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
        <form method="POST" action="{{ route('products.store') }}">
            @php($product = null)
            @include('products._form')
        </form>
    </x-card>
</x-layouts.app>
