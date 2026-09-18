<x-layouts.app title="Modifier le produit">
    <div class="mb-5 flex items-center justify-between">
        <div>
            <h2 class="text-xl font-bold text-slate-900">{{ $product->name }}</h2>
            <p class="text-sm text-slate-500">
                Stock actuel : {{ $product->stock_quantity }} {{ $product->unit->label() }} —
                <a href="{{ route('stock.index', ['product_id' => $product->id]) }}" class="font-medium text-brand-600 hover:underline">ajuster le stock</a>
            </p>
        </div>
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
        <form method="POST" action="{{ route('products.update', $product) }}">
            @include('products._form')
        </form>
    </x-card>
</x-layouts.app>
